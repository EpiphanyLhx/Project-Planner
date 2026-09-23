import SwiftUI

struct SmoothProgressBar: View {
    let value: Double
    var tint: Color = .accentColor

    private var normalizedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))

                ProgressCapsule(progress: normalizedValue)
                    .fill(tint)
                    .frame(width: proxy.size.width)
            }
        }
        .frame(height: 7)
        .animation(.smooth(duration: 0.5), value: normalizedValue)
        .accessibilityElement()
        .accessibilityLabel("进度")
        .accessibilityValue(
            Text(normalizedValue, format: .percent.precision(.fractionLength(0)))
        )
    }
}

private struct ProgressCapsule: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let fillRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width * min(progress, 1),
            height: rect.height
        )
        return Capsule().path(in: fillRect)
    }
}
