/// Identifiers shared by the app, XCUITest and Maestro flows. Change them here only.
public enum AccessibilityID {
    public enum ProductList {
        public static let list = "productList.list"
        public static let searchField = "productList.search"
        public static let sortMenu = "productList.sortMenu"
        public static let categoryMenu = "productList.categoryMenu"
        public static let loading = "productList.loading"
        public static let emptyState = "productList.empty"
        public static let errorState = "productList.error"
        public static let retryButton = "productList.retry"
        public static let pageLoading = "productList.pageLoading"
        public static let pageRetryButton = "productList.pageRetry"
        public static let offlineBanner = "productList.offlineBanner"
        public static let refreshErrorBanner = "productList.refreshErrorBanner"
        public static let announcementBanner = "productList.announcement"

        public static func row(_ id: Int) -> String { "productList.row.\(id)" }
    }

    public enum ProductDetail {
        public static let root = "productDetail.root"
        public static let title = "productDetail.title"
        public static let price = "productDetail.price"
        public static let stock = "productDetail.stock"
        public static let loading = "productDetail.loading"
        public static let errorState = "productDetail.error"
        public static let retryButton = "productDetail.retry"
        public static let unavailable = "productDetail.unavailable"
        public static let reviews = "productDetail.reviews"
        public static let placeholder = "productDetail.placeholder"
    }
}
