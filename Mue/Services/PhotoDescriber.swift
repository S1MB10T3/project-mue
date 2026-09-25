import Foundation
import Vision

/// A few words about what's in a picture, from on-device Vision
/// classification. Nothing leaves the phone.
enum PhotoDescriber {
    /// Comma-separated labels, most confident first, capitalised. Empty when
    /// nothing is confident enough.
    static func describe(_ image: SendableImage, minimumConfidence: Float = 0.4, limit: Int = 4) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: image.cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                    return
                }
                let labels = (request.results ?? [])
                    .filter { $0.confidence >= minimumConfidence }
                    .prefix(limit)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                continuation.resume(returning: sentence(from: Array(labels)))
            }
        }
    }

    static func sentence(from labels: [String]) -> String {
        guard !labels.isEmpty else { return "" }
        let joined = labels.joined(separator: ", ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }
}
