import AppKit
import Combine
import Network

/// Owns the poll loop: fetch → store → diff → notify.
@MainActor
final class Monitor {
    private let store: Store
    private let client = GitHubClient()
    private var timer: Timer?
    private var retryTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var settingsDebounce: AnyCancellable?

    /// Watches the link so a reconnect refreshes straight away instead of
    /// waiting out the rest of the poll interval.
    private let path = NWPathMonitor()
    private var pathSatisfied = true
    private var consecutiveFailures = 0

    /// Backoff after a failed refresh: a short blip heals in seconds, then it
    /// eases off and lets the regular poll timer take over.
    private static let retryDelays: [TimeInterval] = [5, 15, 45]

    /// A link that just came back is not necessarily usable: DNS and VPN need a
    /// moment, so a reconnect or a wake waits this long before fetching.
    private static let settleDelay: TimeInterval = 2

    init(store: Store) {
        self.store = store
    }

    func start() {
        reschedule()

        store.$pollInterval
            .dropFirst()
            .sink { [weak self] _ in self?.reschedule() }
            .store(in: &cancellables)

        // Token or repo list changed → refresh soon, but let typing settle.
        settingsDebounce = Publishers.CombineLatest(store.$token, store.$repos.map(\.count))
            .dropFirst()
            .debounce(for: .milliseconds(700), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleRefresh(in: Self.settleDelay) }
        }

        path.pathUpdateHandler = { [weak self] update in
            let satisfied = update.status == .satisfied
            Task { @MainActor in self?.pathChanged(satisfied: satisfied) }
        }
        path.start(queue: DispatchQueue(label: "com.upulls.path"))

        refresh()
    }

    /// Losing the link is reported immediately; getting it back schedules a
    /// catch-up fetch. Nothing happens when the path was already satisfied,
    /// so this never fires on top of the normal poll.
    private func pathChanged(satisfied: Bool) {
        let wasSatisfied = pathSatisfied
        pathSatisfied = satisfied
        guard satisfied else {
            store.isOffline = true
            return
        }
        guard !wasSatisfied else { return }
        consecutiveFailures = 0
        scheduleRefresh(in: Self.settleDelay)
    }

    func refreshIfStale(olderThan seconds: TimeInterval = 20) {
        guard let last = store.lastRefresh else { refresh(); return }
        if Date().timeIntervalSince(last) > seconds { refresh() }
    }

    func refresh() {
        Task { await performRefresh() }
    }

    /// One-shot fetch, replacing any retry already queued.
    private func scheduleRefresh(in delay: TimeInterval) {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func scheduleRetry() {
        consecutiveFailures += 1
        // Past the backoff ladder the regular poll timer is soon enough;
        // stop stacking retries on a network that is simply down.
        guard consecutiveFailures <= Self.retryDelays.count else { return }
        scheduleRefresh(in: Self.retryDelays[consecutiveFailures - 1])
    }

    private func reschedule() {
        timer?.invalidate()
        let interval = max(15, store.pollInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = interval * 0.1
    }

    private func performRefresh() async {
        store.expireTimers()
        guard !store.isRefreshing else { return }
        guard !store.token.isEmpty else { store.lastError = nil; store.isOffline = false; return }
        guard !store.repos.isEmpty else { store.prs = []; store.lastError = nil; store.isOffline = false; return }

        store.isRefreshing = true
        defer { store.isRefreshing = false }

        let repos = store.repos.map(\.fullName)
        let token = store.token
        do {
            let result = try await client.fetch(repos: repos, token: token)
            // Keep stale PRs for repos that errored this round instead of blanking them.
            let failed = Set(result.repoErrors.keys)
            let kept = store.prs.filter { failed.contains($0.repoKey) }
            store.prs = result.prs + kept
            store.viewerLogin = result.viewer
            store.repoErrors = result.repoErrors
            store.lastRefresh = Date()
            store.lastError = nil
            store.isOffline = false
            consecutiveFailures = 0
            retryTimer?.invalidate()
            retryTimer = nil

            let alerts = store.tracker.ingest(
                prs: result.prs,
                viewer: result.viewer,
                mutedRepos: store.mutedRepoKeys,
                fetchedRepos: result.fetchedRepos
            )
            guard !store.isSnoozed else { return }
            for alert in alerts { deliver(alert) }
        } catch {
            // "The network isn't there" is not something the user can act on:
            // say so quietly and retry, and keep the last known PRs on screen.
            if NetworkFailure.isOffline(error) {
                store.isOffline = true
                store.lastError = nil
            } else {
                store.isOffline = false
                store.lastError = error.localizedDescription
            }
            scheduleRetry()
        }
    }

    private func deliver(_ alert: Alert) {
        let notifier = Notifier.shared
        // One rule for everything: a PR the list filters hide never notifies.
        // (Your own PRs and PRs waiting on your review are never hidden.)
        if store.isHidden(alert.pr) { return }
        switch alert {
        case .comment(let pr, let ev):
            guard store.notifyMyPRs, !(store.quietBots && ev.authorIsBot) else { return }
            notifier.post(title: "\(ev.authorLogin) commented",
                          body: "#\(pr.number) \(pr.title)", subtitle: pr.repo,
                          url: pr.url, thread: pr.id)

        case .changesRequested(let pr, let ev):
            guard store.notifyMyPRs, !(store.quietBots && ev.authorIsBot) else { return }
            notifier.post(title: "\(ev.authorLogin) requested changes",
                          body: "#\(pr.number) \(pr.title)", subtitle: pr.repo,
                          url: pr.url, thread: pr.id)

        case .approved(let pr, let ev):
            if store.quietBots && ev.authorIsBot { return }
            if store.fireworks { Fireworks.launch(store.fireworksTuning) }
            guard store.notifyMyPRs else { return }
            notifier.post(title: "🎉 \(ev.authorLogin) approved your PR",
                          body: "#\(pr.number) \(pr.title)", subtitle: pr.repo,
                          url: pr.url, thread: pr.id)

        case .reviewRequested(let pr):
            guard store.notifyReviewRequests else { return }
            // Renovate/Dependabot re-request reviews on every rebase; quiet bots covers that,
            // and anything the list filters hide shouldn't ping either.
            if store.quietBots && pr.isBotAuthored { return }
            notifier.post(title: "\(pr.authorLogin) wants your review",
                          body: "#\(pr.number) \(pr.title)", subtitle: pr.repo,
                          url: pr.url, thread: pr.id)
        }
    }
}
