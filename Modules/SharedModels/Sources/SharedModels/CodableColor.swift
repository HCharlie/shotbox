import AppKit

public struct CodableColor: Codable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public init(_ nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.init(red: c.redComponent, green: c.greenComponent,
                  blue: c.blueComponent, alpha: c.alphaComponent)
    }

    public var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public static let black  = CodableColor(red: 0,   green: 0,   blue: 0)
    public static let white  = CodableColor(red: 1,   green: 1,   blue: 1)
    public static let yellow = CodableColor(red: 1,   green: 0.9, blue: 0)
    public static let red    = CodableColor(red: 0.9, green: 0.1, blue: 0.1)
}
