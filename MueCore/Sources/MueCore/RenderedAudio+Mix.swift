import Foundation

extension RenderedAudio {
    /// Sum of `stems`, each scaled by the matching entry in `gains` (missing
    /// entries count as 1). All stems must share a sample rate and length.
    public static func mix(_ stems: [RenderedAudio], gains: [Float] = []) -> RenderedAudio {
        guard let first = stems.first else { return RenderedAudio(sampleRate: 44_100, samples: []) }
        var out = [Float](repeating: 0, count: first.samples.count)
        for (index, stem) in stems.enumerated() {
            precondition(stem.samples.count == out.count && stem.sampleRate == first.sampleRate,
                         "stems must match in length and sample rate")
            let gain = index < gains.count ? gains[index] : 1
            guard gain != 0 else { continue }
            stem.samples.withUnsafeBufferPointer { src in
                for i in 0..<out.count { out[i] += src[i] * gain }
            }
        }
        return RenderedAudio(sampleRate: first.sampleRate, samples: out)
    }

    /// Scale every stem by one factor so their *sum* peaks at `peak`. Keeps
    /// the stems' relative loudness, unlike normalising each on its own.
    public static func normalizeTogether(_ stems: inout [RenderedAudio], peak: Float = 0.9) {
        guard !stems.isEmpty else { return }
        let sum = mix(stems)
        var maxAbs: Float = 0
        for v in sum.samples {
            let a = abs(v)
            if a > maxAbs { maxAbs = a }
        }
        guard maxAbs > 0 else { return }
        let k = peak / maxAbs
        for s in stems.indices {
            for i in stems[s].samples.indices { stems[s].samples[i] *= k }
        }
    }
}
