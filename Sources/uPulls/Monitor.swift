import AppKit
import Combine

/// Owns the poll loop: fetch → store → diff → notify.
@MainActor
final class Monitor {
    private let store: Store
    private let client = GitHubClient()
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var settingsDebounce: AnyCancellable?

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
            Task { @MainActor in self?.refresh() }
        }

        refresh()
    }

    func refreshIfStale(olderThan seconds: TimeInterval = 20) {
        guard let last = store.lastRefresh else { refresh(); return }
        if Date().timeIntervalSince(last) > seconds { refresh() }
    }

    func refresh() {
        Task { await performRefresh() }
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
        guard !store.token.isEmpty else { store.lastError = nil; return }
        guard !store.repos.isEmpty else { store.prs = []; store.lastError = nil; return }

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

            let alerts = store.tracker.ingest(
                prs: result.prs,
                viewer: result.viewer,
                mutedRepos: store.mutedRepoKeys,
                fetchedRepos: result.fetchedRepos
            )
            guard !store.isSnoozed else { return }
            for alert in alerts { deliver(alert) }
        } catch {
            store.lastError = error.localizedDescription
        }
    }

    private func deliver(_ alert: Alert) {
        let notifier = Notifier.shared
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
            if store.isHidden(pr) { return }
            notifier.post(title: "\(pr.authorLogin) wants your review",
                          body: "#\(pr.number) \(pr.title)", subtitle: pr.repo,
                          url: pr.url, thread: pr.id)
        }
    }
}
