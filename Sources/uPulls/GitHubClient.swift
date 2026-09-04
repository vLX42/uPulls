import Foundation

struct FetchResult: Sendable {
    let viewer: String
    let prs: [PullRequest]
    /// Repos (lowercased "owner/name") that came back successfully this round.
    let fetchedRepos: Set<String>
    /// Per-repo error messages keyed by lowercased "owner/name".
    let repoErrors: [String: String]
}

enum GitHubError: LocalizedError {
    case noToken
    case http(Int)
    case graphQL(String)
    case malformed

    var errorDescription: String? {
        switch self {
        case .noToken: return "No GitHub token configured"
        case .http(401): return "GitHub rejected the token (401)"
        case .http(let code): return "GitHub returned HTTP \(code)"
        case .graphQL(let msg): return msg
        case .malformed: return "Unexpected response from GitHub"
        }
    }
}

/// One GraphQL round-trip per refresh: every tracked repo is an aliased
/// `repository(owner:name:)` field so a bad repo fails alone instead of
/// poisoning the whole request.
struct GitHubClient: Sendable {
    private static let endpoint = URL(string: "https://api.github.com/graphql")!
    private static let prsPerRepo = 50
    private static let timelineWindow = 20

    private static let fragment = """
    fragment PR on PullRequest {
      id number title url isDraft createdAt updatedAt reviewDecision
      author { __typename login avatarUrl(size: 40) }
      reviewRequests(first: 10) { nodes { requestedReviewer { __typename ... on User { login } } } }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
      timelineItems(last: \(timelineWindow), itemTypes: [ISSUE_COMMENT, PULL_REQUEST_REVIEW]) {
        nodes {
          __typename
          ... on IssueComment { id createdAt author { __typename login } }
          ... on PullRequestReview { id createdAt state body author { __typename login } comments { totalCount } }
        }
      }
    }
    """

    func fetch(repos: [String], token: String) async throws -> FetchResult {
        guard !token.isEmpty else { throw GitHubError.noToken }

        var fields = ["viewer { login }"]
        for (i, full) in repos.enumerated() {
            let parts = full.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            fields.append("""
            r\(i): repository(owner: "\(parts[0])", name: "\(parts[1])") {
              nameWithOwner
              pullRequests(states: OPEN, first: \(Self.prsPerRepo), orderBy: {field: UPDATED_AT, direction: DESC}) { nodes { ...PR } }
            }
            """)
        }
        let query = Self.fragment + "\nquery {\n" + fields.joined(separator: "\n") + "\n}"

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("uPulls", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GitHubError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch let err as DecodingError {
            throw GitHubError.graphQL("Unexpected response shape: \(Self.describe(err))")
        }

        guard let payload = envelope.data else {
            let msg = envelope.errors?.first?.message ?? "empty response"
            throw GitHubError.graphQL(msg)
        }
        guard let viewer = payload.viewer?.login else { throw GitHubError.malformed }

        // Map alias -> requested name so errors land on the right repo.
        var repoErrors: [String: String] = [:]
        for err in envelope.errors ?? [] {
            guard let alias = err.path?.first, alias.hasPrefix("r"),
                  let idx = Int(alias.dropFirst()), repos.indices.contains(idx) else { continue }
            repoErrors[repos[idx].lowercased()] = err.message
        }

        var prs: [PullRequest] = []
        var fetched: Set<String> = []
        for (i, full) in repos.enumerated() {
            guard let node = payload.repos["r\(i)"] ?? nil else {
                if repoErrors[full.lowercased()] == nil {
                    repoErrors[full.lowercased()] = "Repository not found or no access"
                }
                continue
            }
            fetched.insert(full.lowercased())
            for pr in node.pullRequests.nodes.compactMap({ $0 }) {
                prs.append(Self.map(pr, repo: node.nameWithOwner))
            }
        }
        return FetchResult(viewer: viewer, prs: prs, fetchedRepos: fetched, repoErrors: repoErrors)
    }

    private static func describe(_ err: DecodingError) -> String {
        func path(_ c: DecodingError.Context) -> String { c.codingPath.map(\.stringValue).joined(separator: ".") }
        switch err {
        case .keyNotFound(let k, let c): return "missing \(k.stringValue) at \(path(c))"
        case .valueNotFound(_, let c): return "null at \(path(c))"
        case .typeMismatch(_, let c): return "type mismatch at \(path(c))"
        case .dataCorrupted(let c): return "corrupt at \(path(c)): \(c.debugDescription)"
        @unknown default: return String(describing: err)
        }
    }

    // MARK: - Mapping

    private static func map(_ n: PRNode, repo: String) -> PullRequest {
        let events: [ActivityEvent] = n.timelineItems.nodes.compactMap { item -> ActivityEvent? in
            guard let item, let id = item.id, let createdAt = item.createdAt else { return nil }
            let login = item.author?.login ?? "ghost"
            let isBot = item.author?.typename == "Bot"
            let kind: ActivityEvent.Kind
            switch item.typename {
            case "IssueComment":
                kind = .comment
            case "PullRequestReview":
                switch item.state {
                case "APPROVED": kind = .approved
                case "CHANGES_REQUESTED": kind = .changesRequested
                case "COMMENTED":
                    // GitHub emits empty COMMENTED reviews as containers for thread replies
                    // that were already counted; only a review with actual content is news.
                    let hasBody = !(item.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let inline = item.comments?.totalCount ?? 0
                    kind = (hasBody || inline > 0) ? .reviewComment : .other
                default: kind = .other
                }
            default:
                kind = .other
            }
            return ActivityEvent(id: id, kind: kind, authorLogin: login, authorIsBot: isBot, createdAt: createdAt)
        }

        let checks: CheckState
        switch n.commits.nodes.first??.commit.statusCheckRollup?.state {
        case "SUCCESS": checks = .success
        case "FAILURE", "ERROR": checks = .failure
        case "PENDING", "EXPECTED": checks = .pending
        default: checks = .none
        }

        return PullRequest(
            id: n.id,
            number: n.number,
            title: n.title,
            url: n.url,
            repo: repo,
            authorLogin: n.author?.login ?? "ghost",
            authorAvatar: n.author?.avatarUrl,
            authorIsBot: n.author?.typename == "Bot",
            isDraft: n.isDraft,
            createdAt: n.createdAt,
            updatedAt: n.updatedAt,
            reviewDecision: ReviewDecision(rawValue: n.reviewDecision ?? "") ?? .none,
            checks: checks,
            requestedReviewers: n.reviewRequests.nodes.compactMap { $0?.requestedReviewer?.login },
            events: events
        )
    }

    // MARK: - Wire format

    private struct Envelope: Decodable {
        let data: Payload?
        let errors: [GQLError]?
    }

    private struct GQLError: Decodable {
        let message: String
        let path: [String]?

        private enum CodingKeys: String, CodingKey { case message, path }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            message = try c.decode(String.self, forKey: .message)
            // Path elements may be strings or ints; keep the strings.
            if var arr = try? c.nestedUnkeyedContainer(forKey: .path) {
                var out: [String] = []
                while !arr.isAtEnd {
                    if let s = try? arr.decode(String.self) { out.append(s) }
                    else if let i = try? arr.decode(Int.self) { out.append(String(i)) }
                    else { _ = try? arr.decode(Empty.self) }
                }
                path = out
            } else {
                path = nil
            }
        }
        private struct Empty: Decodable {}
    }

    private struct Payload: Decodable {
        let viewer: Viewer?
        /// alias -> repo (nil when GitHub nulled it out because of an error)
        let repos: [String: RepoNode?]

        private struct Key: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            var viewer: Viewer? = nil
            var repos: [String: RepoNode?] = [:]
            for key in c.allKeys {
                if key.stringValue == "viewer" {
                    viewer = try c.decodeIfPresent(Viewer.self, forKey: key)
                } else {
                    repos[key.stringValue] = try c.decodeIfPresent(RepoNode.self, forKey: key)
                }
            }
            self.viewer = viewer
            self.repos = repos
        }
    }

    private struct Viewer: Decodable { let login: String }

    private struct Actor: Decodable {
        let typename: String
        let login: String
        let avatarUrl: URL?
        private enum CodingKeys: String, CodingKey { case typename = "__typename", login, avatarUrl }
    }

    private struct Connection<T: Decodable>: Decodable { let nodes: [T?] }

    private struct RepoNode: Decodable {
        let nameWithOwner: String
        let pullRequests: Connection<PRNode>
    }

    private struct PRNode: Decodable {
        let id: String
        let number: Int
        let title: String
        let url: URL
        let isDraft: Bool
        let createdAt: Date
        let updatedAt: Date
        let reviewDecision: String?
        let author: Actor?
        let reviewRequests: Connection<ReviewRequestNode>
        let commits: Connection<CommitNode>
        let timelineItems: Connection<TimelineNode>
    }

    private struct ReviewRequestNode: Decodable { let requestedReviewer: Reviewer? }
    private struct Reviewer: Decodable { let login: String? }
    private struct CommitNode: Decodable { let commit: Commit }
    private struct Commit: Decodable { let statusCheckRollup: Rollup? }
    private struct Rollup: Decodable { let state: String }
    private struct Count: Decodable { let totalCount: Int }

    private struct TimelineNode: Decodable {
        let typename: String
        let id: String?
        let createdAt: Date?
        let state: String?
        let body: String?
        let author: Actor?
        let comments: Count?
        private enum CodingKeys: String, CodingKey {
            case typename = "__typename", id, createdAt, state, body, author, comments
        }
    }
}
