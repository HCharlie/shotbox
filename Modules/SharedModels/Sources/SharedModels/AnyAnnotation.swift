import Foundation

/// Tagged-union wrapper enabling Codable serialization of heterogeneous annotation arrays.
public enum AnyAnnotation: Codable {
    case arrow(ArrowAnnotation)
    case shape(ShapeAnnotation)
    case text(TextAnnotation)
    case highlight(HighlightAnnotation)
    case pixelate(PixelateAnnotation)
    case blur(BlurAnnotation)
    case spotlight(SpotlightAnnotation)
    case counter(CounterAnnotation)
    case pencil(PencilAnnotation)

    private enum TypeKey: String, Codable {
        case arrow, shape, text, highlight, pixelate, blur, spotlight, counter, pencil
    }

    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(TypeKey.self, forKey: .type)
        switch type {
        case .arrow:     self = .arrow(try c.decode(ArrowAnnotation.self, forKey: .value))
        case .shape:     self = .shape(try c.decode(ShapeAnnotation.self, forKey: .value))
        case .text:      self = .text(try c.decode(TextAnnotation.self, forKey: .value))
        case .highlight: self = .highlight(try c.decode(HighlightAnnotation.self, forKey: .value))
        case .pixelate:  self = .pixelate(try c.decode(PixelateAnnotation.self, forKey: .value))
        case .blur:      self = .blur(try c.decode(BlurAnnotation.self, forKey: .value))
        case .spotlight: self = .spotlight(try c.decode(SpotlightAnnotation.self, forKey: .value))
        case .counter:   self = .counter(try c.decode(CounterAnnotation.self, forKey: .value))
        case .pencil:    self = .pencil(try c.decode(PencilAnnotation.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .arrow(let v):     try c.encode(TypeKey.arrow, forKey: .type);     try c.encode(v, forKey: .value)
        case .shape(let v):     try c.encode(TypeKey.shape, forKey: .type);     try c.encode(v, forKey: .value)
        case .text(let v):      try c.encode(TypeKey.text, forKey: .type);      try c.encode(v, forKey: .value)
        case .highlight(let v): try c.encode(TypeKey.highlight, forKey: .type); try c.encode(v, forKey: .value)
        case .pixelate(let v):  try c.encode(TypeKey.pixelate, forKey: .type);  try c.encode(v, forKey: .value)
        case .blur(let v):      try c.encode(TypeKey.blur, forKey: .type);      try c.encode(v, forKey: .value)
        case .spotlight(let v): try c.encode(TypeKey.spotlight, forKey: .type); try c.encode(v, forKey: .value)
        case .counter(let v):   try c.encode(TypeKey.counter, forKey: .type);   try c.encode(v, forKey: .value)
        case .pencil(let v):    try c.encode(TypeKey.pencil, forKey: .type);    try c.encode(v, forKey: .value)
        }
    }

    public var base: any AnnotationObject {
        switch self {
        case .arrow(let v):     return v
        case .shape(let v):     return v
        case .text(let v):      return v
        case .highlight(let v): return v
        case .pixelate(let v):  return v
        case .blur(let v):      return v
        case .spotlight(let v): return v
        case .counter(let v):   return v
        case .pencil(let v):    return v
        }
    }
}
