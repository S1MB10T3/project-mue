import SwiftUI

/// Two screens: capture, then edit. Choosing a picture sets `model.sound`,
/// which pushes the edit screen; going back clears it and the live feed
/// resumes.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            CaptureView()
                .navigationDestination(item: $model.sound) { sound in
                    EditView(sound: sound)
                }
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
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
