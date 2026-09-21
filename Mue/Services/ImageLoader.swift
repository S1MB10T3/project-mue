import CoreGraphics
import UIKit

/// A `CGImage` wrapper that can cross isolation boundaries. `CGImage` is
/// immutable, so sharing it read-only between tasks is safe.
struct SendableImage: @unchecked Sendable {
    let cgImage: CGImage
    var width: Int { cgImage.width }
    var height: Int { cgImage.height }
}

enum ImageLoader {
    /// Bakes in the photo's EXIF orientation and caps the longest side, so the
    /// expensive resampling later starts from something manageable.
    @MainActor
    static func prepare(_ image: UIImage, maxSide: CGFloat = 1024) -> SendableImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let drawn = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let cg = drawn.cgImage else { return nil }
        return SendableImage(cgImage: cg)
    }

    /// Tightly packed RGBA8 bytes of the image resampled to `columns` × `rows`,
    /// top row first. Halves the image step by step first; a single draw from
    /// a large photo down to a few hundred pixels aliases badly.
    static func rgba(_ image: SendableImage, columns: Int, rows: Int) -> [UInt8]? {
        var current = image.cgImage
        var w = current.width
        var h = current.height
        while w / 2 >= columns && h / 2 >= rows {
            w /= 2
            h /= 2
            guard let scaled = draw(current, width: w, height: h)?.makeImage() else { return nil }
            current = scaled
        }
        guard let ctx = draw(current, width: columns, height: rows), let data = ctx.data else { return nil }
        let count = columns * rows * 4
        var bytes = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: count))
        // The context is premultiplied, so transparency is already baked into
        // RGB as darkness. Report every pixel as opaque so the caller's own
        // alpha step (`AmplitudeMatrix.fromRGBA`) doesn't apply it twice.
        var i = 3
        while i < count {
            bytes[i] = 255
            i += 4
        }
        return bytes
    }

    private static func draw(_ image: CGImage, width: Int, height: Int) -> CGContext? {
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx
    }
}
