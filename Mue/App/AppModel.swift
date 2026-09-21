import CoreGraphics
import Foundation
import MueCore
import Observation
import UIKit

/// Single source of truth for the UI. Heavy work (resampling, rendering)
/// runs off the main actor and comes back as `Sendable` values from
/// `MueCore`.
@MainActor
@Observable
final class AppModel {
    var settings = EncodingSettings()

    private(set) var photo: UIImage?
    private(set) var photoAspect: CGFloat = 4 / 3
    private(set) var audio: RenderedAudio?
    private(set) var envelope: [Float] = []
    private(set) var isPreparing = false
    private(set) var isPlaying = false
    /// Playback position, 0…1.
    private(set) var progress: Double = 0
    private(set) var spectrogramImage: CGImage?
    private(set) var errorMessage: String?

    var hasAudio: Bool { audio != nil }

    private let player = AudioPlayer()
    private var matrix: AmplitudeMatrix?
    private var painter: SpectrogramPainter?
    private var mapper: SpectrogramColumnMapper?
    private var peakDecibels: Float = 0
    private var generation = 0

    private static let fftSize = 4096
    /// Dynamic range shown in the spectrogram, below the loudest thing heard.
    private static let displayRangeDecibels: Float = 50

    private struct Prepared: Sendable {
        let matrix: AmplitudeMatrix
        let audio: RenderedAudio
    }

    /// Encode a new photo and render its audio.
    func setPhoto(_ image: UIImage) async {
        stop()
        photo = image
        photoAspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        audio = nil
        matrix = nil
        envelope = []
        spectrogramImage = nil
        errorMessage = nil
        generation += 1
        let gen = generation

        guard let prepared = ImageLoader.prepare(image) else {
            errorMessage = "Couldn't read that image."
            return
        }
        isPreparing = true
        let settings = self.settings.clamped()
        let result: Prepared? = await Task.detached(priority: .userInitiated) {
            guard let rgba = ImageLoader.rgba(prepared, columns: settings.columns, rows: settings.bands) else { return nil }
            let matrix = AmplitudeMatrix.fromRGBA(
                rgba, columns: settings.columns, rows: settings.bands,
                invert: settings.invert, gamma: settings.gamma, floor: settings.floor
            )
            let audio = AdditiveSynthesizer.render(matrix, settings: settings)
            return Prepared(matrix: matrix, audio: audio)
        }.value

        guard gen == generation else { return } // a newer photo replaced this one
        isPreparing = false
        guard let result else {
            errorMessage = "Couldn't process that image."
            return
        }
        matrix = result.matrix
        audio = result.audio
        envelope = result.audio.envelope(bars: 24)
        painter = SpectrogramPainter(columns: result.matrix.columns, rows: result.matrix.rows)
    }

    func togglePlay() {
        if isPlaying { stop() } else { play() }
    }

    func play() {
        guard let audio, let matrix else { return }
        let s = settings.clamped()
        let analyzer = SpectrogramAnalyzer(fftSize: Self.fftSize, sampleRate: audio.sampleRate)
        mapper = SpectrogramColumnMapper(
            rows: matrix.rows, minFrequency: s.minFrequency, maxFrequency: s.maxFrequency,
            scale: s.scale, sampleRate: audio.sampleRate, fftSize: Self.fftSize
        )
        painter?.clear()
        spectrogramImage = nil
        progress = 0
        peakDecibels = -30
        errorMessage = nil
        do {
            try player.play(
                audio,
                analyzer: analyzer,
                onFrame: { [weak self] frame in
                    Task { @MainActor in self?.apply(frame) }
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

    private func apply(_ frame: AnalysisFrame) {
        guard isPlaying, var painter, let mapper else { return }
        progress = frame.position
        let perRow = mapper.maxPerRow(frame.decibels)
        if let loudest = perRow.max(), loudest > peakDecibels { peakDecibels = loudest }
        let floor = peakDecibels - Self.displayRangeDecibels
        let values = perRow.map { max(0, min(1, ($0 - floor) / Self.displayRangeDecibels)) }
        painter.paint(upTo: Int(frame.position * Double(painter.columns)), values: values)
        self.painter = painter
        spectrogramImage = painter.makeImage()
    }
}
