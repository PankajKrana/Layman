import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                LoggedInScreen(viewModel: authViewModel)
            } else {
                WelcomeScreen(authViewModel: authViewModel)
            }
        }
    }
}

#Preview {
    RootView()
}
