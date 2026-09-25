import Foundation
import UIKit

/// A captured or chosen picture, ready to be turned into sound. Identity is
/// the `id`; two `Sound`s with different pictures are never equal.
struct Sound: Identifiable, Hashable, Sendable {
    let id: UUID
    /// What the user sees (thumbnail, share preview).
    let photo: UIImage
    /// Orientation-normalised, size-capped copy the engine works from.
    let prepared: SendableImage

    init(photo: UIImage, prepared: SendableImage) {
        id = UUID()
        self.photo = photo
        self.prepared = prepared
    }

    static func == (lhs: Sound, rhs: Sound) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
