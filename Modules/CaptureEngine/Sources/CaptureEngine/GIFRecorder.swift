import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
import SharedModels

@available(macOS 13.0, *)
public final class GIFRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
    public struct Config {
        public var fps: Int = 10
        public var quality: Double = 0.9
        public init() {}
    }

    private let config: Config
    private var stream: SCStream?
    private var frames: [(image: CGImage, delay: Double)] = []
    private var lastTimestamp: CMTime?
    private(set) public var isRecording = false

    public init(config: Config = Config()) {
        self.config = config
    }

    public func startRecording(filter: SCContentFilter) async throws {
        frames.removeAll()
        lastTimestamp = nil
        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
        streamConfig.capturesAudio = false
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try stream!.addStreamOutput(self, type: .screen,
                                    sampleHandlerQueue: DispatchQueue(label: "com.cleanshotalt.gif"))
        try await stream!.startCapture()
        isRecording = true
    }

    public func stopRecording() async throws -> URL {
        guard let stream else { throw RecordingError.notRecording }
        try await stream.stopCapture()
        self.stream = nil
        isRecording = false
        return try encodeGIF()
    }

    public func stream(_ stream: SCStream,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       of type: SCStreamOutputType) {
        guard type == .screen, isRecording else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let delay = lastTimestamp.map { CMTimeGetSeconds(CMTimeSubtract(ts, $0)) }
            ?? (1.0 / Double(config.fps))
        lastTimestamp = ts
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(ciImage, from: ciImage.extent) else { return }
        frames.append((cgImage, delay))
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) { isRecording = false }

    private func encodeGIF() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".gif")
        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ]
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                          UTType.gif.identifier as CFString,
                                                          frames.count, nil)
        else { throw RecordingError.writeFailed }
        CGImageDestinationSetProperties(dest, fileProperties as CFDictionary)
        for (cgImage, delay) in frames {
            let props: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: max(0.02, delay)
                ]
            ]
            CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        }
        guard CGImageDestinationFinalize(dest) else { throw RecordingError.writeFailed }
        return url
    }
}
