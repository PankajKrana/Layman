import SwiftUI

struct ProfileScreen: View {
    @StateObject private var viewModel: ProfileViewModel

    init(authViewModel: AuthViewModel) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(authViewModel: authViewModel))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(#colorLiteral(red: 0.98, green: 0.86, blue: 0.78, alpha: 1)),
                    Color(#colorLiteral(red: 0.95, green: 0.75, blue: 0.60, alpha: 1))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Profile")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.black.opacity(0.9))

                    infoCard

                    signOutButton

                    deleteAccountButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .alert("Sign Out", isPresented: $viewModel.isShowingLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await viewModel.confirmLogout()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $viewModel.isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.confirmDeleteAccount()
                }
            }
        } message: {
            Text("This will permanently delete your account and sign you out.")
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoRow(label: "Name", value: viewModel.nameText)
            infoRow(label: "Email", value: viewModel.emailText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var signOutButton: some View {
        Button {
            viewModel.requestLogoutConfirmation()
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSigningOut {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.isSigningOut ? "Signing out..." : "Sign Out")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(viewModel.isSigningOut || viewModel.isDeletingAccount)
        .opacity((viewModel.isSigningOut || viewModel.isDeletingAccount) ? 0.7 : 1)
    }

    private var deleteAccountButton: some View {
        Button {
            viewModel.requestDeleteConfirmation()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isDeletingAccount {
                    ProgressView()
                        .tint(.red)
                }
                Text(viewModel.isDeletingAccount ? "Deleting account..." : "Delete Account")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isDeletingAccount || viewModel.isSigningOut)
        .opacity((viewModel.isDeletingAccount || viewModel.isSigningOut) ? 0.7 : 1)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black.opacity(0.6))
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ProfileScreen(authViewModel: AuthViewModel())
}
