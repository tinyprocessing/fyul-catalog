import SwiftUI

/// Moving highlight for placeholders. Turns itself off when the user asks for reduced motion.
struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            content
                .overlay {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width)
                        .offset(x: phase * proxy.size.width)
                    }
                    .clipped()
                    .allowsHitTesting(false)
                }
                .onAppear {
                    withAnimation(Motion.shimmer) { phase = 1 }
                }
        } else {
            content
        }
    }
}

extension View {
    public func shimmering(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

/// Rounded placeholder block used to sketch content while it loads.
public struct SkeletonBlock: View {
    private let width: CGFloat?
    private let height: CGFloat

    public init(width: CGFloat? = nil, height: CGFloat) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: Radius.s)
            .fill(Palette.placeholder)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
