import Foundation

extension RenderedAudio {
    /// RMS loudness in `bars` equal time slices, normalised so the loudest
    /// slice is 1. Empty for empty audio; all zeros for silence.
    public func envelope(bars: Int) -> [Float] {
        guard bars > 0, !samples.isEmpty else { return [] }
        var out = [Float](repeating: 0, count: bars)
        let chunk = Swift.max(1, samples.count / bars)
        for b in 0..<bars {
            let start = b * chunk
            let end = b == bars - 1 ? samples.count : Swift.min(samples.count, start + chunk)
            guard start < end else { continue }
            var sum: Float = 0
            for i in start..<end { sum += samples[i] * samples[i] }
            out[b] = (sum / Float(end - start)).squareRoot()
        }
        if let peak = out.max(), peak > 0 {
            for i in out.indices { out[i] /= peak }
        }
        return out
    }
}
