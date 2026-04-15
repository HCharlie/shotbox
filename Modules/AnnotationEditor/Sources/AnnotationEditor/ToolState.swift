import Foundation
import CoreGraphics
import SharedModels

public enum ActiveTool: String, CaseIterable {
    case select, arrow, shape, text, highlight, pixelate, blur, spotlight, counter, pencil
    case crop, resize, rotate, background

    public var iconName: String {
        switch self {
        case .select:     return "cursorarrow"
        case .arrow:      return "arrow.up.right"
        case .shape:      return "rectangle"
        case .text:       return "textformat"
        case .highlight:  return "highlighter"
        case .pixelate:   return "mosaic"
        case .blur:       return "aqi.medium"
        case .spotlight:  return "spotlight"
        case .counter:    return "number.circle"
        case .pencil:     return "pencil"
        case .crop:       return "crop"
        case .resize:     return "arrow.up.left.and.arrow.down.right"
        case .rotate:     return "rotate.right"
        case .background: return "photo.on.rectangle"
        }
    }
}

public final class ToolState: ObservableObject {
    @Published public var activeTool: ActiveTool = .select
    @Published public var selectedAnnotationID: UUID? = nil
    @Published public var strokeColor: CodableColor = .red
    @Published public var fillColor: CodableColor? = nil
    @Published public var strokeThickness: CGFloat = 3
    @Published public var fontSize: CGFloat = 16
    @Published public var opacity: Double = 1.0
    @Published public var arrowHeadStyle: ArrowHeadStyle = .filled
    @Published public var shapeKind: ShapeKind = .rectangle
    @Published public var counterValue: Int = 1
    @Published public var pixelSize: CGFloat = 12
    @Published public var blurRadius: CGFloat = 10

    public init() {}

    public func resetCounter() { counterValue = 1 }

    public func nextCounter() -> Int {
        defer { counterValue += 1 }
        return counterValue
    }
}
