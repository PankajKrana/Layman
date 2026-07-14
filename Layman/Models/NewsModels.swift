import Foundation

struct NewsArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let imageURL: URL?
    let url: URL?

    init(title: String, imageURL: URL?, url: URL?) {
        self.title = title
        self.imageURL = imageURL
        self.url = url
        self.id = url?.absoluteString ?? UUID().uuidString
    }
}

struct NewsDataLatestResponse: Decodable {
    let status: String?
    let totalResults: Int?
    let results: [NewsDataRawArticle]?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status
        case totalResults = "totalResults"
        case results
        case message
    }
}

struct NewsDataRawArticle: Decodable {
    let articleID: String?
    let title: String?
    let link: String?
    let imageURLString: String?

    enum CodingKeys: String, CodingKey {
        case articleID = "article_id"
        case title
        case link
        case imageURLString = "image_url"
    }

    func toArticle() -> NewsArticle? {
        guard let title, !title.isEmpty else { return nil }
        if title == "[Removed]" { return nil }

        return NewsArticle(
            title: title,
            imageURL: URL(string: imageURLString ?? ""),
            url: URL(string: link ?? "")
        )
    }
}
