import Foundation
import GRDB
import SharedModels
import AppKit
import AVFoundation

public final class HistoryStore {
    private let db: DatabaseQueue

    public static let shared: HistoryStore = {
        let url = storeDirectory.appendingPathComponent("history.sqlite")
        return try! HistoryStore(databaseURL: url)
    }()

    public static var storeDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("CleanShotAlt")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var capturesDirectory: URL {
        let dir = storeDirectory.appendingPathComponent("captures")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var thumbnailsDirectory: URL {
        let dir = storeDirectory.appendingPathComponent("thumbnails")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public init(databaseURL: URL) throws {
        db = try DatabaseQueue(path: databaseURL.path)
        try migrate()
    }

    private func migrate() throws {
        try db.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS captures (
                    id              TEXT    PRIMARY KEY,
                    mode            TEXT    NOT NULL,
                    created_at      INTEGER NOT NULL,
                    file_path       TEXT    NOT NULL,
                    thumbnail_path  TEXT    NOT NULL,
                    export_format   TEXT    NOT NULL
                )
                """)
        }
    }

    // MARK: - Public API

    public func ingest(_ capture: Capture) async throws {
        let thumbnail = try await generateThumbnail(for: capture)
        try await db.write { db in
            try db.execute(sql: """
                INSERT INTO captures (id, mode, created_at, file_path, thumbnail_path, export_format)
                VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                capture.id.uuidString,
                capture.mode.rawValue,
                Int(capture.createdAt.timeIntervalSince1970),
                capture.filePath.path,
                thumbnail.path,
                capture.exportFormat.rawValue,
            ])
        }
    }

    public func fetchAll(filter: CaptureMode? = nil) async throws -> [Capture] {
        try await db.read { db -> [Capture] in
            var sql = "SELECT * FROM captures"
            var args: StatementArguments = []
            if let filter {
                sql += " WHERE mode = ?"
                args = [filter.rawValue]
            }
            sql += " ORDER BY created_at DESC"
            let rows = try Row.fetchAll(db, sql: sql, arguments: args)
            return rows.compactMap { row -> Capture? in
                guard
                    let id     = UUID(uuidString: row["id"] as String),
                    let mode   = CaptureMode(rawValue: row["mode"] as String),
                    let format = ExportFormat(rawValue: row["export_format"] as String)
                else { return nil }
                let ts: Int = row["created_at"]
                return Capture(
                    id: id,
                    mode: mode,
                    createdAt: Date(timeIntervalSince1970: Double(ts)),
                    filePath: URL(fileURLWithPath: row["file_path"] as String),
                    thumbnailPath: URL(fileURLWithPath: row["thumbnail_path"] as String),
                    exportFormat: format
                )
            }
        }
    }

    public func delete(_ id: UUID) async throws {
        let all = try await fetchAll()
        let capture = all.first(where: { $0.id == id })
        try await db.write { db in
            try db.execute(sql: "DELETE FROM captures WHERE id = ?",
                           arguments: [id.uuidString])
        }
        if let capture {
            try? FileManager.default.removeItem(at: capture.filePath)
            try? FileManager.default.removeItem(at: capture.thumbnailPath)
        }
    }

    public func replace(originalID: UUID, with annotated: Capture) async throws {
        try await delete(originalID)
        try await ingest(annotated)
    }

    public func pruneOlderThan(_ days: Int) async throws {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let old = try await fetchAll().filter { $0.createdAt < cutoff }
        for capture in old {
            try await delete(capture.id)
        }
    }

    // MARK: - Thumbnail generation

    private func generateThumbnail(for capture: Capture) async throws -> URL {
        let destURL = Self.thumbnailsDirectory
            .appendingPathComponent(capture.id.uuidString + "_thumb.jpg")

        switch capture.mode {
        case .video:
            let asset = AVURLAsset(url: capture.filePath)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            let cgImage = try await gen.image(at: .zero).image
            try writeJPEG(cgImage, to: destURL)
        default:
            guard
                let src     = CGImageSourceCreateWithURL(capture.filePath as CFURL, nil),
                let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil)
            else { throw HistoryStoreError.thumbnailFailed }
            try writeJPEG(cgImage, to: destURL, maxDimension: 240)
        }
        return destURL
    }

    private func writeJPEG(_ image: CGImage, to url: URL, maxDimension: Int = 240) throws {
        let scale = min(1.0, Double(maxDimension) / Double(max(image.width, image.height)))
        let w = max(1, Int(Double(image.width)  * scale))
        let h = max(1, Int(Double(image.height) * scale))

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo.rawValue)
        else { throw HistoryStoreError.thumbnailFailed }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let scaled = ctx.makeImage() else { throw HistoryStoreError.thumbnailFailed }

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                          "public.jpeg" as CFString, 1, nil)
        else { throw HistoryStoreError.thumbnailFailed }

        CGImageDestinationAddImage(dest, scaled,
                                   [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw HistoryStoreError.thumbnailFailed }
    }
}

public enum HistoryStoreError: Error {
    case thumbnailFailed
    case notFound
}
