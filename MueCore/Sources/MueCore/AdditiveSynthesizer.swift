import Foundation

/// Mono PCM audio produced by the synthesiser.
public struct RenderedAudio: Equatable, Sendable {
    public let sampleRate: Double
    public var samples: [Float]

    public init(sampleRate: Double, samples: [Float]) {
        self.sampleRate = sampleRate
        self.samples = samples
    }

    public var duration: Double { Double(samples.count) / sampleRate }
}

/// Turns an `AmplitudeMatrix` into audio by summing one sine wave per row.
///
/// Each row's frequency comes from `FrequencyMapping`; its gain follows the
/// row's column values, linearly interpolated across the duration. Start
/// phases are randomised so the partials don't all line up into a click at
/// t = 0. The mix gets a short master fade and is peak-normalised.
public enum AdditiveSynthesizer {
    public struct Options: Equatable, Sendable {
        public var sampleRate: Double
        /// Master fade in/out, seconds.
        public var fade: Double
        /// Target absolute peak after normalisation.
        public var peak: Float
        /// Seed for the start phases. `nil` = random each render.
        public var seed: UInt64?

        public init(sampleRate: Double = 44_100, fade: Double = 0.01, peak: Float = 0.9, seed: UInt64? = nil) {
            self.sampleRate = sampleRate
            self.fade = fade
            self.peak = peak
            self.seed = seed
        }
    }

    public static func render(
        _ matrix: AmplitudeMatrix,
        settings: EncodingSettings,
        options: Options = Options()
    ) -> RenderedAudio {
        let sampleRate = options.sampleRate
        let count = max(1, Int((settings.duration * sampleRate).rounded(.up)))
        var out = [Float](repeating: 0, count: count)
        var rng = SplitMix64(seed: options.seed ?? UInt64.random(in: .min ... .max))

        let rows = matrix.rows
        let columns = matrix.columns
        let nyquist = sampleRate / 2
        // Column position advances from 0 to columns-1 over the whole buffer.
        let columnStep = columns > 1 ? Double(columns - 1) / Double(max(1, count - 1)) : 0
        var activeRows = 0

        out.withUnsafeMutableBufferPointer { outBuf in
            matrix.values.withUnsafeBufferPointer { vals in
                for r in 0..<rows {
                    let f = FrequencyMapping.frequency(
                        forRow: Double(r), rows: rows,
                        min: settings.minFrequency, max: settings.maxFrequency,
                        scale: settings.scale
                    )
                    guard f > 0, f < nyquist else { continue }

                    let rowBase = r * columns
                    var silent = true
                    for c in 0..<columns where vals[rowBase + c] > 0 {
                        silent = false
                        break
                    }
                    if silent { continue }

                    // Phasor: rotate (c, s) by `delta` radians per sample.
                    let phase0 = rng.nextUnitDouble() * 2 * Double.pi
                    var c = cos(phase0)
                    var s = sin(phase0)
                    let delta = 2 * Double.pi * f / sampleRate
                    let cd = cos(delta)
                    let sd = sin(delta)

                    var position = 0.0
                    for n in 0..<count {
                        let i = min(Int(position), columns - 1)
                        let frac = Float(position - Double(i))
                        let a0 = vals[rowBase + i]
                        let a1 = i + 1 < columns ? vals[rowBase + i + 1] : a0
                        let amp = a0 + (a1 - a0) * frac
                        if amp != 0 { outBuf[n] += amp * Float(s) }
                        let nc = c * cd - s * sd
                        s = s * cd + c * sd
                        c = nc
                        position += columnStep
                    }
                    activeRows += 1
                }
            }
        }

        guard activeRows > 0 else {
            return RenderedAudio(sampleRate: sampleRate, samples: out)
        }

        applyFade(&out, samples: Int(options.fade * sampleRate))
        normalize(&out, peak: options.peak)
        return RenderedAudio(sampleRate: sampleRate, samples: out)
    }

    /// Linear fade in over the first `samples` and out over the last.
    static func applyFade(_ buffer: inout [Float], samples: Int) {
        let n = min(samples, buffer.count / 2)
        guard n > 0 else { return }
        let last = buffer.count - 1
        for i in 0..<n {
            let g = Float(i) / Float(n)
            buffer[i] *= g
            buffer[last - i] *= g
        }
    }

    /// Scale in place so the absolute peak equals `peak`. Silence is left alone.
    static func normalize(_ buffer: inout [Float], peak: Float) {
        var maxAbs: Float = 0
        for v in buffer {
            let a = abs(v)
            if a > maxAbs { maxAbs = a }
        }
        guard maxAbs > 0 else { return }
        let k = peak / maxAbs
        for i in buffer.indices { buffer[i] *= k }
    }
}

/// Tiny deterministic PRNG so renders are reproducible in tests.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func nextUnitDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}
