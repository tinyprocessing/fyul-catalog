import Foundation

/// The fields the list needs. Fetched with `select=` so a page stays small.
public struct ProductSummary: Identifiable, Hashable, Sendable, Decodable {
    public let id: Int
    public let title: String
    public let brand: String?
    public let category: String
    public let price: Decimal
    public let discountPercentage: Double?
    public let rating: Double?
    public let stock: Int
    public let thumbnail: URL?

    public static let selectedFields = ["title", "brand", "category", "price", "discountPercentage", "rating", "stock", "thumbnail"]

    public init(
        id: Int,
        title: String,
        brand: String? = nil,
        category: String,
        price: Decimal,
        discountPercentage: Double? = nil,
        rating: Double? = nil,
        stock: Int,
        thumbnail: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.brand = brand
        self.category = category
        self.price = price
        self.discountPercentage = discountPercentage
        self.rating = rating
        self.stock = stock
        self.thumbnail = thumbnail
    }
}

public struct ProductDetail: Identifiable, Hashable, Sendable, Decodable {
    public struct Review: Hashable, Sendable, Decodable {
        public let rating: Int
        public let comment: String
        public let date: Date

        public init(rating: Int, comment: String, date: Date) {
            self.rating = rating
            self.comment = comment
            self.date = date
        }
    }

    public let id: Int
    public let title: String
    public let description: String
    public let brand: String?
    public let category: String
    public let price: Decimal
    public let discountPercentage: Double?
    public let rating: Double?
    public let stock: Int
    public let sku: String?
    public let minimumOrderQuantity: Int?
    public let warrantyInformation: String?
    public let shippingInformation: String?
    public let returnPolicy: String?
    public let tags: [String]
    public let images: [URL]
    public let reviews: [Review]

    private enum CodingKeys: String, CodingKey {
        case id, title, description, brand, category, price, discountPercentage, rating, stock, sku
        case minimumOrderQuantity, warrantyInformation, shippingInformation, returnPolicy, tags, images, reviews
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        category = try container.decode(String.self, forKey: .category)
        price = try container.decode(Decimal.self, forKey: .price)
        discountPercentage = try container.decodeIfPresent(Double.self, forKey: .discountPercentage)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        stock = try container.decodeIfPresent(Int.self, forKey: .stock) ?? 0
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        minimumOrderQuantity = try container.decodeIfPresent(Int.self, forKey: .minimumOrderQuantity)
        warrantyInformation = try container.decodeIfPresent(String.self, forKey: .warrantyInformation)
        shippingInformation = try container.decodeIfPresent(String.self, forKey: .shippingInformation)
        returnPolicy = try container.decodeIfPresent(String.self, forKey: .returnPolicy)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        // One broken URL should not hide the whole product.
        images = (try container.decodeIfPresent([String].self, forKey: .images) ?? []).compactMap(URL.init(string:))
        reviews = try container.decodeIfPresent([Review].self, forKey: .reviews) ?? []
    }

    public init(
        id: Int,
        title: String,
        description: String,
        brand: String? = nil,
        category: String,
        price: Decimal,
        discountPercentage: Double? = nil,
        rating: Double? = nil,
        stock: Int,
        sku: String? = nil,
        minimumOrderQuantity: Int? = nil,
        warrantyInformation: String? = nil,
        shippingInformation: String? = nil,
        returnPolicy: String? = nil,
        tags: [String] = [],
        images: [URL] = [],
        reviews: [Review] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.brand = brand
        self.category = category
        self.price = price
        self.discountPercentage = discountPercentage
        self.rating = rating
        self.stock = stock
        self.sku = sku
        self.minimumOrderQuantity = minimumOrderQuantity
        self.warrantyInformation = warrantyInformation
        self.shippingInformation = shippingInformation
        self.returnPolicy = returnPolicy
        self.tags = tags
        self.images = images
        self.reviews = reviews
    }
}

public struct ProductCategory: Identifiable, Hashable, Sendable, Decodable {
    public var id: String { slug }
    public let slug: String
    public let name: String

    public init(slug: String, name: String) {
        self.slug = slug
        self.name = name
    }
}

public struct Page<Item: Sendable>: Sendable {
    public let items: [Item]
    public let total: Int
    public let skip: Int

    public init(items: [Item], total: Int, skip: Int) {
        self.items = items
        self.total = total
        self.skip = skip
    }

    public var hasMore: Bool { skip + items.count < total }
}

/// Stock is judged against a threshold that product decides remotely, not the API's own label.
public enum StockLevel: Equatable, Sendable {
    case outOfStock
    case low(Int)
    case available(Int)

    public init(stock: Int, lowThreshold: Int) {
        switch stock {
        case ...0: self = .outOfStock
        case ...lowThreshold: self = .low(stock)
        default: self = .available(stock)
        }
    }
}
