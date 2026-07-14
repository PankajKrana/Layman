import Foundation
import Combine

struct ArticleDetailCard: Identifiable, Hashable {
    let id = UUID()
    let body: String
}

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var selectedCardIndex = 0
    @Published var isBookmarked = false
    @Published var isBookmarkLoading = false
    @Published var errorMessage: String?
    @Published var cards: [ArticleDetailCard]
    @Published var isLoading = true

    let article: NewsArticle

    private let bookmarkService: BookmarkServicing
    private let aiService: AIServicing
    private var hasLoadedRealTakeaways = false

    init(
        article: NewsArticle,
        bookmarkService: BookmarkServicing = BookmarkService.shared,
        aiService: AIServicing = AIService.shared
    ) {
        self.article = article
        self.bookmarkService = bookmarkService
        self.aiService = aiService
        self.cards = Self.loadingCards()
        self.isLoading = true
    }

    var titleText: String {
        article.title
    }

    var imageURL: URL? {
        article.imageURL
    }

    var articleURL: URL? {
        article.url
    }

    var pageIndicatorText: String {
        "\(selectedCardIndex + 1) of \(cards.count)"
    }

    func loadRealTakeaways() async {
        guard !hasLoadedRealTakeaways else { return }
        hasLoadedRealTakeaways = true
        isLoading = true

        let articleSnapshot = article

        do {
            let baseContext = try await makeArticleContext(from: articleSnapshot)
            let prompts = [
                "Give the first key takeaway from this article in exactly 2 sentences, 28 to 35 words total, using very simple casual language.",
                "Give the second key takeaway from this article in exactly 2 sentences, 28 to 35 words total, using very simple casual language.",
                "Give the third key takeaway from this article in exactly 2 sentences, 28 to 35 words total, using very simple casual language."
            ]

            var generatedCards: [ArticleDetailCard] = []
            for (index, prompt) in prompts.enumerated() {
                let answer = try await aiService.answer(question: prompt, articleContext: baseContext)
                let normalized = normalizeCardBody(answer, index: index, title: articleSnapshot.title)
                generatedCards.append(ArticleDetailCard(body: normalized))
            }

            if generatedCards.count == 3 {
                cards = generatedCards
                selectedCardIndex = 0
                isLoading = false
            } else {
                cards = Self.fallbackCards(for: articleSnapshot.title)
                isLoading = false
            }
        } catch {
            cards = Self.fallbackCards(for: articleSnapshot.title)
            isLoading = false
        }
    }

    func toggleBookmark() async {
        guard !isBookmarkLoading else { return }
        errorMessage = nil
        isBookmarkLoading = true
        defer { isBookmarkLoading = false }

        guard let articleURLString = article.url?.absoluteString else {
            errorMessage = BookmarkServiceError.missingArticleURL.localizedDescription
            return
        }

        do {
            if isBookmarked {
                try await bookmarkService.removeBookmark(articleURL: articleURLString)
                isBookmarked = false
            } else {
                do {
                    try await bookmarkService.saveBookmark(article: article)
                    isBookmarked = true
                } catch {
                    if error.localizedDescription.localizedCaseInsensitiveContains("duplicate") {
                        isBookmarked = true
                    } else {
                        throw error
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeArticleContext(from article: NewsArticle) async throws -> String {
        let snippet = await fetchArticleSnippet(from: article.url)

        return """
        Headline: \(article.title)
        Source URL: \(article.url?.absoluteString ?? "N/A")
        Article snippet: \(snippet ?? "Snippet unavailable")
        """
    }

    private func fetchArticleSnippet(from url: URL?) async -> String? {
        guard let url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }

            if let description = extractMetaDescription(from: html) {
                return description
            }

            return extractFirstParagraph(from: html)
        } catch {
            return nil
        }
    }

    private func extractMetaDescription(from html: String) -> String? {
        let patterns = [
            "<meta\\s+name=\\\"description\\\"\\s+content=\\\"([^\\\"]+)\\\"",
            "<meta\\s+property=\\\"og:description\\\"\\s+content=\\\"([^\\\"]+)\\\""
        ]

        for pattern in patterns {
            if let value = firstMatch(in: html, pattern: pattern) {
                return cleanSnippet(value)
            }
        }

        return nil
    }

    private func extractFirstParagraph(from html: String) -> String? {
        guard let paragraph = firstMatch(in: html, pattern: "<p[^>]*>(.*?)</p>") else {
            return nil
        }

        return cleanSnippet(paragraph)
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[matchRange])
    }

    private func cleanSnippet(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(420)
            .description
    }

    private func normalizeCardBody(_ raw: String, index: Int, title: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var sentences = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if sentences.isEmpty {
            sentences = [Self.fallbackSentenceOne(for: title)]
        }

        if sentences.count == 1 {
            sentences.append(Self.fallbackSentenceTwo(for: index))
        }

        var firstWords = words(from: sentences[0])
        var secondWords = words(from: sentences[1])

        if firstWords.isEmpty {
            firstWords = words(from: Self.fallbackSentenceOne(for: title))
        }
        if secondWords.isEmpty {
            secondWords = words(from: Self.fallbackSentenceTwo(for: index))
        }

        var total = firstWords.count + secondWords.count

        let fillerWords = ["for", "regular", "people", "right", "now", "in", "simple", "terms"]
        var fillerIndex = 0
        while total < 28 {
            secondWords.append(fillerWords[fillerIndex % fillerWords.count])
            fillerIndex += 1
            total += 1
        }

        while total > 35 && !secondWords.isEmpty {
            secondWords.removeLast()
            total -= 1
        }

        while total > 35 && firstWords.count > 8 {
            firstWords.removeLast()
            total -= 1
        }

        let sentenceOne = firstWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceTwo = secondWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        return "\(sentenceOne). \(sentenceTwo)."
    }

    private func words(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "[^A-Za-z0-9'%-]", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private static func fallbackSentenceOne(for title: String) -> String {
        "Quick summary: \(HeadlineFormatter.casual(title, maxLength: 52)) explains the main move in plain language"
    }

    private static func fallbackSentenceTwo(for index: Int) -> String {
        switch index {
        case 0:
            return "This helps readers understand what changed and why people are paying attention"
        case 1:
            return "It matters because the impact can show up in products jobs costs and daily decisions"
        default:
            return "Watch next updates to see if results stay strong and move beyond short term hype"
        }
    }

    private static func loadingCards() -> [ArticleDetailCard] {
        [
            ArticleDetailCard(body: "Reading this article now and preparing your first clear takeaway in simple words for easy understanding across six lines."),
            ArticleDetailCard(body: "Finding the real-world impact and turning it into a short practical explanation for readers who want no jargon or confusion today."),
            ArticleDetailCard(body: "Summarizing what to watch next so you can quickly track if this story grows into something bigger over the coming weeks.")
        ]
    }

    private static func fallbackCards(for title: String) -> [ArticleDetailCard] {
        [
            ArticleDetailCard(body: "Quick summary: \(HeadlineFormatter.casual(title, maxLength: 52)). This means the article highlights a clear shift that regular readers can understand without technical jargon or industry buzzwords."),
            ArticleDetailCard(body: "Why it matters: this story can influence products jobs costs and business decisions over time. If momentum continues it may shape what people use daily and where companies invest next."),
            ArticleDetailCard(body: "What to watch next: track official updates measurable outcomes and user adoption signs. If results stay strong after the first hype cycle this news likely has longer-term impact for regular users." )
        ]
    }
}
