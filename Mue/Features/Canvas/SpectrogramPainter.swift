import CoreGraphics
import Foundation

/// An RGBA pixel buffer with the geometry of the encoded matrix. Columns get
/// painted left to right as playback proceeds; unpainted columns stay
/// transparent so the photo shows through.
struct SpectrogramPainter {
    let columns: Int
    let rows: Int
    private var pixels: [UInt8]
    private(set) var paintedColumns = 0

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        pixels = [UInt8](repeating: 0, count: columns * rows * 4)
    }

    mutating func clear() {
        for i in pixels.indices { pixels[i] = 0 }
        paintedColumns = 0
    }

    /// Fill every column from the last painted one up to `column` with
    /// `values` (one 0…1 loudness per row, row 0 at the top).
    mutating func paint(upTo column: Int, values: [Float]) {
        let last = min(column, columns - 1)
        guard last >= paintedColumns, values.count == rows else { return }
        for x in paintedColumns...last {
            for y in 0..<rows {
                let (r, g, b) = Colormap.inferno(values[y])
                let i = (y * columns + x) * 4
                pixels[i] = r
                pixels[i + 1] = g
                pixels[i + 2] = b
                pixels[i + 3] = 255
            }
        }
        paintedColumns = last + 1
    }

    func makeImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: columns,
            height: rows,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: columns * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

/// Black → purple → orange → pale yellow, the classic spectrogram ramp.
enum Colormap {
    private static let stops: [(t: Float, r: Float, g: Float, b: Float)] = [
        (0.00, 0, 0, 4),
        (0.25, 87, 16, 110),
        (0.50, 188, 55, 84),
        (0.75, 249, 142, 9),
        (1.00, 252, 255, 164),
    ]

    private static let table: [UInt8] = {
        var lut = [UInt8](repeating: 0, count: 256 * 3)
        for i in 0..<256 {
            let t = Float(i) / 255
            var k = 0
            while k < stops.count - 2 && t > stops[k + 1].t { k += 1 }
            let a = stops[k]
            let b = stops[k + 1]
            let u = (t - a.t) / (b.t - a.t)
            lut[i * 3] = UInt8(a.r + (b.r - a.r) * u)
            lut[i * 3 + 1] = UInt8(a.g + (b.g - a.g) * u)
            lut[i * 3 + 2] = UInt8(a.b + (b.b - a.b) * u)
        }
        return lut
    }()

    static func inferno(_ value: Float) -> (UInt8, UInt8, UInt8) {
        let i = Int((max(0, min(1, value)) * 255).rounded())
        return (table[i * 3], table[i * 3 + 1], table[i * 3 + 2])
    }
}
