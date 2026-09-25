import MueCore
import SwiftUI

/// The edit screen: what the picture is, what it sounds like, and the knobs
/// that change that. Play and save live in a bar at the bottom.
struct EditView: View {
    @State private var editor: SoundEditor

    init(sound: Sound) {
        _editor = State(initialValue: SoundEditor(sound: sound))
    }

    var body: some View {
        @Bindable var editor = editor
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DescriptionView(photo: editor.sound.photo, text: editor.description, isRendering: editor.isRendering)

                WaveformView(envelope: editor.envelope, progress: editor.progress)
                    .frame(height: 72)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                EQView(gains: $editor.gains, labels: editor.bandLabels)

                SynthControlsView(editor: editor)

                if let message = editor.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground))
        .safeAreaInset(edge: .bottom) { transport }
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
        .task { await editor.start() }
        .onDisappear { editor.stop() }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Button {
                editor.togglePlay()
            } label: {
                Image(systemName: editor.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.accentColor, in: Circle())
            }
            .disabled(!editor.hasAudio)
            .accessibilityLabel(editor.isPlaying ? "Stop" : "Play")

            if let export = editor.export {
                ShareLink(item: export, preview: SharePreview(export.fileName, image: Image(uiImage: editor.sound.photo))) {
                    CircleIcon(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Save as WAV")
            } else {
                CircleIcon(systemName: "square.and.arrow.down")
                    .opacity(0.4)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
