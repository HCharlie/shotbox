import Foundation

public enum CaptureError: Error {
    case cancelled
    case noLastRect
    case noDisplayFound
    case permissionDenied
    case noWindowSelected
}
