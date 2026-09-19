import Foundation

/// A rows × columns grid of loudness values in 0…1, row-major, row 0 at the
/// top. This is the encoded image: each row will drive one oscillator, each
/// column is one slice of time.
public struct AmplitudeMatrix: Equatable, Sendable {
    public let rows: Int
    public let columns: Int
    /// `values[row * columns + column]`
    public private(set) var values: [Float]

    public init(rows: Int, columns: Int, values: [Float]) {
        precondition(rows > 0 && columns > 0, "AmplitudeMatrix needs at least one cell")
        precondition(values.count == rows * columns, "values.count must equal rows * columns")
        self.rows = rows
        self.columns = columns
        self.values = values
    }

    public init(rows: Int, columns: Int, repeating value: Float = 0) {
        self.init(rows: rows, columns: columns, values: Array(repeating: value, count: rows * columns))
    }

    public subscript(row: Int, column: Int) -> Float {
        get { values[row * columns + column] }
        set { values[row * columns + column] = newValue }
    }

    /// The values of one row, as a slice of the backing array.
    public func row(_ r: Int) -> ArraySlice<Float> {
        values[(r * columns)..<((r + 1) * columns)]
    }

    public var isSilent: Bool {
        !values.contains { $0 > 0 }
    }

    /// Rec. 709 luma in 0…1 from 8-bit RGB.
    public static func luminance(r: UInt8, g: UInt8, b: UInt8) -> Float {
        (0.2126 * Float(r) + 0.7152 * Float(g) + 0.0722 * Float(b)) / 255
    }

    /// Build a matrix from tightly packed 8-bit RGBA pixels (row-major, top
    /// row first, exactly `columns * rows * 4` bytes).
    ///
    /// Pipeline per pixel: luminance × alpha → invert → gamma → floor.
    public static func fromRGBA(
        _ pixels: [UInt8],
        columns: Int,
        rows: Int,
        invert: Bool = false,
        gamma: Double = 1,
        floor: Double = 0
    ) -> AmplitudeMatrix {
        precondition(pixels.count == columns * rows * 4, "expected \(columns * rows * 4) bytes, got \(pixels.count)")
        var values = [Float](repeating: 0, count: rows * columns)
        let g = Float(gamma)
        let fl = Float(floor)
        pixels.withUnsafeBufferPointer { p in
            var i = 0
            for cell in 0..<(rows * columns) {
                var v = luminance(r: p[i], g: p[i + 1], b: p[i + 2]) * (Float(p[i + 3]) / 255)
                if invert { v = 1 - v }
                if g != 1 { v = powf(v, g) }
                if v < fl { v = 0 }
                values[cell] = v
                i += 4
            }
        }
        return AmplitudeMatrix(rows: rows, columns: columns, values: values)
    }
}
