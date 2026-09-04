import XCTest
@testable import uPulls

@MainActor
final class FilterTests: XCTestCase {
    private let store = Store.shared

    private func pr(_ n: Int, author: String = "bob", draft: Bool = false,
                    decision: ReviewDecision = .none, reviewers: [String] = []) -> PullRequest {
        PullRequest(id: "p\(n)", number: n, title: "t", url: URL(string: "https://example.com")!, repo: "acme/app",
                    authorLogin: author, authorAvatar: nil, authorIsBot: author == "renovate", isDraft: draft,
                    createdAt: Date(), updatedAt: Date(), reviewDecision: decision, checks: .none,
                    requestedReviewers: reviewers, events: [])
    }

    override func setUp() {
        store.viewerLogin = "me"
        store.hideBotPRs = true
        store.hideDraftPRs = false
        store.hideApprovedPRs = false
    }

    func testBotFilterNeverHidesYourOwn() {
        XCTAssertTrue(store.isHidden(pr(1, author: "renovate")))
        XCTAssertFalse(store.isHidden(pr(2, author: "me")))
        store.hideBotPRs = false
        XCTAssertFalse(store.isHidden(pr(1, author: "renovate")))
    }

    func testDraftFilter() {
        XCTAssertFalse(store.isHidden(pr(3, draft: true)))
        store.hideDraftPRs = true
        XCTAssertTrue(store.isHidden(pr(3, draft: true)))
        XCTAssertFalse(store.isHidden(pr(4, author: "me", draft: true)), "your own drafts always show")
        XCTAssertFalse(store.isHidden(pr(5)))
    }

    func testApprovedFilterKeepsYoursAndOnesWaitingOnYou() {
        let approved = pr(6, decision: .approved)
        XCTAssertFalse(store.isHidden(approved))
        store.hideApprovedPRs = true
        XCTAssertTrue(store.isHidden(approved))
        XCTAssertFalse(store.isHidden(pr(7, author: "me", decision: .approved)), "your own approved PR stays")
        XCTAssertFalse(store.isHidden(pr(8, decision: .approved, reviewers: ["ME"])), "still waiting on your review")
        XCTAssertFalse(store.isHidden(pr(9, decision: .changesRequested)))
        XCTAssertFalse(store.isHidden(pr(10)))
    }
}
