import Foundation
import CoreGraphics

public protocol AnnotationObject: Identifiable, Codable {
    var id: UUID { get }
    var zIndex: Int { get set }
    func contains(_ point: CGPoint) -> Bool
}

public struct ArrowAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var start: CGPoint
    public var end: CGPoint
    public var color: CodableColor = .red
    public var thickness: CGFloat = 3
    public var headStyle: ArrowHeadStyle = .filled

    public init(start: CGPoint, end: CGPoint, color: CodableColor = .red,
                thickness: CGFloat = 3, headStyle: ArrowHeadStyle = .filled) {
        self.start = start; self.end = end; self.color = color
        self.thickness = thickness; self.headStyle = headStyle
    }

    public func contains(_ point: CGPoint) -> Bool {
        pointNearSegment(point, from: start, to: end, tolerance: thickness + 4)
    }
}

public enum ArrowHeadStyle: String, Codable { case filled, outline, open, none }

public struct ShapeAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var shape: ShapeKind = .rectangle
    public var rect: CGRect
    public var color: CodableColor = .red
    public var fillColor: CodableColor? = nil
    public var thickness: CGFloat = 2

    public init(shape: ShapeKind = .rectangle, rect: CGRect, color: CodableColor = .red,
                fillColor: CodableColor? = nil, thickness: CGFloat = 2) {
        self.shape = shape; self.rect = rect; self.color = color
        self.fillColor = fillColor; self.thickness = thickness
    }

    public func contains(_ point: CGPoint) -> Bool {
        rect.insetBy(dx: -8, dy: -8).contains(point)
    }
}

public enum ShapeKind: String, Codable { case rectangle, ellipse, line }

public struct TextAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var text: String = ""
    public var origin: CGPoint
    public var fontSize: CGFloat = 16
    public var color: CodableColor = .white
    public var backgroundColor: CodableColor? = CodableColor.red

    public init(origin: CGPoint, text: String = "", fontSize: CGFloat = 16,
                color: CodableColor = .white, backgroundColor: CodableColor? = .red) {
        self.origin = origin; self.text = text; self.fontSize = fontSize
        self.color = color; self.backgroundColor = backgroundColor
    }

    public func contains(_ point: CGPoint) -> Bool {
        let estimatedRect = CGRect(x: origin.x, y: origin.y,
                                   width: CGFloat(text.count) * fontSize * 0.6,
                                   height: fontSize * 1.4)
        return estimatedRect.contains(point)
    }
}

public struct HighlightAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var points: [CGPoint] = []
    public var color: CodableColor = .yellow
    public var opacity: Double = 0.4
    public var thickness: CGFloat = 20

    public init(points: [CGPoint] = [], color: CodableColor = .yellow,
                opacity: Double = 0.4, thickness: CGFloat = 20) {
        self.points = points; self.color = color
        self.opacity = opacity; self.thickness = thickness
    }

    public func contains(_ point: CGPoint) -> Bool {
        guard points.count > 1 else { return false }
        return zip(points, points.dropFirst()).contains { a, b in
            pointNearSegment(point, from: a, to: b, tolerance: thickness)
        }
    }
}

public struct PixelateAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var rect: CGRect
    public var pixelSize: CGFloat = 12

    public init(rect: CGRect, pixelSize: CGFloat = 12) {
        self.rect = rect; self.pixelSize = pixelSize
    }

    public func contains(_ point: CGPoint) -> Bool {
        rect.insetBy(dx: -8, dy: -8).contains(point)
    }
}

public struct BlurAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var rect: CGRect
    public var radius: CGFloat = 10

    public init(rect: CGRect, radius: CGFloat = 10) {
        self.rect = rect; self.radius = radius
    }

    public func contains(_ point: CGPoint) -> Bool {
        rect.insetBy(dx: -8, dy: -8).contains(point)
    }
}

public struct SpotlightAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var rect: CGRect
    public var dimOpacity: Double = 0.6

    public init(rect: CGRect, dimOpacity: Double = 0.6) {
        self.rect = rect; self.dimOpacity = dimOpacity
    }

    public func contains(_ point: CGPoint) -> Bool {
        rect.insetBy(dx: -8, dy: -8).contains(point)
    }
}

public struct CounterAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var center: CGPoint
    public var number: Int
    public var radius: CGFloat = 16
    public var color: CodableColor = .red

    public init(center: CGPoint, number: Int, radius: CGFloat = 16, color: CodableColor = .red) {
        self.center = center; self.number = number
        self.radius = radius; self.color = color
    }

    public func contains(_ point: CGPoint) -> Bool {
        let dx = point.x - center.x; let dy = point.y - center.y
        return sqrt(dx*dx + dy*dy) <= radius + 6
    }
}

public struct PencilAnnotation: AnnotationObject {
    public var id = UUID()
    public var zIndex: Int = 0
    public var points: [CGPoint] = []
    public var color: CodableColor = .red
    public var thickness: CGFloat = 2

    public init(points: [CGPoint] = [], color: CodableColor = .red, thickness: CGFloat = 2) {
        self.points = points; self.color = color; self.thickness = thickness
    }

    public func contains(_ point: CGPoint) -> Bool {
        guard points.count > 1 else { return false }
        return zip(points, points.dropFirst()).contains { a, b in
            pointNearSegment(point, from: a, to: b, tolerance: thickness + 4)
        }
    }
}

// MARK: - Geometry helper (internal to module)
public func pointNearSegment(_ point: CGPoint, from a: CGPoint, to b: CGPoint, tolerance: CGFloat) -> Bool {
    let dx = b.x - a.x; let dy = b.y - a.y
    let lenSq = dx*dx + dy*dy
    guard lenSq > 0 else { return hypot(point.x - a.x, point.y - a.y) <= tolerance }
    let t = max(0, min(1, ((point.x - a.x)*dx + (point.y - a.y)*dy) / lenSq))
    let projX = a.x + t*dx; let projY = a.y + t*dy
    return hypot(point.x - projX, point.y - projY) <= tolerance
}
