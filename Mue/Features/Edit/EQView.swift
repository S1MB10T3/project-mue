import SwiftUI

/// One vertical slider per EQ band. Bands are horizontal strips of the
/// picture; shown low frequency on the left, high on the right, like a
/// graphic EQ, so the rightmost slider is the top of the picture.
struct EQView: View {
    /// Band gains, band 0 = top of the picture (highest frequencies).
    @Binding var gains: [Float]
    /// Frequency range per band, same order as `gains`.
    let labels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EQ")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(gains.indices.reversed()), id: \.self) { band in
                    VStack(spacing: 8) {
                        VerticalSlider(value: $gains[band])
                            .frame(height: 150)
                        Text(band < labels.count ? labels[band] : "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
