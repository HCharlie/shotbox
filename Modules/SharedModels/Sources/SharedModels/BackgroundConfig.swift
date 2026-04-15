import Foundation
import CoreGraphics

public enum BackgroundStyle: String, Codable {
    case solid, linearGradient, radialGradient, image
}

public struct GradientConfig: Codable, Hashable {
    public var colors: [CodableColor]
    public var angle: Double = 135
    public var center: CGPoint = CGPoint(x: 0.5, y: 0.5)

    public init(colors: [CodableColor], angle: Double = 135,
                center: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.colors = colors; self.angle = angle; self.center = center
    }
}

public struct BackgroundConfig: Codable, Hashable {
    public var style: BackgroundStyle = .solid
    public var color: CodableColor = CodableColor(red: 0.2, green: 0.5, blue: 1.0)
    public var gradient: GradientConfig? = nil
    public var imageURL: URL? = nil
    public var padding: CGFloat = 40
    public var cornerRadius: CGFloat = 12
    public var shadowRadius: CGFloat = 20
    public var shadowOpacity: CGFloat = 0.4
    public var aspectRatio: CGSize? = nil

    public init() {}
}
