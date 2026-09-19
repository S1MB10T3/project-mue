import XCTest
@testable import MueCore

final class AdditiveSynthesizerTests: XCTestCase {
    /// Goertzel power at one frequency over the whole signal.
    private func power(at f: Double, in x: [Float], sampleRate: Double) -> Double {
        let w = 2 * Double.pi * f / sampleRate
        let coeff = 2 * cos(w)
        var s1 = 0.0, s2 = 0.0
        for v in x {
            let s0 = Double(v) + coeff * s1 - s2
            s2 = s1
            s1 = s0
        }
        return s1 * s1 + s2 * s2 - coeff * s1 * s2
    }

    private func settings(duration: Double = 0.5) -> EncodingSettings {
        // 4 rows, linear 1000…4000 Hz → rows are 4000, 3000, 2000, 1000 Hz.
        EncodingSettings(duration: duration, bands: 4, minFrequency: 1000, maxFrequency: 4000,
                         scale: .linear, columnsPerSecond: 20)
    }

    func testSingleBrightRowProducesEnergyAtItsFrequencyOnly() {
        let s = settings()
        var m = AmplitudeMatrix(rows: 4, columns: s.columns)
        for c in 0..<s.columns { m[1, c] = 1 } // row 1 → 3000 Hz
        let audio = AdditiveSynthesizer.render(m, settings: s, options: .init(seed: 1))

        XCTAssertEqual(audio.samples.count, Int(0.5 * 44_100))
        let p3000 = power(at: 3000, in: audio.samples, sampleRate: audio.sampleRate)
        for other in [1000.0, 2000, 4000, 2500] {
            let p = power(at: other, in: audio.samples, sampleRate: audio.sampleRate)
            XCTAssertGreaterThan(p3000, p * 1000, "3000 Hz should dominate \(other) Hz")
        }
    }

    func testOutputIsPeakNormalised() {
        let s = settings()
        var m = AmplitudeMatrix(rows: 4, columns: s.columns)
        for c in 0..<s.columns { m[0, c] = 0.2; m[3, c] = 0.05 }
        let audio = AdditiveSynthesizer.render(m, settings: s, options: .init(seed: 7))
        let peak = audio.samples.map { abs($0) }.max() ?? 0
        XCTAssertEqual(peak, 0.9, accuracy: 1e-5)
    }

    func testSilentMatrixRendersSilence() {
        let s = settings()
        let audio = AdditiveSynthesizer.render(AmplitudeMatrix(rows: 4, columns: s.columns), settings: s)
        XCTAssertTrue(audio.samples.allSatisfy { $0 == 0 })
        XCTAssertEqual(audio.duration, 0.5, accuracy: 1e-3)
    }

    func testGainFollowsColumnsOverTime() {
        // One row, two columns: 1 → 0. Loud at the start, quiet at the end.
        let s = EncodingSettings(duration: 1, bands: 1, minFrequency: 1000, maxFrequency: 1000,
                                 scale: .linear, columnsPerSecond: 2)
        let m = AmplitudeMatrix(rows: 1, columns: 2, values: [1, 0])
        let audio = AdditiveSynthesizer.render(m, settings: s, options: .init(seed: 3))
        let n = audio.samples.count
        func rms(_ r: Range<Int>) -> Float {
            let sum = audio.samples[r].reduce(0) { $0 + $1 * $1 }
            return (sum / Float(r.count)).squareRoot()
        }
        let first = rms(0..<(n / 4))
        let last = rms((3 * n / 4)..<n)
        XCTAssertGreaterThan(first, last * 3)
    }

    func testFadeInStartsAtZero() {
        let s = settings()
        var m = AmplitudeMatrix(rows: 4, columns: s.columns)
        for c in 0..<s.columns { m[2, c] = 1 }
        let audio = AdditiveSynthesizer.render(m, settings: s, options: .init(seed: 5))
        XCTAssertEqual(audio.samples[0], 0)
        XCTAssertEqual(audio.samples[audio.samples.count - 1], 0)
    }

    func testSeedMakesRenderDeterministic() {
        let s = settings()
        var m = AmplitudeMatrix(rows: 4, columns: s.columns)
        for c in 0..<s.columns { m[0, c] = 1; m[3, c] = 0.5 }
        let a = AdditiveSynthesizer.render(m, settings: s, options: .init(seed: 42))
        let b = AdditiveSynthesizer.render(m, settings: s, options: .init(seed: 42))
        XCTAssertEqual(a, b)
    }

    func testRowsAboveNyquistAreSkipped() {
        let s = EncodingSettings(duration: 0.2, bands: 2, minFrequency: 1000, maxFrequency: 30_000,
                                 scale: .linear, columnsPerSecond: 10)
        var m = AmplitudeMatrix(rows: 2, columns: s.columns)
        for c in 0..<s.columns { m[0, c] = 1 } // 30 kHz row only → nothing to render
        let audio = AdditiveSynthesizer.render(m, settings: s)
        XCTAssertTrue(audio.samples.allSatisfy { $0 == 0 })
    }
}
