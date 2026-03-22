//
//  LanguageRepository.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/26/26.
//

import Foundation

final class LanguageRepository {

    static let shared = LanguageRepository()

    private static let canonicalTravelCodeAliases: [String: String] = [
        "pes": "fa"
    ]

    private static let preferredDisplayNamesByTravelCode: [String: String] = [
        "fa": "Persian (Farsi)"
    ]

    private static let searchAliasesByTravelCode: [String: [String]] = [
        "fa": ["farsi", "iran", "iranian", "iranian persian"]
    ]

    private(set) var allLanguages: [AppLanguage] = []
    private var languagesByCode: [String: AppLanguage] = [:]
    private var languageByTravelCode: [String: AppLanguage] = [:]
    private var travelCodeByDisplayName: [String: String] = [:]
    private var travelCodeByAlias: [String: String] = [:]

    private init() {
        loadLanguages()
    }

    private func loadLanguages() {
        guard
            let url = Bundle.main.url(forResource: "global_languages", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([AppLanguage].self, from: data)
        else {
            print("❌ Failed to load global_languages.json")
            return
        }

        self.allLanguages = decoded.sorted { $0.displayName < $1.displayName }
        rebuildLookups()
    }

    func canonicalLanguageCode(for rawValue: String) -> String? {
        guard let travelCode = resolveLanguage(for: rawValue)?.travelLanguageCode else {
            return nil
        }

        return Self.canonicalTravelCodeAliases[travelCode] ?? travelCode
    }

    func displayName(for rawValue: String) -> String {
        if let language = resolveLanguage(for: rawValue) {
            return preferredDisplayName(for: language)
        }

        let normalized = normalizeLookupKey(rawValue)
        guard !normalized.isEmpty else { return rawValue }
        return rawValue
    }

    func localizedDisplayName(for rawValue: String, locale: Locale = .autoupdatingCurrent) -> String {
        if let language = resolveLanguage(for: rawValue) {
            let canonicalCode = canonicalLanguageCode(for: language.travelLanguageCode)
                ?? language.travelLanguageCode

            if let localized = locale.localizedString(forLanguageCode: canonicalCode), !localized.isEmpty {
                return localized.localizedCapitalized
            }

            if let localized = locale.localizedString(forLanguageCode: language.code), !localized.isEmpty {
                return localized.localizedCapitalized
            }

            return preferredDisplayName(for: language)
        }

        let normalized = normalizeLookupKey(rawValue)
        guard !normalized.isEmpty else { return rawValue }

        if let localized = locale.localizedString(forLanguageCode: normalized), !localized.isEmpty {
            return localized.localizedCapitalized
        }

        return rawValue
    }

    func preferredDisplayName(for language: AppLanguage) -> String {
        let travelCode = canonicalLanguageCode(for: language.travelLanguageCode)
            ?? language.travelLanguageCode

        return Self.preferredDisplayNamesByTravelCode[travelCode] ?? language.displayName
    }

    func resolveLanguage(for rawValue: String) -> AppLanguage? {
        let normalized = normalizeLookupKey(rawValue)
        guard !normalized.isEmpty else { return nil }

        if let direct = languagesByCode[normalized] {
            return direct
        }

        if let travelMatch = languageByTravelCode[normalized] {
            return travelMatch
        }

        if let travelCode = travelCodeByDisplayName[normalized] {
            return languageByTravelCode[travelCode]
        }

        if let travelCode = travelCodeByAlias[normalized] {
            return languageByTravelCode[travelCode]
        }

        return nil
    }

    func matchesSearchQuery(_ query: String, language: AppLanguage) -> Bool {
        let normalizedQuery = normalizeLookupKey(query)
        guard !normalizedQuery.isEmpty else { return true }

        let travelCode = canonicalLanguageCode(for: language.travelLanguageCode)
            ?? language.travelLanguageCode

        let searchableTerms = Set([
            normalizeLookupKey(language.displayName),
            normalizeLookupKey(language.code),
            normalizeLookupKey(language.travelLanguageCode)
        ] + (Self.searchAliasesByTravelCode[travelCode] ?? []).map(normalizeLookupKey))

        return searchableTerms.contains { $0.contains(normalizedQuery) }
    }

    private func rebuildLookups() {
        languagesByCode = Dictionary(
            uniqueKeysWithValues: allLanguages.map {
                (normalizeLookupKey($0.code), $0)
            }
        )

        languageByTravelCode = [:]
        for language in allLanguages {
            languageByTravelCode[language.travelLanguageCode] = languageByTravelCode[language.travelLanguageCode] ?? language
        }

        travelCodeByDisplayName = Dictionary(
            uniqueKeysWithValues: allLanguages.map {
                (normalizeLookupKey($0.displayName), $0.travelLanguageCode)
            }
        )

        travelCodeByAlias = [:]
        for (travelCode, aliases) in Self.searchAliasesByTravelCode {
            for alias in aliases {
                travelCodeByAlias[normalizeLookupKey(alias)] = travelCode
            }
        }
    }

    private func normalizeLookupKey(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }
}
