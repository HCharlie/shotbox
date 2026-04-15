import XCTest
@testable import HistoryStore
import SharedModels
import CoreGraphics

final class HistoryStoreTests: XCTestCase {
    var store: HistoryStore!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("test.sqlite")
        store = try HistoryStore(databaseURL: dbURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Creates a 1×1 white PNG so thumbnail generation doesn't fail.
    func makeCapturePNG(mode: CaptureMode = .area) throws -> Capture {
        let pngURL = tempDir.appendingPathComponent(UUID().uuidString + ".png")
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: bitmapInfo.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let img = ctx.makeImage()!
        let dest = CGImageDestinationCreateWithURL(pngURL as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
        return Capture(mode: mode,
                       filePath: pngURL,
                       thumbnailPath: tempDir.appendingPathComponent("thumb_placeholder.jpg"))
    }

    func test_ingest_and_fetch() async throws {
        let capture = try makeCapturePNG()
        try await store.ingest(capture)
        let all = try await store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].id, capture.id)
        XCTAssertEqual(all[0].mode, .area)
    }

    func test_fetch_filters_by_mode() async throws {
        try await store.ingest(try makeCapturePNG(mode: .area))
        try await store.ingest(try makeCapturePNG(mode: .video))
        let screenshots = try await store.fetchAll(filter: .area)
        XCTAssertEqual(screenshots.count, 1)
        XCTAssertEqual(screenshots[0].mode, .area)
    }

    func test_delete_removes_record() async throws {
        let capture = try makeCapturePNG()
        try await store.ingest(capture)
        try await store.delete(capture.id)
        let all = try await store.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_prune_removes_old_captures() async throws {
        let capture = try makeCapturePNG()
        try await store.ingest(capture)
        // pruneOlderThan(0) cuts off at "now", removing everything just inserted
        try await store.pruneOlderThan(0)
        let all = try await store.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_replace_swaps_capture() async throws {
        let original = try makeCapturePNG()
        try await store.ingest(original)
        let annotated = try makeCapturePNG()
        try await store.replace(originalID: original.id, with: annotated)
        let all = try await store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertNotEqual(all[0].id, original.id)
        XCTAssertEqual(all[0].id, annotated.id)
    }
}
