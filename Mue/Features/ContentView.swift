import PhotosUI
import SwiftUI

/// Main screen: the picture canvas and the player pill, per the Figma layout.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 24) {
            PictureCanvasView(pickerItem: $pickerItem)
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
        .task {
            // The live feed is the canvas's resting state, so access is asked
            // for as soon as the screen appears rather than behind a button.
            await model.startCamera()
        }
        .onChange(of: scenePhase) { _, phase in
            // Only `.background` releases the camera. `.inactive` fires for
            // transient things — a notification banner, the app switcher, the
            // permission alert itself — and tearing the session down for those
            // is churn that can leave the feed stopped.
            switch phase {
            case .active: Task { await model.startCamera() }
            case .background: model.stopCamera()
            default: break
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                await model.loadPhoto(from: item)
                pickerItem = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
