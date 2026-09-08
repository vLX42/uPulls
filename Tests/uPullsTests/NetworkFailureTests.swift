import XCTest
@testable import uPulls

final class NetworkFailureTests: XCTestCase {

    func testLinkProblemsCountAsOffline() {
        for code: URLError.Code in [.notConnectedToInternet, .cannotFindHost, .cannotConnectToHost,
                                    .dnsLookupFailed, .networkConnectionLost, .timedOut] {
            XCTAssertTrue(NetworkFailure.isOffline(URLError(code)), "\(code) should read as offline")
        }
    }

    func testGitHubProblemsAreNotOffline() {
        XCTAssertFalse(NetworkFailure.isOffline(GitHubError.http(401)))
        XCTAssertFalse(NetworkFailure.isOffline(GitHubError.graphQL("Bad credentials")))
        XCTAssertFalse(NetworkFailure.isOffline(GitHubError.malformed))
        // A genuine server response we can act on, not a missing network.
        XCTAssertFalse(NetworkFailure.isOffline(URLError(.badServerResponse)))
    }

    /// The failure this was written for: a name that will not resolve, the way
    /// api.github.com behaves when the DNS cache goes stale after a reconnect.
    func testRealDNSFailureReadsAsOffline() async throws {
        let url = URL(string: "https://upulls-nonexistent-host.invalid/graphql")!
        do {
            _ = try await URLSession(configuration: .ephemeral).data(from: url)
            XCTFail("expected the lookup to fail")
        } catch {
            XCTAssertTrue(NetworkFailure.isOffline(error),
                          "unresolvable host should read as offline, got \(error)")
        }
    }
}
