import AVFoundation
import CoreGraphics
import Foundation
import MueCore
import Observation
import UIKit

/// Single source of truth for the UI. Heavy work (resampling, rendering)
/// runs off the main actor and comes back as `Sendable` values from
/// `MueCore`.
@MainActor
@Observable
final class AppModel {
    var settings = EncodingSettings()

    private(set) var photo: UIImage?
    private(set) var photoAspect: CGFloat = 4 / 3
    private(set) var audio: RenderedAudio?
    private(set) var envelope: [Float] = []
    private(set) var isPreparing = false
    private(set) var isPlaying = false
    /// Playback position, 0…1.
    private(set) var progress: Double = 0
    private(set) var errorMessage: String?
    private(set) var cameraAccess = CameraSession.access

    var hasAudio: Bool { audio != nil }
    /// The canvas shows the live feed whenever there is no picture to show.
    var isPreviewingCamera: Bool { photo == nil && cameraAccess == .authorized }
    var cameraSession: AVCaptureSession { camera.previewSession }

    private let player = AudioPlayer()
    private let camera = CameraSession()
    private var generation = 0

    /// Asks for camera access if it has not been asked for, and starts the
    /// live feed. Called when the canvas appears, because the feed is the
    /// canvas's resting state.
    func startCamera() async {
        cameraAccess = await CameraSession.requestAccess()
        guard cameraAccess == .authorized, photo == nil else { return }
        if let failure = await camera.start() {
            errorMessage = "Couldn't start the camera (\(failure.rawValue))."
        } else {
            errorMessage = nil
        }
    }

    func stopCamera() {
        camera.stop()
    }

    /// Takes a shot from the live feed and encodes it.
    func capturePhoto() async {
        guard let image = await camera.capturePhoto() else {
            errorMessage = "Couldn't take that photo."
            return
        }
        await setPhoto(image)
    }

    /// Discards the current picture and goes back to the live feed.
    func retake() {
        stop()
        photo = nil
        audio = nil
        envelope = []
        errorMessage = nil
        generation += 1
        guard cameraAccess == .authorized else { return }
        Task { await startCamera() }
    }

    /// Encode a new photo and render its audio.
    func setPhoto(_ image: UIImage) async {
        stop()
        camera.stop()
        photo = image
        photoAspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        audio = nil
        envelope = []
        errorMessage = nil
        generation += 1
        let gen = generation
        // Owned by this call from here on: an older in-flight render that
        // bails on the generation check must not touch it.
        isPreparing = true

        guard let prepared = ImageLoader.prepare(image) else {
            isPreparing = false
            errorMessage = "Couldn't read that image."
            return
        }
        let settings = self.settings.clamped()
        let result: RenderedAudio? = await Task.detached(priority: .userInitiated) {
            guard let rgba = ImageLoader.rgba(prepared, columns: settings.columns, rows: settings.bands) else { return nil }
            let matrix = AmplitudeMatrix.fromRGBA(
                rgba, columns: settings.columns, rows: settings.bands,
                invert: settings.invert, gamma: settings.gamma, floor: settings.floor
            )
            return AdditiveSynthesizer.render(matrix, settings: settings)
        }.value

        guard gen == generation else { return } // a newer photo replaced this one
        isPreparing = false
        guard let result else {
            errorMessage = "Couldn't process that image."
            return
        }
        audio = result
        envelope = result.envelope(bars: 24)
    }

    func togglePlay() {
        if isPlaying { stop() } else { play() }
    }

    func play() {
        guard let audio else { return }
        progress = 0
        errorMessage = nil
        do {
            try player.play(
                audio,
                onProgress: { [weak self] position in
                    Task { @MainActor in self?.updateProgress(position) }
                },
                onFinish: { [weak self] in
                    self?.finished()
                }
            )
            isPlaying = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        player.stop()
        isPlaying = false
        progress = 0
    }

    private func finished() {
        guard isPlaying else { return }
        player.stop()
        isPlaying = false
        progress = 0
    }

    private func updateProgress(_ position: Double) {
        guard isPlaying else { return }
        progress = position
    }
}
