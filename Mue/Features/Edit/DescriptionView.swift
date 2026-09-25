import SwiftUI
import UIKit

/// Thumbnail of the picture next to a few words about what's in it.
struct DescriptionView: View {
    let photo: UIImage
    let text: String
    let isRendering: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(text.isEmpty ? "Looking at the picture…" : text)
                    .font(.body)
                    .foregroundStyle(text.isEmpty ? Color.secondary : Color.primary)
                if isRendering {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Rendering sound…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}
