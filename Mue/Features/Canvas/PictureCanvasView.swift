import PhotosUI
import SwiftUI

/// The big rounded canvas: the photo, the live spectrogram painting over it
/// during playback, and the camera / library buttons at its foot.
struct PictureCanvasView: View {
    @Environment(AppModel.self) private var model
    @Binding var pickerItem: PhotosPickerItem?
    @Binding var showCamera: Bool

    private let corner: CGFloat = 40

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color(uiColor: .systemGray5))

            if let photo = model.photo {
                // The picture is deliberately larger than the canvas (see
                // `picture`), so it hangs off an overlay: an overlay can't
                // grow its container the way a plain child would.
                Color.clear
                    .overlay { picture(photo) }
                    .clipped()
            } else {
                Text("Take or choose a photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 20) {
                cameraButton
                libraryButton
            }
            .padding(.bottom, 16)

            if model.isPreparing {
                ProgressView()
                    .padding(12)
                    .background(.regularMaterial, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private func picture(_ photo: UIImage) -> some View {
        Image(uiImage: photo)
            .resizable()
            // `.fill` so the picture covers the whole canvas; the overflow is
            // cropped by the canvas's own rounded clip, so no inner corner
            // radius here.
            .aspectRatio(model.photoAspect, contentMode: .fill)
    }

    private var cameraButton: some View {
        Button {
            showCamera = true
        } label: {
            CircleIcon(systemName: "camera")
        }
        .disabled(!CameraPicker.isAvailable)
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
