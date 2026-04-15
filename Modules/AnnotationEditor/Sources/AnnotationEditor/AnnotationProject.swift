import Foundation
import CoreGraphics
import AppKit
import SharedModels

public final class AnnotationProject: ObservableObject {
    public let baseImage: CGImage
    @Published public var annotations: [AnyAnnotation] = []
    @Published public var backgroundConfig: BackgroundConfig? = nil
    public var canvasSize: CGSize

    public init(baseImage: CGImage) {
        self.baseImage = baseImage
        self.canvasSize = CGSize(width: baseImage.width, height: baseImage.height)
    }

    // MARK: - Annotation management

    public func add(_ annotation: AnyAnnotation) {
        annotations.append(annotation)
    }

    public func remove(id: UUID) {
        annotations.removeAll { $0.base.id == id }
    }

    public func update(_ annotation: AnyAnnotation) {
        if let idx = annotations.firstIndex(where: { $0.base.id == annotation.base.id }) {
            annotations[idx] = annotation
        }
    }

    public func moveToFront(id: UUID) {
        guard let idx = annotations.firstIndex(where: { $0.base.id == id }) else { return }
        let item = annotations.remove(at: idx)
        annotations.append(item)
    }

    // MARK: - Persistence (.cleanalt project file)

    private struct ProjectFile: Codable {
        let baseImagePNG: Data
        let annotations: [AnyAnnotation]
        let backgroundConfig: BackgroundConfig?
        let canvasWidth: Double
        let canvasHeight: Double
    }

    public func save(to url: URL) throws {
        guard let data = cgImageToPNG(baseImage) else { throw AnnotationError.exportFailed }
        let file = ProjectFile(
            baseImagePNG: data,
            annotations: annotations,
            backgroundConfig: backgroundConfig,
            canvasWidth: canvasSize.width,
            canvasHeight: canvasSize.height
        )
        let encoded = try JSONEncoder().encode(file)
        try encoded.write(to: url)
    }

    public static func load(from url: URL) throws -> AnnotationProject {
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(ProjectFile.self, from: data)
        guard let cgImage = pngToCGImage(file.baseImagePNG) else {
            throw AnnotationError.invalidProjectFile
        }
        let project = AnnotationProject(baseImage: cgImage)
        project.annotations = file.annotations
        project.backgroundConfig = file.backgroundConfig
        project.canvasSize = CGSize(width: file.canvasWidth, height: file.canvasHeight)
        return project
    }

    // MARK: - Helpers

    private func cgImageToPNG(_ image: CGImage) -> Data? {
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutable as Data
    }

    private static func pngToCGImage(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}

public enum AnnotationError: Error {
    case exportFailed
    case invalidProjectFile
}
