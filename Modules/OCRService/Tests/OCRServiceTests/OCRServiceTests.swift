import XCTest
@testable import OCRService
import CoreGraphics
import AppKit

final class OCRServiceTests: XCTestCase {
    let service = OCRService()

    /// Renders text to a CGImage for OCR testing.
    func makeTextImage(_ text: String,
                       size: CGSize = CGSize(width: 400, height: 80)) -> CGImage {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let ctx = CGContext(data: nil,
                            width: Int(size.width), height: Int(size.height),
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: bitmapInfo.rawValue)!
        // White background
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        // Black text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28),
            .foregroundColor: NSColor.black
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attrs))
        ctx.textPosition = CGPoint(x: 10, y: 20)
        CTLineDraw(line, ctx)
        return ctx.makeImage()!
    }

    func test_recognize_returns_expected_text() async throws {
        let image = makeTextImage("Hello World")
        let result = try await service.recognize(image: image)
        XCTAssertTrue(result.fullText.lowercased().contains("hello"),
                      "Expected 'hello' in '\(result.fullText)'")
    }

    func test_blank_image_returns_empty_result() async throws {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let ctx = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: bitmapInfo.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let image = ctx.makeImage()!
        let result = try await service.recognize(image: image)
        XCTAssertTrue(result.blocks.isEmpty || result.fullText.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}
