import AVFoundation
import MueCore

enum AudioPlayerError: LocalizedError {
    case unsupportedFormat
    var errorDescription: String? { "Couldn't create an audio buffer for playback." }
}

/// Plays a sound's stems through `AVAudioEngine`, one player node per stem
/// so each EQ band has a live gain, then reverb and delay, and reports how
/// far through it is while it plays.
///
///     stem players ─▶ submix ─▶ reverb ─▶ delay ─▶ main mixer
@MainActor
final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let submix = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay()
    private var players: [AVAudioPlayerNode] = []
    private var tapInstalled = false
    private(set) var isPlaying = false

    init() {
        engine.attach(submix)
        engine.attach(reverb)
        engine.attach(delay)
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 0
        delay.delayTime = 0.28
        delay.feedback = 35
        delay.lowPassCutoff = 6000
        delay.wetDryMix = 0
    }

    /// Reverb wet/dry, 0…100. Live.
    var reverbMix: Float {
        get { reverb.wetDryMix }
        set { reverb.wetDryMix = min(100, max(0, newValue)) }
    }

    /// Delay wet/dry, 0…100. Live.
    var delayMix: Float {
        get { delay.wetDryMix }
        set { delay.wetDryMix = min(100, max(0, newValue)) }
    }

    /// Per-stem gains, 0…1. Live; extra entries are ignored, missing ones are 1.
    func setGains(_ gains: [Float]) {
        for (index, player) in players.enumerated() {
            player.volume = index < gains.count ? min(1, max(0, gains[index])) : 1
        }
    }

    /// Starts playback of all stems, sample-aligned. `onProgress` is called
    /// on the audio thread with the position through the sound, 0…1;
    /// `onFinish` on the main actor when playback ends (or is stopped).
    func play(
        stems: [RenderedAudio],
        gains: [Float],
        onProgress: @escaping @Sendable (Double) -> Void,
        onFinish: @escaping @Sendable @MainActor () -> Void
    ) throws {
        stop()
        guard let first = stems.first else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: first.sampleRate, channels: 1) else {
            throw AudioPlayerError.unsupportedFormat
        }
        var buffers: [AVAudioPCMBuffer] = []
        for stem in stems {
            let frameCount = AVAudioFrameCount(stem.samples.count)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
                  let channel = buffer.floatChannelData?[0]
            else { throw AudioPlayerError.unsupportedFormat }
            buffer.frameLength = frameCount
            stem.samples.withUnsafeBufferPointer { src in
                channel.update(from: src.baseAddress!, count: src.count)
            }
            buffers.append(buffer)
        }

        for player in players { engine.detach(player) }
        players = stems.map { _ in AVAudioPlayerNode() }
        for player in players {
            engine.attach(player)
            engine.connect(player, to: submix, format: format)
        }
        engine.connect(submix, to: reverb, format: format)
        engine.connect(reverb, to: delay, format: format)
        engine.connect(delay, to: engine.mainMixerNode, format: format)
        setGains(gains)

        // Progress comes from the first stem's tap; every stem has the same
        // length and they start together.
        let counter = FrameCounter()
        let total = Double(first.samples.count)
        // `@Sendable` is load-bearing: `AVAudioNodeTapBlock` is not Sendable in
        // the AVFoundation overlay, so without it this closure inherits the
        // enclosing `@MainActor` isolation and traps on the render thread.
        players[0].installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable pcm, _ in
            onProgress(counter.advance(by: Int(pcm.frameLength), of: total))
        }
        tapInstalled = true

        engine.prepare()
        try engine.start()

        for (index, player) in players.enumerated() {
            if index == 0 {
                player.scheduleBuffer(buffers[index], at: nil, options: [], completionCallbackType: .dataPlayedBack) { _ in
                    Task { @MainActor in onFinish() }
                }
            } else {
                player.scheduleBuffer(buffers[index], at: nil, options: [], completionHandler: nil)
            }
        }
        // One shared start time keeps the stems sample-aligned.
        let start = AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.05))
        for player in players { player.play(at: start) }
        isPlaying = true
    }

    func stop() {
        if isPlaying {
            for player in players { player.stop() }
        }
        if tapInstalled, let first = players.first {
            first.removeTap(onBus: 0)
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
