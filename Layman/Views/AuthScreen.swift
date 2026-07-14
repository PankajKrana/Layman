import SwiftUI

struct AuthScreen: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var isPasswordVisible = false

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

            VStack(spacing: 20) {
                Text(viewModel.mode.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))

                modeToggle

                VStack(spacing: 14) {
                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 8) {
                        Group {
                            if isPasswordVisible {
                                TextField("Password", text: $viewModel.password)
                            } else {
                                SecureField("Password", text: $viewModel.password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                        Button(isPasswordVisible ? "Hide" : "Show") {
                            isPasswordVisible.toggle()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.orange)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task {
                        await viewModel.submit()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isLoading ? "Please wait..." : viewModel.mode.actionTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.7 : 1)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var modeToggle: some View {
        HStack(spacing: 8) {
            modeButton(title: "Login", mode: .login)
            modeButton(title: "Sign Up", mode: .signUp)
        }
        .padding(6)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func modeButton(title: String, mode: AuthViewModel.Mode) -> some View {
        Button(title) {
            viewModel.switchMode(to: mode)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(viewModel.mode == mode ? .white : .black.opacity(0.8))
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(viewModel.mode == mode ? Color.orange : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        AuthScreen(viewModel: AuthViewModel())
    }
}
