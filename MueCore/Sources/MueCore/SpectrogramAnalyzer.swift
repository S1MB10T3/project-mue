import Foundation

/// Windowed FFT magnitude analysis for the live spectrogram.
///
/// Pure Swift radix-2 FFT so the package stays platform-neutral and testable.
/// At 4096 points it runs in well under a millisecond, which is plenty for
/// a few dozen frames per second. An Accelerate path can replace the inner
/// loop later without changing the API.
public struct SpectrogramAnalyzer: Sendable {
    public let fftSize: Int
    public let sampleRate: Double

    private let window: [Float]      // Hann
    private let windowSum: Float
    private let cosTable: [Float]    // cos(2πk/N), k < N/2
    private let sinTable: [Float]    // sin(2πk/N), k < N/2
    private let bitReversed: [Int]

    /// dB value reported for silence.
    public static let silenceDecibels: Float = -140

    public init(fftSize: Int, sampleRate: Double) {
        precondition(fftSize >= 4 && fftSize & (fftSize - 1) == 0, "fftSize must be a power of two")
        self.fftSize = fftSize
        self.sampleRate = sampleRate

        var window = [Float](repeating: 0, count: fftSize)
        var sum: Float = 0
        for i in 0..<fftSize {
            let w = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(fftSize)))
            window[i] = w
            sum += w
        }
        self.window = window
        self.windowSum = sum

        let half = fftSize / 2
        var cosT = [Float](repeating: 0, count: half)
        var sinT = [Float](repeating: 0, count: half)
        for k in 0..<half {
            let angle = 2 * Double.pi * Double(k) / Double(fftSize)
            cosT[k] = Float(cos(angle))
            sinT[k] = Float(sin(angle))
        }
        self.cosTable = cosT
        self.sinTable = sinT

        var bits = 0
        var t = fftSize
        while t > 1 { t >>= 1; bits += 1 }
        var rev = [Int](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            var r = 0
            var x = i
            for _ in 0..<bits {
                r = (r << 1) | (x & 1)
                x >>= 1
            }
            rev[i] = r
        }
        self.bitReversed = rev
    }

    /// Number of frequency bins returned by `decibels`.
    public var binCount: Int { fftSize / 2 }

    public var hertzPerBin: Double { sampleRate / Double(fftSize) }

    /// Magnitude in dB per bin for the first `fftSize` samples. 0 dB is a
    /// full-scale sine; silence reports `silenceDecibels`.
    public func decibels(_ samples: [Float]) -> [Float] {
        precondition(samples.count >= fftSize, "need at least fftSize samples")
        let n = fftSize
        var re = [Float](repeating: 0, count: n)
        var im = [Float](repeating: 0, count: n)
        for i in 0..<n {
            re[bitReversed[i]] = samples[i] * window[i]
        }

        var size = 2
        while size <= n {
            let half = size / 2
            let step = n / size
            var start = 0
            while start < n {
                var k = 0
                for j in start..<(start + half) {
                    let c = cosTable[k]
                    let s = sinTable[k]
                    let jr = re[j + half]
                    let ji = im[j + half]
                    // (jr + i ji) * (c - i s)
                    let tr = jr * c + ji * s
                    let ti = ji * c - jr * s
                    re[j + half] = re[j] - tr
                    im[j + half] = im[j] - ti
                    re[j] += tr
                    im[j] += ti
                    k += step
                }
                start += size
            }
            size *= 2
        }

        let scale = 2 / windowSum
        var out = [Float](repeating: 0, count: n / 2)
        for b in 0..<(n / 2) {
            let amp = (re[b] * re[b] + im[b] * im[b]).squareRoot() * scale
            out[b] = amp > 1e-7 ? 20 * log10(amp) : Self.silenceDecibels
        }
        return out
    }
}
