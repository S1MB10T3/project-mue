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
                picture(photo)
                    .padding(20)
                    .padding(.bottom, 64)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        ZStack {
            Image(uiImage: photo)
                .resizable()
            if let spectrogram = model.spectrogramImage {
                Image(decorative: spectrogram, scale: 1)
                    .resizable()
                    .interpolation(.none)
            }
            if model.isPlaying {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2)
                        .shadow(color: Color.accentColor.opacity(0.8), radius: 4)
                        .offset(x: geo.size.width * model.progress)
                }
            }
        }
        .aspectRatio(model.photoAspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var cameraButton: some View {
        Button {
            showCamera = true
        } label: {
            circleIcon("camera")
        }
        .disabled(!CameraPicker.isAvailable)
        .accessibilityLabel("Take a photo")
    }

    private var libraryButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            circleIcon("photo.on.rectangle")
        }
        .accessibilityLabel("Choose a photo")
    }

    private func circleIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 48, height: 48)
            .background(.regularMaterial, in: Circle())
    }
}
