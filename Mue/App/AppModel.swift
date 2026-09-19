import Foundation
import Observation
import MueCore

/// Single source of truth for the UI. Long-running work (resampling,
/// rendering) happens off the main actor and hands back `Sendable` values
/// from `MueCore`.
@MainActor
@Observable
final class AppModel {
    var settings = EncodingSettings()
    var status = "Pick a photo to begin."

    // Phase 2 adds: selected image, encoded matrix, rendered audio,
    // playback state, spectrogram frames. See docs/ARCHITECTURE.md.
}
