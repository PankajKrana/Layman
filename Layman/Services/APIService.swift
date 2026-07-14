import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct APIEndpoint<Response: Decodable>: Sendable {
    let baseURL: URL
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval
    let allowedHosts: Set<String>?

    init(
        baseURL: URL,
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30,
        allowedHosts: Set<String>? = nil
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.allowedHosts = allowedHosts
    }

    func asURLRequest() throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIServiceError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIServiceError.invalidURL
        }
        guard url.scheme?.lowercased() == "https" else {
            throw APIServiceError.insecureTransport
        }
        guard let host = url.host?.lowercased() else {
            throw APIServiceError.untrustedHost
        }

        if let allowedHosts, !allowedHosts.contains(host) {
            throw APIServiceError.untrustedHost
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method.rawValue
        request.httpBody = body

        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }

        return request
    }
}

enum APIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)
    case decodingFailed
    case transportError(String)
    case insecureTransport
    case untrustedHost

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to build request URL."
        case .invalidResponse:
            return "Received an invalid response from server."
        case .requestFailed(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Request failed (\(statusCode)): \(message)"
            }
            return "Request failed with status code \(statusCode)."
        case .decodingFailed:
            return "Failed to decode response data."
        case .transportError(let message):
            return message
        case .insecureTransport:
            return "Blocked non-HTTPS request."
        case .untrustedHost:
            return "Blocked request to untrusted host."
        }
    }
}

private struct APIErrorEnvelope: Decodable {
    let message: String?
    let error: String?
    let results: [String]?
}

final class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func request<Response: Decodable>(_ endpoint: APIEndpoint<Response>) async throws -> Response {
        let urlRequest = try endpoint.asURLRequest()

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = parseErrorMessage(from: data)
                throw APIServiceError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIServiceError.decodingFailed
            }
        } catch let apiError as APIServiceError {
            throw apiError
        } catch {
            throw APIServiceError.transportError(error.localizedDescription)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
            return envelope.message ?? envelope.error ?? envelope.results?.joined(separator: ", ")
        }

        guard let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty else {
            return nil
        }

        return String(raw.prefix(180))
    }
}
