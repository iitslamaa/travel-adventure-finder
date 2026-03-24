//
//  LanguageRepository.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/26/26.
//

import Foundation

enum AppDisplayLocale {
    static var current: Locale {
        let systemLocale = Locale.autoupdatingCurrent
        let preferredIdentifier = Bundle.main.preferredLocalizations.first ?? systemLocale.identifier
        let normalizedIdentifier = preferredIdentifier.replacingOccurrences(of: "_", with: "-")

        if normalizedIdentifier.contains("-") {
            return Locale(identifier: normalizedIdentifier)
        }

        if let regionCode = systemLocale.region?.identifier, !regionCode.isEmpty {
            return Locale(identifier: "\(normalizedIdentifier)-\(regionCode)")
        }

        return Locale(identifier: normalizedIdentifier)
    }

    static var languageCode: String {
        current.language.languageCode?.identifier.lowercased()
            ?? current.identifier.split(separator: "-").first.map { String($0).lowercased() }
            ?? "en"
    }
}

enum AppDateFormatting {
    static func dateString(
        from date: Date,
        dateStyle: DateFormatter.Style = .medium,
        timeStyle: DateFormatter.Style = .none
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    static func dateString(from date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    static func dateRangeString(start: Date, end: Date) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start, to: end)
    }

    static func localizedDisplayDate(from rawValue: String) -> String? {
        guard let date = parseDate(from: rawValue) else { return nil }
        return dateString(from: date, dateStyle: .medium)
    }

    private static func parseDate(from rawValue: String) -> Date? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isoFormatters: [ISO8601DateFormatter] = [
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                return formatter
            }()
        ]

        for formatter in isoFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        let fallbackPatterns = [
            "yyyy-MM-dd",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]

        for pattern in fallbackPatterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .autoupdatingCurrent
            formatter.dateFormat = pattern
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }
}

enum AppNumberFormatting {
    static func integerString<T: BinaryInteger>(_ value: T) -> String {
        let formatter = NumberFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Int64(value))) ?? String(value)
    }

    static func integerString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

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

    private static let localizedDisplayNameOverridesByLanguageCode: [String: [String: String]] = [
        "ar": [
            "arz": "العربية المصرية"
        ]
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

    func localizedDisplayName(for rawValue: String, locale: Locale = AppDisplayLocale.current) -> String {
        if let language = resolveLanguage(for: rawValue) {
            let canonicalCode = canonicalLanguageCode(for: language.travelLanguageCode)
                ?? language.travelLanguageCode

            let localeLanguageCode = locale.language.languageCode?.identifier.lowercased()
                ?? locale.identifier.split(separator: "-").first.map { String($0).lowercased() }
                ?? AppDisplayLocale.languageCode

            if let override = Self.localizedDisplayNameOverridesByLanguageCode[localeLanguageCode]?[canonicalCode] {
                return override
            }

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

        travelCodeByDisplayName = [:]
        for language in allLanguages {
            let normalizedDisplayName = normalizeLookupKey(language.displayName)
            guard !normalizedDisplayName.isEmpty else { continue }
            travelCodeByDisplayName[normalizedDisplayName] = travelCodeByDisplayName[normalizedDisplayName] ?? language.travelLanguageCode
        }

        travelCodeByAlias = [:]
        for (travelCode, aliases) in Self.searchAliasesByTravelCode {
            for alias in aliases {
                travelCodeByAlias[normalizeLookupKey(alias)] = travelCode
            }
        }

        let supportedLocaleIdentifiers = Set(
            Bundle.main.localizations
                .filter { $0 != "Base" }
                + [AppDisplayLocale.current.identifier]
        )

        for language in allLanguages {
            let canonicalCode = canonicalLanguageCode(for: language.travelLanguageCode)
                ?? language.travelLanguageCode

            let aliasCandidates = [
                language.displayName,
                preferredDisplayName(for: language),
                language.code,
                language.travelLanguageCode,
                canonicalCode
            ]

            for alias in aliasCandidates {
                let normalizedAlias = normalizeLookupKey(alias)
                if !normalizedAlias.isEmpty {
                    travelCodeByAlias[normalizedAlias] = canonicalCode
                }
            }

            for localeIdentifier in supportedLocaleIdentifiers {
                let locale = Locale(identifier: localeIdentifier)
                let localizedCandidates = [
                    locale.localizedString(forLanguageCode: canonicalCode),
                    locale.localizedString(forLanguageCode: language.code),
                    locale.localizedString(forIdentifier: canonicalCode),
                    locale.localizedString(forIdentifier: language.code)
                ]

                for localized in localizedCandidates.compactMap({ $0 }) {
                    let normalizedAlias = normalizeLookupKey(localized)
                    if !normalizedAlias.isEmpty {
                        travelCodeByAlias[normalizedAlias] = canonicalCode
                    }
                }
            }
        }
    }

    private func normalizeLookupKey(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
