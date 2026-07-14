import SwiftUI

struct ChatScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool

    init(article: NewsArticle) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(article: article))
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

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                        }

                        if viewModel.messages.count <= 2 {
                            suggestionsBar
                        }

                        if viewModel.isTyping {
                            TypingBubble()
                                .id("typing")
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .padding(.bottom, 80)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isTyping) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("Ask Layman")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
            }
        }
        .safeAreaInset(edge: .bottom) {
            inputBar
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
        }
    }

    private var suggestionsBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question Suggestions:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black.opacity(0.65))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        Button {
                            Task {
                                await viewModel.sendSuggestion(suggestion)
                            }
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.85))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Type your question...", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            HStack(spacing: 6) {
                Button {
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Microphone")

                Button {
                    Task {
                        await viewModel.sendCurrentMessage()
                    }
                    isInputFocused = false
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.orange)
                        .clipShape(Circle())
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                .accessibilityLabel("Send message")
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        Task { @MainActor in
            if viewModel.isTyping {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            } else if let last = viewModel.messages.last {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .bot {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.orange)
                    .clipShape(Circle())
            } else {
                Spacer(minLength: 32)
            }

            Text(message.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(message.role == .user ? .white : .black.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(message.role == .user ? Color.orange : Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Circle())
            } else {
                Spacer(minLength: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

private struct TypingBubble: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .clipShape(Circle())

            HStack(spacing: 6) {
                dot(delay: 0)
                dot(delay: 0.16)
                dot(delay: 0.32)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 32)
        }
        .onAppear {
            animate = true
        }
    }

    private func dot(delay: Double) -> some View {
        Circle()
            .fill(Color.black.opacity(0.65))
            .frame(width: 6, height: 6)
            .scaleEffect(animate ? 1 : 0.5)
            .opacity(animate ? 1 : 0.4)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever()
                    .delay(delay),
                value: animate
            )
    }
}

#Preview {
    NavigationStack {
        ChatScreen(
            article: NewsArticle(
                title: "How startups are simplifying AI for mainstream users",
                imageURL: nil,
                url: URL(string: "https://example.com")
            )
        )
    }
}
