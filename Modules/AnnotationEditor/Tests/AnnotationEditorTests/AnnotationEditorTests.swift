import XCTest
@testable import AnnotationEditor
import SharedModels
import CoreGraphics

final class AnnotationEditorTests: XCTestCase {

    func makeSolidImage(width: Int = 100, height: Int = 100) -> CGImage {
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let ctx = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: info.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    func test_annotation_project_add_remove() {
        let project = AnnotationProject(baseImage: makeSolidImage())
        let arrow = AnyAnnotation.arrow(ArrowAnnotation(start: .zero,
                                                         end: CGPoint(x: 50, y: 50)))
        project.add(arrow)
        XCTAssertEqual(project.annotations.count, 1)
        project.remove(id: arrow.base.id)
        XCTAssertEqual(project.annotations.count, 0)
    }

    func test_project_saves_and_loads() throws {
        let project = AnnotationProject(baseImage: makeSolidImage())
        project.add(.arrow(ArrowAnnotation(start: .zero, end: CGPoint(x: 10, y: 10))))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".cleanalt")
        try project.save(to: url)
        let loaded = try AnnotationProject.load(from: url)
        XCTAssertEqual(loaded.annotations.count, 1)
        try? FileManager.default.removeItem(at: url)
    }

    func test_export_service_flatten_produces_image() throws {
        let project = AnnotationProject(baseImage: makeSolidImage())
        let service = ExportService()
        let flattened = try service.flatten(project)
        XCTAssertEqual(flattened.width, 100)
        XCTAssertEqual(flattened.height, 100)
    }

    func test_export_service_writes_png() throws {
        let project = AnnotationProject(baseImage: makeSolidImage())
        let service = ExportService()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "out.png")
        try service.export(project, to: url, format: .png)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    func test_tool_state_counter_increments() {
        let state = ToolState()
        XCTAssertEqual(state.nextCounter(), 1)
        XCTAssertEqual(state.nextCounter(), 2)
        state.resetCounter()
        XCTAssertEqual(state.nextCounter(), 1)
    }
}
