import AppKit
import ScreenCaptureKit
import CoreGraphics
import SharedModels

@available(macOS 14.0, *)
@MainActor
public final class ScrollingCapture {
    public init() {}

    /// Scrolls through the window while capturing frames, then stitches them.
    public func capture(in window: SCWindow) async throws -> CGImage {
        var frames: [CGImage] = []
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.scalesToFit = false

        let first = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                configuration: config)
        frames.append(first)

        var previousFrame = first
        let maxScrollSteps = 50

        for _ in 0..<maxScrollSteps {
            let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                      units: .pixel,
                                      wheelCount: 1,
                                      wheel1: -120,
                                      wheel2: 0,
                                      wheel3: 0)
            scrollEvent?.post(tap: .cghidEventTap)
            try await Task.sleep(nanoseconds: 150_000_000)

            let frame = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                    configuration: config)
            if framesAreIdentical(previousFrame, frame) { break }
            frames.append(frame)
            previousFrame = frame
        }

        return try stitchFrames(frames)
    }

    // MARK: - Private

    private func framesAreIdentical(_ a: CGImage, _ b: CGImage) -> Bool {
        guard a.width == b.width, a.height == b.height else { return false }
        let stripH = min(20, a.height)
        let stripY = a.height / 2
        guard
            let aStrip = a.cropping(to: CGRect(x: 0, y: stripY, width: a.width, height: stripH)),
            let bStrip = b.cropping(to: CGRect(x: 0, y: stripY, width: b.width, height: stripH))
        else { return false }
        return imageToBytes(aStrip) == imageToBytes(bStrip)
    }

    private func stitchFrames(_ frames: [CGImage]) throws -> CGImage {
        guard !frames.isEmpty else { throw CaptureError.cancelled }
        guard frames.count > 1 else { return frames[0] }

        let stripHeight = 30
        var yOffsets: [Int] = [0]
        for i in 1..<frames.count {
            let overlap = findOverlap(frames[i-1], frames[i], stripHeight: stripHeight)
            yOffsets.append(yOffsets[i-1] + frames[i-1].height - overlap)
        }

        let totalHeight = yOffsets.last! + frames.last!.height
        let width = frames[0].width
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let ctx = CGContext(data: nil, width: width, height: totalHeight,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo.rawValue)
        else { throw CaptureError.cancelled }

        for (i, frame) in frames.enumerated() {
            let y = totalHeight - yOffsets[i] - frame.height
            ctx.draw(frame, in: CGRect(x: 0, y: y, width: frame.width, height: frame.height))
        }

        guard let result = ctx.makeImage() else { throw CaptureError.cancelled }
        return result
    }

    private func findOverlap(_ a: CGImage, _ b: CGImage, stripHeight: Int) -> Int {
        let checkRows = min(stripHeight, a.height, b.height)
        for overlap in stride(from: checkRows, through: 1, by: -1) {
            if let aS = a.cropping(to: CGRect(x: 0, y: a.height - overlap, width: a.width, height: overlap)),
               let bS = b.cropping(to: CGRect(x: 0, y: 0, width: b.width, height: overlap)),
               imageToBytes(aS) == imageToBytes(bS) {
                return overlap
            }
        }
        return 0
    }

    private func imageToBytes(_ image: CGImage) -> Data {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height,
                                  bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo.rawValue),
              let data = ctx.data
        else { return Data() }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Data(bytes: data, count: image.width * image.height * 4)
    }
}
