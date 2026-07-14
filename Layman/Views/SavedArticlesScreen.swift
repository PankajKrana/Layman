import SwiftUI

struct SavedArticlesScreen: View {
    @StateObject private var viewModel = SavedArticlesViewModel()
    @State private var isSearchVisible = false

    var body: some View {
        NavigationStack {
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

                content
            }
            .navigationDestination(for: NewsArticle.self) { article in
                ArticleDetailScreen(article: article)
            }
        }
        .task {
            if viewModel.savedArticles.isEmpty {
                await viewModel.loadSavedArticles()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading saved articles...")
                .font(.system(size: 16, weight: .semibold))
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .padding(.horizontal, 16)

                    if isSearchVisible {
                        searchBar
                            .padding(.horizontal, 16)
                    }

                    if viewModel.savedArticles.isEmpty {
                        emptyState
                            .padding(.horizontal, 16)
                            .padding(.top, 30)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if viewModel.filteredArticles.isEmpty {
                        noResultsState
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.filteredArticles) { article in
                                NavigationLink(value: article) {
                                    SavedArticleRow(article: article)
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .refreshable {
                await viewModel.loadSavedArticles()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Saved")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.black.opacity(0.88))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchVisible.toggle()
                    if !isSearchVisible {
                        viewModel.searchText = ""
                    }
                }
            } label: {
                Image(systemName: isSearchVisible ? "xmark" : "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.85))
                    .clipShape(Circle())
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.black.opacity(0.6))

            TextField("Search saved articles", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.black.opacity(0.6))

            Text("No saved articles yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black.opacity(0.88))

            Text("Bookmark stories from article details and they will appear here.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var noResultsState: some View {
        Text("No saved articles match your search.")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.black.opacity(0.66))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SavedArticleRow: View {
    let article: NewsArticle

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: article.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 86, height: 86, alignment: .center)
                case .failure:
                    rowFallback
                case .empty:
                    rowFallback
                @unknown default:
                    rowFallback
                }
            }
            .frame(width: 86, height: 86, alignment: .center)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(HeadlineFormatter.casual(article.title, maxLength: 52))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black.opacity(0.88))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var rowFallback: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.7),
                Color.orange.opacity(0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    SavedArticlesScreen()
}
