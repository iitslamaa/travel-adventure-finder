//
//  CountryDetailView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/11/25.
//

import SwiftUI
import PostgREST
import Supabase

struct CountryDetailView: View {
    @State var country: Country
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var bucketListStore: BucketListStore
    @EnvironmentObject private var traveledStore: TraveledStore
    @StateObject private var visaStore = VisaRequirementsStore.shared
    @State private var scrollAnchor: String? = nil
    @State private var countryLanguageProfile: CountryLanguageProfile?

    private var displayedCountry: Country {
        country.applyingOverallScore(using: weightsStore.weights, selectedMonth: weightsStore.selectedMonth)
    }

    private var languageCompatibility: CountryLanguageCompatibilityResult? {
        guard
            let profile = profileVM.profile,
            let countryLanguageProfile
        else {
            return nil
        }

        return CountryLanguageCompatibilityScorer.evaluate(
            userLanguages: profile.languages,
            countryProfile: countryLanguageProfile
        )
    }

    private var isBucketed: Bool {
        bucketListStore.ids.contains(country.id)
    }

    private var isVisited: Bool {
        traveledStore.ids.contains(country.id)
    }

    @MainActor
    private func refreshCountryIfAvailable() async {
        let iso2 = country.iso2.uppercased()

        if let cached = CountryAPI.loadCachedCountries()?.first(where: { $0.iso2.uppercased() == iso2 }) {
            country = cached
        }

        if let refreshed = await CountryAPI.refreshCountriesIfNeeded(minInterval: 0)?
            .first(where: { $0.iso2.uppercased() == iso2 }) {
            country = refreshed
            return
        }

        if let fetched = try? await CountryAPI.fetchCountries()
            .first(where: { $0.iso2.uppercased() == iso2 }) {
            country = fetched
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                
                LazyVStack(spacing: 28) {
                    
                    // Header polaroid style
                    CountryHeaderCard(country: displayedCountry)
                        .padding()
                        .background(
                            Theme.countryDetailCardBackground(corner: 20)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
                    
                    // Advisory card stack
                    scrapbookSection {
                        CountryAdvisoryCard(
                            country: displayedCountry,
                            weightPercentage: weightsStore.advisoryPercentage
                        )
                    }
                    
                    // Seasonality card stack
                    scrapbookSection {
                        CountrySeasonalityCard(
                            country: displayedCountry,
                            weightPercentage: weightsStore.seasonalityPercentage
                        )
                    }
                    
                    // Visa card stack
                    scrapbookSection {
                        CountryVisaCard(
                            country: displayedCountry,
                            weightPercentage: weightsStore.visaPercentage
                        )
                    }
                    
                    // Affordability card stack
                    if displayedCountry.affordabilityScore != nil {
                        scrapbookSection {
                            CountryAffordabilityCard(
                                country: displayedCountry,
                                weightPercentage: weightsStore.affordabilityPercentage
                            )
                        }
                    }

                    if let languageCompatibility {
                        scrapbookSection {
                            CountryLanguageCompatibilityCard(
                                result: languageCompatibility
                            )
                        }
                    }
                }
                .id("countryDetailTop")
                .padding(.top, 24)
                .padding(.horizontal)
                .safeAreaPadding(.bottom)
            }
        }
        .background(
            ZStack {
                Image("travel5")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color(red: 0.97, green: 0.95, blue: 0.90)
                    .opacity(0.22)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.08),
                        Color.black.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .preferredColorScheme(.light)
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 10) {
                PlanningListActionButton(kind: .bucket, isActive: isBucketed) {
                    Task {
                        await toggleBucket()
                    }
                }

                PlanningListActionButton(kind: .visited, isActive: isVisited) {
                    Task {
                        await toggleVisited()
                    }
                }
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
        .task(id: country.iso2.uppercased()) {
            if sessionManager.isAuthenticated {
                await profileVM.reloadProfile()
            }
            await refreshCountryIfAvailable()
            country = await visaStore.hydrate(country: country)
            countryLanguageProfile = try? await CountryLanguageProfileStore.shared.refreshProfile(for: country.iso2)
        }
    }
    
    private func scrapbookSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(
                Theme.countryDetailCardBackground(corner: 20)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
    }

    @MainActor
    private func toggleBucket() async {
        if sessionManager.isAuthenticated {
            if profileVM.viewedBucketListCountries != bucketListStore.ids {
                profileVM.viewedBucketListCountries = bucketListStore.ids
                profileVM.computeOrderedLists()
            }

            await profileVM.toggleBucket(country.id)
            bucketListStore.replace(with: profileVM.viewedBucketListCountries)
        } else {
            bucketListStore.toggle(country.id)
        }
    }

    @MainActor
    private func toggleVisited() async {
        if sessionManager.isAuthenticated {
            if profileVM.viewedTraveledCountries != traveledStore.ids {
                profileVM.viewedTraveledCountries = traveledStore.ids
                profileVM.computeOrderedLists()
            }

            await profileVM.toggleTraveled(country.id)
            traveledStore.replace(with: profileVM.viewedTraveledCountries)
        } else {
            traveledStore.toggle(country.id)
        }
    }
}

private struct CountryLanguageProfile: Decodable {
    let countryISO2: String
    let source: String?
    let sourceVersion: String?
    let notes: String?
    let evidence: [CountryLanguageEvidence]
    let languages: [CountryLanguageCoverage]

    enum CodingKeys: String, CodingKey {
        case countryISO2 = "country_iso2"
        case source
        case sourceVersion = "source_version"
        case notes
        case evidence
        case languages
    }
}

private struct CountryLanguageCoverage: Decodable, Hashable {
    let code: String
    let type: String
    let coverage: Double
}

private struct CountryLanguageEvidence: Decodable, Hashable {
    let kind: String?
    let title: String?
    let url: URL?
    let note: String?
}

private struct CountryLanguageCompatibilityResult {
    let score: Int
    let headline: String
    let detail: String?
    let primaryLanguageCode: String
    let evidence: CountryLanguageEvidence?

    var evidenceLinkLabel: String {
        guard let evidence else { return "Why this score?" }

        if let title = evidence.title, title.localizedCaseInsensitiveContains("glottolog") {
            return "Source: Glottolog"
        }

        if let title = evidence.title, title.localizedCaseInsensitiveContains("britannica") {
            return "Source: Britannica"
        }

        if let host = evidence.url?.host(percentEncoded: false)?
            .replacingOccurrences(of: "www.", with: ""),
           !host.isEmpty {
            return "Why this score?"
        }

        return "Why this score?"
    }
}

private actor CountryLanguageProfileStore {
    static let shared = CountryLanguageProfileStore()

    private var cache: [String: CountryLanguageProfile] = [:]
    private var missingISO2: Set<String> = []

    func profile(for iso2: String) async throws -> CountryLanguageProfile? {
        let normalizedISO2 = iso2.uppercased()

        if let cached = cache[normalizedISO2] {
            return cached
        }

        if missingISO2.contains(normalizedISO2) {
            return nil
        }

        let response: PostgrestResponse<[CountryLanguageProfile]> = try await SupabaseManager.shared.client
            .from("country_language_profiles")
            .select("country_iso2,source,source_version,notes,evidence,languages")
            .eq("country_iso2", value: normalizedISO2)
            .limit(1)
            .execute()

        guard let profile = response.value.first else {
            missingISO2.insert(normalizedISO2)
            return nil
        }

        cache[normalizedISO2] = profile
        return profile
    }

    func refreshProfile(for iso2: String) async throws -> CountryLanguageProfile? {
        let normalizedISO2 = iso2.uppercased()

        let response: PostgrestResponse<[CountryLanguageProfile]> = try await SupabaseManager.shared.client
            .from("country_language_profiles")
            .select("country_iso2,source,source_version,notes,evidence,languages")
            .eq("country_iso2", value: normalizedISO2)
            .limit(1)
            .execute()

        guard let profile = response.value.first else {
            cache.removeValue(forKey: normalizedISO2)
            missingISO2.insert(normalizedISO2)
            return nil
        }

        missingISO2.remove(normalizedISO2)
        cache[normalizedISO2] = profile
        return profile
    }
}

private enum CountryLanguageCompatibilityScorer {
    static func evaluate(
        userLanguages: [Profile.LanguageJSON],
        countryProfile: CountryLanguageProfile
    ) -> CountryLanguageCompatibilityResult? {
        let normalizedUserLanguages = userLanguages.map { language in
            ScoredUserLanguage(
                code: LanguageRepository.shared.canonicalLanguageCode(for: language.code)
                    ?? language.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                proficiency: LanguageProficiency(storageValue: language.proficiency)
            )
        }

        let userLanguageByCode = Dictionary(
            uniqueKeysWithValues: normalizedUserLanguages.map { ($0.code, $0) }
        )

        let exactMatches = countryProfile.languages.compactMap { countryLanguage -> ExactLanguageMatch? in
            let normalizedCode = countryLanguage.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guard let userLanguage = userLanguageByCode[normalizedCode] else {
                return nil
            }

            return ExactLanguageMatch(
                code: normalizedCode,
                type: countryLanguage.type,
                coverage: countryLanguage.coverage,
                proficiency: userLanguage.proficiency,
                compatibility: userLanguage.proficiency.compatibilityMultiplier * countryLanguage.coverage
            )
        }

        guard let strongestMatch = exactMatches.max(by: { lhs, rhs in
            if lhs.compatibility != rhs.compatibility {
                return lhs.compatibility < rhs.compatibility
            }

            if lhs.proficiency.normalizedScore != rhs.proficiency.normalizedScore {
                return lhs.proficiency.normalizedScore < rhs.proficiency.normalizedScore
            }

            return lhs.coverage < rhs.coverage
        }) else {
            return CountryLanguageCompatibilityResult(
                score: 0,
                headline: "Language may be a barrier here.",
                detail: nil,
                primaryLanguageCode: "",
                evidence: nil
            )
        }

        let score = normalizedScore(for: strongestMatch.compatibility)
        let headline = headline(for: strongestMatch, score: score)
        let detail = detailText(for: strongestMatch, allMatches: exactMatches)
        let evidence = countryProfile.evidence.first(where: { $0.url != nil && $0.kind?.lowercased() != "inference" })
            ?? countryProfile.evidence.first(where: { $0.url != nil })

        return CountryLanguageCompatibilityResult(
            score: score,
            headline: headline,
            detail: detail,
            primaryLanguageCode: strongestMatch.code,
            evidence: evidence
        )
    }

    private static func normalizedScore(for compatibility: Double) -> Int {
        switch compatibility {
        case 0.65...:
            return 100
        case 0.30...:
            return 50
        default:
            return 0
        }
    }

    private static func headline(for match: ExactLanguageMatch, score: Int) -> String {
        let languageName = LanguageRepository.shared.displayName(for: match.code)

        switch score {
        case 100:
            return "You'll be comfortable traveling here in \(languageName)."
        case 50:
            if match.proficiency == .conversational {
                return "You can likely get by here in \(languageName)."
            }
            return "\(languageName) should help in many travel situations here."
        default:
            if match.proficiency == .beginner {
                return "You can practice your \(languageName) here, but you may not want to rely on it."
            }
            return "Language may still be a barrier in parts of the country."
        }
    }

    private static func detailText(
        for strongestMatch: ExactLanguageMatch,
        allMatches: [ExactLanguageMatch]
    ) -> String? {
        let practiceMatches = allMatches
            .filter { $0.code != strongestMatch.code && $0.proficiency == .beginner && $0.coverage >= 0.6 }
            .sorted { $0.coverage > $1.coverage }

        if let practice = practiceMatches.first {
            let practiceLanguage = LanguageRepository.shared.displayName(for: practice.code)
            return "You can also practice your \(practiceLanguage) here."
        }

        if strongestMatch.proficiency == .conversational && strongestMatch.coverage < 0.65 {
            return "Expect things to feel easiest in major tourist areas."
        }

        if strongestMatch.proficiency == .fluent && strongestMatch.coverage < 0.65 {
            return "It should be most useful in tourism-heavy areas rather than everywhere."
        }

        return nil
    }

    private struct ScoredUserLanguage {
        let code: String
        let proficiency: LanguageProficiency
    }

    private struct ExactLanguageMatch {
        let code: String
        let type: String
        let coverage: Double
        let proficiency: LanguageProficiency
        let compatibility: Double
    }
}

private struct CountryLanguageCompatibilityCard: View {
    let result: CountryLanguageCompatibilityResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Language Compatibility")
                    .font(.headline)

                Spacer()

                Text("Your languages")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text("\(result.score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(CountryScoreStyling.backgroundColor(for: result.score))
                    )
                    .overlay(
                        Capsule()
                            .stroke(CountryScoreStyling.borderColor(for: result.score), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.headline)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = result.detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let evidenceURL = result.evidence?.url {
                Link(result.evidenceLinkLabel, destination: evidenceURL)
                    .font(.footnote.weight(.semibold))
            }

            Text("Based on country-level language coverage and your saved language codes. Real-world experience can vary by city and region.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.countryDetailCardBackground(corner: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
