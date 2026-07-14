import SwiftUI
import SafariServices

struct ArticleDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ArticleDetailViewModel
    @State private var safariURL: URL?
    @State private var isChatPresented = false

    init(article: NewsArticle) {
        _viewModel = StateObject(wrappedValue: ArticleDetailViewModel(article: article))
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

            Group {
                if viewModel.isLoading {
                    ProgressView("Loading article…")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    VStack(spacing: 0) {
                        topBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(viewModel.titleText)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.92))
                                    .lineLimit(2, reservesSpace: true)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                articleImage

                                TabView(selection: $viewModel.selectedCardIndex) {
                                    ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                                        ArticleDetailCardView(text: card.body)
                                            .tag(index)
                                            .padding(.horizontal, 2)
                                    }
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                .frame(height: 198)
                                .animation(.easeInOut(duration: 0.22), value: viewModel.selectedCardIndex)

                                VStack(spacing: 8) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(viewModel.cards.enumerated()), id: \.offset) { index, _ in
                                            Circle()
                                                .fill(index == viewModel.selectedCardIndex ? Color.orange : Color.black.opacity(0.22))
                                                .frame(width: index == viewModel.selectedCardIndex ? 9 : 7, height: index == viewModel.selectedCardIndex ? 9 : 7)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)

                                    Text(viewModel.pageIndicatorText)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.black.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 22)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Ask Layman") {
                isChatPresented = true
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
        }
        .sheet(isPresented: $isChatPresented) {
            NavigationStack {
                ChatScreen(article: viewModel.article)
            }
        }
        .alert("Action failed", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadRealTakeaways()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.88))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.85))
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    if let articleURL = viewModel.articleURL {
                        safariURL = articleURL
                    }
                } label: {
                    Image(systemName: "link")
                        .modifier(TopIconStyle())
                }

                Button {
                    Task {
                        await viewModel.toggleBookmark()
                    }
                } label: {
                    if viewModel.isBookmarkLoading {
                        ProgressView()
                            .tint(.black.opacity(0.88))
                            .modifier(TopIconStyle())
                    } else {
                        Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                            .modifier(TopIconStyle())
                    }
                }

                ShareLink(item: viewModel.articleURL ?? URL(string: "https://www.google.com")!) {
                    Image(systemName: "square.and.arrow.up")
                        .modifier(TopIconStyle())
                }
            }
        }
    }

    private var articleImage: some View {
        AsyncImage(url: viewModel.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(Color.black.opacity(0.16))
            case .failure:
                fallbackImage
            case .empty:
                fallbackImage
            @unknown default:
                fallbackImage
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 240, alignment: .center)
        .background(fallbackImage)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private var fallbackImage: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.8),
                Color.brown.opacity(0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct TopIconStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black.opacity(0.88))
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(0.85))
            .clipShape(Circle())
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    NavigationStack {
        ArticleDetailScreen(
            article: NewsArticle(
                title: "How startups are simplifying AI for mainstream users",
                imageURL: URL(string: "https://images.unsplash.com/photo-1498050108023-c5249f4df085"),
                url: URL(string: "https://example.com")
            )
        )
    }
}
