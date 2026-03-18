//
//  Country.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/10/25.
//

import Foundation

struct Country: Identifiable, Hashable {
    let iso2: String
    /// Stable identifier for persistence (do NOT use random UUIDs).
    var id: String { iso2.uppercased() }
    let name: String
    var score: Int?
    let region: String?
    let subregion: String?
    let advisoryScore: Int?

    // Extra details from API
    let advisorySummary: String?
    let advisoryUpdatedAt: String?
    let advisoryUrl: URL?

    // Seasonality
    let seasonalityScore: Int?
    let seasonalityLabel: String?
    let seasonalityBestMonths: [Int]?
    let seasonalityShoulderMonths: [Int]?
    let seasonalityGoodMonths: [Int]?
    let seasonalityAvoidMonths: [Int]?
    let seasonalityNotes: String?

    // Visa
    let visaEaseScore: Int?
    let visaType: String?
    let visaAllowedDays: Int?
    let visaFeeUsd: Double?
    let visaNotes: String?
    let visaSourceUrl: URL?

    // Daily spend
    let dailySpendTotalUsd: Double?
    let dailySpendHotelUsd: Double?
    let dailySpendFoodUsd: Double?
    let dailySpendActivitiesUsd: Double?

    // Canonical affordability (from backend)
    let affordabilityCategory: Int?
    let affordabilityScore: Int?
    let affordabilityBand: String?
    let affordabilityExplanation: String?


    var affordabilityHeadline: String? {
        splitHeadline(from: affordabilityExplanation)
    }

    var affordabilityBody: String? {
        splitBody(from: affordabilityExplanation)
    }
    
    var regionLabel: String? {
        switch (subregion, region) {
        case let (sub?, reg?) where sub != reg:
            // e.g. "Western Europe, Europe" or "South America, Latin America & Caribbean"
            return "\(sub), \(reg)"
        case (nil, let reg?):
            return reg
        case (let sub?, nil):
            return sub
        default:
            return nil
        }
    }
    

    // Custom initializer to maintain compatibility
    init(
        iso2: String,
        name: String,
        score: Int?,
        region: String? = nil,
        subregion: String? = nil,
        advisoryScore: Int? = nil,
        advisorySummary: String? = nil,
        advisoryUpdatedAt: String? = nil,
        advisoryUrl: URL? = nil,
        seasonalityScore: Int? = nil,
        seasonalityLabel: String? = nil,
        seasonalityBestMonths: [Int]? = nil,
        seasonalityShoulderMonths: [Int]? = nil,
        seasonalityGoodMonths: [Int]? = nil,
        seasonalityAvoidMonths: [Int]? = nil,
        seasonalityNotes: String? = nil,
        visaEaseScore: Int? = nil,
        visaType: String? = nil,
        visaAllowedDays: Int? = nil,
        visaFeeUsd: Double? = nil,
        visaNotes: String? = nil,
        visaSourceUrl: URL? = nil,
        dailySpendTotalUsd: Double? = nil,
        dailySpendHotelUsd: Double? = nil,
        dailySpendFoodUsd: Double? = nil,
        dailySpendActivitiesUsd: Double? = nil,
        affordabilityCategory: Int? = nil,
        affordabilityScore: Int? = nil,
        affordabilityBand: String? = nil,
        affordabilityExplanation: String? = nil
    ) {
        self.iso2 = iso2
        self.name = name
        self.score = score
        self.region = region
        self.subregion = subregion
        self.advisoryScore = advisoryScore
        self.advisorySummary = advisorySummary
        self.advisoryUpdatedAt = advisoryUpdatedAt
        self.advisoryUrl = advisoryUrl
        self.seasonalityScore = seasonalityScore
        self.seasonalityLabel = seasonalityLabel
        self.seasonalityBestMonths = seasonalityBestMonths
        self.seasonalityShoulderMonths = seasonalityShoulderMonths
        self.seasonalityGoodMonths = seasonalityGoodMonths
        self.seasonalityAvoidMonths = seasonalityAvoidMonths
        self.seasonalityNotes = seasonalityNotes
        self.visaEaseScore = visaEaseScore
        self.visaType = visaType
        self.visaAllowedDays = visaAllowedDays
        self.visaFeeUsd = visaFeeUsd
        self.visaNotes = visaNotes
        self.visaSourceUrl = visaSourceUrl
        self.dailySpendTotalUsd = dailySpendTotalUsd
        self.dailySpendHotelUsd = dailySpendHotelUsd
        self.dailySpendFoodUsd = dailySpendFoodUsd
        self.dailySpendActivitiesUsd = dailySpendActivitiesUsd
        self.affordabilityCategory = affordabilityCategory
        self.affordabilityScore = affordabilityScore
        self.affordabilityBand = affordabilityBand
        self.affordabilityExplanation = affordabilityExplanation
    }

    var flagEmoji: String {
        iso2.flagEmoji
    }

    // MARK: - Advisory Headline + Body (for CountryDetail consistency)

    var advisoryHeadline: String? {
        splitHeadline(from: advisorySummary)
    }

    var advisoryBody: String? {
        splitBody(from: advisorySummary)
    }

    // MARK: - Visa Headline + Body

    var visaHeadline: String? {
        splitHeadline(from: visaNotes)
    }

    var visaBody: String? {
        splitBody(from: visaNotes)
    }

    // MARK: - Seasonality Headline + Body

    var seasonalityHeadline: String? {
        splitHeadline(from: seasonalityNotes)
    }

    var seasonalityBody: String? {
        splitBody(from: seasonalityNotes)
    }

    // MARK: - Shared Text Splitting Logic

    private func splitHeadline(from text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }

        if let firstSentenceEnd = text.firstIndex(of: ".") {
            let headline = text[..<text.index(after: firstSentenceEnd)]
            return String(headline).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
    }

    private func splitBody(from text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }

        if let firstSentenceEnd = text.firstIndex(of: ".") {
            let bodyStart = text.index(after: firstSentenceEnd)
            let body = text[bodyStart...]
            let trimmed = String(body).trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }
}

extension Country {
    func resolvedSeasonalityScore(for month: Int? = nil) -> Int? {
        guard let month else { return seasonalityScore }

        if let best = seasonalityBestMonths, best.contains(month) {
            return 100
        }
        if let shoulder = seasonalityShoulderMonths, shoulder.contains(month) {
            return 80
        }
        if let good = seasonalityGoodMonths, good.contains(month) {
            return 40
        }
        if let avoid = seasonalityAvoidMonths, avoid.contains(month) {
            return 0
        }

        let hasExplicitSeasonality =
            !(seasonalityBestMonths?.isEmpty ?? true) ||
            !(seasonalityShoulderMonths?.isEmpty ?? true) ||
            !(seasonalityGoodMonths?.isEmpty ?? true) ||
            !(seasonalityAvoidMonths?.isEmpty ?? true)

        if hasExplicitSeasonality {
            return 50
        }

        return seasonalityScore
    }

    func resolvedSeasonalityLabel(for month: Int? = nil) -> String? {
        guard let month else { return seasonalityLabel }

        if let best = seasonalityBestMonths, best.contains(month) {
            return "best"
        }
        if let shoulder = seasonalityShoulderMonths, shoulder.contains(month) {
            return "shoulder"
        }
        if let good = seasonalityGoodMonths, good.contains(month) {
            return "good"
        }
        if let avoid = seasonalityAvoidMonths, avoid.contains(month) {
            return "poor"
        }

        let hasExplicitSeasonality =
            !(seasonalityBestMonths?.isEmpty ?? true) ||
            !(seasonalityShoulderMonths?.isEmpty ?? true) ||
            !(seasonalityGoodMonths?.isEmpty ?? true) ||
            !(seasonalityAvoidMonths?.isEmpty ?? true)

        return hasExplicitSeasonality ? "shoulder" : seasonalityLabel
    }

    func recalculatedScore(using weights: ScoreWeights, selectedMonth: Int? = nil) -> Int? {
        var components: [(value: Double, weight: Double)] = []

        if let advisory = advisoryScore {
            components.append((Double(advisory), weights.advisory))
        }

        if let seasonality = resolvedSeasonalityScore(for: selectedMonth) {
            components.append((Double(seasonality), weights.seasonality))
        }

        if let visa = visaEaseScore {
            components.append((Double(visa), weights.visa))
        }

        if let affordability = affordabilityScore {
            components.append((Double(affordability), weights.affordability))
        }

        guard !components.isEmpty else {
            return nil
        }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            return nil
        }

        let weightedSum = components.reduce(0) { $0 + ($1.value * $1.weight) }
        return Int((weightedSum / totalWeight).rounded())
    }

    func applyingOverallScore(using weights: ScoreWeights, selectedMonth: Int? = nil) -> Country {
        var updated = self
        updated.score = recalculatedScore(using: weights, selectedMonth: selectedMonth)
        return updated
    }

    func applyingVisa(
        visaEaseScore: Int?,
        visaType: String?,
        visaAllowedDays: Int?,
        visaFeeUsd: Double?,
        visaNotes: String?,
        visaSourceUrl: URL?
    ) -> Country {
        Country(
            iso2: iso2,
            name: name,
            score: score,
            region: region,
            subregion: subregion,
            advisoryScore: advisoryScore,
            advisorySummary: advisorySummary,
            advisoryUpdatedAt: advisoryUpdatedAt,
            advisoryUrl: advisoryUrl,
            seasonalityScore: seasonalityScore,
            seasonalityLabel: seasonalityLabel,
            seasonalityBestMonths: seasonalityBestMonths,
            seasonalityShoulderMonths: seasonalityShoulderMonths,
            seasonalityGoodMonths: seasonalityGoodMonths,
            seasonalityAvoidMonths: seasonalityAvoidMonths,
            seasonalityNotes: seasonalityNotes,
            visaEaseScore: visaEaseScore ?? self.visaEaseScore,
            visaType: visaType ?? self.visaType,
            visaAllowedDays: visaAllowedDays ?? self.visaAllowedDays,
            visaFeeUsd: visaFeeUsd ?? self.visaFeeUsd,
            visaNotes: visaNotes ?? self.visaNotes,
            visaSourceUrl: visaSourceUrl ?? self.visaSourceUrl,
            dailySpendTotalUsd: dailySpendTotalUsd,
            dailySpendHotelUsd: dailySpendHotelUsd,
            dailySpendFoodUsd: dailySpendFoodUsd,
            dailySpendActivitiesUsd: dailySpendActivitiesUsd,
            affordabilityCategory: affordabilityCategory,
            affordabilityScore: affordabilityScore,
            affordabilityBand: affordabilityBand,
            affordabilityExplanation: affordabilityExplanation
        )
    }
}

enum CountrySort: String, CaseIterable {
    case name = "Name"
    case score = "Score"
}

// MARK: - ISO2 -> Flag emoji

extension String {
    /// Converts a 2-letter ISO country code (e.g. "US", "EG") into a flag emoji (🇺🇸, 🇪🇬).
    var flagEmoji: String {
        let uppercased = self.uppercased()
        guard uppercased.count == 2 else { return "🏳️" }

        let base: UInt32 = 127397 // Unicode for regional indicator 'A' minus "A"
        var scalars = String.UnicodeScalarView()

        for scalar in uppercased.unicodeScalars {
            guard let flagScalar = UnicodeScalar(base + scalar.value) else { continue }
            scalars.append(flagScalar)
        }

        return String(scalars)
    }

    var normalizedSearchKey: String {
        let specialCharacterMap: [Character: String] = [
            "æ": "ae",
            "œ": "oe",
            "ß": "ss",
            "ø": "o",
            "đ": "d",
            "ł": "l",
            "ı": "i"
        ]

        let lowered = self.lowercased()
        let remapped = lowered.map { specialCharacterMap[$0] ?? String($0) }.joined()
        let strippedDiacritics = remapped.folding(options: .diacriticInsensitive, locale: .current)
        return strippedDiacritics.replacingOccurrences(
            of: "[^a-z0-9]",
            with: "",
            options: .regularExpression
        )
    }
}
