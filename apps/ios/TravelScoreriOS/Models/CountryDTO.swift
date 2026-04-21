//
//  CountryDTO.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/11/25.
//

import Foundation

struct CountryDTO: Decodable {
    let iso2: String
    let name: String
    let region: String?
    let subregion: String?
    let currencyCode: String?

    /// Final 0...100 Travelability score
    let score: Int?

    /// From advisory.level (1–4)
    let advisoryLevelNumber: Int?
    /// Pure advisory normalized score (0...100) from backend
    let advisoryScore: Int?
    let advisorySummary: String?
    let advisoryUrl: URL?
    let advisoryUpdatedAt: String?

    /// Seasonality / timing
    let seasonalityScore: Int?        // 0...100 (today)
    let seasonalityLabel: String?     // "best" | "good" | "shoulder" | "poor"
    let seasonalityBestMonths: [Int]? // 1..12
    let seasonalityShoulderMonths: [Int]?
    let seasonalityGoodMonths: [Int]?
    let seasonalityAvoidMonths: [Int]?
    let seasonalityNotes: String?     // extra description from FM / overrides

    /// Visa (US passport)
    let visaEaseScore: Int?           // 0...100
    let visaType: String?             // visa_free | voa | evisa | visa_required | ban
    let visaAllowedDays: Int?
    let visaFeeUsd: Double?
    let visaNotes: String?
    let visaSourceUrl: URL?

    /// Affordability / daily spend (approx, hotel traveler)
    let dailySpendTotalUsd: Double?
    let dailySpendHotelUsd: Double?
    let dailySpendHostelUsd: Double?
    let dailySpendFoodUsd: Double?
    let dailySpendActivitiesUsd: Double?

    /// Canonical affordability (1–10 bucket from backend)
    let affordabilityCategory: Int?
    /// Canonical affordability score (0–100, derived server-side)
    let affordabilityScore: Int?
    /// Canonical affordability band from backend ("good" | "warn" | "bad" | "danger")
    let affordabilityBand: String?

    /// Canonical affordability explanation from backend
    let affordabilityExplanation: String?
    let languageCompatibilityScore: Int?


    var advisoryLevelText: String? {
        advisoryLevelNumber.map { "Level \($0)" }
    }

    private enum CodingKeys: String, CodingKey {
        case iso2
        case name
        case region
        case subregion
        case currency

        // old/easy places to look for a score
        case score, overallScore, rating, value

        // nested stuff
        case advisory
        case advisoryLevel, advisory_level
        case facts
    }

    // MARK: - Nested DTOs for decoding

    private struct Advisory: Decodable {
        let level: Int?
        let updatedAt: String?
        let url: String?
        let summary: String?
    }

    private struct DailySpend: Decodable {
        let foodUsd: Double?
        let activitiesUsd: Double?
        let hotelUsd: Double?
        let hostelUsd: Double?
        let totalUsd: Double?
    }

    private struct Facts: Decodable {
        let scoreTotal: Double?

        // advisory (single source of truth from backend facts)
        let advisoryScore: Double?
        let advisoryLevel: Int?

        // seasonality
        let seasonality: Double?
        let fmSeasonalityTodayScore: Double?
        let fmSeasonalityTodayLabel: String?
        let fmSeasonalityBestMonths: [Int]?
        let fmSeasonalityShoulderMonths: [Int]?
        let fmSeasonalityGoodMonths: [Int]?
        let fmSeasonalityAvoidMonths: [Int]?
        let fmSeasonalityNotes: String?

        // visa
        let visaEase: Double?
        let visaType: String?
        let visaAllowedDays: Int?
        let visaFeeUsd: Double?
        let visaNotes: String?
        let visaSource: String?

        // affordability / daily spend
        let dailySpend: DailySpend?

        // canonical affordability (from Supabase)
        let affordabilityCategory: Int?
        let affordability: Double?
        let affordabilityBand: String?
        let affordabilityExplanation: String?
        let languageCompatibilityScore: Double?


        private enum CodingKeys: String, CodingKey {
            case scoreTotal
            case advisoryScore
            case advisoryLevel
            case seasonality
            case fmSeasonalityTodayScore
            case fmSeasonalityTodayLabel
            case fmSeasonalityBestMonths
            case fmSeasonalityShoulderMonths
            case fmSeasonalityGoodMonths
            case fmSeasonalityAvoidMonths
            case fmSeasonalityNotes
            case visaEase
            case visaType
            case visaAllowedDays
            case visaFeeUsd
            case visaNotes
            case visaSource
            case dailySpend
            case affordabilityCategory
            case affordability
            case affordabilityBand
            case affordabilityExplanation
            case languageCompatibilityScore
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            scoreTotal = try? c.decode(Double.self, forKey: .scoreTotal)
            // Decode advisoryScore as Double OR Int (backend may send either)
            if let d = try? c.decode(Double.self, forKey: .advisoryScore) {
                advisoryScore = d
            } else if let i = try? c.decode(Int.self, forKey: .advisoryScore) {
                advisoryScore = Double(i)
            } else {
                advisoryScore = nil
            }
            advisoryLevel = try? c.decode(Int.self, forKey: .advisoryLevel)

            seasonality = try? c.decode(Double.self, forKey: .seasonality)
            fmSeasonalityTodayScore = try? c.decode(Double.self, forKey: .fmSeasonalityTodayScore)
            fmSeasonalityTodayLabel = try? c.decode(String.self, forKey: .fmSeasonalityTodayLabel)
            fmSeasonalityBestMonths = try? c.decode([Int].self, forKey: .fmSeasonalityBestMonths)
            fmSeasonalityShoulderMonths = try? c.decode([Int].self, forKey: .fmSeasonalityShoulderMonths)
            fmSeasonalityGoodMonths = try? c.decode([Int].self, forKey: .fmSeasonalityGoodMonths)
            fmSeasonalityAvoidMonths = try? c.decode([Int].self, forKey: .fmSeasonalityAvoidMonths)
            fmSeasonalityNotes = try? c.decode(String.self, forKey: .fmSeasonalityNotes)

            visaEase = try? c.decode(Double.self, forKey: .visaEase)
            visaType = try? c.decode(String.self, forKey: .visaType)
            visaAllowedDays = try? c.decode(Int.self, forKey: .visaAllowedDays)
            visaFeeUsd = try? c.decode(Double.self, forKey: .visaFeeUsd)
            visaNotes = try? c.decode(String.self, forKey: .visaNotes)
            visaSource = try? c.decode(String.self, forKey: .visaSource)

            dailySpend = try? c.decode(DailySpend.self, forKey: .dailySpend)

            affordabilityCategory = try? c.decode(Int.self, forKey: .affordabilityCategory)

            if let d = try? c.decode(Double.self, forKey: .affordability) {
                affordability = d
            } else if let i = try? c.decode(Int.self, forKey: .affordability) {
                affordability = Double(i)
            } else {
                affordability = nil
            }
            affordabilityBand = try? c.decode(String.self, forKey: .affordabilityBand)
            affordabilityExplanation = try? c.decode(String.self, forKey: .affordabilityExplanation)
            if let d = try? c.decode(Double.self, forKey: .languageCompatibilityScore) {
                languageCompatibilityScore = d
            } else if let i = try? c.decode(Int.self, forKey: .languageCompatibilityScore) {
                languageCompatibilityScore = Double(i)
            } else {
                languageCompatibilityScore = nil
            }
        }
    }

    private static func decodeHTML(_ text: String) -> String {
        var s = text

        // Decode numeric HTML entities (e.g. &#8217;)
        if let regex = try? NSRegularExpression(pattern: "&#([0-9]+);") {
            let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
            for match in matches.reversed() {
                guard
                    match.numberOfRanges == 2,
                    let codeRange = Range(match.range(at: 1), in: s),
                    let fullRange = Range(match.range(at: 0), in: s),
                    let code = Int(s[codeRange]),
                    let scalar = UnicodeScalar(code)
                else { continue }

                s.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
        }

        // Decode common named entities
        s = s
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&rsquo;", with: "’")
            .replacingOccurrences(of: "&lsquo;", with: "‘")
            .replacingOccurrences(of: "&rdquo;", with: "”")
            .replacingOccurrences(of: "&ldquo;", with: "“")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&hellip;", with: "…")

        // Normalize whitespace
        s = s
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return s
    }

    // MARK: - Init

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.iso2 = try c.decode(String.self, forKey: .iso2)
        self.name = try c.decode(String.self, forKey: .name)
        self.region = try c.decodeIfPresent(String.self, forKey: .region)
        self.subregion = try c.decodeIfPresent(String.self, forKey: .subregion)
        self.currencyCode = AppCurrencyCatalog.normalizedCode(try c.decodeIfPresent(String.self, forKey: .currency))

        // Try lots of shapes for scores: Int, Double, String
        func decodeIntLikeScore(for key: CodingKeys) -> Int? {
            // 1) Int
            if let i = try? c.decode(Int.self, forKey: key) {
                return i
            }
            // 2) Double (e.g. 83.2)
            if let d = try? c.decode(Double.self, forKey: key) {
                return Int(d.rounded())
            }
            // 3) String -> Int / Double
            if let s = try? c.decode(String.self, forKey: key) {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if let i = Int(trimmed) {
                    return i
                }
                if let d = Double(trimmed) {
                    return Int(d.rounded())
                }
            }
            return nil
        }

        // 1️⃣ First try old/top-level numeric keys (for backwards compatibility)
        var s: Int? =
            decodeIntLikeScore(for: .score) ??
            decodeIntLikeScore(for: .overallScore) ??
            decodeIntLikeScore(for: .rating) ??
            decodeIntLikeScore(for: .value)

        // 2️⃣ Then fall back to facts.scoreTotal (your new canonical field)
        let facts = try? c.decode(Facts.self, forKey: .facts)
        if s == nil, let total = facts?.scoreTotal {
            s = Int(total.rounded())
        }
        self.score = s

        // Decode advisory object (level + metadata)
        let advisory = try? c.decode(Advisory.self, forKey: .advisory)

        // Advisory score: prefer facts.advisoryScore, fallback to advisory.level
        if let score = facts?.advisoryScore {
            self.advisoryScore = Int(score.rounded())
        } else if let level = advisory?.level {
            let normalized = ((5.0 - Double(level)) / 4.0) * 100.0
            self.advisoryScore = Int(normalized.rounded())
        } else {
            self.advisoryScore = nil
        }

        // Advisory level: prefer facts.advisoryLevel, fallback to advisory.level
        self.advisoryLevelNumber = facts?.advisoryLevel ?? advisory?.level

        // advisory metadata (text + URL)
        self.advisorySummary = advisory?.summary.map { Self.decodeHTML($0) }
        self.advisoryUpdatedAt = advisory?.updatedAt
        if let urlString = advisory?.url, let url = URL(string: urlString) {
            self.advisoryUrl = url
        } else {
            self.advisoryUrl = nil
        }

        // we ignore advisoryLevel/advisory_level strings here; you already show "Level N"
        _ = (try? c.decode(String.self, forKey: .advisoryLevel))
            ?? (try? c.decode(String.self, forKey: .advisory_level))

        // --- Seasonality (from facts) ---
        if let seasonalityToday = facts?.fmSeasonalityTodayScore ?? facts?.seasonality {
            self.seasonalityScore = Int(seasonalityToday.rounded())
        } else {
            self.seasonalityScore = nil
        }
        self.seasonalityLabel = facts?.fmSeasonalityTodayLabel
        self.seasonalityBestMonths = facts?.fmSeasonalityBestMonths
        self.seasonalityShoulderMonths = facts?.fmSeasonalityShoulderMonths
        self.seasonalityGoodMonths = facts?.fmSeasonalityGoodMonths
        self.seasonalityAvoidMonths = facts?.fmSeasonalityAvoidMonths
        self.seasonalityNotes = facts?.fmSeasonalityNotes

        // --- Visa (from facts) ---
        if let visaEase = facts?.visaEase {
            self.visaEaseScore = Int(visaEase.rounded())
        } else {
            self.visaEaseScore = nil
        }
        self.visaType = facts?.visaType
        self.visaAllowedDays = facts?.visaAllowedDays
        self.visaFeeUsd = facts?.visaFeeUsd
        self.visaNotes = facts?.visaNotes
        if let sourceString = facts?.visaSource, let url = URL(string: sourceString) {
            self.visaSourceUrl = url
        } else {
            self.visaSourceUrl = nil
        }

        // --- Daily spend (from facts.dailySpend) ---
        if let ds = facts?.dailySpend {
            self.dailySpendTotalUsd = ds.totalUsd
            self.dailySpendHotelUsd = ds.hotelUsd
            self.dailySpendHostelUsd = ds.hostelUsd
            self.dailySpendFoodUsd = ds.foodUsd
            self.dailySpendActivitiesUsd = ds.activitiesUsd
        } else {
            self.dailySpendTotalUsd = nil
            self.dailySpendHotelUsd = nil
            self.dailySpendHostelUsd = nil
            self.dailySpendFoodUsd = nil
            self.dailySpendActivitiesUsd = nil
        }

        // --- Canonical affordability (from facts) ---
        if let cat = facts?.affordabilityCategory {
            self.affordabilityCategory = cat
        } else {
            self.affordabilityCategory = nil
        }

        if let aff = facts?.affordability {
            self.affordabilityScore = Int(aff.rounded())
        } else {
            self.affordabilityScore = nil
        }
        self.affordabilityBand = facts?.affordabilityBand
        self.affordabilityExplanation = facts?.affordabilityExplanation.map { Self.decodeHTML($0) }
        self.languageCompatibilityScore = facts?.languageCompatibilityScore.map { Int($0.rounded()) }
    }
}
