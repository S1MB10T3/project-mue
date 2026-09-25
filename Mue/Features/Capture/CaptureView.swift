import PhotosUI
import SwiftUI

/// The capture screen: the live camera feed filling a rounded canvas, with
/// shutter and library buttons at its foot. Choosing a picture hands off to
/// the edit screen.
struct CaptureView: View {
    @Environment(AppModel.self) private var model
    @State private var pickerItem: PhotosPickerItem?

    private let corner: CGFloat = 40

    var body: some View {
        VStack(spacing: 12) {
            canvas
            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(Color(uiColor: .systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // The live feed is the screen's resting state, so access is asked
            // for as soon as it appears rather than behind a button.
            await model.startCamera()
        }
        .onChange(of: model.sound) { _, sound in
            // Coming back from the edit screen.
            if sound == nil { Task { await model.startCamera() } }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                await model.loadPhoto(from: item)
                pickerItem = nil
            }
        }
    }

    private var canvas: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color(uiColor: .systemGray5))

            if model.isPreviewingCamera {
                CameraPreviewView(session: model.cameraSession)
                    .clipped()
            } else {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 20) {
                shutterButton
                libraryButton
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var placeholder: String {
        model.cameraAccess == .denied
            ? "Camera access is off. Turn it on in Settings, or choose a photo."
            : "Take or choose a photo"
    }

    private var shutterButton: some View {
        Button {
            Task { await model.capturePhoto() }
        } label: {
            CircleIcon(systemName: "camera")
        }
        .disabled(model.cameraAccess != .authorized || model.isCapturing)
        .accessibilityLabel("Take a photo")
    }

    private var libraryButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            CircleIcon(systemName: "photo.on.rectangle")
        }
        .accessibilityLabel("Choose a photo")
    }
}

/// A 48 pt circular glass button face. A standalone view rather than a helper
/// method so it can be used from label closures that aren't main-actor
/// isolated, like `PhotosPicker`'s.
struct CircleIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 48, height: 48)
            .background(.regularMaterial, in: Circle())
    }
}
