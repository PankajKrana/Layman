import Foundation

enum AIServiceError: LocalizedError {
    case missingConfiguration
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Missing AI configuration. Add provider API key in app settings."
        case .invalidResponse:
            return "Could not generate a valid AI response."
        case .requestFailed(let message):
            return message
        }
    }
}

protocol AIServicing {
    func answer(question: String, articleContext: String) async throws -> String
}

final class AIService: AIServicing {
    enum Provider: String {
        case openAI = "openai"
        case gemini = "gemini"
        case groq = "groq"
    }

    static let shared = AIService()

    private let session: URLSession
    private let preferredProvider: Provider
    private let openAIKey: String?
    private let groqKey: String?
    private let geminiKey: String?
    private let openAIModel: String
    private let groqModel: String
    private let geminiModel: String

    init(
        session: URLSession = .shared,
        providerString: String? = SecureConfig.value(for: "AI_PROVIDER"),
        openAIKey: String? = SecureConfig.value(for: "OPENAI_API_KEY"),
        groqKey: String? = SecureConfig.value(for: "GROQ_API_KEY"),
        geminiKey: String? = SecureConfig.value(for: "GEMINI_API_KEY"),
        openAIModel: String = SecureConfig.value(for: "OPENAI_MODEL") ?? "gpt-4o-mini",
        groqModel: String = SecureConfig.value(for: "GROQ_MODEL") ?? "llama-3.1-8b-instant",
        geminiModel: String = SecureConfig.value(for: "GEMINI_MODEL") ?? "gemini-2.0-flash"
    ) {
        self.session = session
        self.preferredProvider = Provider(rawValue: (providerString ?? "openai").lowercased()) ?? .openAI
        self.openAIKey = openAIKey
        self.groqKey = groqKey
        self.geminiKey = geminiKey
        self.openAIModel = openAIModel
        self.groqModel = groqModel
        self.geminiModel = geminiModel
    }

    func answer(question: String, articleContext: String) async throws -> String {
        let providers = try configuredProviders()
        var lastError: Error?

        for provider in providers {
            do {
                let rawAnswer: String
                switch provider {
                case .openAI:
                    do {
                        rawAnswer = try await callOpenAI(question: question, articleContext: articleContext)
                    } catch let error as AIServiceError {
                        if case .requestFailed(let message) = error, message.lowercased().contains("rate") || message.lowercased().contains("limit") {
                            try await Task.sleep(nanoseconds: 600_000_000) // 0.6s backoff
                            rawAnswer = try await callOpenAI(question: question, articleContext: articleContext)
                        } else {
                            throw error
                        }
                    }
                case .groq:
                    rawAnswer = try await callGroq(question: question, articleContext: articleContext)
                case .gemini:
                    rawAnswer = try await callGemini(question: question, articleContext: articleContext)
                }
                return enforceShortSimpleResponse(rawAnswer)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AIServiceError.invalidResponse
    }

    private func configuredProviders() throws -> [Provider] {
        var order: [Provider] = []

        if preferredProvider == .openAI {
            // Enforce OpenAI-only mode regardless of other keys
            guard hasAPIKey(for: .openAI) else {
                throw AIServiceError.missingConfiguration
            }
            return [.openAI]
        }

        let candidates: [Provider] = [preferredProvider, .openAI, .gemini, .groq]

        for provider in candidates where hasAPIKey(for: provider) {
            if !order.contains(provider) {
                order.append(provider)
            }
        }

        guard !order.isEmpty else {
            throw AIServiceError.missingConfiguration
        }
        return order
    }

    private func hasAPIKey(for provider: Provider) -> Bool {
        switch provider {
        case .openAI:
            return !(openAIKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        case .groq:
            return !(groqKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        case .gemini:
            return !(geminiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }

    private func callOpenAI(question: String, articleContext: String) async throws -> String {
        guard let openAIKey, !openAIKey.isEmpty else {
            throw AIServiceError.missingConfiguration
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIServiceError.invalidResponse
        }
        try NetworkSecurity.validateSecureURL(url, allowedHosts: NetworkSecurity.allowedAIHosts)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")

        let prompt = buildPrompt(question: question, articleContext: articleContext)
        let body = OpenAIChatRequest(
            model: openAIModel,
            messages: [
                .init(role: "system", content: "You simplify business and tech topics. Keep answers very short and simple."),
                .init(role: "user", content: prompt)
            ],
            temperature: 0.3,
            max_tokens: 120
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw providerError(provider: .openAI, data: data)
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        return text
    }

    private func callGroq(question: String, articleContext: String) async throws -> String {
        guard let groqKey, !groqKey.isEmpty else {
            throw AIServiceError.missingConfiguration
        }

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw AIServiceError.invalidResponse
        }
        try NetworkSecurity.validateSecureURL(url, allowedHosts: NetworkSecurity.allowedAIHosts)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(groqKey)", forHTTPHeaderField: "Authorization")

        let prompt = buildPrompt(question: question, articleContext: articleContext)
        let body = OpenAIChatRequest(
            model: groqModel,
            messages: [
                .init(role: "system", content: "You simplify business and tech topics. Keep answers very short and simple."),
                .init(role: "user", content: prompt)
            ],
            temperature: 0.3,
            max_tokens: 120
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw providerError(provider: .groq, data: data)
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        return text
    }

    private func callGemini(question: String, articleContext: String) async throws -> String {
        guard let geminiKey, !geminiKey.isEmpty else {
            throw AIServiceError.missingConfiguration
        }

        let selectedModel = try await resolveGeminiModelName()

        guard let escapedModel = selectedModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(escapedModel):generateContent") else {
            throw AIServiceError.invalidResponse
        }
        try NetworkSecurity.validateSecureURL(url, allowedHosts: NetworkSecurity.allowedAIHosts)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(geminiKey, forHTTPHeaderField: "x-goog-api-key")

        let prompt = buildPrompt(question: question, articleContext: articleContext)
        let body = GeminiRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ],
            generationConfig: .init(temperature: 0.3, maxOutputTokens: 120)
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw providerError(provider: .gemini, data: data)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        return text
    }

    private func resolveGeminiModelName() async throws -> String {
        guard let geminiKey, !geminiKey.isEmpty else {
            throw AIServiceError.missingConfiguration
        }

        let availableModels = try await fetchAvailableGeminiModels(apiKey: geminiKey)
        let preferred = geminiModel.trimmingCharacters(in: .whitespacesAndNewlines)

        if availableModels.contains(preferred) {
            return preferred
        }

        let fallbackOrder = [
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-2.0-flash-lite",
            "gemini-1.5-flash-latest",
            "gemini-1.5-flash"
        ]

        for candidate in fallbackOrder where availableModels.contains(candidate) {
            return candidate
        }

        if let flashModel = availableModels.first(where: { $0.localizedCaseInsensitiveContains("flash") }) {
            return flashModel
        }

        if let firstAvailable = availableModels.first {
            return firstAvailable
        }

        throw AIServiceError.requestFailed("Gemini request failed: no supported model is available for this API key.")
    }

    private func fetchAvailableGeminiModels(apiKey: String) async throws -> [String] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
            throw AIServiceError.invalidResponse
        }
        try NetworkSecurity.validateSecureURL(url, allowedHosts: NetworkSecurity.allowedAIHosts)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw providerError(provider: .gemini, data: data)
        }

        let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)

        let models = (decoded.models ?? []).compactMap { model -> String? in
            guard model.supportedGenerationMethods?.contains("generateContent") == true else {
                return nil
            }

            let cleanedName = model.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedName.hasPrefix("models/") {
                return String(cleanedName.dropFirst("models/".count))
            }
            return cleanedName
        }

        return models
    }

    private func buildPrompt(question: String, articleContext: String) -> String {
        """
        Explain in simple terms: \(articleContext). Answer in 1-2 sentences.
        User question: \(question)
        """
    }

    private func enforceShortSimpleResponse(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let selected = Array(parts.prefix(2)).joined(separator: ". ")
        let finalText = selected.isEmpty ? cleaned : selected + "."

        if finalText.count <= 260 {
            return finalText
        }
        let clipped = String(finalText.prefix(260)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clipped + "..."
    }

    private func providerError(provider: Provider, data: Data) -> AIServiceError {
        let providerLabel = provider.rawValue.capitalized
        if let apiMessage = parseProviderErrorMessage(from: data), !apiMessage.isEmpty {
            return .requestFailed("\(providerLabel) request failed: \(apiMessage)")
        }
        return .requestFailed("\(providerLabel) request failed. Check API key and model configuration.")
    }

    private func parseProviderErrorMessage(from data: Data) -> String? {
        if let openAIEnvelope = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data),
           let message = openAIEnvelope.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        if let geminiEnvelope = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data),
           let message = geminiEnvelope.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        guard let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return String(raw.prefix(180))
    }
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let max_tokens: Int
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: String
}

private struct OpenAIChatResponse: Decodable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIResponseMessage
}

private struct OpenAIResponseMessage: Decodable {
    let content: String
}

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable {
    let text: String
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double
    let maxOutputTokens: Int
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]
}

private struct GeminiResponsePart: Decodable {
    let text: String
}

private struct GeminiModelsResponse: Decodable {
    let models: [GeminiModelDescriptor]?
}

private struct GeminiModelDescriptor: Decodable {
    let name: String
    let supportedGenerationMethods: [String]?
}

private struct OpenAIErrorEnvelope: Decodable {
    let error: OpenAIErrorBody?
}

private struct OpenAIErrorBody: Decodable {
    let message: String?
}

private struct GeminiErrorEnvelope: Decodable {
    let error: GeminiErrorBody?
}

private struct GeminiErrorBody: Decodable {
    let message: String?
}
