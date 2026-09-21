import XCTest
@testable import MueCore

final class AmplitudeMatrixTests: XCTestCase {
    func testLuminanceEndpoints() {
        XCTAssertEqual(AmplitudeMatrix.luminance(r: 255, g: 255, b: 255), 1, accuracy: 1e-6)
        XCTAssertEqual(AmplitudeMatrix.luminance(r: 0, g: 0, b: 0), 0)
    }

    func testFromRGBAHandlesAlphaInvertGammaAndFloor() {
        // 2x1: white opaque, white fully transparent
        let px: [UInt8] = [255, 255, 255, 255, 255, 255, 255, 0]
        var m = AmplitudeMatrix.fromRGBA(px, columns: 2, rows: 1)
        XCTAssertEqual(m.rows, 1)
        XCTAssertEqual(m.columns, 2)
        XCTAssertEqual(m[0, 0], 1, accuracy: 1e-6)
        XCTAssertEqual(m[0, 1], 0)

        m = AmplitudeMatrix.fromRGBA(px, columns: 2, rows: 1, invert: true)
        XCTAssertEqual(m[0, 0], 0, accuracy: 1e-6)
        XCTAssertEqual(m[0, 1], 1)

        let grey: [UInt8] = [128, 128, 128, 255]
        let g1 = AmplitudeMatrix.fromRGBA(grey, columns: 1, rows: 1, gamma: 1)[0, 0]
        let g2 = AmplitudeMatrix.fromRGBA(grey, columns: 1, rows: 1, gamma: 2)[0, 0]
        XCTAssertEqual(g2, g1 * g1, accuracy: 1e-5)

        XCTAssertEqual(AmplitudeMatrix.fromRGBA(grey, columns: 1, rows: 1, floor: 0.9)[0, 0], 0)
    }

    func testRowSliceAndSilence() {
        var m = AmplitudeMatrix(rows: 2, columns: 3)
        XCTAssertTrue(m.isSilent)
        m[1, 2] = 0.5
        XCTAssertFalse(m.isSilent)
        XCTAssertEqual(Array(m.row(1)), [0, 0, 0.5])
        XCTAssertEqual(Array(m.row(0)), [0, 0, 0])
    }
}
