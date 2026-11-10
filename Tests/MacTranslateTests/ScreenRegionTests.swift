import CoreGraphics
import XCTest
@testable import MacTranslate

final class ScreenRegionTests: XCTestCase {
    private let primaryFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testReversedDragConvertsFromBottomLeftToTopLeft() {
        let region = ScreenRegion(
            start: CGPoint(x: 400, y: 700),
            end: CGPoint(x: 100, y: 500),
            displayFrame: primaryFrame,
            primaryScreenTop: primaryFrame.maxY
        )

        XCTAssertEqual(region?.rect, CGRect(x: 100, y: 200, width: 300, height: 200))
    }

    func testDragIsClippedToDisplayLeftOfPrimary() {
        let region = ScreenRegion(
            start: CGPoint(x: -40, y: 850),
            end: CGPoint(x: 100, y: 1000),
            displayFrame: CGRect(x: -1920, y: 0, width: 1920, height: 900),
            primaryScreenTop: primaryFrame.maxY
        )

        XCTAssertEqual(region?.rect, CGRect(x: -40, y: 0, width: 40, height: 50))
    }

    func testDisplayAbovePrimaryHasNegativeCaptureY() {
        let region = ScreenRegion(
            start: CGPoint(x: 20, y: 930),
            end: CGPoint(x: 120, y: 970),
            displayFrame: CGRect(x: 0, y: 900, width: 1440, height: 900),
            primaryScreenTop: primaryFrame.maxY
        )

        XCTAssertEqual(region?.rect, CGRect(x: 20, y: -70, width: 100, height: 40))
    }

    func testThinSelectionIsCancelled() {
        XCTAssertNil(ScreenRegion(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 103, y: 200),
            displayFrame: primaryFrame,
            primaryScreenTop: primaryFrame.maxY
        ))
    }
}
