import Foundation

/// Maps FFT bins onto image rows so a live spectrogram can be painted with
/// exactly the geometry of the encoded picture.
public struct SpectrogramColumnMapper: Sendable {
    public let rows: Int
    /// Half-open FFT bin range covered by each row (row 0 = top).
    public let binRanges: [Range<Int>]

    public init(
        rows: Int,
        minFrequency: Double,
        maxFrequency: Double,
        scale: FrequencyScale,
        sampleRate: Double,
        fftSize: Int
    ) {
        precondition(rows > 0)
        self.rows = rows
        let binCount = fftSize / 2
        let hzPerBin = sampleRate / Double(fftSize)
        var ranges: [Range<Int>] = []
        ranges.reserveCapacity(rows)
        for y in 0..<rows {
            // Frequencies at the top and bottom edges of this pixel row.
            let fTop = FrequencyMapping.frequency(forRow: Double(y) - 0.5, rows: rows, min: minFrequency, max: maxFrequency, scale: scale)
            let fBottom = FrequencyMapping.frequency(forRow: Double(y) + 0.5, rows: rows, min: minFrequency, max: maxFrequency, scale: scale)
            var lower = Int((Swift.min(fTop, fBottom) / hzPerBin).rounded(.down))
            var upper = Int((Swift.max(fTop, fBottom) / hzPerBin).rounded(.up))
            if upper <= lower { upper = lower + 1 }
            lower = Swift.max(0, Swift.min(binCount - 1, lower))
            upper = Swift.max(lower + 1, Swift.min(binCount, upper))
            ranges.append(lower..<upper)
        }
        self.binRanges = ranges
    }

    /// The loudest bin in each row's range, in the same units as the input.
    public func maxPerRow(_ perBin: [Float]) -> [Float] {
        var out = [Float](repeating: -Float.greatestFiniteMagnitude, count: rows)
        for y in 0..<rows {
            var m = -Float.greatestFiniteMagnitude
            for b in binRanges[y] where b < perBin.count {
                if perBin[b] > m { m = perBin[b] }
            }
            out[y] = m
        }
        return out
    }
}
