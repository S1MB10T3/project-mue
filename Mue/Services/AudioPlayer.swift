import AVFoundation
import MueCore

/// One analysis result from the playback tap.
struct AnalysisFrame: Sendable {
    /// Playback position, 0…1.
    let position: Double
    /// dB per FFT bin.
    let decibels: [Float]
}

enum AudioPlayerError: LocalizedError {
    case unsupportedFormat
    var errorDescription: String? { "Couldn't create an audio buffer for playback." }
}

/// Plays a `RenderedAudio` through `AVAudioEngine` and reports FFT frames
/// from a tap on the player node while it plays.
@MainActor
final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var tapInstalled = false
    private(set) var isPlaying = false

    init() {
        engine.attach(player)
    }

    /// Starts playback. `onFrame` is called on the audio thread; `onFinish`
    /// on the main actor when the buffer has been played back (or the player
    /// was stopped).
    func play(
        _ audio: RenderedAudio,
        analyzer: SpectrogramAnalyzer,
        onFrame: @escaping @Sendable (AnalysisFrame) -> Void,
        onFinish: @escaping @Sendable @MainActor () -> Void
    ) throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        let frameCount = AVAudioFrameCount(audio.samples.count)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: audio.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0]
        else { throw AudioPlayerError.unsupportedFormat }
        buffer.frameLength = frameCount
        audio.samples.withUnsafeBufferPointer { src in
            channel.update(from: src.baseAddress!, count: src.count)
        }

        engine.connect(player, to: engine.mainMixerNode, format: format)

        let state = TapState(fftSize: analyzer.fftSize)
        let total = Double(audio.samples.count)
        // `@Sendable` is load-bearing: `AVAudioNodeTapBlock` is not Sendable in
        // the AVFoundation overlay, so without it this closure inherits the
        // enclosing `@MainActor` isolation and traps on the render thread.
        player.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable pcm, _ in
            guard let data = pcm.floatChannelData?[0] else { return }
            state.push(data, count: Int(pcm.frameLength))
            let position = min(1, Double(state.framesSeen) / total)
            let dB = analyzer.decibels(state.window())
            onFrame(AnalysisFrame(position: position, decibels: dB))
        }
        tapInstalled = true

        engine.prepare()
        try engine.start()
        player.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { _ in
            Task { @MainActor in onFinish() }
        }
        player.play()
        isPlaying = true
    }

    func stop() {
        if isPlaying { player.stop() }
        if tapInstalled {
            player.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning { engine.stop() }
        isPlaying = false
    }
}

/// Ring buffer of the most recent samples. Only ever touched from the audio
/// tap thread, which is why it can be `@unchecked Sendable`.
private final class TapState: @unchecked Sendable {
    private var ring: [Float]
    private var head = 0
    private(set) var framesSeen = 0

    init(fftSize: Int) {
        ring = [Float](repeating: 0, count: fftSize)
    }

    func push(_ samples: UnsafePointer<Float>, count: Int) {
        let n = ring.count
        for i in 0..<count {
            ring[head] = samples[i]
            head += 1
            if head == n { head = 0 }
        }
        framesSeen += count
    }

    /// The last `fftSize` samples in chronological order.
    func window() -> [Float] {
        let n = ring.count
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            var idx = head + i
            if idx >= n { idx -= n }
            out[i] = ring[idx]
        }
        return out
    }
}
