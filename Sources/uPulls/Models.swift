import Foundation

/// A repository the user wants to keep an eye on.
struct TrackedRepo: Codable, Identifiable, Hashable {
    var fullName: String            // "owner/name"
    var mutedUntil: Date? = nil     // nil = not muted, .distantFuture = muted indefinitely

    var id: String { fullName }
    var key: String { fullName.lowercased() }

    var isMuted: Bool {
        guard let until = mutedUntil else { return false }
        return until > Date()
    }

    var isMutedIndefinitely: Bool { mutedUntil == .distantFuture }

    var url: URL { URL(string: "https://github.com/\(fullName)")! }
    var pullsURL: URL { URL(string: "https://github.com/\(fullName)/pulls")! }

    /// Accepts "owner/repo", a github.com URL, or an SSH remote and returns "owner/repo".
    static func parse(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let range = s.range(of: "github.com[:/]", options: .regularExpression) {
            s = String(s[range.upperBound...])
        }
        let parts = s.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else { return nil }
        var name = parts[1]
        if name.hasSuffix(".git") { name.removeLast(4) }
        let owner = parts[0]
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard owner.unicodeScalars.allSatisfy(allowed.contains),
              name.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return "\(owner)/\(name)"
    }
}

enum ReviewDecision: String, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
    case none
}

enum CheckState: String, Sendable {
    case success, failure, pending, none
}

struct ActivityEvent: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case comment
        case approved
        case changesRequested
        case reviewComment
        case other
    }
    let id: String
    let kind: Kind
    let authorLogin: String
    let authorIsBot: Bool
    let createdAt: Date
}

struct PullRequest: Identifiable, Hashable, Sendable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repo: String                // "owner/name" as GitHub reports it
    let authorLogin: String
    let authorAvatar: URL?
    let authorIsBot: Bool
    let isDraft: Bool
    let createdAt: Date
    let updatedAt: Date
    let reviewDecision: ReviewDecision
    let checks: CheckState
    let requestedReviewers: [String]
    let events: [ActivityEvent]

    var repoKey: String { repo.lowercased() }

    /// Dependabot, Renovate, GitHub Actions, Copilot… anything that isn't a person.
    var isBotAuthored: Bool { Self.isBot(login: authorLogin, typeIsBot: authorIsBot) }

    static func isBot(login: String, typeIsBot: Bool) -> Bool {
        if typeIsBot { return true }
        let l = login.lowercased()
        if l.hasSuffix("[bot]") { return true }
        return ["dependabot", "renovate", "renovate-bot", "github-actions", "copilot", "copilot-pull-request-reviewer"].contains(l)
    }

    func isAuthored(by login: String?) -> Bool {
        guard let login else { return false }
        return authorLogin.caseInsensitiveCompare(login) == .orderedSame
    }

    func isReviewRequested(from login: String?) -> Bool {
        guard let login else { return false }
        return requestedReviewers.contains { $0.caseInsensitiveCompare(login) == .orderedSame }
    }
}

/// Human-friendly short age: "now", "4m", "3h", "2d", "5mo".
func shortAge(_ date: Date, now: Date = Date()) -> String {
    let s = max(0, Int(now.timeIntervalSince(date)))
    if s < 60 { return "now" }
    let m = s / 60
    if m < 60 { return "\(m)m" }
    let h = m / 60
    if h < 24 { return "\(h)h" }
    let d = h / 24
    if d < 30 { return "\(d)d" }
    return "\(d / 30)mo"
}
