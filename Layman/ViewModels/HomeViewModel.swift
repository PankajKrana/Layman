import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var featuredArticles: [NewsArticle] = []
    @Published var todaysPicks: [NewsArticle] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let newsService: NewsServicing
    private var allArticles: [NewsArticle] = []

    init(newsService: NewsServicing = NewsService.shared) {
        self.newsService = newsService
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filteredFeaturedArticles: [NewsArticle] {
        guard isSearching else { return featuredArticles }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return featuredArticles.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var filteredTodaysPicks: [NewsArticle] {
        guard isSearching else { return todaysPicks }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return todaysPicks.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var searchResults: [NewsArticle] {
        guard isSearching else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return allArticles.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    func loadArticles() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let articles = try await newsService.fetchTopHeadlines()
            allArticles = articles
            featuredArticles = Array(articles.prefix(5))
            todaysPicks = Array(articles.dropFirst(5).prefix(15))

            if featuredArticles.isEmpty {
                featuredArticles = Array(articles.prefix(3))
            }
            if todaysPicks.isEmpty {
                todaysPicks = Array(articles.prefix(10))
            }
        } catch {
            allArticles = []
            featuredArticles = []
            todaysPicks = []
            errorMessage = error.localizedDescription
        }
    }
}
