import AppKit
import AVFoundation

/// Floating NSPanel showing a circular webcam preview, composited above recordings.
public final class CameraOverlay: NSObject {
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var panel: NSPanel?
    public private(set) var isRunning = false

    public override init() {}

    public func start(at position: CGPoint = CGPoint(x: 20, y: 20),
                      size: CGFloat = 160) throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraError.noDevice
        }
        let input = try AVCaptureDeviceInput(device: device)
        let session = AVCaptureSession()
        session.addInput(input)
        session.startRunning()
        self.session = session

        let panel = NSPanel(
            contentRect: CGRect(x: position.x, y: position.y, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating

        let hostView = NSView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        hostView.wantsLayer = true

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.cornerRadius = size / 2
        previewLayer.masksToBounds = true
        hostView.layer?.addSublayer(previewLayer)

        panel.contentView = hostView
        panel.orderFront(nil)

        self.previewLayer = previewLayer
        self.panel = panel
        isRunning = true
    }

    public func stop() {
        session?.stopRunning()
        panel?.orderOut(nil)
        session = nil
        panel = nil
        previewLayer = nil
        isRunning = false
    }
}

public enum CameraError: Error { case noDevice }
