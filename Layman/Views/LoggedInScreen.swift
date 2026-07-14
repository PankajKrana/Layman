import SwiftUI

struct LoggedInScreen: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        TabView {
            HomeScreen()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            SavedArticlesScreen()
                .tabItem {
                    Label("Saved", systemImage: "bookmark.fill")
                }

            ProfileScreen(authViewModel: viewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(.orange)
    }
}

#Preview {
    LoggedInScreen(viewModel: AuthViewModel())
}
