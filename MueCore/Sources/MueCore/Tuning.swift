import Foundation

/// Optional musical quantisation of row frequencies. `free` leaves rows
/// wherever `FrequencyMapping` puts them; the others snap each row to the
/// nearest note of a C-rooted scale in 12-tone equal temperament (A4 = 440),
/// so a picture becomes chords and melody rather than a smear.
public enum Tuning: String, Codable, CaseIterable, Sendable {
    case free
    case chromatic
    case major
    case minor
    case pentatonic

    /// Semitone offsets from C that the scale allows, or `nil` for `free`.
    public var pitchClasses: [Int]? {
        switch self {
        case .free: nil
        case .chromatic: Array(0..<12)
        case .major: [0, 2, 4, 5, 7, 9, 11]
        case .minor: [0, 2, 3, 5, 7, 8, 10]
        case .pentatonic: [0, 2, 4, 7, 9]
        }
    }

    /// C0 in Hz: 57 semitones below A4.
    static let c0 = 440.0 * pow(2.0, -57.0 / 12.0)

    /// The nearest allowed note to `frequency`, in Hz. Ties go to the lower note.
    public func quantize(_ frequency: Double) -> Double {
        guard let classes = pitchClasses, frequency > 0 else { return frequency }
        let semitones = 12 * log2(frequency / Self.c0)
        let nearest = Int(semitones.rounded())
        var best = nearest
        var bestDistance = Double.infinity
        for candidate in (nearest - 6)...(nearest + 6) {
            let pitchClass = ((candidate % 12) + 12) % 12
            guard classes.contains(pitchClass) else { continue }
            let distance = abs(Double(candidate) - semitones)
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return Self.c0 * pow(2.0, Double(best) / 12.0)
    }
}
