import Foundation
import ScreenCaptureKit
import AVFoundation
import SharedModels

@available(macOS 13.0, *)
public final class ScreenRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
    public enum State { case idle, recording, stopping }

    public struct Config {
        public var fps: Int = 30
        public var resolution: CGSize? = nil
        public var captureMicrophone: Bool = false
        public var captureSystemAudio: Bool = true
        public var showMouseClicks: Bool = false
        public var showKeystrokes: Bool = false
        public init() {}
    }

    private let config: Config
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var firstSampleTime: CMTime?
    private(set) public var state: State = .idle

    public init(config: Config = Config()) {
        self.config = config
        super.init()
    }

    public func startRecording(filter: SCContentFilter) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        outputURL = url

        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let w = Int(config.resolution?.width ?? 1920)
        let h = Int(config.resolution?.height ?? 1080)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput!.expectsMediaDataInRealTime = true
        assetWriter!.add(videoInput!)

        if config.captureSystemAudio || config.captureMicrophone {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
            ]
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput!.expectsMediaDataInRealTime = true
            assetWriter!.add(audioInput!)
        }

        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
        streamConfig.capturesAudio = config.captureSystemAudio
        streamConfig.showsCursor = true

        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try stream!.addStreamOutput(self, type: .screen,
                                    sampleHandlerQueue: DispatchQueue(label: "com.cleanshotalt.video"))
        if config.captureSystemAudio {
            try stream!.addStreamOutput(self, type: .audio,
                                        sampleHandlerQueue: DispatchQueue(label: "com.cleanshotalt.audio"))
        }
        try await stream!.startCapture()
        state = .recording
        return url
    }

    public func stopRecording() async throws -> URL {
        guard let stream, let assetWriter, let outputURL else {
            throw RecordingError.notRecording
        }
        state = .stopping
        try await stream.stopCapture()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            assetWriter.finishWriting { cont.resume() }
        }
        self.stream = nil
        state = .idle
        return outputURL
    }

    // MARK: - SCStreamOutput

    public func stream(_ stream: SCStream,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       of outputType: SCStreamOutputType) {
        guard state == .recording,
              CMSampleBufferDataIsReady(sampleBuffer) else { return }

        if firstSampleTime == nil {
            firstSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: firstSampleTime!)
        }

        switch outputType {
        case .screen:
            if videoInput?.isReadyForMoreMediaData == true { videoInput?.append(sampleBuffer) }
        case .audio:
            if audioInput?.isReadyForMoreMediaData == true { audioInput?.append(sampleBuffer) }
        case .microphone:
            if audioInput?.isReadyForMoreMediaData == true { audioInput?.append(sampleBuffer) }
        @unknown default: break
        }
    }

    // MARK: - SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        state = .idle
    }
}

public enum RecordingError: Error {
    case notRecording
    case writeFailed
}
