import SwiftUI
import MueCore

/// Phase 1 skeleton: the screen layout with placeholders, so the project
/// builds, runs on a device, and the shape of the UI is agreed before the
/// features land. See docs/PLAN.md.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Every row of pixels is a sine wave; brightness is loudness.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    placeholder(title: "Image", subtitle: "Photo picker, encoded preview and playhead go here.")

                    HStack(spacing: 8) {
                        Button("Render & play") {}
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        Button("Stop") {}
                            .buttonStyle(.bordered)
                        Button("Share") {}
                            .buttonStyle(.bordered)
                    }
                    .disabled(true)

                    Text(model.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    placeholder(title: "What comes back out", subtitle: "Live spectrogram of playback goes here.")

                    settingsSummary
                }
                .padding()
            }
            .navigationTitle("MUE")
        }
    }

    private func placeholder(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
        }
    }

    private var settingsSummary: some View {
        let s = model.settings
        return VStack(alignment: .leading, spacing: 6) {
            Text("Settings").font(.headline)
            Text("\(s.columns) × \(s.bands) cells · \(Int(s.minFrequency))–\(Int(s.maxFrequency)) Hz \(s.scale.rawValue) · \(s.duration.formatted()) s")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
