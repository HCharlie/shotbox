import XCTest
@testable import SharedModels

final class SharedModelsTests: XCTestCase {

    func test_capture_roundtrips_codable() throws {
        let original = Capture(mode: .area,
                               filePath: URL(fileURLWithPath: "/tmp/a.png"),
                               thumbnailPath: URL(fileURLWithPath: "/tmp/a_thumb.jpg"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Capture.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.mode, decoded.mode)
        XCTAssertEqual(original.filePath, decoded.filePath)
    }

    func test_anyAnnotation_arrow_roundtrips() throws {
        let arrow = ArrowAnnotation(start: CGPoint(x: 10, y: 20),
                                    end: CGPoint(x: 100, y: 200))
        let wrapped = AnyAnnotation.arrow(arrow)
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyAnnotation.self, from: data)
        guard case .arrow(let decodedArrow) = decoded else {
            XCTFail("Expected .arrow case"); return
        }
        XCTAssertEqual(decodedArrow.start.x, arrow.start.x, accuracy: 0.001)
        XCTAssertEqual(decodedArrow.end.y,   arrow.end.y,   accuracy: 0.001)
    }

    func test_anyAnnotation_all_cases_roundtrip() throws {
        let cases: [AnyAnnotation] = [
            .arrow(ArrowAnnotation(start: .zero, end: CGPoint(x: 1, y: 1))),
            .shape(ShapeAnnotation(rect: CGRect(x: 0, y: 0, width: 100, height: 50))),
            .text(TextAnnotation(origin: .zero)),
            .highlight(HighlightAnnotation()),
            .pixelate(PixelateAnnotation(rect: .zero)),
            .blur(BlurAnnotation(rect: .zero)),
            .spotlight(SpotlightAnnotation(rect: CGRect(x: 10, y: 10, width: 200, height: 100))),
            .counter(CounterAnnotation(center: .zero, number: 1)),
            .pencil(PencilAnnotation()),
        ]
        for annotation in cases {
            let data = try JSONEncoder().encode(annotation)
            let decoded = try JSONDecoder().decode(AnyAnnotation.self, from: data)
            // Verify type tag preserved by checking description prefix
            let origPrefix = String(describing: annotation).prefix(8)
            let decPrefix  = String(describing: decoded).prefix(8)
            XCTAssertEqual(origPrefix, decPrefix, "Roundtrip failed for \(origPrefix)")
        }
    }

    func test_codable_color_roundtrips() throws {
        let color = CodableColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 0.9)
        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(CodableColor.self, from: data)
        XCTAssertEqual(color.red,   decoded.red,   accuracy: 0.001)
        XCTAssertEqual(color.green, decoded.green, accuracy: 0.001)
        XCTAssertEqual(color.alpha, decoded.alpha, accuracy: 0.001)
    }

    func test_background_config_gradient_roundtrips() throws {
        var config = BackgroundConfig()
        config.style = .linearGradient
        config.gradient = GradientConfig(colors: [.red, .white], angle: 45)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BackgroundConfig.self, from: data)
        XCTAssertEqual(decoded.gradient?.angle, 45, accuracy: 0.001)
        XCTAssertEqual(decoded.gradient?.colors.count, 2)
    }

    func test_point_near_segment_geometry() {
        // Point exactly on the midpoint of a horizontal segment
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 100, y: 0)
        let mid = CGPoint(x: 50, y: 0)
        XCTAssertTrue(pointNearSegment(mid, from: a, to: b, tolerance: 1))

        // Point far away
        let far = CGPoint(x: 50, y: 100)
        XCTAssertFalse(pointNearSegment(far, from: a, to: b, tolerance: 5))
    }
}
