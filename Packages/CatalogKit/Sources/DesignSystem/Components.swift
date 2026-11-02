import SwiftUI

public struct Badge: View {
    public enum Style: Sendable {
        case positive, warning, critical, neutral

        var color: Color {
            switch self {
            case .positive: Palette.positive
            case .warning: Palette.warning
            case .critical: Palette.critical
            case .neutral: Palette.secondaryText
            }
        }
    }

    private let text: String
    private let style: Style

    public init(_ text: String, style: Style) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(Typography.badge)
            .monospacedDigit()
            .foregroundStyle(style.color)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs)
            .background(style.color.opacity(0.12), in: Capsule())
            .lineLimit(1)
    }
}

/// Star and value as one unit, sized from the surrounding font.
public struct RatingView: View {
    private let rating: Double

    public init(_ rating: Double) {
        self.rating = rating
    }

    public var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "star.fill")
                .imageScale(.small)
                .foregroundStyle(Palette.rating)
            Text(rating, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
        }
        .font(Typography.rowMeta.weight(.medium))
        .lineLimit(1)
    }
}

/// Five stars for a single review score.
public struct StarsView: View {
    private let rating: Int
    private let maximum = 5

    public init(_ rating: Int) {
        self.rating = rating
    }

    public var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(0..<maximum, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .foregroundStyle(index < rating ? Palette.rating : Palette.placeholder)
            }
        }
        .imageScale(.small)
        .font(Typography.caption)
    }
}

/// Remote image on a backdrop that matches the photo's own edge color, so product shots
/// on white or grey studio backgrounds blend into their frame instead of sitting in a box.
public struct RemoteImage: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let onBackdrop: ((Color) -> Void)?

    @State private var image: UIImage?
    @State private var backdrop: Color?
    @State private var failed = false

    public init(url: URL?, contentMode: ContentMode = .fill, onBackdrop: ((Color) -> Void)? = nil) {
        self.url = url
        self.contentMode = contentMode
        self.onBackdrop = onBackdrop
    }

    public var body: some View {
        ZStack {
            (backdrop ?? Palette.insetBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .padding(contentMode == .fit ? Spacing.l : 0)
                    .transition(.opacity)
            } else if failed || url == nil {
                Image(systemName: failed ? "photo.badge.exclamationmark" : "photo")
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.secondaryText)
            } else {
                Color.clear.shimmering()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
        .task(id: url) { await load() }
    }

    private func load() async {
        failed = false
        guard let url else {
            image = nil
            backdrop = nil
            return
        }
        let samplesEdge = contentMode == .fit || onBackdrop != nil
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let (prepared, edge) = try await Self.decode(data, samplingEdge: samplesEdge)
            withAnimation(Motion.gentle) {
                backdrop = edge.map(Color.init(uiColor:))
                image = prepared
            }
            if let backdrop { onBackdrop?(backdrop) }
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch is CancellationError {
            return
        } catch {
            // Never leave the previous product's photo behind a failed load.
            image = nil
            backdrop = nil
            failed = true
        }
    }

    /// Decoding and sampling stay off the main actor so scrolling does not drop frames.
    private nonisolated static func decode(_ data: Data, samplingEdge: Bool) async throws -> (UIImage, UIColor?) {
        guard let decoded = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
        let prepared = await decoded.byPreparingForDisplay() ?? decoded
        return (prepared, samplingEdge ? prepared.averageEdgeColor : nil)
    }

}

extension UIImage {
    /// Average color of the outer ring of pixels, sampled from a tiny downscaled copy.
    var averageEdgeColor: UIColor? {
        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let cgImage,
                let context = CGContext(
                    data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var sum = (r: 0, g: 0, b: 0, a: 0)
        var count = 0
        for y in 0..<side {
            for x in 0..<side where x == 0 || y == 0 || x == side - 1 || y == side - 1 {
                let offset = (y * side + x) * 4
                sum.r += Int(pixels[offset])
                sum.g += Int(pixels[offset + 1])
                sum.b += Int(pixels[offset + 2])
                sum.a += Int(pixels[offset + 3])
                count += 1
            }
        }
        // Transparent PNGs have no backdrop of their own; keep the design-system surface.
        guard sum.a / count > 200 else { return nil }
        return UIColor(
            red: CGFloat(sum.r) / CGFloat(count * 255),
            green: CGFloat(sum.g) / CGFloat(count * 255),
            blue: CGFloat(sum.b) / CGFloat(count * 255),
            alpha: 1
        )
    }
}

/// Full-area state for empty, error and placeholder screens.
public struct StateView: View {
    private let systemImage: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let actionIdentifier: String?
    private let action: (() -> Void)?

    @State private var appeared = false

    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        actionIdentifier: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.actionIdentifier = actionIdentifier
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .symbolEffect(.bounce, value: appeared)
        } description: {
            if let message { Text(message) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier(actionIdentifier ?? "")
            }
        }
        .frame(maxWidth: Metrics.stateMaxWidth)
        .onAppear { appeared = true }
    }
}

/// Inline message that sits above content instead of replacing it.
public struct Banner: View {
    private let systemImage: String
    private let text: String
    private let style: Badge.Style

    public init(systemImage: String, text: String, style: Badge.Style) {
        self.systemImage = systemImage
        self.text = text
        self.style = style
    }

    public var body: some View {
        Label(text, systemImage: systemImage)
            .font(Typography.rowMeta)
            .foregroundStyle(style == .neutral ? Palette.primaryText : style.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.m)
            .background(style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.m))
            .accessibilityElement(children: .combine)
    }
}

/// Grouped content block: the one surface style used across the app.
public struct CardModifier: ViewModifier {
    let isSelected: Bool
    let padding: CGFloat

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.l)
                    .fill(isSelected ? Palette.selectionFill : Palette.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.l)
                    .strokeBorder(Palette.accent, lineWidth: isSelected ? Metrics.selectionBorder : 0)
            }
    }
}

extension View {
    public func card(isSelected: Bool = false, padding: CGFloat = Spacing.l) -> some View {
        modifier(CardModifier(isSelected: isSelected, padding: padding))
    }
}

/// Plain button that shrinks a little while pressed, for tappable cards.
public struct PressableStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: Radius.l))
            .scaleEffect(configuration.isPressed ? Metrics.pressedScale : 1)
            .animation(Motion.standard, value: configuration.isPressed)
    }
}
