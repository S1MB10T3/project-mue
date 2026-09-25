import Foundation
import MueCore
import Observation
import UIKit

/// Everything the edit screen does to one `Sound`: renders it as EQ-band
/// stems, plays them with live gains and effects, re-renders when the synth
/// settings change, and exports the mix.
@MainActor
@Observable
final class SoundEditor {
    /// Number of EQ bands, each a horizontal strip of the picture.
    static let bandCount = 4

    let sound: Sound
    private(set) var settings: EncodingSettings
    private(set) var stems: [RenderedAudio] = []
    /// Per-band gain, band 0 = top of the picture = highest frequencies.
    var gains: [Float] = Array(repeating: 1, count: SoundEditor.bandCount) {
        didSet {
            player.setGains(gains)
            refreshEnvelope()
        }
    }
    /// Reverb wet/dry, 0…100.
    var reverbMix: Float = 0 {
        didSet { player.reverbMix = reverbMix }
    }
    /// Delay wet/dry, 0…100.
    var delayMix: Float = 0 {
        didSet { player.delayMix = delayMix }
    }
    private(set) var envelope: [Float] = []
    private(set) var description = ""
    private(set) var isRendering = false
    private(set) var isPlaying = false
    /// Playback position, 0…1.
    private(set) var progress: Double = 0
    private(set) var errorMessage: String?

    private let player = AudioPlayer()
    /// One seed per sound so every re-render (and every stem) shares phases.
    private let seed = UInt64.random(in: .min ... .max)
    private var renderGeneration = 0

    init(sound: Sound, settings: EncodingSettings = EncodingSettings()) {
        self.sound = sound
        self.settings = settings
    }

    var hasAudio: Bool { !stems.isEmpty }

    /// "400–2.3k"-style frequency range of each band, band 0 first.
    var bandLabels: [String] {
        let s = settings.clamped()
        return (0..<Self.bandCount).map { band in
            let rows = AdditiveSynthesizer.bandRows(band, of: Self.bandCount, rows: s.bands)
            let topRow = Double(rows.lowerBound)
            let bottomRow = Double(max(rows.lowerBound, rows.upperBound - 1))
            let top = FrequencyMapping.frequency(forRow: topRow, rows: s.bands, min: s.minFrequency, max: s.maxFrequency, scale: s.scale)
            let bottom = FrequencyMapping.frequency(forRow: bottomRow, rows: s.bands, min: s.minFrequency, max: s.maxFrequency, scale: s.scale)
            return "\(Self.hertz(bottom))–\(Self.hertz(top))"
        }
    }

    /// The EQ'd mix, for the share sheet. `nil` until rendered.
    var export: WAVExport? {
        guard hasAudio else { return nil }
        return WAVExport(stems: stems, gains: gains, fileName: "MUE \(Self.timestamp()).wav")
    }

    /// Render and describe the picture. Call once when the screen appears.
    func start() async {
        async let described = PhotoDescriber.describe(sound.prepared)
        await render()
        description = await described
    }

    /// Tuning and timbre change the oscillators, so they need a re-render.
    /// EQ and effects are live and don't.
    func setTuning(_ tuning: Tuning) {
        guard tuning != settings.tuning else { return }
        settings.tuning = tuning
        Task { await render() }
    }

    func setWaveform(_ waveform: Waveform) {
        guard waveform != settings.waveform else { return }
        settings.waveform = waveform
        Task { await render() }
    }

    func render() async {
        stop()
        renderGeneration += 1
        let gen = renderGeneration
        isRendering = true
        errorMessage = nil

        let prepared = sound.prepared
        let settings = self.settings.clamped()
        let seed = self.seed
        let bands = Self.bandCount
        let result: [RenderedAudio]? = await Task.detached(priority: .userInitiated) {
            guard let rgba = ImageLoader.rgba(prepared, columns: settings.columns, rows: settings.bands) else { return nil }
            let matrix = AmplitudeMatrix.fromRGBA(
                rgba, columns: settings.columns, rows: settings.bands,
                invert: settings.invert, gamma: settings.gamma, floor: settings.floor
            )
            return AdditiveSynthesizer.renderStems(matrix, settings: settings, bands: bands, options: .init(seed: seed))
        }.value

        guard gen == renderGeneration else { return } // superseded by a newer render
        isRendering = false
        guard let result else {
            errorMessage = "Couldn't process that image."
            return
        }
        stems = result
        refreshEnvelope()
    }

    func togglePlay() {
        if isPlaying { stop() } else { play() }
    }

    func play() {
        guard hasAudio else { return }
        progress = 0
        errorMessage = nil
        do {
            try player.play(
                stems: stems,
                gains: gains,
                onProgress: { [weak self] position in
                    Task { @MainActor in self?.updateProgress(position) }
                },
                onFinish: { [weak self] in
                    self?.finished()
                }
            )
            isPlaying = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        player.stop()
        isPlaying = false
        progress = 0
    }

    private func finished() {
        guard isPlaying else { return }
        player.stop()
        isPlaying = false
        progress = 0
    }

    private func updateProgress(_ position: Double) {
        guard isPlaying else { return }
        progress = position
    }

    private func refreshEnvelope() {
        guard hasAudio else {
            envelope = []
            return
        }
        envelope = RenderedAudio.mix(stems, gains: gains).envelope(bars: 24)
    }

    private static func hertz(_ f: Double) -> String {
        f >= 1000 ? String(format: "%.1fk", f / 1000) : "\(Int(f.rounded()))"
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }
}
