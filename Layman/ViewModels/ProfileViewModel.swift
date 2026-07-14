import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isShowingLogoutConfirmation = false
    @Published var isShowingDeleteConfirmation = false
    @Published var isSigningOut = false
    @Published var isDeletingAccount = false

    private let authViewModel: AuthViewModel

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    var emailText: String {
        let value = authViewModel.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "your-account@layman.app" : value
    }

    var nameText: String {
        let email = emailText
        let localPart = email.split(separator: "@").first.map(String.init) ?? "Layman User"
        let cleaned = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty {
            return "Layman User"
        }

        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    var errorMessage: String? {
        authViewModel.errorMessage
    }

    func requestLogoutConfirmation() {
        isShowingLogoutConfirmation = true
    }

    func confirmLogout() async {
        guard !isSigningOut else { return }

        isSigningOut = true
        defer { isSigningOut = false }

        await authViewModel.signOut()
    }

    func requestDeleteConfirmation() {
        isShowingDeleteConfirmation = true
    }

    func confirmDeleteAccount() async {
        guard !isDeletingAccount else { return }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        await authViewModel.deleteAccount()
    }
}
