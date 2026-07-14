import SwiftUI

struct ArticleDetailCardView: View {
    let text: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.94))

            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.black.opacity(0.88))
                .lineSpacing(1.5)
                .lineLimit(6, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 186)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 5)
    }
}

#Preview {
    ArticleDetailCardView(
        text: "Markets are loud, but this story\nshows why patient teams keep\nwinning through careful execution.\nRead it slowly, spot the signals,\nand decide what matters before\neveryone else catches on."
    )
    .padding()
}
