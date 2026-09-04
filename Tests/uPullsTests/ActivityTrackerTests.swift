import XCTest
@testable import uPulls

final class ActivityTrackerTests: XCTestCase {
    private func event(_ id: String, _ kind: ActivityEvent.Kind, by author: String, bot: Bool = false) -> ActivityEvent {
        ActivityEvent(id: id, kind: kind, authorLogin: author, authorIsBot: bot, createdAt: Date())
    }

    private func pr(_ id: String, repo: String = "acme/app", author: String = "me", reviewers: [String] = [], events: [ActivityEvent] = []) -> PullRequest {
        PullRequest(id: id, number: 1, title: "t", url: URL(string: "https://github.com/\(repo)/pull/1")!, repo: repo,
                    authorLogin: author, authorAvatar: nil, authorIsBot: false, isDraft: false,
                    createdAt: Date(), updatedAt: Date(), reviewDecision: .none, checks: .none,
                    requestedReviewers: reviewers, events: events)
    }

    func testFirstFetchIsSilentBaseline() {
        var t = ActivityTracker()
        let prs = [pr("p1", events: [event("e1", .comment, by: "bob"), event("e2", .approved, by: "bob")])]
        let alerts = t.ingest(prs: prs, viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        XCTAssertTrue(alerts.isEmpty)
        XCTAssertTrue(t.baselined.contains("acme/app"))
    }

    func testNewEventsOnMyPRAlertOnce() {
        var t = ActivityTracker()
        _ = t.ingest(prs: [pr("p1")], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        let updated = [pr("p1", events: [event("e1", .comment, by: "bob"), event("e2", .approved, by: "carol")])]
        let alerts = t.ingest(prs: updated, viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        XCTAssertEqual(alerts.count, 2)
        guard case .comment(_, let ev) = alerts[0] else { return XCTFail("expected comment") }
        XCTAssertEqual(ev.authorLogin, "bob")
        guard case .approved = alerts[1] else { return XCTFail("expected approval") }
        // Same data again: nothing new.
        XCTAssertTrue(t.ingest(prs: updated, viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"]).isEmpty)
    }

    func testOwnActivityAndOthersPRsAreIgnored() {
        var t = ActivityTracker()
        _ = t.ingest(prs: [pr("p1"), pr("p2", author: "bob")], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        let updated = [
            pr("p1", events: [event("e1", .comment, by: "ME")]),          // my own comment (case-insensitive)
            pr("p2", author: "bob", events: [event("e2", .approved, by: "carol")]), // not my PR
        ]
        XCTAssertTrue(t.ingest(prs: updated, viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"]).isEmpty)
    }

    func testMutedRepoSwallowsEventsForGood() {
        var t = ActivityTracker()
        _ = t.ingest(prs: [pr("p1")], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        let updated = [pr("p1", events: [event("e1", .comment, by: "bob")])]
        XCTAssertTrue(t.ingest(prs: updated, viewer: "me", mutedRepos: ["acme/app"], fetchedRepos: ["acme/app"]).isEmpty)
        // Unmuting later must not replay what happened while muted.
        XCTAssertTrue(t.ingest(prs: updated, viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"]).isEmpty)
    }

    func testReviewRequestAlertsAndReArmsWhenCleared() {
        var t = ActivityTracker()
        _ = t.ingest(prs: [pr("p1", author: "bob")], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        var alerts = t.ingest(prs: [pr("p1", author: "bob", reviewers: ["me"])], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        XCTAssertEqual(alerts.count, 1)
        guard case .reviewRequested = alerts[0] else { return XCTFail("expected review request") }
        alerts = t.ingest(prs: [pr("p1", author: "bob", reviewers: ["me"])], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        XCTAssertTrue(alerts.isEmpty)
        _ = t.ingest(prs: [pr("p1", author: "bob")], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        alerts = t.ingest(prs: [pr("p1", author: "bob", reviewers: ["me"])], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        XCTAssertEqual(alerts.count, 1)
    }

    func testFailedRepoKeepsItsHistory() {
        var t = ActivityTracker()
        let seen = [pr("p1", events: [event("e1", .comment, by: "bob")])]
        _ = t.ingest(prs: seen, viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        // A round where acme/app errored: it is absent from prs and fetchedRepos.
        _ = t.ingest(prs: [], viewer: "me", mutedRepos: [], fetchedRepos: [])
        // Back to normal: the old comment must not resurface as new.
        XCTAssertTrue(t.ingest(prs: seen, viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"]).isEmpty)
    }

    func testForgetRepoResetsBaseline() {
        var t = ActivityTracker()
        _ = t.ingest(prs: [pr("p1", events: [event("e1", .comment, by: "bob")])], viewer: "me", mutedRepos: [], fetchedRepos: ["acme/app"])
        t.forget(repo: "acme/app")
        XCTAssertFalse(t.baselined.contains("acme/app"))
        XCTAssertNil(t.seenEvents["acme/app"])
    }
}

final class TrackedRepoParseTests: XCTestCase {
    func testAcceptsCommonShapes() {
        XCTAssertEqual(TrackedRepo.parse("vLX42/uHosts"), "vLX42/uHosts")
        XCTAssertEqual(TrackedRepo.parse("  https://github.com/vLX42/uHosts  "), "vLX42/uHosts")
        XCTAssertEqual(TrackedRepo.parse("https://github.com/vLX42/uHosts/pull/12"), "vLX42/uHosts")
        XCTAssertEqual(TrackedRepo.parse("git@github.com:vLX42/uHosts.git"), "vLX42/uHosts")
    }

    func testRejectsJunk() {
        XCTAssertNil(TrackedRepo.parse(""))
        XCTAssertNil(TrackedRepo.parse("uHosts"))
        XCTAssertNil(TrackedRepo.parse("owner/re po"))
        XCTAssertNil(TrackedRepo.parse("owner/\"x\""))
    }
}

final class BotDetectionTests: XCTestCase {
    func testKnownBots() {
        XCTAssertTrue(PullRequest.isBot(login: "dependabot", typeIsBot: true))
        XCTAssertTrue(PullRequest.isBot(login: "renovate", typeIsBot: false))
        XCTAssertTrue(PullRequest.isBot(login: "something[bot]", typeIsBot: false))
        XCTAssertTrue(PullRequest.isBot(login: "copilot-pull-request-reviewer", typeIsBot: true))
        XCTAssertFalse(PullRequest.isBot(login: "vLX42", typeIsBot: false))
    }
}
