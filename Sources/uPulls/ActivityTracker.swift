import Foundation

/// Something worth telling the user about.
enum Alert {
    case comment(PullRequest, by: ActivityEvent)
    case approved(PullRequest, by: ActivityEvent)
    case changesRequested(PullRequest, by: ActivityEvent)
    case reviewRequested(PullRequest)
}

/// Pure bookkeeping: which timeline events and review requests we've already
/// seen, so each poll yields only the new ones. Keyed per repo so a repo that
/// errors out for a round doesn't lose its history.
struct ActivityTracker: Codable {
    /// repoKey -> event ids
    var seenEvents: [String: Set<String>] = [:]
    /// PR ids where a review request from the viewer has already been announced
    var seenReviewRequests: Set<String> = []
    /// repos whose first successful fetch has happened (no alerts for the backlog)
    var baselined: Set<String> = []

    mutating func ingest(prs: [PullRequest], viewer: String, mutedRepos: Set<String>, fetchedRepos: Set<String>) -> [Alert] {
        var alerts: [Alert] = []
        var currentEvents: [String: Set<String>] = [:]
        var currentPRs: Set<String> = []

        for pr in prs {
            let repo = pr.repoKey
            let isBaseline = !baselined.contains(repo)
            let muted = mutedRepos.contains(repo)
            let mine = pr.isAuthored(by: viewer)
            currentPRs.insert(pr.id)

            for ev in pr.events {
                currentEvents[repo, default: []].insert(ev.id)
                if seenEvents[repo]?.contains(ev.id) == true { continue }
                seenEvents[repo, default: []].insert(ev.id)
                guard !isBaseline, !muted, mine,
                      ev.authorLogin.caseInsensitiveCompare(viewer) != .orderedSame else { continue }
                switch ev.kind {
                case .comment, .reviewComment: alerts.append(.comment(pr, by: ev))
                case .approved: alerts.append(.approved(pr, by: ev))
                case .changesRequested: alerts.append(.changesRequested(pr, by: ev))
                case .other: break
                }
            }

            if pr.isReviewRequested(from: viewer) {
                if !seenReviewRequests.contains(pr.id) {
                    seenReviewRequests.insert(pr.id)
                    if !isBaseline, !muted, !mine { alerts.append(.reviewRequested(pr)) }
                }
            } else {
                // Cleared or re-requested later: announce again next time.
                seenReviewRequests.remove(pr.id)
            }
        }

        baselined.formUnion(fetchedRepos)
        for repo in fetchedRepos {
            seenEvents[repo] = currentEvents[repo] ?? []
        }
        seenReviewRequests.formIntersection(currentPRs)
        return alerts
    }

    mutating func forget(repo: String) {
        seenEvents[repo] = nil
        baselined.remove(repo)
    }
}
