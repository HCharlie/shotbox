import Foundation
import CoreGraphics
import AppKit
import SharedModels

public struct ExportService {
    public init() {}

    public func export(_ project: AnnotationProject, to url: URL, format: ExportFormat) throws {
        let flattened = try flatten(project)
        try write(flattened, to: url, format: format)
    }

    public func copyToPasteboard(_ project: AnnotationProject) throws {
        let flattened = try flatten(project)
        guard let data = cgImageToPNG(flattened) else { throw AnnotationError.exportFailed }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
    }

    public func flatten(_ project: AnnotationProject) throws -> CGImage {
        let size = project.canvasSize
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(data: nil,
                                  width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo.rawValue)
        else { throw AnnotationError.exportFailed }

        if let bg = project.backgroundConfig {
            drawBackground(bg, in: ctx, size: size)
        }

        ctx.draw(project.baseImage, in: CGRect(origin: .zero, size: size))

        // Note: annotations are rendered by AnnotationCanvas in SwiftUI.
        // For export flattening, we draw them here using CoreGraphics equivalents.
        for annotation in project.annotations {
            drawAnnotationCG(annotation, in: ctx, size: size)
        }

        guard let result = ctx.makeImage() else { throw AnnotationError.exportFailed }
        return result
    }

    // MARK: - CoreGraphics annotation rendering

    private func drawAnnotationCG(_ annotation: AnyAnnotation, in ctx: CGContext, size: CGSize) {
        switch annotation {
        case .arrow(let a): drawArrowCG(a, in: ctx)
        case .shape(let s): drawShapeCG(s, in: ctx)
        case .counter(let c): drawCounterCG(c, in: ctx)
        case .spotlight(let s): drawSpotlightCG(s, in: ctx, size: size)
        default: break  // text/highlight/pencil/pixelate/blur handled at higher fidelity in SwiftUI
        }
    }

    private func drawArrowCG(_ a: ArrowAnnotation, in ctx: CGContext) {
        ctx.setStrokeColor(a.color.nsColor.cgColor)
        ctx.setLineWidth(a.thickness)
        ctx.move(to: a.start); ctx.addLine(to: a.end); ctx.strokePath()
    }

    private func drawShapeCG(_ s: ShapeAnnotation, in ctx: CGContext) {
        ctx.setStrokeColor(s.color.nsColor.cgColor)
        ctx.setLineWidth(s.thickness)
        switch s.shape {
        case .rectangle:
            if let fill = s.fillColor { ctx.setFillColor(fill.nsColor.cgColor); ctx.fill(s.rect) }
            ctx.stroke(s.rect)
        case .ellipse:
            if let fill = s.fillColor { ctx.setFillColor(fill.nsColor.cgColor); ctx.fillEllipse(in: s.rect) }
            ctx.strokeEllipse(in: s.rect)
        case .line:
            ctx.move(to: CGPoint(x: s.rect.minX, y: s.rect.minY))
            ctx.addLine(to: CGPoint(x: s.rect.maxX, y: s.rect.maxY))
            ctx.strokePath()
        }
    }

    private func drawCounterCG(_ c: CounterAnnotation, in ctx: CGContext) {
        let rect = CGRect(x: c.center.x - c.radius, y: c.center.y - c.radius,
                          width: c.radius * 2, height: c.radius * 2)
        ctx.setFillColor(c.color.nsColor.cgColor)
        ctx.fillEllipse(in: rect)
    }

    private func drawSpotlightCG(_ s: SpotlightAnnotation, in ctx: CGContext, size: CGSize) {
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: s.dimOpacity))
        // Fill entire canvas
        ctx.fill(CGRect(origin: .zero, size: size))
        // Clear the spotlight rect (composite clear)
        ctx.clear(s.rect)
    }

    // MARK: - Background

    private func drawBackground(_ config: BackgroundConfig, in ctx: CGContext, size: CGSize) {
        switch config.style {
        case .solid:
            ctx.setFillColor(config.color.nsColor.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        case .linearGradient, .radialGradient:
            guard let grad = config.gradient else { return }
            let colors = grad.colors.map { $0.nsColor.cgColor } as CFArray
            let locs: [CGFloat] = grad.colors.enumerated().map {
                CGFloat($0.offset) / CGFloat(max(grad.colors.count - 1, 1))
            }
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: locs)
            else { return }
            if config.style == .linearGradient {
                let rad = grad.angle * .pi / 180
                let sx = size.width / 2 - cos(rad) * size.width / 2
                let sy = size.height / 2 - sin(rad) * size.height / 2
                let ex = size.width / 2 + cos(rad) * size.width / 2
                let ey = size.height / 2 + sin(rad) * size.height / 2
                ctx.drawLinearGradient(gradient,
                                       start: CGPoint(x: sx, y: sy),
                                       end: CGPoint(x: ex, y: ey), options: [])
            } else {
                let center = CGPoint(x: grad.center.x * size.width, y: grad.center.y * size.height)
                ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: max(size.width, size.height),
                                       options: [])
            }
        case .image:
            if let url = config.imageURL,
               let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                ctx.draw(img, in: CGRect(origin: .zero, size: size))
            }
        }
    }

    // MARK: - Helpers

    private func write(_ image: CGImage, to url: URL, format: ExportFormat) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                          format.utType as CFString, 1, nil)
        else { throw AnnotationError.exportFailed }
        let properties: CFDictionary? = format == .jpeg
            ? [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
            : nil
        CGImageDestinationAddImage(dest, image, properties)
        guard CGImageDestinationFinalize(dest) else { throw AnnotationError.exportFailed }
    }

    private func cgImageToPNG(_ image: CGImage) -> Data? {
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? (mutable as Data) : nil
    }
}
