import Foundation
import Combine
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isTyping = false
    @Published var suggestions: [String] = []

    let article: NewsArticle
    private let aiService: AIServicing

    init(article: NewsArticle, aiService: AIServicing = AIService.shared) {
        self.article = article
        self.aiService = aiService

        messages = [
            ChatMessage(role: .bot, text: "Hi, I'm Layman! What can I answer for you?")
        ]

        suggestions = Self.makeSuggestions(from: article.title)
    }

    func sendCurrentMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        await send(question: trimmed)
    }

    func sendSuggestion(_ suggestion: String) async {
        await send(question: suggestion)
    }

    private func send(question: String) async {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            messages.append(ChatMessage(role: .user, text: question))
            isTyping = true
        }

        do {
            let context = "Headline: \(article.title). URL: \(article.url?.absoluteString ?? "N/A")"
            let reply = try await aiService.answer(question: question, articleContext: context)
            withAnimation(.easeInOut(duration: 0.2)) {
                isTyping = false
                messages.append(ChatMessage(role: .bot, text: reply))
            }
        } catch {
            let message = error.localizedDescription
            withAnimation(.easeInOut(duration: 0.2)) {
                isTyping = false
                messages.append(
                    ChatMessage(
                        role: .bot,
                        text: "I could not respond right now. \(message)"
                    )
                )
            }
        }
    }

    private static func makeSuggestions(from title: String) -> [String] {
        let topic = HeadlineFormatter.casual(title, maxLength: 44)

        return [
            "Can you explain \"\(topic)\" in simple words?",
            "Who is most affected by this news?",
            "What could happen next from this story?"
        ]
    }
}
