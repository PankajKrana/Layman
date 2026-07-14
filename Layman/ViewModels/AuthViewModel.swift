import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode {
        case login
        case signUp

        var title: String {
            switch self {
            case .login:
                return "Login"
            case .signUp:
                return "Sign Up"
            }
        }

        var actionTitle: String {
            switch self {
            case .login:
                return "Log In"
            case .signUp:
                return "Create Account"
            }
        }
    }

    @Published var email = ""
    @Published var password = ""
    @Published var mode: Mode = .login
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    private let authService: AuthServicing

    init(authService: AuthServicing = SupabaseAuthService.shared) {
        self.authService = authService
        Task {
            await restoreSession()
        }
    }

    func restoreSession() async {
        isAuthenticated = await authService.hasActiveSession()
    }

    func submit() async {
        guard !isLoading else { return }

        errorMessage = validate()
        guard errorMessage == nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .login:
                try await authService.signIn(email: email, password: password)
                isAuthenticated = true
            case .signUp:
                try await authService.signUp(email: email, password: password)
                isAuthenticated = await authService.hasActiveSession()
                if !isAuthenticated {
                    mode = .login
                    errorMessage = "Account created. Verify your email, then log in."
                }
            }
        } catch {
            isAuthenticated = false
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await authService.signOut()
            isAuthenticated = false
            email = ""
            password = ""
            mode = .login
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() async {
        do {
            try await authService.deleteCurrentUser()
            isAuthenticated = false
            email = ""
            password = ""
            mode = .login
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchMode(to newMode: Mode) {
        mode = newMode
        errorMessage = nil
    }

    private func validate() -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"

        if trimmedEmail.range(of: emailRegex, options: .regularExpression) == nil {
            return "Please enter a valid email address."
        }

        if password.count < 6 {
            return "Password must be at least 6 characters long."
        }

        return nil
    }
}
