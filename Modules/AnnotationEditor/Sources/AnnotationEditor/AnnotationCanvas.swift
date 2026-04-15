import SwiftUI
import CoreImage
import SharedModels

/// Interactive SwiftUI Canvas for rendering and editing annotations.
public struct AnnotationCanvas: View {
    @ObservedObject public var project: AnnotationProject
    @ObservedObject public var toolState: ToolState

    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil
    @State private var pencilPoints: [CGPoint] = []

    public init(project: AnnotationProject, toolState: ToolState) {
        self.project = project
        self.toolState = toolState
    }

    public var body: some View {
        Canvas { ctx, size in
            // Base image
            let uiImage = Image(project.baseImage, scale: 1.0, label: Text(""))
            ctx.draw(uiImage, in: CGRect(origin: .zero, size: size))

            // Committed annotations
            for annotation in project.annotations {
                drawAnnotation(annotation, in: &ctx, size: size)
            }

            // In-progress ghost
            if let start = dragStart, let current = dragCurrent {
                drawInProgress(from: start, to: current, in: &ctx)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStart == nil { dragStart = value.startLocation }
                    dragCurrent = value.location
                    if toolState.activeTool == .pencil ||
                       toolState.activeTool == .highlight {
                        pencilPoints.append(value.location)
                    }
                }
                .onEnded { value in
                    guard let start = dragStart else { return }
                    commitAnnotation(from: start, to: value.location)
                    dragStart = nil; dragCurrent = nil; pencilPoints = []
                }
        )
        .frame(width: project.canvasSize.width, height: project.canvasSize.height)
    }

    // MARK: - Commit

    private func commitAnnotation(from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        switch toolState.activeTool {
        case .arrow:
            project.add(.arrow(ArrowAnnotation(start: start, end: end,
                                               color: toolState.strokeColor,
                                               thickness: toolState.strokeThickness,
                                               headStyle: toolState.arrowHeadStyle)))
        case .shape:
            project.add(.shape(ShapeAnnotation(shape: toolState.shapeKind, rect: rect,
                                               color: toolState.strokeColor,
                                               fillColor: toolState.fillColor,
                                               thickness: toolState.strokeThickness)))
        case .text:
            project.add(.text(TextAnnotation(origin: start)))
        case .highlight:
            project.add(.highlight(HighlightAnnotation(points: pencilPoints,
                                                        color: toolState.strokeColor,
                                                        opacity: toolState.opacity,
                                                        thickness: toolState.strokeThickness)))
        case .pixelate:
            project.add(.pixelate(PixelateAnnotation(rect: rect, pixelSize: toolState.pixelSize)))
        case .blur:
            project.add(.blur(BlurAnnotation(rect: rect, radius: toolState.blurRadius)))
        case .spotlight:
            project.add(.spotlight(SpotlightAnnotation(rect: rect)))
        case .counter:
            project.add(.counter(CounterAnnotation(center: start,
                                                    number: toolState.nextCounter())))
        case .pencil:
            project.add(.pencil(PencilAnnotation(points: pencilPoints,
                                                  color: toolState.strokeColor,
                                                  thickness: toolState.strokeThickness)))
        default: break
        }
    }

    // MARK: - Rendering

    private func drawAnnotation(_ annotation: AnyAnnotation, in ctx: inout GraphicsContext,
                                  size: CGSize) {
        switch annotation {
        case .arrow(let a):     drawArrow(a, in: &ctx)
        case .shape(let s):     drawShape(s, in: &ctx)
        case .text(let t):      drawText(t, in: &ctx)
        case .highlight(let h): drawHighlight(h, in: &ctx)
        case .pixelate(let p):  drawPixelate(p, in: &ctx)
        case .blur(let b):      drawBlurAnnotation(b, in: &ctx)
        case .spotlight(let s): drawSpotlight(s, in: &ctx, size: size)
        case .counter(let c):   drawCounter(c, in: &ctx)
        case .pencil(let p):    drawPencil(p, in: &ctx)
        }
    }

    private func drawInProgress(from start: CGPoint, to end: CGPoint,
                                  in ctx: inout GraphicsContext) {
        switch toolState.activeTool {
        case .arrow:
            let a = ArrowAnnotation(start: start, end: end, color: toolState.strokeColor,
                                    thickness: toolState.strokeThickness,
                                    headStyle: toolState.arrowHeadStyle)
            drawArrow(a, in: &ctx)
        case .shape:
            let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                              width: abs(end.x - start.x), height: abs(end.y - start.y))
            let s = ShapeAnnotation(shape: toolState.shapeKind, rect: rect,
                                    color: toolState.strokeColor, thickness: toolState.strokeThickness)
            drawShape(s, in: &ctx)
        default: break
        }
    }

    // MARK: - Per-tool drawing

    private func drawArrow(_ a: ArrowAnnotation, in ctx: inout GraphicsContext) {
        var path = Path()
        path.move(to: a.start); path.addLine(to: a.end)
        ctx.stroke(path, with: .color(Color(a.color.nsColor)), lineWidth: a.thickness)

        let angle = atan2(a.end.y - a.start.y, a.end.x - a.start.x)
        let headLen = max(12, a.thickness * 4)
        let spread: CGFloat = .pi / 6
        let p1 = CGPoint(x: a.end.x - headLen * cos(angle - spread),
                         y: a.end.y - headLen * sin(angle - spread))
        let p2 = CGPoint(x: a.end.x - headLen * cos(angle + spread),
                         y: a.end.y - headLen * sin(angle + spread))
        var head = Path()
        if a.headStyle == .filled {
            head.move(to: a.end); head.addLine(to: p1); head.addLine(to: p2); head.closeSubpath()
            ctx.fill(head, with: .color(Color(a.color.nsColor)))
        } else {
            head.move(to: a.end); head.addLine(to: p1); head.move(to: a.end); head.addLine(to: p2)
            ctx.stroke(head, with: .color(Color(a.color.nsColor)), lineWidth: a.thickness)
        }
    }

    private func drawShape(_ s: ShapeAnnotation, in ctx: inout GraphicsContext) {
        let color = Color(s.color.nsColor)
        switch s.shape {
        case .rectangle:
            let path = Path(s.rect)
            if let fill = s.fillColor { ctx.fill(path, with: .color(Color(fill.nsColor))) }
            ctx.stroke(path, with: .color(color), lineWidth: s.thickness)
        case .ellipse:
            let path = Path(ellipseIn: s.rect)
            if let fill = s.fillColor { ctx.fill(path, with: .color(Color(fill.nsColor))) }
            ctx.stroke(path, with: .color(color), lineWidth: s.thickness)
        case .line:
            var path = Path()
            path.move(to: CGPoint(x: s.rect.minX, y: s.rect.minY))
            path.addLine(to: CGPoint(x: s.rect.maxX, y: s.rect.maxY))
            ctx.stroke(path, with: .color(color), lineWidth: s.thickness)
        }
    }

    private func drawText(_ t: TextAnnotation, in ctx: inout GraphicsContext) {
        guard !t.text.isEmpty else { return }
        if let bg = t.backgroundColor {
            let bgRect = CGRect(x: t.origin.x - 4, y: t.origin.y - 2,
                                width: CGFloat(t.text.count) * t.fontSize * 0.6 + 8,
                                height: t.fontSize * 1.5)
            ctx.fill(Path(bgRect), with: .color(Color(bg.nsColor)))
        }
        let text = Text(t.text).font(.system(size: t.fontSize))
                               .foregroundColor(Color(t.color.nsColor))
        ctx.draw(text, at: t.origin, anchor: .topLeading)
    }

    private func drawHighlight(_ h: HighlightAnnotation, in ctx: inout GraphicsContext) {
        guard h.points.count > 1 else { return }
        var path = Path(); path.move(to: h.points[0])
        for pt in h.points.dropFirst() { path.addLine(to: pt) }
        ctx.stroke(path, with: .color(Color(h.color.nsColor).opacity(h.opacity)),
                   lineWidth: h.thickness)
    }

    private func drawPixelate(_ p: PixelateAnnotation, in ctx: inout GraphicsContext) {
        guard let cropped = project.baseImage.cropping(to: p.rect),
              let filter = CIFilter(name: "CIPixellate") else { return }
        let ci = CIImage(cgImage: cropped)
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(p.pixelSize, forKey: kCIInputScaleKey)
        let ciCtx = CIContext()
        guard let out = filter.outputImage,
              let result = ciCtx.createCGImage(out, from: ci.extent) else { return }
        ctx.draw(Image(result, scale: 1.0, label: Text("")), in: p.rect)
    }

    private func drawBlurAnnotation(_ b: BlurAnnotation, in ctx: inout GraphicsContext) {
        guard let cropped = project.baseImage.cropping(to: b.rect),
              let filter = CIFilter(name: "CIGaussianBlur") else { return }
        let ci = CIImage(cgImage: cropped)
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(b.radius, forKey: kCIInputRadiusKey)
        let ciCtx = CIContext()
        guard let out = filter.outputImage,
              let result = ciCtx.createCGImage(out, from: ci.extent) else { return }
        ctx.draw(Image(result, scale: 1.0, label: Text("")), in: b.rect)
    }

    private func drawSpotlight(_ s: SpotlightAnnotation, in ctx: inout GraphicsContext,
                                 size: CGSize) {
        var dimPath = Path(CGRect(origin: .zero, size: size))
        dimPath.addRect(s.rect)
        ctx.fill(dimPath, with: .color(.black.opacity(s.dimOpacity)),
                 style: FillStyle(eoFill: true))
    }

    private func drawCounter(_ c: CounterAnnotation, in ctx: inout GraphicsContext) {
        let rect = CGRect(x: c.center.x - c.radius, y: c.center.y - c.radius,
                          width: c.radius * 2, height: c.radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(Color(c.color.nsColor)))
        let label = Text("\(c.number)")
            .font(.system(size: c.radius * 1.1, weight: .bold))
            .foregroundColor(.white)
        ctx.draw(label, at: c.center, anchor: .center)
    }

    private func drawPencil(_ p: PencilAnnotation, in ctx: inout GraphicsContext) {
        guard p.points.count > 1 else { return }
        var path = Path(); path.move(to: p.points[0])
        for pt in p.points.dropFirst() { path.addLine(to: pt) }
        ctx.stroke(path, with: .color(Color(p.color.nsColor)), lineWidth: p.thickness)
    }
}
