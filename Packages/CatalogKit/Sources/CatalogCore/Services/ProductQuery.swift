import Foundation

public enum SortOption: String, CaseIterable, Codable, Sendable {
    case featured
    case priceLowToHigh
    case priceHighToLow
    case lowStockFirst
    case topRated

    var queryItems: [URLQueryItem] {
        let (field, order): (String?, String) =
            switch self {
            case .featured: (nil, "")
            case .priceLowToHigh: ("price", "asc")
            case .priceHighToLow: ("price", "desc")
            case .lowStockFirst: ("stock", "asc")
            case .topRated: ("rating", "desc")
            }
        guard let field else { return [] }
        return [URLQueryItem(name: "sortBy", value: field), URLQueryItem(name: "order", value: order)]
    }
}

/// What the merchant is looking at. The API cannot combine search with a category,
/// so a non-empty search always covers every category.
public struct ProductQuery: Equatable, Sendable {
    public var search: String
    public var categorySlug: String?
    public var sort: SortOption

    public init(search: String = "", categorySlug: String? = nil, sort: SortOption = .featured) {
        self.search = search
        self.categorySlug = categorySlug
        self.sort = sort
    }

    public static let all = ProductQuery()

    public func endpoint(skip: Int, limit: Int) -> Endpoint {
        let path: String
        var items: [URLQueryItem] = []
        if !search.isEmpty {
            path = "products/search"
            items.append(URLQueryItem(name: "q", value: search))
        } else if let categorySlug {
            path = "products/category/\(categorySlug)"
        } else {
            path = "products"
        }
        items += [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "select", value: ProductSummary.selectedFields.joined(separator: ",")),
        ]
        items += sort.queryItems
        return Endpoint(path: path, queryItems: items)
    }
}
