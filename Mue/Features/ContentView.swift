import PhotosUI
import SwiftUI

/// Main screen: the picture canvas and the player pill, per the Figma layout.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 24) {
            PictureCanvasView(pickerItem: $pickerItem, showCamera: $showCamera)
            PlayerPillView()
            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(Color(uiColor: .systemBackground))
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image {
                    Task { await model.setPhoto(image) }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        await model.setPhoto(image)
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
