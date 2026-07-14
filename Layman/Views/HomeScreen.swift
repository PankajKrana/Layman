import SwiftUI

struct HomeScreen: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedFeaturedIndex = 0
    @State private var isSearchVisible = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
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

                    if viewModel.isLoading {
                        ProgressView("Loading articles...")
                            .font(.system(size: 16, weight: .semibold))
                    } else if let errorMessage = viewModel.errorMessage {
                        errorState(message: errorMessage)
                    } else {
                        content(width: proxy.size.width)
                    }
                }
            }
            .navigationDestination(for: NewsArticle.self) { article in
                ArticleDetailScreen(article: article)
            }
        }
        .task {
            if viewModel.featuredArticles.isEmpty && viewModel.todaysPicks.isEmpty {
                await viewModel.loadArticles()
            }
        }
    }

    private func content(width: CGFloat) -> some View {
        let cardHeight = min(300, max(220, width * 0.58))

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                    .padding(.horizontal, 16)

                if isSearchVisible {
                    searchBar
                        .padding(.horizontal, 16)
                }

                if viewModel.isSearching {
                    searchResultsSection
                } else {
                    if !viewModel.filteredFeaturedArticles.isEmpty {
                        featuredCarousel(cardHeight: cardHeight, availableWidth: width)
                    }

                    HStack {
                        Text("Today's Picks")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black.opacity(0.9))
                        Spacer()
                        Button {
                            Task { await viewModel.loadArticles() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.orange.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        ForEach(viewModel.filteredTodaysPicks) { article in
                            NavigationLink(value: article) {
                                ArticleRowView(article: article)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.loadArticles()
        }
    }

    private var header: some View {
        HStack {
            Text("Layman")
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

            TextField("Search articles", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black.opacity(0.9))
                .padding(.horizontal, 16)

            if viewModel.searchResults.isEmpty {
                Text("No matching articles found.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.65))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.searchResults) { article in
                        NavigationLink(value: article) {
                            ArticleRowView(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func featuredCarousel(cardHeight: CGFloat, availableWidth: CGFloat) -> some View {
        let cardWidth = max(availableWidth - 52, 280)

        return VStack(spacing: 10) {
            TabView(selection: $selectedFeaturedIndex) {
                ForEach(Array(viewModel.filteredFeaturedArticles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: article) {
                        FeaturedArticleCard(article: article)
                            .frame(width: cardWidth)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: cardHeight)
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Text("Could not load news")
                .font(.system(size: 20, weight: .bold))
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black.opacity(0.7))
                .padding(.horizontal, 24)

            Button("Retry") {
                Task {
                    await viewModel.loadArticles()
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 140, height: 44)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct FeaturedArticleCard: View {
    let article: NewsArticle

    var body: some View {
        ZStack(alignment: .topLeading) {
            AsyncImage(url: article.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .background(Color.black.opacity(0.18))
                case .failure:
                    fallbackBackground
                case .empty:
                    fallbackBackground
                @unknown default:
                    fallbackBackground
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(fallbackBackground)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.55),
                    .init(color: Color.black.opacity(0.72), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading) {
                Text(HeadlineFormatter.casual(article.title, maxLength: 52))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(.top, 16)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
    }

    private var fallbackBackground: some View {
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

private struct ArticleRowView: View {
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
    HomeScreen()
}
