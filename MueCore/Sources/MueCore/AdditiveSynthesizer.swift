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

/// Turns an `AmplitudeMatrix` into audio by summing one oscillator per row.
///
/// Each row's frequency comes from `FrequencyMapping` (then `Tuning`); its
/// gain follows the row's column values, linearly interpolated across the
/// duration; its timbre is `Waveform`'s partials. Start phases are random
/// but derived from the seed *and the row*, so rendering the rows in
/// separate calls (see `Options.rows`) gives stems that add up exactly to
/// the full render. The mix gets a short master fade and, by default, is
/// peak-normalised.
public enum AdditiveSynthesizer {
    public struct Options: Equatable, Sendable {
        public var sampleRate: Double
        /// Master fade in/out, seconds.
        public var fade: Double
        /// Target absolute peak after normalisation.
        public var peak: Float
        /// Seed for the start phases. `nil` = random each render. Use the same
        /// seed for every stem of one sound.
        public var seed: UInt64?
        /// Only render these rows (others are silent). `nil` = all rows.
        public var rows: Range<Int>?
        /// Peak-normalise the result. Turn off when rendering stems that will
        /// be normalised together afterwards (`RenderedAudio.normalizeTogether`).
        public var normalize: Bool

        public init(
            sampleRate: Double = 44_100,
            fade: Double = 0.01,
            peak: Float = 0.9,
            seed: UInt64? = nil,
            rows: Range<Int>? = nil,
            normalize: Bool = true
        ) {
            self.sampleRate = sampleRate
            self.fade = fade
            self.peak = peak
            self.seed = seed
            self.rows = rows
            self.normalize = normalize
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
        let baseSeed = options.seed ?? UInt64.random(in: .min ... .max)

        let rows = matrix.rows
        let columns = matrix.columns
        let nyquist = sampleRate / 2
        // Column position advances from 0 to columns-1 over the whole buffer.
        let columnStep = columns > 1 ? Double(columns - 1) / Double(max(1, count - 1)) : 0
        let rowRange = (options.rows ?? 0..<rows).clamped(to: 0..<rows)

        let partials = settings.waveform.partials
        let partialScale = 1 / partials.reduce(0) { $0 + abs($1.amplitude) }

        var activeRows = 0

        out.withUnsafeMutableBufferPointer { outBuf in
            matrix.values.withUnsafeBufferPointer { vals in
                for r in rowRange {
                    var f = FrequencyMapping.frequency(
                        forRow: Double(r), rows: rows,
                        min: settings.minFrequency, max: settings.maxFrequency,
                        scale: settings.scale
                    )
                    f = settings.tuning.quantize(f)
                    guard f > 0, f < nyquist else { continue }

                    let rowBase = r * columns
                    var silent = true
                    for c in 0..<columns where vals[rowBase + c] > 0 {
                        silent = false
                        break
                    }
                    if silent { continue }

                    // Per-row phase: mixing the row index into the seed keeps
                    // stems consistent with the full render.
                    var rng = SplitMix64(seed: baseSeed &+ UInt64(r) &* 0x9E37_79B9_7F4A_7C15)
                    let phase0 = rng.nextUnitDouble() * 2 * Double.pi

                    for partial in partials {
                        let pf = f * Double(partial.harmonic)
                        guard pf < nyquist else { continue }
                        let weight = partial.amplitude * partialScale

                        // Phasor: rotate (c, s) by `delta` radians per sample.
                        // Harmonic k starts at k × the fundamental's phase so
                        // the partials line up into the intended waveform.
                        let start = phase0 * Double(partial.harmonic)
                        var c = cos(start)
                        var s = sin(start)
                        let delta = 2 * Double.pi * pf / sampleRate
                        let cd = cos(delta)
                        let sd = sin(delta)

                        var position = 0.0
                        for n in 0..<count {
                            let i = min(Int(position), columns - 1)
                            let frac = Float(position - Double(i))
                            let a0 = vals[rowBase + i]
                            let a1 = i + 1 < columns ? vals[rowBase + i + 1] : a0
                            let amp = (a0 + (a1 - a0) * frac) * weight
                            if amp != 0 { outBuf[n] += amp * Float(s) }
                            let nc = c * cd - s * sd
                            s = s * cd + c * sd
                            c = nc
                            position += columnStep
                        }
                    }
                    activeRows += 1
                }
            }
        }

        guard activeRows > 0 else {
            return RenderedAudio(sampleRate: sampleRate, samples: out)
        }

        applyFade(&out, samples: Int(options.fade * sampleRate))
        if options.normalize {
            normalize(&out, peak: options.peak)
        }
        return RenderedAudio(sampleRate: sampleRate, samples: out)
    }

    /// Render the matrix as `count` stems of contiguous row bands, top band
    /// first, sharing one seed and normalised together so they sum to a
    /// full render at `options.peak`.
    public static func renderStems(
        _ matrix: AmplitudeMatrix,
        settings: EncodingSettings,
        bands count: Int,
        options: Options = Options()
    ) -> [RenderedAudio] {
        precondition(count > 0)
        var stemOptions = options
        stemOptions.seed = options.seed ?? UInt64.random(in: .min ... .max)
        stemOptions.normalize = false
        var stems: [RenderedAudio] = []
        stems.reserveCapacity(count)
        for band in 0..<count {
            stemOptions.rows = bandRows(band, of: count, rows: matrix.rows)
            stems.append(render(matrix, settings: settings, options: stemOptions))
        }
        if options.normalize {
            RenderedAudio.normalizeTogether(&stems, peak: options.peak)
        }
        return stems
    }

    /// The rows band `band` (0 = top) covers when `rows` are split into
    /// `count` bands as evenly as possible.
    public static func bandRows(_ band: Int, of count: Int, rows: Int) -> Range<Int> {
        let start = band * rows / count
        let end = (band + 1) * rows / count
        return start..<end
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
