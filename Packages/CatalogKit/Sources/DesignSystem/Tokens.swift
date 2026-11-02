import SwiftUI

/// 4-point grid. Views use these names only, never raw numbers.
public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum Radius {
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 20
}

public enum Metrics {
    public static let thumbnailSize: CGFloat = 72
    public static let galleryHeight: CGFloat = 320
    public static let readableWidth: CGFloat = 760
    public static let sidebarMinWidth: CGFloat = 340
    public static let sidebarIdealWidth: CGFloat = 400
    public static let stateMaxWidth: CGFloat = 360
    public static let selectionBorder: CGFloat = 1.5
    public static let skeletonRows = 8
    public static let pressedScale: CGFloat = 0.98
}

/// Semantic colors: they follow dark mode and increased contrast. Status colors are darkened
/// in light mode so small badge text keeps a 4.5:1 contrast ratio.
public enum Palette {
    public static let accent = Color.accentColor
    public static let positive = Color(light: UIColor(red: 0.11, green: 0.47, blue: 0.20, alpha: 1), dark: .systemGreen)
    public static let warning = Color(light: UIColor(red: 0.66, green: 0.30, blue: 0.0, alpha: 1), dark: .systemOrange)
    public static let critical = Color(light: UIColor(red: 0.76, green: 0.09, blue: 0.11, alpha: 1), dark: .systemRed)
    public static let rating = Color(light: UIColor(red: 0.85, green: 0.55, blue: 0.0, alpha: 1), dark: .systemYellow)
    public static let primaryText = Color.primary
    /// Darker than `.secondary`: system gray fails 4.5:1 on the tinted selected card.
    public static let secondaryText = Color(
        light: UIColor(red: 0.33, green: 0.34, blue: 0.37, alpha: 1),
        dark: UIColor(red: 0.70, green: 0.71, blue: 0.74, alpha: 1)
    )
    public static let screenBackground = Color(uiColor: .systemGroupedBackground)
    public static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    public static let insetBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    public static let placeholder = Color(uiColor: .tertiarySystemFill)
    public static let selectionFill = Color.accentColor.opacity(0.10)
    public static let separator = Color(uiColor: .separator)
}

/// Text styles, never point sizes, so every label scales with Dynamic Type.
public enum Typography {
    public static let rowTitle = Font.headline
    public static let rowMeta = Font.subheadline
    public static let price = Font.headline.monospacedDigit()
    public static let detailTitle = Font.title2.weight(.bold)
    public static let detailPrice = Font.title2.weight(.semibold).monospacedDigit()
    public static let sectionTitle = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let badge = Font.caption.weight(.semibold)
}

public enum Motion {
    public static let standard = Animation.snappy(duration: 0.3)
    public static let gentle = Animation.smooth(duration: 0.45)
    public static let shimmer = Animation.linear(duration: 1.2).repeatForever(autoreverses: false)
}

extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
