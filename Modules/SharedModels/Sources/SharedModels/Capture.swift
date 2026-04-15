import Foundation

public struct Capture: Identifiable, Codable, Hashable {
    public let id: UUID
    public let mode: CaptureMode
    public let createdAt: Date
    public let filePath: URL
    public let thumbnailPath: URL
    public var exportFormat: ExportFormat

    public init(id: UUID = UUID(), mode: CaptureMode, createdAt: Date = Date(),
                filePath: URL, thumbnailPath: URL, exportFormat: ExportFormat = .png) {
        self.id = id
        self.mode = mode
        self.createdAt = createdAt
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.exportFormat = exportFormat
    }
}

public enum CaptureMode: String, Codable, CaseIterable {
    case area, window, fullscreen, scrolling, video, gif
}

public enum ExportFormat: String, Codable, CaseIterable {
    case png, jpeg, tiff, webp, gif, mp4

    public var fileExtension: String { rawValue }

    public var utType: String {
        switch self {
        case .png:  return "public.png"
        case .jpeg: return "public.jpeg"
        case .tiff: return "public.tiff"
        case .webp: return "org.webmproject.webp"
        case .gif:  return "com.compuserve.gif"
        case .mp4:  return "public.mpeg-4"
        }
    }
}
