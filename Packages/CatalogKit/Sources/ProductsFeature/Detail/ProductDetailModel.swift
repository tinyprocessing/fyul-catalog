import CatalogCore
import Foundation
import Observation

/// Shows the list summary at once, then replaces it with the full, fresher product.
@MainActor
@Observable
public final class ProductDetailModel {
    public enum Phase: Equatable {
        case loading
        case loaded(ProductDetail)
        /// The product was removed after the list was loaded.
        case unavailable
        case failed(APIError)
    }

    public let summary: ProductSummary
    public private(set) var phase: Phase = .loading

    @ObservationIgnored private let service: any ProductService
    @ObservationIgnored private var isLoading = false

    public init(summary: ProductSummary, service: any ProductService) {
        self.summary = summary
        self.service = service
    }

    public var detail: ProductDetail? {
        if case .loaded(let detail) = phase { detail } else { nil }
    }

    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        phase = .loading
        do {
            phase = .loaded(try await service.product(id: summary.id))
        } catch is CancellationError {
            return
        } catch APIError.notFound {
            phase = .unavailable
        } catch {
            phase = .failed(error.asAPIError)
        }
    }
}
