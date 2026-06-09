import Foundation
import PostgREST
import Supabase

@MainActor
final class MediaGuideService {
    private let supabase: SupabaseManager

    init(supabase: SupabaseManager? = nil) {
        self.supabase = supabase ?? .shared
    }

    func fetchPublishedGuides(
        preferredLocale: Locale? = nil,
        limit: Int = 50
    ) async throws -> [MediaGuide] {
        let preferredLocale = preferredLocale ?? AppDisplayLocale.current
        let preferredLocales = Self.preferredLocaleCodes(for: preferredLocale)

        do {
            let response: PostgrestResponse<[MediaGuide]> = try await supabase.client
                .from("media_guides")
                .select("""
                    id,
                    slug,
                    locale,
                    title,
                    subtitle,
                    excerpt,
                    body_markdown,
                    category,
                    country_iso2,
                    cover_image_url,
                    external_url,
                    tags,
                    sort_order,
                    published_at,
                    updated_at
                """)
                .eq("status", value: "published")
                .in("locale", values: preferredLocales)
                .order("sort_order", ascending: true)
                .order("published_at", ascending: false)
                .limit(limit)
                .execute()

            return Self.contentByBestLocale(response.value, preferredLocales: preferredLocales)
        } catch let error as PostgrestError {
            guard Self.isMissingTable(error, tableName: "media_guides") else {
                throw error
            }
            return []
        }
    }

    func fetchPublishedPodcastEpisodes(
        preferredLocale: Locale? = nil,
        limit: Int = 50
    ) async throws -> [MediaPodcastEpisode] {
        let preferredLocale = preferredLocale ?? AppDisplayLocale.current
        let preferredLocales = Self.preferredLocaleCodes(for: preferredLocale)

        do {
            let response: PostgrestResponse<[MediaPodcastEpisode]> = try await supabase.client
                .from("media_podcast_episodes")
                .select("""
                    id,
                    slug,
                    locale,
                    title,
                    subtitle,
                    description,
                    season_number,
                    episode_number,
                    duration_seconds,
                    audio_url,
                    external_url,
                    cover_image_url,
                    transcript_markdown,
                    tags,
                    sort_order,
                    published_at,
                    updated_at
                """)
                .eq("status", value: "published")
                .in("locale", values: preferredLocales)
                .order("sort_order", ascending: true)
                .order("published_at", ascending: false)
                .limit(limit)
                .execute()

            return Self.contentByBestLocale(response.value, preferredLocales: preferredLocales)
        } catch let error as PostgrestError {
            guard Self.isMissingTable(error, tableName: "media_podcast_episodes") else {
                throw error
            }
            return []
        }
    }

    private static func preferredLocaleCodes(for locale: Locale) -> [String] {
        let identifier = locale.identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        let languageCode = locale.language.languageCode?.identifier.lowercased()
            ?? identifier.split(separator: "-").first.map(String.init)
            ?? "en"

        return Array(
            Set([identifier, languageCode, "en"])
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )
        .sorted { lhs, rhs in
            scoreLocale(lhs, identifier: identifier, languageCode: languageCode)
                > scoreLocale(rhs, identifier: identifier, languageCode: languageCode)
        }
    }

    private static func scoreLocale(_ locale: String, identifier: String, languageCode: String) -> Int {
        if locale == identifier { return 3 }
        if locale == languageCode { return 2 }
        if locale == "en" { return 1 }
        return 0
    }

    private static func contentByBestLocale<Content: MediaRemoteContent>(
        _ content: [Content],
        preferredLocales: [String]
    ) -> [Content] {
        var orderedSlugs: [String] = []
        var contentBySlug: [String: Content] = [:]

        for item in content {
            let slug = item.slug.lowercased()
            if contentBySlug[slug] == nil {
                orderedSlugs.append(slug)
                contentBySlug[slug] = item
                continue
            }

            guard let existing = contentBySlug[slug] else { continue }
            if localeRank(item.locale, preferredLocales: preferredLocales) > localeRank(existing.locale, preferredLocales: preferredLocales) {
                contentBySlug[slug] = item
            }
        }

        return orderedSlugs.compactMap { contentBySlug[$0] }
    }

    private static func localeRank(_ locale: String, preferredLocales: [String]) -> Int {
        guard let index = preferredLocales.firstIndex(of: locale.lowercased()) else {
            return 0
        }
        return preferredLocales.count - index
    }

    private static func isMissingTable(_ error: PostgrestError, tableName: String) -> Bool {
        let haystack = [
            error.message,
            error.detail,
            error.hint,
            error.code
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        return haystack.contains(tableName) && (
            haystack.contains("does not exist")
            || haystack.contains("not found")
            || haystack.contains("schema cache")
        )
    }
}

private protocol MediaRemoteContent {
    var slug: String { get }
    var locale: String { get }
}

extension MediaGuide: MediaRemoteContent {}
extension MediaPodcastEpisode: MediaRemoteContent {}
