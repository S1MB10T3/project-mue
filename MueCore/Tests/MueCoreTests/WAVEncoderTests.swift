import XCTest
@testable import MueCore

final class WAVEncoderTests: XCTestCase {
    private func u16(_ d: Data, _ o: Int) -> UInt16 { UInt16(d[o]) | UInt16(d[o + 1]) << 8 }
    private func u32(_ d: Data, _ o: Int) -> UInt32 {
        UInt32(d[o]) | UInt32(d[o + 1]) << 8 | UInt32(d[o + 2]) << 16 | UInt32(d[o + 3]) << 24
    }
    private func i16(_ d: Data, _ o: Int) -> Int16 { Int16(bitPattern: u16(d, o)) }
    private func tag(_ d: Data, _ o: Int) -> String { String(decoding: d[o..<(o + 4)], as: UTF8.self) }

    func testHeaderAndSamplesMono() {
        let d = WAVEncoder.encode(RenderedAudio(sampleRate: 44_100, samples: [0, 1, -1, 0.5]))
        XCTAssertEqual(d.count, 44 + 4 * 2)
        XCTAssertEqual(tag(d, 0), "RIFF")
        XCTAssertEqual(u32(d, 4), 36 + 8)
        XCTAssertEqual(tag(d, 8), "WAVE")
        XCTAssertEqual(tag(d, 12), "fmt ")
        XCTAssertEqual(u32(d, 16), 16)
        XCTAssertEqual(u16(d, 20), 1)
        XCTAssertEqual(u16(d, 22), 1)
        XCTAssertEqual(u32(d, 24), 44_100)
        XCTAssertEqual(u32(d, 28), 44_100 * 2)
        XCTAssertEqual(u16(d, 32), 2)
        XCTAssertEqual(u16(d, 34), 16)
        XCTAssertEqual(tag(d, 36), "data")
        XCTAssertEqual(u32(d, 40), 8)
        XCTAssertEqual(i16(d, 44), 0)
        XCTAssertEqual(i16(d, 46), 32767)
        XCTAssertEqual(i16(d, 48), -32768)
        XCTAssertEqual(i16(d, 50), 16383)
    }

    func testClippingAndInterleaving() {
        let d = WAVEncoder.encode(channels: [[2, -2], [0.5, -0.5]], sampleRate: 8000)
        XCTAssertEqual(u16(d, 22), 2)
        XCTAssertEqual(u32(d, 28), 8000 * 4)
        XCTAssertEqual(i16(d, 44), 32767)   // L0 clipped
        XCTAssertEqual(i16(d, 46), 16383)   // R0
        XCTAssertEqual(i16(d, 48), -32768)  // L1 clipped
        XCTAssertEqual(i16(d, 50), -16384)  // R1
    }
}
