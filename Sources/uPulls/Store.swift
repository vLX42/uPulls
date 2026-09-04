import Foundation
import Combine

/// Settings + live state. Everything user-configurable persists to
/// UserDefaults on write; the token lives in the Keychain.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    // MARK: Settings

    @Published var repos: [TrackedRepo] { didSet { persist(repos, .repos) } }
    @Published var token: String { didSet { if token != oldValue, !Self.keychainDisabled { Keychain.write(token) } } }
    @Published var hideBotPRs: Bool { didSet { defaults.set(hideBotPRs, forKey: Key.hideBotPRs.rawValue) } }
    @Published var quietBots: Bool { didSet { defaults.set(quietBots, forKey: Key.quietBots.rawValue) } }
    @Published var notifyMyPRs: Bool { didSet { defaults.set(notifyMyPRs, forKey: Key.notifyMyPRs.rawValue) } }
    @Published var notifyReviewRequests: Bool { didSet { defaults.set(notifyReviewRequests, forKey: Key.notifyReviewRequests.rawValue) } }
    @Published var fireworks: Bool { didSet { defaults.set(fireworks, forKey: Key.fireworks.rawValue) } }
    @Published var fireworksTuning: FireworksTuning { didSet { persist(fireworksTuning, .fireworksTuning) } }
    @Published var showCount: Bool { didSet { defaults.set(showCount, forKey: Key.showCount.rawValue) } }
    @Published var pollInterval: TimeInterval { didSet { defaults.set(pollInterval, forKey: Key.pollInterval.rawValue) } }
    @Published var snoozedUntil: Date? { didSet { defaults.set(snoozedUntil, forKey: Key.snoozedUntil.rawValue) } }

    // MARK: Live state

    @Published var prs: [PullRequest] = []
    @Published var viewerLogin: String? = nil
    @Published var repoErrors: [String: String] = [:]
    @Published var lastError: String? = nil
    @Published var lastRefresh: Date? = nil
    @Published var isRefreshing = false

    var tracker: ActivityTracker { didSet { persist(tracker, .tracker) } }

    private let defaults = UserDefaults.standard

    /// `UPULLS_NO_KEYCHAIN=1` keeps the token in memory only (dev runs: an
    /// ad-hoc rebuild would otherwise trigger a keychain prompt every launch).
    static let keychainDisabled = ProcessInfo.processInfo.environment["UPULLS_NO_KEYCHAIN"] == "1"

    private enum Key: String {
        case repos, hideBotPRs, quietBots, notifyMyPRs, notifyReviewRequests, fireworks, fireworksTuning, showCount, pollInterval, snoozedUntil, tracker
    }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            Key.hideBotPRs.rawValue: true,
            Key.quietBots.rawValue: true,
            Key.notifyMyPRs.rawValue: true,
            Key.notifyReviewRequests.rawValue: true,
            Key.fireworks.rawValue: true,
            Key.showCount.rawValue: true,
            Key.pollInterval.rawValue: 60.0,
        ])
        repos = Self.load([TrackedRepo].self, .repos) ?? []
        tracker = Self.load(ActivityTracker.self, .tracker) ?? ActivityTracker()
        fireworksTuning = Self.load(FireworksTuning.self, .fireworksTuning) ?? FireworksTuning()
        token = Self.keychainDisabled ? "" : (Keychain.read() ?? "")
        hideBotPRs = d.bool(forKey: Key.hideBotPRs.rawValue)
        quietBots = d.bool(forKey: Key.quietBots.rawValue)
        notifyMyPRs = d.bool(forKey: Key.notifyMyPRs.rawValue)
        notifyReviewRequests = d.bool(forKey: Key.notifyReviewRequests.rawValue)
        fireworks = d.bool(forKey: Key.fireworks.rawValue)
        showCount = d.bool(forKey: Key.showCount.rawValue)
        pollInterval = d.double(forKey: Key.pollInterval.rawValue)
        snoozedUntil = d.object(forKey: Key.snoozedUntil.rawValue) as? Date
    }

    // MARK: Derived

    var isSnoozed: Bool {
        guard let until = snoozedUntil else { return false }
        return until > Date()
    }

    var mutedRepoKeys: Set<String> { Set(repos.filter(\.isMuted).map(\.key)) }

    /// PRs for one repo after the bot filter, mine first, then ones waiting on me, then newest activity.
    func visiblePRs(for repo: TrackedRepo) -> [PullRequest] {
        prs.filter { $0.repoKey == repo.key && !(hideBotPRs && $0.isBotAuthored) }
            .sorted { a, b in
                let ra = rank(a), rb = rank(b)
                if ra != rb { return ra < rb }
                return a.updatedAt > b.updatedAt
            }
    }

    func hiddenBotCount(for repo: TrackedRepo) -> Int {
        guard hideBotPRs else { return 0 }
        return prs.filter { $0.repoKey == repo.key && $0.isBotAuthored }.count
    }

    /// What the menu-bar badge shows: open PRs across unmuted repos.
    var badgeCount: Int {
        repos.filter { !$0.isMuted }.reduce(0) { $0 + visiblePRs(for: $1).count }
    }

    private func rank(_ pr: PullRequest) -> Int {
        if pr.isAuthored(by: viewerLogin) { return 0 }
        if pr.isReviewRequested(from: viewerLogin) { return 1 }
        return 2
    }

    // MARK: Mutations

    @discardableResult
    func addRepo(_ raw: String) -> Bool {
        guard let name = TrackedRepo.parse(raw),
              !repos.contains(where: { $0.key == name.lowercased() }) else { return false }
        repos.append(TrackedRepo(fullName: name))
        return true
    }

    func removeRepo(_ repo: TrackedRepo) {
        repos.removeAll { $0.key == repo.key }
        prs.removeAll { $0.repoKey == repo.key }
        repoErrors[repo.key] = nil
        tracker.forget(repo: repo.key)
    }

    func mute(_ repo: TrackedRepo, until: Date?) {
        guard let i = repos.firstIndex(where: { $0.key == repo.key }) else { return }
        repos[i].mutedUntil = until
    }

    /// Drop expired mutes/snoozes so `didSet` persistence and UI stay honest.
    func expireTimers() {
        let now = Date()
        if let s = snoozedUntil, s <= now { snoozedUntil = nil }
        for i in repos.indices where repos[i].mutedUntil.map({ $0 <= now }) == true {
            repos[i].mutedUntil = nil
        }
    }

    // MARK: Persistence helpers

    private func persist<T: Encodable>(_ value: T, _ key: Key) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key.rawValue)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

/// "Until tomorrow" for mutes and snoozes: next 09:00.
func tomorrowMorning(from now: Date = Date()) -> Date {
    Calendar.current.nextDate(after: now, matching: DateComponents(hour: 9, minute: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(16 * 3600)
}
