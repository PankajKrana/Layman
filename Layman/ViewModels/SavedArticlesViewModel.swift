import Foundation
import Combine
import SwiftUI

@MainActor
final class SavedArticlesViewModel: ObservableObject {
    @Published var savedArticles: [NewsArticle] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let bookmarkService: BookmarkServicing

    init(bookmarkService: BookmarkServicing = BookmarkService.shared) {
        self.bookmarkService = bookmarkService
    }

    var filteredArticles: [NewsArticle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return savedArticles }

        return savedArticles.filter { article in
            article.title.localizedCaseInsensitiveContains(query)
        }
    }

    func loadSavedArticles() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await bookmarkService.fetchBookmarks()
            withAnimation(.easeInOut(duration: 0.2)) {
                savedArticles = fetched
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeBookmark(for article: NewsArticle) async {
        guard let articleURL = article.url?.absoluteString else { return }

        do {
            try await bookmarkService.removeBookmark(articleURL: articleURL)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                savedArticles.removeAll { $0.id == article.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
