import Foundation

/// Converts between image rows and frequencies.
///
/// Row 0 is the **top** of the image and maps to `max`, the highest
/// frequency, exactly like a spectrogram display. Rows may be fractional so
/// callers can ask for the frequency at a pixel *edge*.
public enum FrequencyMapping {
    /// Frequency in Hz for `row` in an image of `rows` rows.
    public static func frequency(
        forRow row: Double,
        rows: Int,
        min: Double,
        max: Double,
        scale: FrequencyScale
    ) -> Double {
        guard rows > 1 else { return max }
        let u = 1 - row / Double(rows - 1) // 1 at top, 0 at bottom
        switch scale {
        case .linear:
            return min + (max - min) * u
        case .logarithmic:
            return min * pow(max / min, u)
        }
    }

    /// Inverse of `frequency(forRow:)`: the (fractional) row a frequency
    /// lands on.
    public static func row(
        forFrequency f: Double,
        rows: Int,
        min: Double,
        max: Double,
        scale: FrequencyScale
    ) -> Double {
        guard rows > 1 else { return 0 }
        let u: Double
        switch scale {
        case .linear:
            u = (f - min) / (max - min)
        case .logarithmic:
            u = log(f / min) / log(max / min)
        }
        return (1 - u) * Double(rows - 1)
    }
}
