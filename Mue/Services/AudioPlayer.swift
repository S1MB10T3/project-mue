import AVFoundation
import MueCore

enum AudioPlayerError: LocalizedError {
    case unsupportedFormat
    var errorDescription: String? { "Couldn't create an audio buffer for playback." }
}

/// Plays a `RenderedAudio` through `AVAudioEngine` and reports how far through
/// it is while it plays.
@MainActor
final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var tapInstalled = false
    private(set) var isPlaying = false

    init() {
        engine.attach(player)
    }

    /// Starts playback. `onProgress` is called on the audio thread with the
    /// position through the buffer, 0…1; `onFinish` on the main actor when the
    /// buffer has been played back (or the player was stopped).
    func play(
        _ audio: RenderedAudio,
        onProgress: @escaping @Sendable (Double) -> Void,
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

        let counter = FrameCounter()
        let total = Double(audio.samples.count)
        // `@Sendable` is load-bearing: `AVAudioNodeTapBlock` is not Sendable in
        // the AVFoundation overlay, so without it this closure inherits the
        // enclosing `@MainActor` isolation and traps on the render thread.
        player.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable pcm, _ in
            onProgress(counter.advance(by: Int(pcm.frameLength), of: total))
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

/// Running total of the frames the playback tap has seen. Only ever touched
/// from the audio tap thread, which is why it can be `@unchecked Sendable`.
private final class FrameCounter: @unchecked Sendable {
    private var framesSeen = 0

    /// Adds `count` frames and returns the position through `total`, 0…1.
    func advance(by count: Int, of total: Double) -> Double {
        framesSeen += count
        return Swift.min(1, Double(framesSeen) / total)
    }
}
