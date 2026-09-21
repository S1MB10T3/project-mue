import AVFoundation
import UIKit

/// Owns the `AVCaptureSession` behind the canvas's live preview and takes
/// stills from it.
///
/// `@unchecked Sendable` because every piece of mutable state below is touched
/// only on `queue`, one serial queue. That is also AVFoundation's own contract
/// for a capture session: configuration and `startRunning()` block, so they
/// must not run on the main thread.
final class CameraSession: @unchecked Sendable {
    enum Access: Equatable {
        case notDetermined
        case authorized
        case denied
    }

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.mue.camera-session")
    private var isConfigured = false
    /// `AVCapturePhotoOutput` does not retain its delegate, so the in-flight
    /// one is held here for the length of the capture.
    private var activeDelegate: PhotoCaptureDelegate?

    /// The session the preview layer renders. `AVCaptureVideoPreviewLayer` is
    /// main-actor bound and attaching a session to it from there is supported.
    var previewSession: AVCaptureSession { session }

    /// Whether the user has been asked for camera access yet, and what they said.
    static var access: Access {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// Shows the system camera prompt if it has not been shown before, and
    /// reports where access stands afterwards.
    static func requestAccess() async -> Access {
        if access == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        return access
    }

    /// Configures inputs on first use and starts delivering frames. Safe to
    /// call repeatedly.
    func start() {
        queue.async {
            guard Self.access == .authorized else { return }
            if !self.isConfigured {
                self.configure()
                guard self.isConfigured else { return }
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// Takes one still from the live feed. `nil` if the session is not running
    /// or the capture failed.
    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let delegate = PhotoCaptureDelegate { image in
                    // Called on AVFoundation's own queue: hop back to ours to
                    // drop the delegate, then hand the photo over. `self` is
                    // already held strongly by the enclosing `queue.async`.
                    self.queue.async { self.activeDelegate = nil }
                    continuation.resume(returning: image)
                }
                self.activeDelegate = delegate
                self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
            }
        }
    }

    /// Must only be called on `queue`.
    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output)
        else { return }
        session.addInput(input)
        session.addOutput(output)
        isConfigured = true
    }
}

/// Bridges one `capturePhoto` call back to its continuation.
///
/// Deliberately *not* `@MainActor`: AVFoundation calls this back on its own
/// queue, and a main-actor-isolated delegate method would trap there the same
/// way the playback tap used to.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (UIImage?) -> Void

    init(completion: @escaping @Sendable (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            completion(nil)
            return
        }
        completion(image)
    }
}
