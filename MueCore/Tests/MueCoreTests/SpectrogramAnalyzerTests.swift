import XCTest
@testable import MueCore

final class SpectrogramAnalyzerTests: XCTestCase {
    func testFullScaleSinePeaksAtItsBinNearZeroDecibels() {
        let n = 1024
        let analyzer = SpectrogramAnalyzer(fftSize: n, sampleRate: 44_100)
        let bin = 100
        let samples = (0..<n).map { i in Float(sin(2 * Double.pi * Double(bin) * Double(i) / Double(n))) }
        let dB = analyzer.decibels(samples)

        XCTAssertEqual(dB.count, n / 2)
        XCTAssertEqual(dB[bin], 0, accuracy: 0.5)
        let peakIndex = dB.indices.max { dB[$0] < dB[$1] }!
        XCTAssertEqual(peakIndex, bin)
        // Far from the peak the Hann window should have pushed leakage way down.
        XCTAssertLessThan(dB[bin + 20], -60)
        XCTAssertLessThan(dB[bin - 20], -60)
        XCTAssertLessThan(dB[10], -60)
    }

    func testSilenceReportsFloor() {
        let analyzer = SpectrogramAnalyzer(fftSize: 256, sampleRate: 8000)
        let dB = analyzer.decibels([Float](repeating: 0, count: 256))
        XCTAssertTrue(dB.allSatisfy { $0 == SpectrogramAnalyzer.silenceDecibels })
    }

    func testTwoTonesAreBothFound() {
        let n = 2048
        let analyzer = SpectrogramAnalyzer(fftSize: n, sampleRate: 44_100)
        let samples = (0..<n).map { i -> Float in
            let t = Double(i) / Double(n)
            return Float(0.5 * sin(2 * .pi * 50 * t) + 0.25 * sin(2 * .pi * 300 * t))
        }
        let dB = analyzer.decibels(samples)
        XCTAssertEqual(dB[50], 20 * log10(0.5), accuracy: 0.5)
        XCTAssertEqual(dB[300], 20 * log10(0.25), accuracy: 0.5)
        XCTAssertLessThan(dB[175], -60)
    }

    func testHertzPerBin() {
        let analyzer = SpectrogramAnalyzer(fftSize: 4096, sampleRate: 44_100)
        XCTAssertEqual(analyzer.hertzPerBin, 44_100 / 4096, accuracy: 1e-9)
        XCTAssertEqual(analyzer.binCount, 2048)
    }
}
