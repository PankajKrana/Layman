import Foundation
import Supabase

enum BookmarkServiceError: LocalizedError {
    case missingConfiguration
    case missingArticleURL

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Missing Supabase configuration."
        case .missingArticleURL:
            return "This article does not have a valid URL to bookmark."
        }
    }
}

protocol BookmarkServicing {
    func saveBookmark(article: NewsArticle) async throws
    func fetchBookmarks() async throws -> [NewsArticle]
    func removeBookmark(articleURL: String) async throws
}

private struct BookmarkPayload: Encodable {
    let user_id: String
    let article_title: String
    let article_url: String
    let article_image_url: String?
}

private struct BookmarkRecord: Decodable {
    let article_title: String
    let article_url: String
    let article_image_url: String?
}

final class BookmarkService: BookmarkServicing {
    static let shared = BookmarkService()

    private let client: SupabaseClient?

    init(
        supabaseURL: String? = SecureConfig.value(for: "SUPABASE_URL"),
        supabaseAnonKey: String? = SecureConfig.value(for: "SUPABASE_ANON_KEY")
    ) {
        guard
            let supabaseURL,
            let supabaseAnonKey,
            let url = URL(string: supabaseURL)
        else {
            self.client = nil
            return
        }

        self.client = SupabaseClient(supabaseURL: url, supabaseKey: supabaseAnonKey)
    }

    func saveBookmark(article: NewsArticle) async throws {
        guard let client else {
            throw BookmarkServiceError.missingConfiguration
        }

        guard let articleURL = article.url?.absoluteString, !articleURL.isEmpty else {
            throw BookmarkServiceError.missingArticleURL
        }

        let user = try await client.auth.user()
        let payload = BookmarkPayload(
            user_id: user.id.uuidString,
            article_title: article.title,
            article_url: articleURL,
            article_image_url: article.imageURL?.absoluteString
        )

        try await client
            .from("bookmarks")
            .insert(payload)
            .execute()
    }

    func fetchBookmarks() async throws -> [NewsArticle] {
        guard let client else {
            throw BookmarkServiceError.missingConfiguration
        }

        let user = try await client.auth.user()

        let response = try await client
            .from("bookmarks")
            .select("article_title, article_url, article_image_url")
            .eq("user_id", value: user.id.uuidString)
            .execute()

        let records = try JSONDecoder().decode([BookmarkRecord].self, from: response.data)
        return records.map { record in
            NewsArticle(
                title: record.article_title,
                imageURL: URL(string: record.article_image_url ?? ""),
                url: URL(string: record.article_url)
            )
        }
    }

    func removeBookmark(articleURL: String) async throws {
        guard let client else {
            throw BookmarkServiceError.missingConfiguration
        }

        let user = try await client.auth.user()

        try await client
            .from("bookmarks")
            .delete()
            .eq("user_id", value: user.id.uuidString)
            .eq("article_url", value: articleURL)
            .execute()
    }
}
