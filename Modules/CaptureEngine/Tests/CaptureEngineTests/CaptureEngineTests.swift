import XCTest
@testable import CaptureEngine

final class CaptureEngineTests: XCTestCase {
    // Most capture tests require screen recording permission and a running display.
    // These verify the public API surface compiles and error types exist.

    func test_capture_error_cases_exist() {
        let errors: [CaptureError] = [.cancelled, .noLastRect, .noDisplayFound,
                                       .permissionDenied, .noWindowSelected]
        XCTAssertEqual(errors.count, 5)
    }

    func test_area_capture_last_rect_initially_nil() {
        XCTAssertNil(AreaCapture.lastRect)
    }
}
