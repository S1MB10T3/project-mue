import XCTest
@testable import MueCore

final class SpectrogramColumnMapperTests: XCTestCase {
    func testRangesAreNonEmptyAndDescendInFrequencyFromTop() {
        let m = SpectrogramColumnMapper(rows: 128, minFrequency: 400, maxFrequency: 8000, scale: .linear, sampleRate: 44_100, fftSize: 4096)
        XCTAssertEqual(m.binRanges.count, 128)
        for r in m.binRanges { XCTAssertFalse(r.isEmpty) }
        // Row 0 is the top = highest frequency = highest bins.
        XCTAssertGreaterThan(m.binRanges[0].lowerBound, m.binRanges[127].lowerBound)
        for y in 1..<128 {
            XCTAssertLessThanOrEqual(m.binRanges[y].lowerBound, m.binRanges[y - 1].lowerBound)
        }
    }

    func testRowsCoverTheirFrequencies() {
        let hzPerBin = 44_100.0 / 4096
        let m = SpectrogramColumnMapper(rows: 64, minFrequency: 400, maxFrequency: 8000, scale: .logarithmic, sampleRate: 44_100, fftSize: 4096)
        for y in 0..<64 {
            let f = FrequencyMapping.frequency(forRow: Double(y), rows: 64, min: 400, max: 8000, scale: .logarithmic)
            let bin = Int(f / hzPerBin)
            XCTAssertTrue(m.binRanges[y].contains(bin) || m.binRanges[y].contains(bin + 1), "row \(y) should cover \(f) Hz")
        }
    }

    func testMaxPerRowPicksLoudestBin() {
        let m = SpectrogramColumnMapper(rows: 4, minFrequency: 1000, maxFrequency: 4000, scale: .linear, sampleRate: 8000, fftSize: 64)
        var perBin = [Float](repeating: -100, count: 32)
        // Row 1 is 3000 Hz → bin 24 at 125 Hz/bin.
        perBin[24] = -3
        let rows = m.maxPerRow(perBin)
        XCTAssertEqual(rows[1], -3)
        XCTAssertEqual(rows[0], -100)
        XCTAssertEqual(rows[3], -100)
    }
}
