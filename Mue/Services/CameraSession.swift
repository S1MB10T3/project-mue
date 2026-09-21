import AVFoundation
import OSLog
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

    /// Why the live feed isn't running. `nil` once frames are flowing.
    enum StartFailure: String {
        case notAuthorized
        case noCameraDevice
        case cannotConfigureSession
    }

    private static let log = Logger(subsystem: "com.mue", category: "camera")

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.mue.camera-session")
    private var isConfigured = false
    /// `AVCapturePhotoOutput` does not retain its delegates, so each in-flight
    /// capture's delegate is held here, keyed by its settings' `uniqueID`,
    /// until it has resumed its caller. Several captures can overlap without
    /// one dropping another's continuation.
    private var inFlight: [Int64: PhotoCaptureDelegate] = [:]

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
    /// call repeatedly. Returns the reason it could not start, or `nil` on
    /// success — a silent failure here is invisible on screen, so the caller
    /// gets something it can show.
    @discardableResult
    func start() async -> StartFailure? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard Self.access == .authorized else {
                    Self.log.error("start: not authorized")
                    continuation.resume(returning: .notAuthorized)
                    return
                }
                if !self.isConfigured {
                    if let failure = self.configure() {
                        Self.log.error("start: configure failed (\(failure.rawValue, privacy: .public))")
                        continuation.resume(returning: failure)
                        return
                    }
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                Self.log.info("start: running=\(self.session.isRunning, privacy: .public)")
                continuation.resume(returning: self.session.isRunning ? nil : .cannotConfigureSession)
            }
        }
    }

    /// Stops the feed. Any capture still waiting on a still gets `nil`: a
    /// stopped session is not guaranteed to call its photo delegate back.
    func stop() {
        queue.async {
            for delegate in self.inFlight.values { delegate.finish(nil) }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// Takes one still from the live feed. `nil` if the session is not running,
    /// is stopped mid-capture, or the capture failed. Always returns.
    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let settings = AVCapturePhotoSettings()
                let id = settings.uniqueID
                let delegate = PhotoCaptureDelegate(queue: self.queue) { image in
                    // Runs on `queue`, exactly once per capture (see `finish`).
                    self.inFlight[id] = nil
                    continuation.resume(returning: image)
                }
                self.inFlight[id] = delegate
                self.output.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    /// Must only be called on `queue`. Returns the reason it failed, or `nil`.
    private func configure() -> StartFailure? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            Self.log.error("configure: no back wide-angle camera")
            return .noCameraDevice
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            Self.log.error("configure: could not open \(device.localizedName, privacy: .public)")
            return .noCameraDevice
        }
        guard session.canAddInput(input) else {
            Self.log.error("configure: session refused the input")
            return .cannotConfigureSession
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            Self.log.error("configure: session refused the photo output")
            return .cannotConfigureSession
        }
        session.addOutput(output)

        // The app is portrait-only, so pin stills to portrait (90° for the
        // back camera, the same rotation the preview layer applies) instead of
        // trusting the connection's default. Otherwise a still can come out
        // sideways relative to what the live feed showed.
        if let connection = output.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        isConfigured = true
        Self.log.info("configure: ready on \(device.localizedName, privacy: .public)")
        return nil
    }
}

/// Bridges one `capturePhoto` call back to its continuation.
///
/// Deliberately *not* `@MainActor`: AVFoundation calls this back on its own
/// queue, and a main-actor-isolated delegate method would trap there the same
/// way the playback tap used to. `@unchecked Sendable` because `completion`
/// is only read and cleared on `queue`.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let queue: DispatchQueue
    private var completion: (@Sendable (UIImage?) -> Void)?

    init(queue: DispatchQueue, completion: @escaping @Sendable (UIImage?) -> Void) {
        self.queue = queue
        self.completion = completion
    }

    /// Resumes the waiting call exactly once, on `queue`. Safe to call from
    /// AVFoundation's callback and from `CameraSession.stop()` alike; whichever
    /// comes second is a no-op.
    func finish(_ image: UIImage?) {
        queue.async {
            guard let completion = self.completion else { return }
            self.completion = nil
            completion(image)
        }
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
            finish(nil)
            return
        }
        finish(image)
    }
}
