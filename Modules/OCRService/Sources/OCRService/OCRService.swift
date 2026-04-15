import Foundation
import Vision
import CoreGraphics

public struct OCRResult {
    public let fullText: String
    public let blocks: [RecognizedBlock]

    public init(fullText: String, blocks: [RecognizedBlock]) {
        self.fullText = fullText
        self.blocks = blocks
    }
}

public struct RecognizedBlock {
    public let text: String
    /// Normalized bounding box (0–1, origin bottom-left, Vision coordinate space).
    public let boundingBox: CGRect
    public let confidence: Float

    public init(text: String, boundingBox: CGRect, confidence: Float) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

public final class OCRService {
    public init() {}

    /// Recognize all text in the given CGImage (accurate, language-corrected).
    public func recognize(image: CGImage) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    cont.resume(returning: OCRResult(fullText: "", blocks: []))
                    return
                }
                var blocks: [RecognizedBlock] = []
                var lines: [String] = []
                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    blocks.append(RecognizedBlock(text: candidate.string,
                                                  boundingBox: obs.boundingBox,
                                                  confidence: candidate.confidence))
                    lines.append(candidate.string)
                }
                cont.resume(returning: OCRResult(fullText: lines.joined(separator: "\n"),
                                                  blocks: blocks))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    /// Detect QR codes in the given CGImage, returning payload strings.
    public func detectQRCodes(image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { cont in
            let request = VNDetectBarcodesRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                let barcodes = req.results as? [VNBarcodeObservation] ?? []
                let values = barcodes
                    .filter { $0.symbology == .qr }
                    .compactMap { $0.payloadStringValue }
                cont.resume(returning: values)
            }
            request.symbologies = [.qr]
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
