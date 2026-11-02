import Foundation

/// Values product can change without a release. Every key is optional in the payload:
/// a missing or malformed value falls back to its default instead of failing the whole config.
public struct FeatureFlags: Equatable, Sendable, Codable {
    public var lowStockThreshold: Int
    public var showsDiscounts: Bool
    public var showsReviews: Bool
    public var sortOptions: [SortOption]
    /// Shown above the list when set, e.g. during a backend incident.
    public var announcement: String?

    public static let defaults = FeatureFlags(
        lowStockThreshold: 10,
        showsDiscounts: true,
        showsReviews: true,
        sortOptions: SortOption.allCases,
        announcement: nil
    )

    public init(lowStockThreshold: Int, showsDiscounts: Bool, showsReviews: Bool, sortOptions: [SortOption], announcement: String?) {
        self.lowStockThreshold = lowStockThreshold
        self.showsDiscounts = showsDiscounts
        self.showsReviews = showsReviews
        self.sortOptions = sortOptions
        self.announcement = announcement
    }

    private enum CodingKeys: String, CodingKey {
        case lowStockThreshold, showsDiscounts, showsReviews, sortOptions, announcement
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FeatureFlags.defaults
        let threshold = (try? container.decodeIfPresent(Int.self, forKey: .lowStockThreshold)) ?? nil
        lowStockThreshold = threshold.map { max(0, $0) } ?? defaults.lowStockThreshold
        showsDiscounts = (try? container.decodeIfPresent(Bool.self, forKey: .showsDiscounts)) ?? nil ?? defaults.showsDiscounts
        showsReviews = (try? container.decodeIfPresent(Bool.self, forKey: .showsReviews)) ?? nil ?? defaults.showsReviews
        // Unknown options from a newer config are dropped; `featured` is always available.
        let rawSorts = (try? container.decodeIfPresent([String].self, forKey: .sortOptions)) ?? nil
        let sorts = rawSorts?.compactMap(SortOption.init(rawValue:)) ?? defaults.sortOptions
        sortOptions = sorts.contains(.featured) ? sorts : [.featured] + sorts
        let text = (try? container.decodeIfPresent(String.self, forKey: .announcement)) ?? nil
        announcement = text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
