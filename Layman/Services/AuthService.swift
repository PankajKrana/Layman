import Foundation
import Supabase

enum AuthServiceError: LocalizedError {
    case missingConfiguration
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Missing Supabase configuration. Add SUPABASE_URL and SUPABASE_ANON_KEY to your app settings."
        case .deleteFailed(let message):
            return "Failed to delete account. \(message)"
        }
    }
}

protocol AuthServicing {
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut() async throws
    func hasActiveSession() async -> Bool
    func deleteCurrentUser() async throws
}

final class SupabaseAuthService: AuthServicing {
    static let shared = SupabaseAuthService()

    private let client: SupabaseClient?
    private let configurationError: AuthServiceError?
    private let supabaseURL: URL?
    private let supabaseAnonKey: String?

    init(
        client: SupabaseClient? = nil,
        supabaseURL: String? = SecureConfig.value(for: "SUPABASE_URL"),
        supabaseAnonKey: String? = SecureConfig.value(for: "SUPABASE_ANON_KEY")
    ) {
        self.supabaseAnonKey = supabaseAnonKey

        if let client {
            self.client = client
            self.configurationError = nil
            self.supabaseURL = URL(string: supabaseURL ?? "")
            return
        }

        guard
            let supabaseURL,
            let supabaseAnonKey,
            let url = URL(string: supabaseURL)
        else {
            self.client = nil
            self.configurationError = .missingConfiguration
            self.supabaseURL = nil
            return
        }

        self.supabaseURL = url
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: supabaseAnonKey)
        self.configurationError = nil
    }

    func signIn(email: String, password: String) async throws {
        let client = try requireClient()
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        let client = try requireClient()
        try await client.auth.signUp(email: email, password: password)
    }

    func signOut() async throws {
        let client = try requireClient()
        try await client.auth.signOut()
    }

    func hasActiveSession() async -> Bool {
        guard let client else { return false }
        do {
            _ = try await client.auth.session
            return true
        } catch {
            return false
        }
    }

    func deleteCurrentUser() async throws {
        let client = try requireClient()

        guard
            let baseURL = supabaseURL,
            let anonKey = supabaseAnonKey,
            !anonKey.isEmpty
        else {
            throw AuthServiceError.missingConfiguration
        }

        let session = try await client.auth.session

        guard let deleteURL = URL(string: "/auth/v1/user", relativeTo: baseURL) else {
            throw AuthServiceError.missingConfiguration
        }

        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.deleteFailed("Invalid server response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw AuthServiceError.deleteFailed(body)
        }

        try await client.auth.signOut()
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else {
            throw configurationError ?? AuthServiceError.missingConfiguration
        }
        return client
    }
}
