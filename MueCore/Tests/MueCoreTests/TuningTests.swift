import XCTest
@testable import MueCore

final class TuningTests: XCTestCase {
    func testFreeLeavesFrequencyAlone() {
        XCTAssertEqual(Tuning.free.quantize(431.7), 431.7)
    }

    func testChromaticSnapsToNearestSemitone() {
        XCTAssertEqual(Tuning.chromatic.quantize(440), 440, accuracy: 1e-6)
        XCTAssertEqual(Tuning.chromatic.quantize(450), 440, accuracy: 1e-6)      // closer to A4 than A#4
        XCTAssertEqual(Tuning.chromatic.quantize(460), 466.1638, accuracy: 1e-3) // A#4
    }

    /// Exact 12-TET frequency `semitones` above A4. Rounded literals sit a
    /// few millionths of a semitone off the true midpoint, which decides ties.
    private func note(_ semitones: Double) -> Double { 440 * pow(2.0, semitones / 12) }

    func testMajorSkipsAccidentals() {
        // A#4 is not in C major; the nearest scale notes are A4 and B4, tie → lower.
        XCTAssertEqual(Tuning.major.quantize(note(1)), 440, accuracy: 1e-6)
        // 470 Hz is nearer B4 than A4.
        XCTAssertEqual(Tuning.major.quantize(470), 493.8833, accuracy: 1e-3)
    }

    func testPentatonicSkipsFourthAndSeventh() {
        // F4 (349.23) is not pentatonic; E4 is one semitone down, G4 two up.
        XCTAssertEqual(Tuning.pentatonic.quantize(349.23), 329.6276, accuracy: 1e-3)
        // B4 (493.88) → C5 (one up) rather than A4 (two down).
        XCTAssertEqual(Tuning.pentatonic.quantize(493.88), 523.2511, accuracy: 1e-3)
    }

    func testMinorHasFlatThird() {
        // E4 is not in C minor; D#4 is one semitone down, F4 one up → tie → lower.
        XCTAssertEqual(Tuning.minor.quantize(note(-5)), note(-6), accuracy: 1e-6)
    }

    func testQuantizedFrequenciesAreScaleNotes() {
        for tuning in [Tuning.major, .minor, .pentatonic] {
            for f in stride(from: 100.0, through: 8000, by: 37) {
                let q = tuning.quantize(f)
                let semis = 12 * log2(q / Tuning.c0)
                XCTAssertEqual(semis, semis.rounded(), accuracy: 1e-6)
                let pc = ((Int(semis.rounded()) % 12) + 12) % 12
                XCTAssertTrue(tuning.pitchClasses!.contains(pc), "\(tuning) produced pitch class \(pc) for \(f) Hz")
            }
        }
    }
}
