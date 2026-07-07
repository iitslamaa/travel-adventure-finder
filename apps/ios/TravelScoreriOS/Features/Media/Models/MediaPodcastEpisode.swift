import Foundation

struct MediaPodcastEpisode: Identifiable, Hashable, Decodable {
    let id: UUID
    let slug: String
    let locale: String
    let title: String
    let subtitle: String?
    let description: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let durationSeconds: Int?
    let audioURL: String?
    let externalURL: String?
    let coverImageURL: String?
    let transcriptMarkdown: String?
    let tags: [String]
    let sortOrder: Int
    let publishedAt: Date?
    let updatedAt: Date

    var playbackURL: URL? {
        url(from: audioURL) ?? url(from: externalURL)
    }

    var coverURL: URL? {
        url(from: coverImageURL)
    }

    var summary: String {
        subtitle?.nilIfBlank ?? description?.nilIfBlank ?? "Podcast episode"
    }

    var durationText: String? {
        guard let durationSeconds else { return nil }
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func url(from rawValue: String?) -> URL? {
        guard let rawValue,
              let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return url
    }

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case locale
        case title
        case subtitle
        case description
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case durationSeconds = "duration_seconds"
        case audioURL = "audio_url"
        case externalURL = "external_url"
        case coverImageURL = "cover_image_url"
        case transcriptMarkdown = "transcript_markdown"
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
