import SwiftUI

/// A system `Slider` turned on its side: minimum at the bottom.
struct VerticalSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float> = 0...1

    var body: some View {
        GeometryReader { geo in
            Slider(value: $value, in: range)
                .frame(width: geo.size.height, height: geo.size.width)
                .rotationEffect(.degrees(-90))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
