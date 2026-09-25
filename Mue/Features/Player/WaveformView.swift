import SwiftUI

/// The sound's loudness envelope as bars, filling in with the accent colour
/// as playback proceeds.
struct WaveformView: View {
    let envelope: [Float]
    let progress: Double

    private static let placeholder: [Float] = [0.3, 0.55, 0.4, 0.7, 0.45, 0.35, 0.6, 0.8, 0.5, 0.3, 0.65, 0.4, 0.55, 0.35, 0.7, 0.5, 0.3, 0.6]

    var body: some View {
        Canvas { context, size in
            let bars = envelope.isEmpty ? Self.placeholder : envelope
            let count = bars.count
            let gap: CGFloat = 4
            let width = max(2, (size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            for (i, value) in bars.enumerated() {
                let height = max(6, CGFloat(value) * size.height)
                let rect = CGRect(x: CGFloat(i) * (width + gap), y: (size.height - height) / 2, width: width, height: height)
                let played = Double(i) / Double(count) < progress
                let color: Color = envelope.isEmpty ? .primary.opacity(0.2) : (played ? .accentColor : .primary)
                context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
