import Foundation

/// One harmonic of a waveform: which multiple of the fundamental, and how
/// loud relative to it.
public struct Partial: Equatable, Sendable {
    public let harmonic: Int
    public let amplitude: Float

    public init(harmonic: Int, amplitude: Float) {
        self.harmonic = harmonic
        self.amplitude = amplitude
    }
}

/// The timbre of every row's oscillator. Non-sine waveforms are built from a
/// handful of band-limited partials rather than the full series: the first
/// few harmonics carry the character, and every extra partial multiplies
/// synthesis cost by the row count. They also paint ghost copies of the
/// picture at 2×, 3×… the frequency in a spectrogram, which is the point.
public enum Waveform: String, Codable, CaseIterable, Sendable {
    case sine
    case triangle
    case square
    case saw

    public var partials: [Partial] {
        switch self {
        case .sine:
            [Partial(harmonic: 1, amplitude: 1)]
        case .triangle:
            // Odd harmonics, 1/k², alternating sign.
            [1, 3, 5, 7].enumerated().map { index, k in
                Partial(harmonic: k, amplitude: (index.isMultiple(of: 2) ? 1 : -1) / Float(k * k))
            }
        case .square:
            // Odd harmonics, 1/k.
            [1, 3, 5, 7, 9, 11].map { Partial(harmonic: $0, amplitude: 1 / Float($0)) }
        case .saw:
            // All harmonics, 1/k.
            (1...6).map { Partial(harmonic: $0, amplitude: 1 / Float($0)) }
        }
    }
}
