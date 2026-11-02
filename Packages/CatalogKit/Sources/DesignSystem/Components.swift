import SwiftUI

public struct Badge: View {
    public enum Style: Sendable {
        case positive, warning, critical, neutral

        var color: Color {
            switch self {
            case .positive: Palette.positive
            case .warning: Palette.warning
            case .critical: Palette.critical
            case .neutral: Color.secondary
            }
        }
    }

    private let text: String
    private let style: Style

    /// `.increased` inside a selected list row: status colors would disappear on the accent fill.
    @Environment(\.backgroundProminence) private var prominence

    public init(_ text: String, style: Style) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        let color = prominence == .increased ? Color.white : style.color
        Text(text)
            .font(Typography.badge)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs)
            .background(color.opacity(prominence == .increased ? 0.2 : 0.12), in: Capsule())
    }
}

/// `AsyncImage` with a stable placeholder so rows do not jump while images load or fail.
public struct RemoteImage: View {
    private let url: URL?
    private let contentMode: ContentMode

    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    public var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .default)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder(systemImage: "photo.badge.exclamationmark")
            case .empty:
                url == nil ? placeholder(systemImage: "photo") : placeholder(systemImage: nil)
            @unknown default:
                placeholder(systemImage: "photo")
            }
        }
        .accessibilityHidden(true)
    }

    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Palette.placeholder
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(Palette.secondaryText)
            } else {
                ProgressView()
            }
        }
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
        } description: {
            if let message { Text(message) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(actionIdentifier ?? "")
            }
        }
        .frame(maxWidth: Metrics.stateMaxWidth)
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
            .foregroundStyle(style.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.m)
            .background(style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.m))
            .accessibilityElement(children: .combine)
    }
}

public struct RatingView: View {
    private let rating: Double

    public init(_ rating: Double) {
        self.rating = rating
    }

    public var body: some View {
        Label {
            Text(rating, format: .number.precision(.fractionLength(1)))
        } icon: {
            Image(systemName: "star.fill").foregroundStyle(.yellow)
        }
        .labelStyle(.titleAndIcon)
        .font(Typography.rowMeta)
    }
}
