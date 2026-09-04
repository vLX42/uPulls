import XCTest
@testable import uPulls

final class UpdaterVersionTests: XCTestCase {
    func testSemverOrdering() {
        XCTAssertTrue(Updater.isNewer("1.1.0", than: "1.0.9"))
        XCTAssertTrue(Updater.isNewer("2.0", than: "1.9.9"))
        XCTAssertTrue(Updater.isNewer("1.0.4.1", than: "1.0.4"))
        XCTAssertFalse(Updater.isNewer("1.0.4", than: "1.0.4"))
        XCTAssertFalse(Updater.isNewer("1.0.3", than: "1.0.4"))
        XCTAssertFalse(Updater.isNewer("1.0", than: "1.0.0"))
    }
}
