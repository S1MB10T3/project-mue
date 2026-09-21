import XCTest
@testable import MueCore

final class FrequencyMappingTests: XCTestCase {
    func testTopRowIsMaxAndBottomRowIsMin() {
        for scale in FrequencyScale.allCases {
            XCTAssertEqual(FrequencyMapping.frequency(forRow: 0, rows: 100, min: 200, max: 8000, scale: scale), 8000, accuracy: 1e-9)
            XCTAssertEqual(FrequencyMapping.frequency(forRow: 99, rows: 100, min: 200, max: 8000, scale: scale), 200, accuracy: 1e-9)
        }
    }

    func testLinearRowsAreEvenlySpacedInHertz() {
        let a = FrequencyMapping.frequency(forRow: 10, rows: 101, min: 0, max: 1000, scale: .linear)
        let b = FrequencyMapping.frequency(forRow: 11, rows: 101, min: 0, max: 1000, scale: .linear)
        XCTAssertEqual(a - b, 10, accuracy: 1e-9)
    }

    func testLogarithmicRowsAreEvenlySpacedInOctaves() {
        // 40 steps over 4 octaves = 10 rows per octave.
        let f0 = FrequencyMapping.frequency(forRow: 0, rows: 41, min: 500, max: 8000, scale: .logarithmic)
        let f10 = FrequencyMapping.frequency(forRow: 10, rows: 41, min: 500, max: 8000, scale: .logarithmic)
        XCTAssertEqual(f0 / f10, 2, accuracy: 1e-9)
    }

    func testRowForFrequencyInvertsFrequencyForRow() {
        for scale in FrequencyScale.allCases {
            for row in [0.0, 7, 63.5, 127] {
                let f = FrequencyMapping.frequency(forRow: row, rows: 128, min: 400, max: 8000, scale: scale)
                XCTAssertEqual(FrequencyMapping.row(forFrequency: f, rows: 128, min: 400, max: 8000, scale: scale), row, accuracy: 1e-6)
            }
        }
    }

    func testSingleRowReturnsMax() {
        XCTAssertEqual(FrequencyMapping.frequency(forRow: 0, rows: 1, min: 100, max: 900, scale: .linear), 900)
    }
}
