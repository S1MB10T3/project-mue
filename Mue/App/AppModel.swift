import AVFoundation
import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// State for the capture screen: the live feed and how a picture gets
/// chosen. Once one is chosen it becomes `sound`, which pushes the edit
/// screen; editing state lives in `SoundEditor`.
@MainActor
@Observable
final class AppModel {
    private(set) var cameraAccess = CameraSession.access
    private(set) var isCapturing = false
    private(set) var errorMessage: String?
    /// The picture being edited. Non-nil pushes the edit screen; popping it
    /// sets this back to nil and the live feed resumes.
    var sound: Sound?

    /// The canvas shows the live feed whenever no picture is being edited.
    var isPreviewingCamera: Bool { sound == nil && cameraAccess == .authorized }
    var cameraSession: AVCaptureSession { camera.previewSession }

    private let camera = CameraSession()
    /// Bumped whenever the user asks for a picture. A request that finishes
    /// after a newer one started is discarded, whichever finishes first.
    private var latestRequest = 0

    /// Asks for camera access if it has not been asked for, and starts the
    /// live feed. Called when the capture screen appears or comes back.
    func startCamera() async {
        cameraAccess = await CameraSession.requestAccess()
        guard cameraAccess == .authorized, sound == nil else { return }
        if let failure = await camera.start() {
            errorMessage = "Couldn't start the camera (\(failure.rawValue))."
        } else {
            errorMessage = nil
        }
    }

    func stopCamera() {
        camera.stop()
    }

    /// Takes a shot from the live feed and opens it for editing, unless a
    /// newer request superseded it while the shutter was in flight.
    func capturePhoto() async {
        guard !isCapturing else { return }
        let request = beginRequest()
        isCapturing = true
        let image = await camera.capturePhoto()
        isCapturing = false
        guard request == latestRequest else { return }
        guard let image else {
            errorMessage = "Couldn't take that photo."
            return
        }
        open(image)
    }

    /// Loads a library pick and opens it for editing, unless a newer request
    /// superseded it while it was loading.
    func loadPhoto(from item: PhotosPickerItem) async {
        let request = beginRequest()
        let loaded = try? await item.loadTransferable(type: Data.self)
        guard request == latestRequest else { return }
        guard let data = loaded, let image = UIImage(data: data) else {
            errorMessage = "Couldn't load that photo."
            return
        }
        open(image)
    }

    private func open(_ image: UIImage) {
        guard let prepared = ImageLoader.prepare(image) else {
            errorMessage = "Couldn't read that image."
            return
        }
        errorMessage = nil
        camera.stop()
        sound = Sound(photo: image, prepared: prepared)
    }

    @discardableResult
    private func beginRequest() -> Int {
        latestRequest += 1
        return latestRequest
    }
}
