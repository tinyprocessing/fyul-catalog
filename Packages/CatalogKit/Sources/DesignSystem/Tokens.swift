import SwiftUI

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
    public static let s: CGFloat = 6
    public static let m: CGFloat = 10
    public static let l: CGFloat = 16
}

public enum Metrics {
    public static let thumbnailSize: CGFloat = 64
    public static let galleryHeight: CGFloat = 320
    public static let galleryMaxWidth: CGFloat = 480
    public static let readableWidth: CGFloat = 720
    public static let sidebarMinWidth: CGFloat = 320
    public static let sidebarIdealWidth: CGFloat = 380
    public static let stateMaxWidth: CGFloat = 360
}

/// Semantic colors: they follow dark mode and tint. Status colors are darkened in light mode
/// so small badge text keeps a 4.5:1 contrast ratio.
public enum Palette {
    public static let positive = Color(light: UIColor(red: 0.11, green: 0.47, blue: 0.20, alpha: 1), dark: .systemGreen)
    public static let warning = Color(light: UIColor(red: 0.66, green: 0.30, blue: 0.0, alpha: 1), dark: .systemOrange)
    public static let critical = Color(light: UIColor(red: 0.76, green: 0.09, blue: 0.11, alpha: 1), dark: .systemRed)
    public static let accent = Color.accentColor
    /// Hierarchical, so it stays readable on a selected (accent-filled) row.
    public static let secondaryText = HierarchicalShapeStyle.secondary
    public static let surface = Color(uiColor: .secondarySystemBackground)
    public static let placeholder = Color(uiColor: .tertiarySystemFill)
}

/// Text styles, never point sizes, so every label scales with Dynamic Type.
public enum Typography {
    public static let rowTitle = Font.body.weight(.semibold)
    public static let rowMeta = Font.subheadline
    public static let price = Font.headline.monospacedDigit()
    public static let detailTitle = Font.title2.weight(.bold)
    public static let detailPrice = Font.title3.weight(.semibold).monospacedDigit()
    public static let sectionTitle = Font.headline
    public static let caption = Font.caption
    public static let badge = Font.caption.weight(.semibold)
}

extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
