import MueCore
import SwiftUI

/// Tuning and timbre (which re-render the sound) and the live effects.
struct SynthControlsView: View {
    @Bindable var editor: SoundEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Synth")
                .font(.headline)

            LabeledContent("Tuning") {
                Picker("Tuning", selection: Binding(
                    get: { editor.settings.tuning },
                    set: { editor.setTuning($0) }
                )) {
                    ForEach(Tuning.allCases, id: \.self) { tuning in
                        Text(tuning.label).tag(tuning)
                    }
                }
                .pickerStyle(.menu)
            }

            Picker("Waveform", selection: Binding(
                get: { editor.settings.waveform },
                set: { editor.setWaveform($0) }
            )) {
                ForEach(Waveform.allCases, id: \.self) { waveform in
                    Text(waveform.label).tag(waveform)
                }
            }
            .pickerStyle(.segmented)

            LabeledSlider(title: "Reverb", value: $editor.reverbMix, range: 0...100)
            LabeledSlider(title: "Delay", value: $editor.delayMix, range: 0...100)
        }
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 64, alignment: .leading)
            Slider(value: $value, in: range)
        }
    }
}

extension Tuning {
    var label: String {
        switch self {
        case .free: "Free"
        case .chromatic: "Chromatic"
        case .major: "Major"
        case .minor: "Minor"
        case .pentatonic: "Pentatonic"
        }
    }
}

extension Waveform {
    var label: String {
        switch self {
        case .sine: "Sine"
        case .triangle: "Triangle"
        case .square: "Square"
        case .saw: "Saw"
        }
    }
}
