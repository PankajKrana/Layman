import Foundation

enum NewsServiceError: LocalizedError {
    case missingAPIKey
    case noResults

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing NewsData API key. Add NEWSDATA_API_KEY to your app settings."
        case .noResults:
            return "No articles available right now."
        }
    }
}

protocol NewsServicing {
    func fetchTopHeadlines() async throws -> [NewsArticle]
}

final class NewsService: NewsServicing {
    static let shared = NewsService()

    private let apiService: APIService
    private let apiKey: String?

    init(
        apiService: APIService = .shared,
        apiKey: String? = SecureConfig.value(for: "NEWSDATA_API_KEY")
            ?? SecureConfig.value(for: "NEWS_API_KEY")
    ) {
        self.apiService = apiService
        self.apiKey = apiKey
    }

    func fetchTopHeadlines() async throws -> [NewsArticle] {
        guard let apiKey, !apiKey.isEmpty else {
            throw NewsServiceError.missingAPIKey
        }

        let endpoint = APIEndpoint<NewsDataLatestResponse>(
            baseURL: URL(string: "https://newsdata.io")!,
            path: "/api/1/latest",
            queryItems: [
                URLQueryItem(name: "apikey", value: apiKey),
                URLQueryItem(name: "country", value: "us"),
                URLQueryItem(name: "language", value: "en"),
                URLQueryItem(name: "category", value: "business,technology"),
                URLQueryItem(name: "size", value: "10")
            ],
            allowedHosts: ["newsdata.io"]
        )

        let response = try await apiService.request(endpoint)
        let articles = response.results?.compactMap { $0.toArticle() } ?? []

        guard !articles.isEmpty else {
            throw NewsServiceError.noResults
        }

        return articles
    }
}
