import XCTest
@testable import MueCore

final class EnvelopeTests: XCTestCase {
    func testLoudThenSilent() {
        var s = [Float](repeating: 0.5, count: 1000)
        for i in 500..<1000 { s[i] = 0 }
        let env = RenderedAudio(sampleRate: 1000, samples: s).envelope(bars: 10)
        XCTAssertEqual(env.count, 10)
        for b in 0..<5 { XCTAssertEqual(env[b], 1, accuracy: 1e-6) }
        for b in 5..<10 { XCTAssertEqual(env[b], 0, accuracy: 1e-6) }
    }

    func testSilenceAndEmpty() {
        XCTAssertTrue(RenderedAudio(sampleRate: 1000, samples: [Float](repeating: 0, count: 100)).envelope(bars: 5).allSatisfy { $0 == 0 })
        XCTAssertTrue(RenderedAudio(sampleRate: 1000, samples: []).envelope(bars: 5).isEmpty)
    }
}
