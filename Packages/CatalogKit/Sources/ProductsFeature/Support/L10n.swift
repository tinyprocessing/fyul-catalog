import CatalogCore
import Foundation

/// Every user-facing string of the feature. Keys live in `Resources/Localizable.xcstrings`.
enum L10n {
    enum List {
        static var title: String { String(localized: "list.title", bundle: .module) }
        static var searchPrompt: String { String(localized: "list.search.prompt", bundle: .module) }
        static var sort: String { String(localized: "list.sort", bundle: .module) }
        static var category: String { String(localized: "list.category", bundle: .module) }
        static var allCategories: String { String(localized: "list.category.all", bundle: .module) }
        static var categoryDisabledWhileSearching: String { String(localized: "list.category.searching", bundle: .module) }
        static var loading: String { String(localized: "list.loading", bundle: .module) }
        static var emptyTitle: String { String(localized: "list.empty.title", bundle: .module) }
        static var emptyMessage: String { String(localized: "list.empty.message", bundle: .module) }
        static var noResultsTitle: String { String(localized: "search.empty.title", bundle: .module) }
        static func noResultsMessage(_ query: String) -> String { String(localized: "search.empty.message \(query)", bundle: .module) }
        static var emptyCategoryTitle: String { String(localized: "category.empty.title", bundle: .module) }
        static var emptyCategoryMessage: String { String(localized: "category.empty.message", bundle: .module) }
        static var offlineBanner: String { String(localized: "banner.offline", bundle: .module) }
        static var refreshFailedBanner: String { String(localized: "banner.refreshFailed", bundle: .module) }
        static var pageFailed: String { String(localized: "page.failed", bundle: .module) }
        static var pageLoading: String { String(localized: "page.loading", bundle: .module) }
    }

    enum Sort {
        static func title(_ option: SortOption) -> String {
            switch option {
            case .featured: String(localized: "sort.featured", bundle: .module)
            case .priceLowToHigh: String(localized: "sort.priceLowToHigh", bundle: .module)
            case .priceHighToLow: String(localized: "sort.priceHighToLow", bundle: .module)
            case .lowStockFirst: String(localized: "sort.lowStockFirst", bundle: .module)
            case .topRated: String(localized: "sort.topRated", bundle: .module)
            }
        }
    }

    enum Error {
        static var retry: String { String(localized: "error.retry", bundle: .module) }

        static func title(_ error: APIError) -> String {
            switch error {
            case .offline: String(localized: "error.offline.title", bundle: .module)
            case .timedOut: String(localized: "error.timeout.title", bundle: .module)
            case .server, .rateLimited: String(localized: "error.server.title", bundle: .module)
            case .notFound, .client, .decoding, .transport: String(localized: "error.generic.title", bundle: .module)
            }
        }

        static func message(_ error: APIError) -> String {
            switch error {
            case .offline: String(localized: "error.offline.message", bundle: .module)
            case .timedOut: String(localized: "error.timeout.message", bundle: .module)
            case .server, .rateLimited: String(localized: "error.server.message", bundle: .module)
            case .notFound, .client, .decoding, .transport: String(localized: "error.generic.message", bundle: .module)
            }
        }
    }

    enum Stock {
        static var outOfStock: String { String(localized: "stock.out", bundle: .module) }
        static func low(_ count: Int) -> String { String(localized: "stock.low \(count)", bundle: .module) }
        static func available(_ count: Int) -> String { String(localized: "stock.available \(count)", bundle: .module) }
    }

    enum Price {
        static func discounted(price: String, original: String, discount: String) -> String {
            String(localized: "price.a11y.discounted \(price) \(original) \(discount)", bundle: .module)
        }
    }

    static func rating(_ value: String) -> String { String(localized: "rating.a11y \(value)", bundle: .module) }

    enum Detail {
        static var placeholderTitle: String { String(localized: "detail.placeholder.title", bundle: .module) }
        static var placeholderMessage: String { String(localized: "detail.placeholder.message", bundle: .module) }
        static var unavailableTitle: String { String(localized: "detail.unavailable.title", bundle: .module) }
        static var unavailableMessage: String { String(localized: "detail.unavailable.message", bundle: .module) }
        static var loading: String { String(localized: "detail.loading", bundle: .module) }
        static var loadFailed: String { String(localized: "detail.error.message", bundle: .module) }
        static var description: String { String(localized: "detail.section.description", bundle: .module) }
        static var details: String { String(localized: "detail.section.details", bundle: .module) }
        static var reviews: String { String(localized: "detail.section.reviews", bundle: .module) }
        static var noReviews: String { String(localized: "detail.reviews.empty", bundle: .module) }
        static func reviewCount(_ count: Int) -> String { String(localized: "detail.reviews.count \(count)", bundle: .module) }
        static var sku: String { String(localized: "detail.sku", bundle: .module) }
        static var brand: String { String(localized: "detail.brand", bundle: .module) }
        static var category: String { String(localized: "detail.category", bundle: .module) }
        static var minimumOrder: String { String(localized: "detail.minOrder", bundle: .module) }
        static func units(_ count: Int) -> String { String(localized: "detail.minOrder.value \(count)", bundle: .module) }
        static var shipping: String { String(localized: "detail.shipping", bundle: .module) }
        static var warranty: String { String(localized: "detail.warranty", bundle: .module) }
        static var returns: String { String(localized: "detail.returns", bundle: .module) }
        static var stock: String { String(localized: "detail.stock", bundle: .module) }
    }
}
