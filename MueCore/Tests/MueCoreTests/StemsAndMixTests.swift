import XCTest
@testable import MueCore

final class StemsAndMixTests: XCTestCase {
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

    private func fullMatrix(rows: Int, columns: Int) -> AmplitudeMatrix {
        var m = AmplitudeMatrix(rows: rows, columns: columns)
        for r in 0..<rows { for c in 0..<columns { m[r, c] = Float(r + 1) / Float(rows) } }
        return m
    }

    func testBandRowsPartitionAllRows() {
        var covered: [Int] = []
        for band in 0..<4 { covered += Array(AdditiveSynthesizer.bandRows(band, of: 4, rows: 10)) }
        XCTAssertEqual(covered, Array(0..<10))
        XCTAssertEqual(AdditiveSynthesizer.bandRows(0, of: 4, rows: 10), 0..<2)
        XCTAssertEqual(AdditiveSynthesizer.bandRows(3, of: 4, rows: 10), 7..<10)
    }

    func testStemsSumToTheFullRender() {
        let s = EncodingSettings(duration: 0.3, bands: 8, minFrequency: 500, maxFrequency: 4000, columnsPerSecond: 20)
        let m = fullMatrix(rows: 8, columns: s.columns)
        let seed: UInt64 = 99
        let full = AdditiveSynthesizer.render(m, settings: s, options: .init(seed: seed, normalize: false))
        let stems = AdditiveSynthesizer.renderStems(m, settings: s, bands: 4, options: .init(seed: seed, normalize: false))
        XCTAssertEqual(stems.count, 4)
        let sum = RenderedAudio.mix(stems)
        XCTAssertEqual(sum.samples.count, full.samples.count)
        for i in stride(from: 0, to: sum.samples.count, by: 97) {
            XCTAssertEqual(sum.samples[i], full.samples[i], accuracy: 1e-4)
        }
    }

    func testNormalizedStemsSumToPeak() {
        let s = EncodingSettings(duration: 0.3, bands: 8, minFrequency: 500, maxFrequency: 4000, columnsPerSecond: 20)
        let m = fullMatrix(rows: 8, columns: s.columns)
        let stems = AdditiveSynthesizer.renderStems(m, settings: s, bands: 4, options: .init(seed: 5))
        let peak = RenderedAudio.mix(stems).samples.map { abs($0) }.max() ?? 0
        XCTAssertEqual(peak, 0.9, accuracy: 1e-4)
        // Each stem alone is quieter than the mix.
        for stem in stems {
            XCTAssertLessThan(stem.samples.map { abs($0) }.max() ?? 0, 0.9)
        }
    }

    func testMixAppliesGains() {
        let a = RenderedAudio(sampleRate: 100, samples: [1, 1, 1])
        let b = RenderedAudio(sampleRate: 100, samples: [2, 2, 2])
        XCTAssertEqual(RenderedAudio.mix([a, b]).samples, [3, 3, 3])
        XCTAssertEqual(RenderedAudio.mix([a, b], gains: [0.5, 0]).samples, [0.5, 0.5, 0.5])
        XCTAssertEqual(RenderedAudio.mix([a, b], gains: [1]).samples, [3, 3, 3])
        XCTAssertTrue(RenderedAudio.mix([]).samples.isEmpty)
    }

    func testSawHasEnergyAtSecondHarmonicAndSineDoesNot() {
        // One row at 1000 Hz.
        let s = EncodingSettings(duration: 0.5, bands: 1, minFrequency: 1000, maxFrequency: 1000, columnsPerSecond: 10)
        let m = AmplitudeMatrix(rows: 1, columns: s.columns, repeating: 1)
        var saw = s; saw.waveform = .saw
        let sineAudio = AdditiveSynthesizer.render(m, settings: s, options: .init(seed: 1))
        let sawAudio = AdditiveSynthesizer.render(m, settings: saw, options: .init(seed: 1))

        let sine1 = power(at: 1000, in: sineAudio.samples, sampleRate: 44_100)
        let sine2 = power(at: 2000, in: sineAudio.samples, sampleRate: 44_100)
        let saw1 = power(at: 1000, in: sawAudio.samples, sampleRate: 44_100)
        let saw2 = power(at: 2000, in: sawAudio.samples, sampleRate: 44_100)
        XCTAssertGreaterThan(sine1, sine2 * 1000)
        // Saw's 2nd harmonic is 1/2 the amplitude → 1/4 the power of the fundamental.
        XCTAssertEqual(saw2 / saw1, 0.25, accuracy: 0.05)
    }

    func testTuningMovesRowToScaleNote() {
        // One row at 466 Hz (A#4); with major tuning it should render at 440 Hz.
        let free = EncodingSettings(duration: 0.5, bands: 1, minFrequency: 466.16, maxFrequency: 466.16, columnsPerSecond: 10)
        var major = free; major.tuning = .major
        let m = AmplitudeMatrix(rows: 1, columns: free.columns, repeating: 1)
        let audio = AdditiveSynthesizer.render(m, settings: major, options: .init(seed: 2))
        let at440 = power(at: 440, in: audio.samples, sampleRate: 44_100)
        let at466 = power(at: 466.16, in: audio.samples, sampleRate: 44_100)
        XCTAssertGreaterThan(at440, at466 * 10)
    }
}
