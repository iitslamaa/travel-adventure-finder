import Foundation

struct MediaGuide: Identifiable, Hashable, Decodable {
    let id: UUID
    let slug: String
    let locale: String
    let title: String
    let subtitle: String?
    let excerpt: String?
    let bodyMarkdown: String?
    let category: String
    let countryIso2: String?
    let coverImageURL: String?
    let externalURL: String?
    let tags: [String]
    let sortOrder: Int
    let publishedAt: Date?
    let updatedAt: Date

    var destinationURL: URL? {
        guard let externalURL,
              let url = URL(string: externalURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return url
    }

    var coverURL: URL? {
        guard let coverImageURL,
              let url = URL(string: coverImageURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return url
    }

    var summary: String {
        subtitle?.nilIfBlank ?? excerpt?.nilIfBlank ?? "Travel guide"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case locale
        case title
        case subtitle
        case excerpt
        case bodyMarkdown = "body_markdown"
        case category
        case countryIso2 = "country_iso2"
        case coverImageURL = "cover_image_url"
        case externalURL = "external_url"
        case tags
        case sortOrder = "sort_order"
        case publishedAt = "published_at"
        case updatedAt = "updated_at"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
