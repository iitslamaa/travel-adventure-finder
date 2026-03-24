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
    let visaPassportCode: String?
    let visaPassportLabel: String?
    let visaRecommendedPassportLabel: String?

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
    let languageCompatibilityScore: Int?


    var affordabilityHeadline: String? {
        localizedAffordabilityContent.headline
    }

    var affordabilityBody: String? {
        localizedAffordabilityContent.body
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

    var localizedRegionLabel: String? {
        switch (subregion, region) {
        case let (sub?, reg?) where sub != reg:
            return "\(Self.localizedRegionComponent(sub)), \(Self.localizedRegionComponent(reg))"
        case (nil, let reg?):
            return Self.localizedRegionComponent(reg)
        case (let sub?, nil):
            return Self.localizedRegionComponent(sub)
        default:
            return nil
        }
    }

    var overviewDescription: String {
        CountryOverviewDescriptionStore.description(for: self)
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
        visaPassportCode: String? = nil,
        visaPassportLabel: String? = nil,
        visaRecommendedPassportLabel: String? = nil,
        dailySpendTotalUsd: Double? = nil,
        dailySpendHotelUsd: Double? = nil,
        dailySpendFoodUsd: Double? = nil,
        dailySpendActivitiesUsd: Double? = nil,
        affordabilityCategory: Int? = nil,
        affordabilityScore: Int? = nil,
        affordabilityBand: String? = nil,
        affordabilityExplanation: String? = nil,
        languageCompatibilityScore: Int? = nil
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
        self.visaPassportCode = visaPassportCode
        self.visaPassportLabel = visaPassportLabel
        self.visaRecommendedPassportLabel = visaRecommendedPassportLabel
        self.dailySpendTotalUsd = dailySpendTotalUsd
        self.dailySpendHotelUsd = dailySpendHotelUsd
        self.dailySpendFoodUsd = dailySpendFoodUsd
        self.dailySpendActivitiesUsd = dailySpendActivitiesUsd
        self.affordabilityCategory = affordabilityCategory
        self.affordabilityScore = affordabilityScore
        self.affordabilityBand = affordabilityBand
        self.affordabilityExplanation = affordabilityExplanation
        self.languageCompatibilityScore = languageCompatibilityScore
    }

    var flagEmoji: String {
        iso2.flagEmoji
    }

    var localizedDisplayName: String {
        let upper = iso2.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty else { return name }
        return AppDisplayLocale.current.localizedString(forRegionCode: upper) ?? name
    }

    var localizedSearchableNames: [String] {
        let localized = localizedDisplayName
        if localized == name {
            return [localized]
        }
        return [localized, name]
    }

    // MARK: - Advisory Headline + Body (for CountryDetail consistency)

    var advisoryHeadline: String? {
        nil
    }

    var advisoryBody: String? {
        nil
    }

    // MARK: - Visa Headline + Body

    var visaHeadline: String? {
        nil
    }

    var visaBody: String? {
        nil
    }

    // MARK: - Seasonality Headline + Body

    var seasonalityHeadline: String? {
        nil
    }

    var seasonalityBody: String? {
        nil
    }

    // MARK: - Shared Text Splitting Logic

    private var localizedAffordabilityContent: (headline: String?, body: String?) {
        let tier = affordabilityTier
        let locale = Locale.autoupdatingCurrent
        let formattedDailySpend = formattedUSD(dailySpendTotalUsd, locale: locale)

        let headline: String
        switch (Self.currentLanguageCode, tier, formattedDailySpend) {
        case ("fr", .veryLow, let amount?):
            headline = "Cout quotidien tres bas (~ \(amount)/jour)"
        case ("fr", .low, let amount?):
            headline = "Cout quotidien bas (~ \(amount)/jour)"
        case ("fr", .moderate, let amount?):
            headline = "Cout quotidien modere (~ \(amount)/jour)"
        case ("fr", .high, let amount?):
            headline = "Cout quotidien eleve (~ \(amount)/jour)"
        case ("fr", .veryHigh, let amount?):
            headline = "Cout quotidien tres eleve (~ \(amount)/jour)"

        case ("es", .veryLow, let amount?):
            headline = "Costos diarios muy bajos (~ \(amount)/dia)"
        case ("es", .low, let amount?):
            headline = "Costos diarios bajos (~ \(amount)/dia)"
        case ("es", .moderate, let amount?):
            headline = "Costos diarios moderados (~ \(amount)/dia)"
        case ("es", .high, let amount?):
            headline = "Costos diarios altos (~ \(amount)/dia)"
        case ("es", .veryHigh, let amount?):
            headline = "Costos diarios muy altos (~ \(amount)/dia)"

        case ("pt", .veryLow, let amount?):
            headline = "Custos diarios muito baixos (~ \(amount)/dia)"
        case ("pt", .low, let amount?):
            headline = "Custos diarios baixos (~ \(amount)/dia)"
        case ("pt", .moderate, let amount?):
            headline = "Custos diarios moderados (~ \(amount)/dia)"
        case ("pt", .high, let amount?):
            headline = "Custos diarios altos (~ \(amount)/dia)"
        case ("pt", .veryHigh, let amount?):
            headline = "Custos diarios muito altos (~ \(amount)/dia)"

        case ("de", .veryLow, let amount?):
            headline = "Sehr niedrige Tageskosten (~ \(amount)/Tag)"
        case ("de", .low, let amount?):
            headline = "Niedrige Tageskosten (~ \(amount)/Tag)"
        case ("de", .moderate, let amount?):
            headline = "Mittlere Tageskosten (~ \(amount)/Tag)"
        case ("de", .high, let amount?):
            headline = "Hohe Tageskosten (~ \(amount)/Tag)"
        case ("de", .veryHigh, let amount?):
            headline = "Sehr hohe Tageskosten (~ \(amount)/Tag)"

        case ("it", .veryLow, let amount?):
            headline = "Costi giornalieri molto bassi (~ \(amount)/giorno)"
        case ("it", .low, let amount?):
            headline = "Costi giornalieri bassi (~ \(amount)/giorno)"
        case ("it", .moderate, let amount?):
            headline = "Costi giornalieri moderati (~ \(amount)/giorno)"
        case ("it", .high, let amount?):
            headline = "Costi giornalieri alti (~ \(amount)/giorno)"
        case ("it", .veryHigh, let amount?):
            headline = "Costi giornalieri molto alti (~ \(amount)/giorno)"

        case ("ru", .veryLow, let amount?):
            headline = "Очень низкие ежедневные расходы (~ \(amount)/день)"
        case ("ru", .low, let amount?):
            headline = "Низкие ежедневные расходы (~ \(amount)/день)"
        case ("ru", .moderate, let amount?):
            headline = "Умеренные ежедневные расходы (~ \(amount)/день)"
        case ("ru", .high, let amount?):
            headline = "Высокие ежедневные расходы (~ \(amount)/день)"
        case ("ru", .veryHigh, let amount?):
            headline = "Очень высокие ежедневные расходы (~ \(amount)/день)"

        case ("nl", .veryLow, let amount?):
            headline = "Zeer lage dagelijkse kosten (~ \(amount)/dag)"
        case ("nl", .low, let amount?):
            headline = "Lage dagelijkse kosten (~ \(amount)/dag)"
        case ("nl", .moderate, let amount?):
            headline = "Gemiddelde dagelijkse kosten (~ \(amount)/dag)"
        case ("nl", .high, let amount?):
            headline = "Hoge dagelijkse kosten (~ \(amount)/dag)"
        case ("nl", .veryHigh, let amount?):
            headline = "Zeer hoge dagelijkse kosten (~ \(amount)/dag)"

        case ("ar", .veryLow, let amount?):
            headline = "تكاليف يومية منخفضة جدا (~ \(amount)/يوم)"
        case ("ar", .low, let amount?):
            headline = "تكاليف يومية منخفضة (~ \(amount)/يوم)"
        case ("ar", .moderate, let amount?):
            headline = "تكاليف يومية متوسطة (~ \(amount)/يوم)"
        case ("ar", .high, let amount?):
            headline = "تكاليف يومية مرتفعة (~ \(amount)/يوم)"
        case ("ar", .veryHigh, let amount?):
            headline = "تكاليف يومية مرتفعة جدا (~ \(amount)/يوم)"

        case ("ja", .veryLow, let amount?):
            headline = "非常に低い1日コスト（約\(amount)/日）"
        case ("ja", .low, let amount?):
            headline = "低い1日コスト（約\(amount)/日）"
        case ("ja", .moderate, let amount?):
            headline = "中程度の1日コスト（約\(amount)/日）"
        case ("ja", .high, let amount?):
            headline = "高い1日コスト（約\(amount)/日）"
        case ("ja", .veryHigh, let amount?):
            headline = "非常に高い1日コスト（約\(amount)/日）"

        case ("ko", .veryLow, let amount?):
            headline = "매우 낮은 일일 비용(약 \(amount)/일)"
        case ("ko", .low, let amount?):
            headline = "낮은 일일 비용(약 \(amount)/일)"
        case ("ko", .moderate, let amount?):
            headline = "보통 수준의 일일 비용(약 \(amount)/일)"
        case ("ko", .high, let amount?):
            headline = "높은 일일 비용(약 \(amount)/일)"
        case ("ko", .veryHigh, let amount?):
            headline = "매우 높은 일일 비용(약 \(amount)/일)"

        case ("zh", .veryLow, let amount?):
            headline = "每日花费很低（约\(amount)/天）"
        case ("zh", .low, let amount?):
            headline = "每日花费较低（约\(amount)/天）"
        case ("zh", .moderate, let amount?):
            headline = "每日花费中等（约\(amount)/天）"
        case ("zh", .high, let amount?):
            headline = "每日花费较高（约\(amount)/天）"
        case ("zh", .veryHigh, let amount?):
            headline = "每日花费很高（约\(amount)/天）"

        case ("hi", .veryLow, let amount?):
            headline = "बहुत कम दैनिक खर्च (~ \(amount)/दिन)"
        case ("hi", .low, let amount?):
            headline = "कम दैनिक खर्च (~ \(amount)/दिन)"
        case ("hi", .moderate, let amount?):
            headline = "मध्यम दैनिक खर्च (~ \(amount)/दिन)"
        case ("hi", .high, let amount?):
            headline = "उच्च दैनिक खर्च (~ \(amount)/दिन)"
        case ("hi", .veryHigh, let amount?):
            headline = "बहुत अधिक दैनिक खर्च (~ \(amount)/दिन)"

        case ("tr", .veryLow, let amount?):
            headline = "Cok dusuk gunluk maliyet (~ \(amount)/gun)"
        case ("tr", .low, let amount?):
            headline = "Dusuk gunluk maliyet (~ \(amount)/gun)"
        case ("tr", .moderate, let amount?):
            headline = "Orta gunluk maliyet (~ \(amount)/gun)"
        case ("tr", .high, let amount?):
            headline = "Yuksek gunluk maliyet (~ \(amount)/gun)"
        case ("tr", .veryHigh, let amount?):
            headline = "Cok yuksek gunluk maliyet (~ \(amount)/gun)"

        case ("pl", .veryLow, let amount?):
            headline = "Bardzo niskie dzienne koszty (~ \(amount)/dzien)"
        case ("pl", .low, let amount?):
            headline = "Niskie dzienne koszty (~ \(amount)/dzien)"
        case ("pl", .moderate, let amount?):
            headline = "Srednie dzienne koszty (~ \(amount)/dzien)"
        case ("pl", .high, let amount?):
            headline = "Wysokie dzienne koszty (~ \(amount)/dzien)"
        case ("pl", .veryHigh, let amount?):
            headline = "Bardzo wysokie dzienne koszty (~ \(amount)/dzien)"

        case ("he", .veryLow, let amount?):
            headline = "עלות יומית נמוכה מאוד (~ \(amount)/יום)"
        case ("he", .low, let amount?):
            headline = "עלות יומית נמוכה (~ \(amount)/יום)"
        case ("he", .moderate, let amount?):
            headline = "עלות יומית בינונית (~ \(amount)/יום)"
        case ("he", .high, let amount?):
            headline = "עלות יומית גבוהה (~ \(amount)/יום)"
        case ("he", .veryHigh, let amount?):
            headline = "עלות יומית גבוהה מאוד (~ \(amount)/יום)"

        case ("sv", .veryLow, let amount?):
            headline = "Mycket laga dagliga kostnader (~ \(amount)/dag)"
        case ("sv", .low, let amount?):
            headline = "Laga dagliga kostnader (~ \(amount)/dag)"
        case ("sv", .moderate, let amount?):
            headline = "Medelhoga dagliga kostnader (~ \(amount)/dag)"
        case ("sv", .high, let amount?):
            headline = "Hoga dagliga kostnader (~ \(amount)/dag)"
        case ("sv", .veryHigh, let amount?):
            headline = "Mycket hoga dagliga kostnader (~ \(amount)/dag)"

        case ("fi", .veryLow, let amount?):
            headline = "Hyvin matalat paivittaiset kustannukset (~ \(amount)/paiva)"
        case ("fi", .low, let amount?):
            headline = "Matalat paivittaiset kustannukset (~ \(amount)/paiva)"
        case ("fi", .moderate, let amount?):
            headline = "Kohtalaiset paivittaiset kustannukset (~ \(amount)/paiva)"
        case ("fi", .high, let amount?):
            headline = "Korkeat paivittaiset kustannukset (~ \(amount)/paiva)"
        case ("fi", .veryHigh, let amount?):
            headline = "Erittain korkeat paivittaiset kustannukset (~ \(amount)/paiva)"

        case ("da", .veryLow, let amount?):
            headline = "Meget lave daglige omkostninger (~ \(amount)/dag)"
        case ("da", .low, let amount?):
            headline = "Lave daglige omkostninger (~ \(amount)/dag)"
        case ("da", .moderate, let amount?):
            headline = "Moderate daglige omkostninger (~ \(amount)/dag)"
        case ("da", .high, let amount?):
            headline = "Hoje daglige omkostninger (~ \(amount)/dag)"
        case ("da", .veryHigh, let amount?):
            headline = "Meget hoje daglige omkostninger (~ \(amount)/dag)"

        case ("el", .veryLow, let amount?):
            headline = "Πολύ χαμηλό ημερήσιο κόστος (~ \(amount)/ημέρα)"
        case ("el", .low, let amount?):
            headline = "Χαμηλό ημερήσιο κόστος (~ \(amount)/ημέρα)"
        case ("el", .moderate, let amount?):
            headline = "Μέτριο ημερήσιο κόστος (~ \(amount)/ημέρα)"
        case ("el", .high, let amount?):
            headline = "Υψηλό ημερήσιο κόστος (~ \(amount)/ημέρα)"
        case ("el", .veryHigh, let amount?):
            headline = "Πολύ υψηλό ημερήσιο κόστος (~ \(amount)/ημέρα)"

        case ("id", .veryLow, let amount?):
            headline = "Biaya harian sangat rendah (~ \(amount)/hari)"
        case ("id", .low, let amount?):
            headline = "Biaya harian rendah (~ \(amount)/hari)"
        case ("id", .moderate, let amount?):
            headline = "Biaya harian sedang (~ \(amount)/hari)"
        case ("id", .high, let amount?):
            headline = "Biaya harian tinggi (~ \(amount)/hari)"
        case ("id", .veryHigh, let amount?):
            headline = "Biaya harian sangat tinggi (~ \(amount)/hari)"

        case ("uk", .veryLow, let amount?):
            headline = "Дуже низькі щоденні витрати (~ \(amount)/день)"
        case ("uk", .low, let amount?):
            headline = "Низькі щоденні витрати (~ \(amount)/день)"
        case ("uk", .moderate, let amount?):
            headline = "Помірні щоденні витрати (~ \(amount)/день)"
        case ("uk", .high, let amount?):
            headline = "Високі щоденні витрати (~ \(amount)/день)"
        case ("uk", .veryHigh, let amount?):
            headline = "Дуже високі щоденні витрати (~ \(amount)/день)"

        case ("zh-Hant", .veryLow, let amount?):
            headline = "每日花費很低（約\(amount)/天）"
        case ("zh-Hant", .low, let amount?):
            headline = "每日花費較低（約\(amount)/天）"
        case ("zh-Hant", .moderate, let amount?):
            headline = "每日花費中等（約\(amount)/天）"
        case ("zh-Hant", .high, let amount?):
            headline = "每日花費較高（約\(amount)/天）"
        case ("zh-Hant", .veryHigh, let amount?):
            headline = "每日花費很高（約\(amount)/天）"

        case (_, .veryLow, let amount?):
            headline = "Very low daily costs (~ \(amount)/day)"
        case (_, .low, let amount?):
            headline = "Low daily costs (~ \(amount)/day)"
        case (_, .moderate, let amount?):
            headline = "Moderate daily costs (~ \(amount)/day)"
        case (_, .high, let amount?):
            headline = "High daily costs (~ \(amount)/day)"
        case (_, .veryHigh, let amount?):
            headline = "Very high daily costs (~ \(amount)/day)"

        case ("fr", .veryLow, nil):
            headline = "Cout quotidien tres bas"
        case ("fr", .low, nil):
            headline = "Cout quotidien bas"
        case ("fr", .moderate, nil):
            headline = "Cout quotidien modere"
        case ("fr", .high, nil):
            headline = "Cout quotidien eleve"
        case ("fr", .veryHigh, nil):
            headline = "Cout quotidien tres eleve"

        case ("es", .veryLow, nil):
            headline = "Costos diarios muy bajos"
        case ("es", .low, nil):
            headline = "Costos diarios bajos"
        case ("es", .moderate, nil):
            headline = "Costos diarios moderados"
        case ("es", .high, nil):
            headline = "Costos diarios altos"
        case ("es", .veryHigh, nil):
            headline = "Costos diarios muy altos"

        case ("pt", .veryLow, nil):
            headline = "Custos diarios muito baixos"
        case ("pt", .low, nil):
            headline = "Custos diarios baixos"
        case ("pt", .moderate, nil):
            headline = "Custos diarios moderados"
        case ("pt", .high, nil):
            headline = "Custos diarios altos"
        case ("pt", .veryHigh, nil):
            headline = "Custos diarios muito altos"

        case ("de", .veryLow, nil):
            headline = "Sehr niedrige Tageskosten"
        case ("de", .low, nil):
            headline = "Niedrige Tageskosten"
        case ("de", .moderate, nil):
            headline = "Mittlere Tageskosten"
        case ("de", .high, nil):
            headline = "Hohe Tageskosten"
        case ("de", .veryHigh, nil):
            headline = "Sehr hohe Tageskosten"

        case ("it", .veryLow, nil):
            headline = "Costi giornalieri molto bassi"
        case ("it", .low, nil):
            headline = "Costi giornalieri bassi"
        case ("it", .moderate, nil):
            headline = "Costi giornalieri moderati"
        case ("it", .high, nil):
            headline = "Costi giornalieri alti"
        case ("it", .veryHigh, nil):
            headline = "Costi giornalieri molto alti"

        case ("ru", .veryLow, nil):
            headline = "Очень низкие ежедневные расходы"
        case ("ru", .low, nil):
            headline = "Низкие ежедневные расходы"
        case ("ru", .moderate, nil):
            headline = "Умеренные ежедневные расходы"
        case ("ru", .high, nil):
            headline = "Высокие ежедневные расходы"
        case ("ru", .veryHigh, nil):
            headline = "Очень высокие ежедневные расходы"

        case ("nl", .veryLow, nil):
            headline = "Zeer lage dagelijkse kosten"
        case ("nl", .low, nil):
            headline = "Lage dagelijkse kosten"
        case ("nl", .moderate, nil):
            headline = "Gemiddelde dagelijkse kosten"
        case ("nl", .high, nil):
            headline = "Hoge dagelijkse kosten"
        case ("nl", .veryHigh, nil):
            headline = "Zeer hoge dagelijkse kosten"

        case ("ar", .veryLow, nil):
            headline = "تكاليف يومية منخفضة جدا"
        case ("ar", .low, nil):
            headline = "تكاليف يومية منخفضة"
        case ("ar", .moderate, nil):
            headline = "تكاليف يومية متوسطة"
        case ("ar", .high, nil):
            headline = "تكاليف يومية مرتفعة"
        case ("ar", .veryHigh, nil):
            headline = "تكاليف يومية مرتفعة جدا"

        case ("ja", .veryLow, nil):
            headline = "非常に低い1日コスト"
        case ("ja", .low, nil):
            headline = "低い1日コスト"
        case ("ja", .moderate, nil):
            headline = "中程度の1日コスト"
        case ("ja", .high, nil):
            headline = "高い1日コスト"
        case ("ja", .veryHigh, nil):
            headline = "非常に高い1日コスト"

        case ("ko", .veryLow, nil):
            headline = "매우 낮은 일일 비용"
        case ("ko", .low, nil):
            headline = "낮은 일일 비용"
        case ("ko", .moderate, nil):
            headline = "보통 수준의 일일 비용"
        case ("ko", .high, nil):
            headline = "높은 일일 비용"
        case ("ko", .veryHigh, nil):
            headline = "매우 높은 일일 비용"

        case ("zh", .veryLow, nil):
            headline = "每日花费很低"
        case ("zh", .low, nil):
            headline = "每日花费较低"
        case ("zh", .moderate, nil):
            headline = "每日花费中等"
        case ("zh", .high, nil):
            headline = "每日花费较高"
        case ("zh", .veryHigh, nil):
            headline = "每日花费很高"

        case ("hi", .veryLow, nil):
            headline = "बहुत कम दैनिक खर्च"
        case ("hi", .low, nil):
            headline = "कम दैनिक खर्च"
        case ("hi", .moderate, nil):
            headline = "मध्यम दैनिक खर्च"
        case ("hi", .high, nil):
            headline = "उच्च दैनिक खर्च"
        case ("hi", .veryHigh, nil):
            headline = "बहुत अधिक दैनिक खर्च"

        case ("tr", .veryLow, nil):
            headline = "Cok dusuk gunluk maliyet"
        case ("tr", .low, nil):
            headline = "Dusuk gunluk maliyet"
        case ("tr", .moderate, nil):
            headline = "Orta gunluk maliyet"
        case ("tr", .high, nil):
            headline = "Yuksek gunluk maliyet"
        case ("tr", .veryHigh, nil):
            headline = "Cok yuksek gunluk maliyet"

        case ("pl", .veryLow, nil):
            headline = "Bardzo niskie dzienne koszty"
        case ("pl", .low, nil):
            headline = "Niskie dzienne koszty"
        case ("pl", .moderate, nil):
            headline = "Srednie dzienne koszty"
        case ("pl", .high, nil):
            headline = "Wysokie dzienne koszty"
        case ("pl", .veryHigh, nil):
            headline = "Bardzo wysokie dzienne koszty"

        case ("he", .veryLow, nil):
            headline = "עלות יומית נמוכה מאוד"
        case ("he", .low, nil):
            headline = "עלות יומית נמוכה"
        case ("he", .moderate, nil):
            headline = "עלות יומית בינונית"
        case ("he", .high, nil):
            headline = "עלות יומית גבוהה"
        case ("he", .veryHigh, nil):
            headline = "עלות יומית גבוהה מאוד"

        case ("sv", .veryLow, nil):
            headline = "Mycket laga dagliga kostnader"
        case ("sv", .low, nil):
            headline = "Laga dagliga kostnader"
        case ("sv", .moderate, nil):
            headline = "Medelhoga dagliga kostnader"
        case ("sv", .high, nil):
            headline = "Hoga dagliga kostnader"
        case ("sv", .veryHigh, nil):
            headline = "Mycket hoga dagliga kostnader"

        case ("fi", .veryLow, nil):
            headline = "Hyvin matalat paivittaiset kustannukset"
        case ("fi", .low, nil):
            headline = "Matalat paivittaiset kustannukset"
        case ("fi", .moderate, nil):
            headline = "Kohtalaiset paivittaiset kustannukset"
        case ("fi", .high, nil):
            headline = "Korkeat paivittaiset kustannukset"
        case ("fi", .veryHigh, nil):
            headline = "Erittain korkeat paivittaiset kustannukset"

        case ("da", .veryLow, nil):
            headline = "Meget lave daglige omkostninger"
        case ("da", .low, nil):
            headline = "Lave daglige omkostninger"
        case ("da", .moderate, nil):
            headline = "Moderate daglige omkostninger"
        case ("da", .high, nil):
            headline = "Hoje daglige omkostninger"
        case ("da", .veryHigh, nil):
            headline = "Meget hoje daglige omkostninger"

        case ("el", .veryLow, nil):
            headline = "Πολύ χαμηλό ημερήσιο κόστος"
        case ("el", .low, nil):
            headline = "Χαμηλό ημερήσιο κόστος"
        case ("el", .moderate, nil):
            headline = "Μέτριο ημερήσιο κόστος"
        case ("el", .high, nil):
            headline = "Υψηλό ημερήσιο κόστος"
        case ("el", .veryHigh, nil):
            headline = "Πολύ υψηλό ημερήσιο κόστος"

        case ("id", .veryLow, nil):
            headline = "Biaya harian sangat rendah"
        case ("id", .low, nil):
            headline = "Biaya harian rendah"
        case ("id", .moderate, nil):
            headline = "Biaya harian sedang"
        case ("id", .high, nil):
            headline = "Biaya harian tinggi"
        case ("id", .veryHigh, nil):
            headline = "Biaya harian sangat tinggi"

        case ("uk", .veryLow, nil):
            headline = "Дуже низькі щоденні витрати"
        case ("uk", .low, nil):
            headline = "Низькі щоденні витрати"
        case ("uk", .moderate, nil):
            headline = "Помірні щоденні витрати"
        case ("uk", .high, nil):
            headline = "Високі щоденні витрати"
        case ("uk", .veryHigh, nil):
            headline = "Дуже високі щоденні витрати"

        case ("zh-Hant", .veryLow, nil):
            headline = "每日花費很低"
        case ("zh-Hant", .low, nil):
            headline = "每日花費較低"
        case ("zh-Hant", .moderate, nil):
            headline = "每日花費中等"
        case ("zh-Hant", .high, nil):
            headline = "每日花費較高"
        case ("zh-Hant", .veryHigh, nil):
            headline = "每日花費很高"

        case ("ms", .veryLow, nil):
            headline = "Kos harian sangat rendah"
        case ("ms", .low, nil):
            headline = "Kos harian rendah"
        case ("ms", .moderate, nil):
            headline = "Kos harian sederhana"
        case ("ms", .high, nil):
            headline = "Kos harian tinggi"
        case ("ms", .veryHigh, nil):
            headline = "Kos harian sangat tinggi"

        case ("ro", .veryLow, nil):
            headline = "Costuri zilnice foarte mici"
        case ("ro", .low, nil):
            headline = "Costuri zilnice mici"
        case ("ro", .moderate, nil):
            headline = "Costuri zilnice moderate"
        case ("ro", .high, nil):
            headline = "Costuri zilnice ridicate"
        case ("ro", .veryHigh, nil):
            headline = "Costuri zilnice foarte ridicate"

        case ("th", .veryLow, nil):
            headline = "ค่าใช้จ่ายรายวันต่ำมาก"
        case ("th", .low, nil):
            headline = "ค่าใช้จ่ายรายวันต่ำ"
        case ("th", .moderate, nil):
            headline = "ค่าใช้จ่ายรายวันปานกลาง"
        case ("th", .high, nil):
            headline = "ค่าใช้จ่ายรายวันสูง"
        case ("th", .veryHigh, nil):
            headline = "ค่าใช้จ่ายรายวันสูงมาก"

        case ("vi", .veryLow, nil):
            headline = "Chi phi hang ngay rat thap"
        case ("vi", .low, nil):
            headline = "Chi phi hang ngay thap"
        case ("vi", .moderate, nil):
            headline = "Chi phi hang ngay trung binh"
        case ("vi", .high, nil):
            headline = "Chi phi hang ngay cao"
        case ("vi", .veryHigh, nil):
            headline = "Chi phi hang ngay rat cao"

        case ("cs", .veryLow, nil):
            headline = "Velmi nizke denni naklady"
        case ("cs", .low, nil):
            headline = "Nizke denni naklady"
        case ("cs", .moderate, nil):
            headline = "Stredni denni naklady"
        case ("cs", .high, nil):
            headline = "Vysoke denni naklady"
        case ("cs", .veryHigh, nil):
            headline = "Velmi vysoke denni naklady"

        case ("hu", .veryLow, nil):
            headline = "Nagyon alacsony napi koltsegek"
        case ("hu", .low, nil):
            headline = "Alacsony napi koltsegek"
        case ("hu", .moderate, nil):
            headline = "Kozepes napi koltsegek"
        case ("hu", .high, nil):
            headline = "Magas napi koltsegek"
        case ("hu", .veryHigh, nil):
            headline = "Nagyon magas napi koltsegek"

        case ("nb", .veryLow, nil):
            headline = "Svaert lave daglige kostnader"
        case ("nb", .low, nil):
            headline = "Lave daglige kostnader"
        case ("nb", .moderate, nil):
            headline = "Moderate daglige kostnader"
        case ("nb", .high, nil):
            headline = "Hoye daglige kostnader"
        case ("nb", .veryHigh, nil):
            headline = "Svaert hoye daglige kostnader"

        case ("ca", .veryLow, nil):
            headline = "Costos diaris molt baixos"
        case ("ca", .low, nil):
            headline = "Costos diaris baixos"
        case ("ca", .moderate, nil):
            headline = "Costos diaris moderats"
        case ("ca", .high, nil):
            headline = "Costos diaris elevats"
        case ("ca", .veryHigh, nil):
            headline = "Costos diaris molt elevats"

        case ("hr", .veryLow, nil):
            headline = "Vrlo niski dnevni troskovi"
        case ("hr", .low, nil):
            headline = "Niski dnevni troskovi"
        case ("hr", .moderate, nil):
            headline = "Umjereni dnevni troskovi"
        case ("hr", .high, nil):
            headline = "Visoki dnevni troskovi"
        case ("hr", .veryHigh, nil):
            headline = "Vrlo visoki dnevni troskovi"

        case ("sk", .veryLow, nil):
            headline = "Velmi nizke denne naklady"
        case ("sk", .low, nil):
            headline = "Nizke denne naklady"
        case ("sk", .moderate, nil):
            headline = "Stredne denne naklady"
        case ("sk", .high, nil):
            headline = "Vysoke denne naklady"
        case ("sk", .veryHigh, nil):
            headline = "Velmi vysoke denne naklady"

        case (_, .veryLow, nil):
            headline = "Very low daily costs"
        case (_, .low, nil):
            headline = "Low daily costs"
        case (_, .moderate, nil):
            headline = "Moderate daily costs"
        case (_, .high, nil):
            headline = "High daily costs"
        case (_, .veryHigh, nil):
            headline = "Very high daily costs"
        }

        let body: String
        switch (Self.currentLanguageCode, tier) {
        case ("fr", .veryLow):
            body = "Tres bon rapport qualite-prix pour l'hebergement, les repas et les transports par rapport aux moyennes mondiales."
        case ("fr", .low):
            body = "Destination plutot abordable pour la plupart des voyageurs, avec une bonne marge pour rester confortable."
        case ("fr", .moderate):
            body = "Couts de voyage de milieu de gamme compares aux moyennes mondiales."
        case ("fr", .high):
            body = "Les depenses quotidiennes sont au-dessus de la moyenne mondiale, surtout pour l'hebergement."
        case ("fr", .veryHigh):
            body = "Destination premium avec des depenses de voyage regulierement elevees."

        case ("es", .veryLow):
            body = "Muy buena relacion calidad-precio en alojamiento, comida y transporte frente a los promedios globales."
        case ("es", .low):
            body = "Destino bastante accesible para la mayoria de los viajeros, con margen para viajar comodo."
        case ("es", .moderate):
            body = "Costos de viaje de gama media en comparacion con los promedios globales."
        case ("es", .high):
            body = "Los gastos diarios estan por encima del promedio global, especialmente en alojamiento."
        case ("es", .veryHigh):
            body = "Destino premium con costos de viaje constantemente altos."

        case ("pt", .veryLow):
            body = "Otimo custo-beneficio para hospedagem, comida e transporte em comparacao com as medias globais."
        case ("pt", .low):
            body = "Destino relativamente acessivel para a maioria dos viajantes, com folga para viajar com conforto."
        case ("pt", .moderate):
            body = "Custos de viagem de faixa media em comparacao com as medias globais."
        case ("pt", .high):
            body = "Os gastos diarios ficam acima da media global, especialmente em hospedagem."
        case ("pt", .veryHigh):
            body = "Destino premium com custos de viagem consistentemente altos."

        case ("de", .veryLow):
            body = "Sehr gutes Preis-Leistungs-Verhaeltnis bei Unterkunft, Essen und Transport im Vergleich zum weltweiten Durchschnitt."
        case ("de", .low):
            body = "Fuer die meisten Reisenden eher erschwinglich und mit Spielraum fuer etwas mehr Komfort."
        case ("de", .moderate):
            body = "Reisekosten im mittleren Bereich verglichen mit weltweiten Durchschnittswerten."
        case ("de", .high):
            body = "Die taeglichen Kosten liegen ueber dem weltweiten Durchschnitt, besonders bei Unterkuenften."
        case ("de", .veryHigh):
            body = "Premium-Reiseziel mit durchgehend hohen Reisekosten."

        case ("it", .veryLow):
            body = "Ottimo rapporto qualita-prezzo per alloggio, cibo e trasporti rispetto alle medie globali."
        case ("it", .low):
            body = "Destinazione abbastanza accessibile per la maggior parte dei viaggiatori, con margine per stare comodi."
        case ("it", .moderate):
            body = "Costi di viaggio di fascia media rispetto alle medie globali."
        case ("it", .high):
            body = "Le spese giornaliere sono sopra la media globale, soprattutto per l'alloggio."
        case ("it", .veryHigh):
            body = "Destinazione premium con costi di viaggio costantemente elevati."

        case ("ru", .veryLow):
            body = "Очень выгодное направление по жилью, еде и транспорту по сравнению с мировыми средними."
        case ("ru", .low):
            body = "В целом доступное направление для большинства путешественников с запасом на комфорт."
        case ("ru", .moderate):
            body = "Расходы на поездку находятся на среднем уровне по сравнению с мировыми значениями."
        case ("ru", .high):
            body = "Ежедневные расходы выше мирового среднего, особенно на проживание."
        case ("ru", .veryHigh):
            body = "Премиальное направление со стабильно высокими расходами на поездку."

        case ("nl", .veryLow):
            body = "Sterke prijs-kwaliteitverhouding voor verblijf, eten en vervoer vergeleken met wereldwijde gemiddelden."
        case ("nl", .low):
            body = "Relatief betaalbare bestemming voor de meeste reizigers, met ruimte om comfortabel te reizen."
        case ("nl", .moderate):
            body = "Reiskosten in het middensegment vergeleken met wereldwijde gemiddelden."
        case ("nl", .high):
            body = "Dagelijkse kosten liggen boven het wereldwijde gemiddelde, vooral voor accommodatie."
        case ("nl", .veryHigh):
            body = "Premium bestemming met consequent hoge reiskosten."

        case ("ar", .veryLow):
            body = "قيمة ممتازة مقابل المال في الاقامة والطعام والتنقل مقارنة بالمتوسطات العالمية."
        case ("ar", .low):
            body = "وجهة ميسورة نسبيا لمعظم المسافرين مع مساحة كافية للسفر براحة."
        case ("ar", .moderate):
            body = "تكاليف السفر متوسطة مقارنة بالمتوسطات العالمية."
        case ("ar", .high):
            body = "التكاليف اليومية اعلى من المتوسط العالمي، خاصة في الاقامة."
        case ("ar", .veryHigh):
            body = "وجهة مرتفعة التكلفة مع مصاريف سفر عالية باستمرار."

        case ("ja", .veryLow):
            body = "宿泊、食事、移動のコストは世界平均と比べてかなり割安です。"
        case ("ja", .low):
            body = "多くの旅行者にとって比較的手頃で、快適さを保つ余地もあります。"
        case ("ja", .moderate):
            body = "旅行コストは世界平均と比べて中程度です。"
        case ("ja", .high):
            body = "1日の費用は世界平均より高く、特に宿泊費がかさみます。"
        case ("ja", .veryHigh):
            body = "継続的に旅行費用が高いプレミアム寄りの目的地です。"

        case ("ko", .veryLow):
            body = "숙박, 식사, 교통비가 세계 평균과 비교해 매우 좋은 편입니다."
        case ("ko", .low):
            body = "대부분의 여행자에게 비교적 부담이 적고, 편안하게 여행할 여유도 있습니다."
        case ("ko", .moderate):
            body = "여행 비용은 세계 평균과 비교해 중간 수준입니다."
        case ("ko", .high):
            body = "일일 비용이 세계 평균보다 높으며 특히 숙박비가 큽니다."
        case ("ko", .veryHigh):
            body = "여행 비용이 꾸준히 높은 프리미엄 목적지입니다."

        case ("zh", .veryLow):
            body = "与全球平均相比，这里的住宿、餐饮和交通性价比很高。"
        case ("zh", .low):
            body = "对大多数旅行者来说相对实惠，也有空间保持舒适。"
        case ("zh", .moderate):
            body = "旅行成本与全球平均相比处于中等水平。"
        case ("zh", .high):
            body = "每日花费高于全球平均，尤其是住宿。"
        case ("zh", .veryHigh):
            body = "这是一个旅行成本持续偏高的高端目的地。"

        case ("hi", .veryLow):
            body = "आवास, भोजन और परिवहन के लिए यह गंतव्य वैश्विक औसत की तुलना में बहुत अच्छी वैल्यू देता है।"
        case ("hi", .low):
            body = "अधिकांश यात्रियों के लिए यह अपेक्षाकृत किफायती है और आराम से यात्रा करने की गुंजाइश देता है।"
        case ("hi", .moderate):
            body = "यात्रा खर्च वैश्विक औसत की तुलना में मध्यम स्तर पर हैं।"
        case ("hi", .high):
            body = "दैनिक खर्च वैश्विक औसत से ऊपर हैं, खासकर आवास के लिए।"
        case ("hi", .veryHigh):
            body = "यह लगातार ऊंचे यात्रा खर्च वाला प्रीमियम गंतव्य है।"

        case ("tr", .veryLow):
            body = "Konaklama, yemek ve ulasim acisindan kuresel ortalamalara gore cok iyi bir deger sunar."
        case ("tr", .low):
            body = "Cogu gezgin icin nispeten uygun fiyatlidir ve rahat seyahat etmek icin pay birakir."
        case ("tr", .moderate):
            body = "Seyahat maliyetleri kuresel ortalamalara gore orta seviyededir."
        case ("tr", .high):
            body = "Gunluk maliyetler kuresel ortalamanin uzerindedir; ozellikle konaklama pahali olabilir."
        case ("tr", .veryHigh):
            body = "Seyahat maliyetleri surekli yuksek olan premium bir destinasyondur."

        case ("pl", .veryLow):
            body = "To kierunek o bardzo dobrej relacji ceny do jakosci w noclegach, jedzeniu i transporcie na tle srednich swiatowych."
        case ("pl", .low):
            body = "Dla wiekszosci podroznych jest to dosc przystepny kierunek, z zapasem na wygodne podrozowanie."
        case ("pl", .moderate):
            body = "Koszty podrozy sa na srednim poziomie w porownaniu ze srednimi swiatowymi."
        case ("pl", .high):
            body = "Dzienne wydatki sa wyzsze od sredniej swiatowej, szczegolnie na noclegi."
        case ("pl", .veryHigh):
            body = "To premium kierunek z konsekwentnie wysokimi kosztami podrozy."

        case ("he", .veryLow):
            body = "היעד הזה נותן תמורה מצוינת ללינה, אוכל ותחבורה ביחס לממוצע העולמי."
        case ("he", .low):
            body = "זהו יעד יחסית נגיש לרוב המטיילים, עם מרחב לשמור על נוחות."
        case ("he", .moderate):
            body = "עלויות הטיול נמצאות בטווח בינוני ביחס לממוצעים עולמיים."
        case ("he", .high):
            body = "ההוצאות היומיות גבוהות מהממוצע העולמי, במיוחד על לינה."
        case ("he", .veryHigh):
            body = "זהו יעד פרימיום עם עלויות נסיעה גבוהות באופן עקבי."

        case ("sv", .veryLow):
            body = "Mycket bra varde for boende, mat och transporter jamfort med globala genomsnitt."
        case ("sv", .low):
            body = "Relativt prisvart for de flesta resenarer, med utrymme att resa bekvamt."
        case ("sv", .moderate):
            body = "Resekostnaderna ligger pa mellanniva jamfort med globala genomsnitt."
        case ("sv", .high):
            body = "Dagliga kostnader ligger over globala genomsnitt, sarskilt for boende."
        case ("sv", .veryHigh):
            body = "En premiumdestination med genomgaende hoga resekostnader."

        case ("fi", .veryLow):
            body = "Majoitus, ruoka ja liikkuminen tarjoavat erinomaista vastinetta rahalle maailmanlaajuisiin keskiarvoihin verrattuna."
        case ("fi", .low):
            body = "Useimmille matkailijoille melko edullinen kohde, jossa on varaa matkustaa mukavasti."
        case ("fi", .moderate):
            body = "Matkakustannukset ovat maailmanlaajuisiin keskiarvoihin verrattuna keskitasoa."
        case ("fi", .high):
            body = "Paivittaiset kustannukset ovat maailmanlaajuisen keskitason ylapuolella, erityisesti majoituksessa."
        case ("fi", .veryHigh):
            body = "Premium-kohde, jossa matkakustannukset ovat johdonmukaisesti korkeat."

        case ("da", .veryLow):
            body = "Meget god vaerdi for overnatning, mad og transport sammenlignet med globale gennemsnit."
        case ("da", .low):
            body = "Relativt overkommelig for de fleste rejsende med plads til at rejse komfortabelt."
        case ("da", .moderate):
            body = "Rejseomkostningerne ligger pa mellemniveau sammenlignet med globale gennemsnit."
        case ("da", .high):
            body = "Daglige omkostninger ligger over de globale gennemsnit, isaer for overnatning."
        case ("da", .veryHigh):
            body = "Et premiumrejsemaal med gennemgaende hoje rejseomkostninger."

        case ("el", .veryLow):
            body = "Πολύ καλή αξία για διαμονή, φαγητό και μεταφορές σε σύγκριση με τους παγκόσμιους μέσους όρους."
        case ("el", .low):
            body = "Σχετικά προσιτός προορισμός για τους περισσότερους ταξιδιώτες, με περιθώριο για άνετο ταξίδι."
        case ("el", .moderate):
            body = "Το κόστος ταξιδιού κινείται σε μεσαίο επίπεδο σε σύγκριση με τους παγκόσμιους μέσους όρους."
        case ("el", .high):
            body = "Οι ημερήσιες δαπάνες είναι πάνω από τους παγκόσμιους μέσους όρους, ιδιαίτερα στη διαμονή."
        case ("el", .veryHigh):
            body = "Προορισμός premium με σταθερά υψηλό ταξιδιωτικό κόστος."

        case ("id", .veryLow):
            body = "Sangat bernilai untuk akomodasi, makanan, dan transportasi dibandingkan rata-rata global."
        case ("id", .low):
            body = "Relatif terjangkau bagi sebagian besar pelancong, dengan ruang untuk tetap nyaman."
        case ("id", .moderate):
            body = "Biaya perjalanan berada di tingkat menengah dibandingkan rata-rata global."
        case ("id", .high):
            body = "Biaya harian berada di atas rata-rata global, terutama untuk akomodasi."
        case ("id", .veryHigh):
            body = "Destinasi premium dengan biaya perjalanan yang konsisten tinggi."

        case ("uk", .veryLow):
            body = "Дуже вигідний напрямок для житла, харчування та транспорту порівняно зі світовими середніми показниками."
        case ("uk", .low):
            body = "Відносно доступний для більшості мандрівників, із запасом для комфортної подорожі."
        case ("uk", .moderate):
            body = "Витрати на подорож перебувають на середньому рівні порівняно зі світовими середніми."
        case ("uk", .high):
            body = "Щоденні витрати вищі за світові середні, особливо на проживання."
        case ("uk", .veryHigh):
            body = "Преміальний напрямок зі стабільно високими витратами на подорож."

        case ("zh-Hant", .veryLow):
            body = "與全球平均相比，這裡的住宿、餐飲和交通都有很高的性價比。"
        case ("zh-Hant", .low):
            body = "對大多數旅客來說相對實惠，也有空間維持舒適體驗。"
        case ("zh-Hant", .moderate):
            body = "旅遊成本與全球平均相比處於中等水平。"
        case ("zh-Hant", .high):
            body = "每日花費高於全球平均，尤其是住宿。"
        case ("zh-Hant", .veryHigh):
            body = "這是一個旅遊成本持續偏高的高端目的地。"

        case ("ms", .veryLow):
            body = "Nilai yang sangat baik untuk penginapan, makanan, dan pengangkutan berbanding purata global."
        case ("ms", .low):
            body = "Destinasi yang agak mampu milik bagi kebanyakan pelancong, dengan ruang untuk kekal selesa."
        case ("ms", .moderate):
            body = "Kos perjalanan berada pada tahap pertengahan berbanding purata global."
        case ("ms", .high):
            body = "Kos harian melebihi purata global, terutamanya untuk penginapan."
        case ("ms", .veryHigh):
            body = "Destinasi premium dengan kos perjalanan yang konsisten tinggi."

        case ("ro", .veryLow):
            body = "Raport foarte bun calitate-pret pentru cazare, mancare si transport comparativ cu mediile globale."
        case ("ro", .low):
            body = "Destinatie relativ accesibila pentru majoritatea calatorilor, cu spatiu pentru confort."
        case ("ro", .moderate):
            body = "Costurile de calatorie sunt la nivel mediu comparativ cu mediile globale."
        case ("ro", .high):
            body = "Costurile zilnice sunt peste media globala, mai ales pentru cazare."
        case ("ro", .veryHigh):
            body = "Destinatie premium cu costuri de calatorie constant ridicate."

        case ("th", .veryLow):
            body = "คุ้มค่ามากสำหรับที่พัก อาหาร และการเดินทางเมื่อเทียบกับค่าเฉลี่ยทั่วโลก"
        case ("th", .low):
            body = "เป็นจุดหมายที่ค่อนข้างประหยัดสำหรับนักเดินทางส่วนใหญ่ และยังมีพื้นที่ให้เที่ยวได้อย่างสบาย"
        case ("th", .moderate):
            body = "ค่าใช้จ่ายในการเดินทางอยู่ในระดับปานกลางเมื่อเทียบกับค่าเฉลี่ยทั่วโลก"
        case ("th", .high):
            body = "ค่าใช้จ่ายรายวันสูงกว่าค่าเฉลี่ยทั่วโลก โดยเฉพาะค่าที่พัก"
        case ("th", .veryHigh):
            body = "เป็นจุดหมายปลายทางระดับพรีเมียมที่มีค่าใช้จ่ายในการเดินทางสูงอย่างต่อเนื่อง"

        case ("vi", .veryLow):
            body = "Gia tri rat tot cho luu tru, an uong va di chuyen so voi mat bang chung toan cau."
        case ("vi", .low):
            body = "Day la diem den tuong doi phai chang doi voi da so du khach, van du de giu su thoai mai."
        case ("vi", .moderate):
            body = "Chi phi du lich nam o muc trung binh so voi mat bang chung toan cau."
        case ("vi", .high):
            body = "Chi phi hang ngay cao hon mat bang chung toan cau, dac biet la luu tru."
        case ("vi", .veryHigh):
            body = "Day la diem den cao cap voi chi phi du lich luon o muc cao."

        case ("cs", .veryLow):
            body = "Velmi dobra hodnota za ubytovani, jidlo a dopravu ve srovnani s globalnimi prumery."
        case ("cs", .low):
            body = "Pro vetsinu cestovatelu pomerne dostupna destinace s prostorem pro pohodlne cestovani."
        case ("cs", .moderate):
            body = "Naklady na cestovani jsou ve srovnani s globalnimi prumery stredni."
        case ("cs", .high):
            body = "Denni naklady jsou nad globalnim prumerem, zejmena u ubytovani."
        case ("cs", .veryHigh):
            body = "Premiova destinace s trvale vysokymi cestovnimi naklady."

        case ("hu", .veryLow):
            body = "Szallast, etkezest es kozlekedest tekintve nagyon jo erteket nyujt a globalis atlagokhoz kepest."
        case ("hu", .low):
            body = "A legtobb utazo szamara viszonylag megfizetheto, es marad ter a kenyelmes utazashoz is."
        case ("hu", .moderate):
            body = "Az utazasi koltsegek a globalis atlagokhoz kepest kozepes szinten vannak."
        case ("hu", .high):
            body = "A napi koltsegek meghaladjak a globalis atlagot, kulonosen a szallasnal."
        case ("hu", .veryHigh):
            body = "Premium uticel, ahol az utazasi koltsegek tartosan magasak."

        case ("nb", .veryLow):
            body = "Svaert god verdi for overnatting, mat og transport sammenlignet med globale gjennomsnitt."
        case ("nb", .low):
            body = "Relativt rimelig for de fleste reisende, med rom for a reise komfortabelt."
        case ("nb", .moderate):
            body = "Reisekostnadene ligger pa et middels niva sammenlignet med globale gjennomsnitt."
        case ("nb", .high):
            body = "Daglige kostnader ligger over det globale gjennomsnittet, spesielt for overnatting."
        case ("nb", .veryHigh):
            body = "Et premium reisemal med gjennomgaende hoye reisekostnader."

        case ("ca", .veryLow):
            body = "Molt bona relacio qualitat-preu per a allotjament, menjar i transport en comparacio amb les mitjanes globals."
        case ("ca", .low):
            body = "Destinacio relativament assequible per a la majoria de viatgers, amb marge per viatjar amb comoditat."
        case ("ca", .moderate):
            body = "Els costos del viatge se situen en una franja mitjana en comparacio amb les mitjanes globals."
        case ("ca", .high):
            body = "Les despeses diaries estan per sobre de la mitjana global, especialment en allotjament."
        case ("ca", .veryHigh):
            body = "Destinacio premium amb costos de viatge constantment elevats."

        case ("hr", .veryLow):
            body = "Vrlo dobra vrijednost za smjestaj, hranu i prijevoz u usporedbi s globalnim prosjecima."
        case ("hr", .low):
            body = "Relativno pristupacna destinacija za vecinu putnika, uz dovoljno prostora za ugodno putovanje."
        case ("hr", .moderate):
            body = "Troskovi putovanja su na srednjoj razini u usporedbi s globalnim prosjecima."
        case ("hr", .high):
            body = "Dnevni troskovi su iznad globalnog prosjeka, posebno za smjestaj."
        case ("hr", .veryHigh):
            body = "Premium destinacija sa stalno visokim troskovima putovanja."

        case ("sk", .veryLow):
            body = "Velmi dobra hodnota za ubytovanie, jedlo a dopravu v porovnani s globalnymi priemermi."
        case ("sk", .low):
            body = "Relativne dostupna destinacia pre vacsinu cestovatelov, s priestorom na pohodlne cestovanie."
        case ("sk", .moderate):
            body = "Naklady na cestovanie su na strednej urovni v porovnani s globalnymi priemermi."
        case ("sk", .high):
            body = "Denne naklady su nad globalnym priemerom, najma pri ubytovani."
        case ("sk", .veryHigh):
            body = "Premierova destinacia s dlhodobo vysokymi cestovnymi nakladmi."

        case (_, .veryLow):
            body = "Strong value for accommodation, food, and transport compared to global averages."
        case (_, .low):
            body = "Relatively affordable for most travelers, with room to stay comfortable."
        case (_, .moderate):
            body = "Mid-range travel costs compared with global averages."
        case (_, .high):
            body = "Daily costs run above global averages, especially for accommodation."
        case (_, .veryHigh):
            body = "Premium destination with consistently high travel costs."
        }

        return (headline, body)
    }

    private var affordabilityTier: AffordabilityTier {
        if let band = affordabilityBand?.lowercased() {
            if band.contains("very low") { return .veryLow }
            if band.contains("low") { return .low }
            if band.contains("moderate") || band.contains("mid") { return .moderate }
            if band.contains("very high") { return .veryHigh }
            if band.contains("high") || band.contains("expensive") { return .high }
        }

        if let total = dailySpendTotalUsd {
            switch total {
            case ..<65: return .veryLow
            case ..<120: return .low
            case ..<220: return .moderate
            case ..<350: return .high
            default: return .veryHigh
            }
        }

        if let score = affordabilityScore {
            switch score {
            case 85...: return .veryLow
            case 70...: return .low
            case 45...: return .moderate
            case 20...: return .high
            default: return .veryHigh
            }
        }

        return .moderate
    }

    private func formattedUSD(_ amount: Double?, locale: Locale) -> String? {
        guard let amount else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount))
    }

    private enum AffordabilityTier {
        case veryLow
        case low
        case moderate
        case high
        case veryHigh
    }

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

    private static func localizedRegionComponent(_ value: String) -> String {
        let code = currentLanguageCode
        let table = regionTranslations[code] ?? [:]
        return table[value] ?? value
    }

    private static var currentLanguageCode: String {
        CountryTextHelpers.currentLanguageCode
    }

    private static let regionTranslations: [String: [String: String]] = [
        "fr": [
            "Africa": "Afrique",
            "Americas": "Ameriques",
            "Antarctic": "Antarctique",
            "Asia": "Asie",
            "Europe": "Europe",
            "Oceania": "Oceanie",
            "Caribbean": "Caraibes",
            "Central America": "Amerique centrale",
            "Central Asia": "Asie centrale",
            "Eastern Africa": "Afrique de l'Est",
            "Eastern Asia": "Asie de l'Est",
            "Eastern Europe": "Europe de l'Est",
            "Melanesia": "Melanesie",
            "Micronesia": "Micronesie",
            "Middle Africa": "Afrique centrale",
            "North America": "Amerique du Nord",
            "Northern Africa": "Afrique du Nord",
            "Northern Europe": "Europe du Nord",
            "Polynesia": "Polynesie",
            "South America": "Amerique du Sud",
            "Southeast Asia": "Asie du Sud-Est",
            "Southern Africa": "Afrique australe",
            "Southern Asia": "Asie du Sud",
            "Southern Europe": "Europe du Sud",
            "Western Africa": "Afrique de l'Ouest",
            "Western Asia": "Asie de l'Ouest",
            "Western Europe": "Europe de l'Ouest",
            "Latin America & Caribbean": "Amerique latine et Caraibes"
        ],
        "es": [
            "Africa": "Africa",
            "Americas": "Americas",
            "Antarctic": "Antartida",
            "Asia": "Asia",
            "Europe": "Europa",
            "Oceania": "Oceania",
            "Caribbean": "Caribe",
            "Central America": "America Central",
            "Central Asia": "Asia Central",
            "Eastern Africa": "Africa Oriental",
            "Eastern Asia": "Asia Oriental",
            "Eastern Europe": "Europa Oriental",
            "Melanesia": "Melanesia",
            "Micronesia": "Micronesia",
            "Middle Africa": "Africa Central",
            "North America": "America del Norte",
            "Northern Africa": "Africa del Norte",
            "Northern Europe": "Europa del Norte",
            "Polynesia": "Polinesia",
            "South America": "America del Sur",
            "Southeast Asia": "Sudeste Asiatico",
            "Southern Africa": "Africa Austral",
            "Southern Asia": "Asia del Sur",
            "Southern Europe": "Europa del Sur",
            "Western Africa": "Africa Occidental",
            "Western Asia": "Asia Occidental",
            "Western Europe": "Europa Occidental",
            "Latin America & Caribbean": "America Latina y el Caribe"
        ],
        "pt": [
            "Africa": "Africa",
            "Americas": "Americas",
            "Antarctic": "Antartida",
            "Asia": "Asia",
            "Europe": "Europa",
            "Oceania": "Oceania",
            "Caribbean": "Caribe",
            "Central America": "America Central",
            "Central Asia": "Asia Central",
            "Eastern Africa": "Africa Oriental",
            "Eastern Asia": "Asia Oriental",
            "Eastern Europe": "Europa Oriental",
            "Melanesia": "Melanesia",
            "Micronesia": "Micronesia",
            "Middle Africa": "Africa Central",
            "North America": "America do Norte",
            "Northern Africa": "Africa do Norte",
            "Northern Europe": "Europa do Norte",
            "Polynesia": "Polinesia",
            "South America": "America do Sul",
            "Southeast Asia": "Sudeste Asiatico",
            "Southern Africa": "Africa Austral",
            "Southern Asia": "Asia do Sul",
            "Southern Europe": "Europa do Sul",
            "Western Africa": "Africa Ocidental",
            "Western Asia": "Asia Ocidental",
            "Western Europe": "Europa Ocidental",
            "Latin America & Caribbean": "America Latina e Caribe"
        ],
        "de": [
            "Africa": "Afrika",
            "Americas": "Amerika",
            "Antarctic": "Antarktis",
            "Asia": "Asien",
            "Europe": "Europa",
            "Oceania": "Ozeanien",
            "Caribbean": "Karibik",
            "Central America": "Mittelamerika",
            "Central Asia": "Zentralasien",
            "Eastern Africa": "Ostafrika",
            "Eastern Asia": "Ostasien",
            "Eastern Europe": "Osteuropa",
            "Melanesia": "Melanesien",
            "Micronesia": "Mikronesien",
            "Middle Africa": "Zentralafrika",
            "North America": "Nordamerika",
            "Northern Africa": "Nordafrika",
            "Northern Europe": "Nordeuropa",
            "Polynesia": "Polynesien",
            "South America": "Sudamerika",
            "Southeast Asia": "Sudostasien",
            "Southern Africa": "Sudliches Afrika",
            "Southern Asia": "Sudasien",
            "Southern Europe": "Sudeuropa",
            "Western Africa": "Westafrika",
            "Western Asia": "Westasien",
            "Western Europe": "Westeuropa",
            "Latin America & Caribbean": "Lateinamerika und Karibik"
        ],
        "it": [
            "Africa": "Africa",
            "Americas": "Americhe",
            "Antarctic": "Antartide",
            "Asia": "Asia",
            "Europe": "Europa",
            "Oceania": "Oceania",
            "Caribbean": "Caraibi",
            "Central America": "America Centrale",
            "Central Asia": "Asia Centrale",
            "Eastern Africa": "Africa Orientale",
            "Eastern Asia": "Asia Orientale",
            "Eastern Europe": "Europa Orientale",
            "Melanesia": "Melanesia",
            "Micronesia": "Micronesia",
            "Middle Africa": "Africa Centrale",
            "North America": "America del Nord",
            "Northern Africa": "Africa Settentrionale",
            "Northern Europe": "Europa Settentrionale",
            "Polynesia": "Polinesia",
            "South America": "America del Sud",
            "Southeast Asia": "Sud-est asiatico",
            "Southern Africa": "Africa Australe",
            "Southern Asia": "Asia Meridionale",
            "Southern Europe": "Europa Meridionale",
            "Western Africa": "Africa Occidentale",
            "Western Asia": "Asia Occidentale",
            "Western Europe": "Europa Occidentale",
            "Latin America & Caribbean": "America Latina e Caraibi"
        ],
        "hi": [
            "Africa": "अफ्रीका",
            "Americas": "अमेरिकाज",
            "Antarctic": "अंटार्कटिका",
            "Asia": "एशिया",
            "Europe": "यूरोप",
            "Oceania": "ओशिनिया",
            "Caribbean": "कैरेबियन",
            "Central America": "मध्य अमेरिका",
            "Central Asia": "मध्य एशिया",
            "Eastern Africa": "पूर्वी अफ्रीका",
            "Eastern Asia": "पूर्वी एशिया",
            "Eastern Europe": "पूर्वी यूरोप",
            "Melanesia": "मेलानेशिया",
            "Micronesia": "माइक्रोनेशिया",
            "Middle Africa": "मध्य अफ्रीका",
            "North America": "उत्तरी अमेरिका",
            "Northern Africa": "उत्तरी अफ्रीका",
            "Northern Europe": "उत्तरी यूरोप",
            "Polynesia": "पॉलीनेशिया",
            "South America": "दक्षिण अमेरिका",
            "Southeast Asia": "दक्षिण-पूर्व एशिया",
            "Southern Africa": "दक्षिणी अफ्रीका",
            "Southern Asia": "दक्षिण एशिया",
            "Southern Europe": "दक्षिणी यूरोप",
            "Western Africa": "पश्चिमी अफ्रीका",
            "Western Asia": "पश्चिमी एशिया",
            "Western Europe": "पश्चिमी यूरोप",
            "Latin America & Caribbean": "लैटिन अमेरिका और कैरेबियन"
        ],
        "tr": [
            "Africa": "Afrika",
            "Americas": "Amerikalar",
            "Antarctic": "Antarktika",
            "Asia": "Asya",
            "Europe": "Avrupa",
            "Oceania": "Okyanusya",
            "Caribbean": "Karayipler",
            "Central America": "Orta Amerika",
            "Central Asia": "Orta Asya",
            "Eastern Africa": "Dogu Afrika",
            "Eastern Asia": "Dogu Asya",
            "Eastern Europe": "Dogu Avrupa",
            "Melanesia": "Melanezya",
            "Micronesia": "Mikronezya",
            "Middle Africa": "Orta Afrika",
            "North America": "Kuzey Amerika",
            "Northern Africa": "Kuzey Afrika",
            "Northern Europe": "Kuzey Avrupa",
            "Polynesia": "Polinezya",
            "South America": "Guney Amerika",
            "Southeast Asia": "Guneydogu Asya",
            "Southern Africa": "Guney Afrika",
            "Southern Asia": "Guney Asya",
            "Southern Europe": "Guney Avrupa",
            "Western Africa": "Bati Afrika",
            "Western Asia": "Bati Asya",
            "Western Europe": "Bati Avrupa",
            "Latin America & Caribbean": "Latin Amerika ve Karayipler"
        ],
        "pl": [
            "Africa": "Afryka",
            "Americas": "Ameryki",
            "Antarctic": "Antarktyda",
            "Asia": "Azja",
            "Europe": "Europa",
            "Oceania": "Oceania",
            "Caribbean": "Karaiby",
            "Central America": "Ameryka Srodkowa",
            "Central Asia": "Azja Srodkowa",
            "Eastern Africa": "Afryka Wschodnia",
            "Eastern Asia": "Azja Wschodnia",
            "Eastern Europe": "Europa Wschodnia",
            "Melanesia": "Melanezja",
            "Micronesia": "Mikronezja",
            "Middle Africa": "Afryka Srodkowa",
            "North America": "Ameryka Polnocna",
            "Northern Africa": "Afryka Polnocna",
            "Northern Europe": "Europa Polnocna",
            "Polynesia": "Polinezja",
            "South America": "Ameryka Poludniowa",
            "Southeast Asia": "Azja Poludniowo-Wschodnia",
            "Southern Africa": "Afryka Poludniowa",
            "Southern Asia": "Azja Poludniowa",
            "Southern Europe": "Europa Poludniowa",
            "Western Africa": "Afryka Zachodnia",
            "Western Asia": "Azja Zachodnia",
            "Western Europe": "Europa Zachodnia",
            "Latin America & Caribbean": "Ameryka Lacinska i Karaiby"
        ],
        "he": [
            "Africa": "אפריקה",
            "Americas": "אמריקות",
            "Antarctic": "אנטארקטיקה",
            "Asia": "אסיה",
            "Europe": "אירופה",
            "Oceania": "אוקיאניה",
            "Caribbean": "הקריביים",
            "Central America": "מרכז אמריקה",
            "Central Asia": "מרכז אסיה",
            "Eastern Africa": "מזרח אפריקה",
            "Eastern Asia": "מזרח אסיה",
            "Eastern Europe": "מזרח אירופה",
            "Melanesia": "מלנזיה",
            "Micronesia": "מיקרונזיה",
            "Middle Africa": "מרכז אפריקה",
            "North America": "צפון אמריקה",
            "Northern Africa": "צפון אפריקה",
            "Northern Europe": "צפון אירופה",
            "Polynesia": "פולינזיה",
            "South America": "דרום אמריקה",
            "Southeast Asia": "דרום-מזרח אסיה",
            "Southern Africa": "דרום אפריקה",
            "Southern Asia": "דרום אסיה",
            "Southern Europe": "דרום אירופה",
            "Western Africa": "מערב אפריקה",
            "Western Asia": "מערב אסיה",
            "Western Europe": "מערב אירופה",
            "Latin America & Caribbean": "אמריקה הלטינית והקריביים"
        ],
        "ar": [
            "Africa": "أفريقيا",
            "Americas": "الأمريكيتان",
            "Antarctic": "القارة القطبية الجنوبية",
            "Asia": "آسيا",
            "Europe": "أوروبا",
            "Oceania": "أوقيانوسيا",
            "Caribbean": "الكاريبي",
            "Central America": "أمريكا الوسطى",
            "Central Asia": "آسيا الوسطى",
            "Eastern Africa": "شرق أفريقيا",
            "Eastern Asia": "شرق آسيا",
            "Eastern Europe": "أوروبا الشرقية",
            "Melanesia": "ميلانيزيا",
            "Micronesia": "ميكرونيزيا",
            "Middle Africa": "وسط أفريقيا",
            "North America": "أمريكا الشمالية",
            "Northern Africa": "شمال أفريقيا",
            "Northern Europe": "شمال أوروبا",
            "Polynesia": "بولينيزيا",
            "South America": "أمريكا الجنوبية",
            "Southeast Asia": "جنوب شرق آسيا",
            "Southern Africa": "جنوب أفريقيا",
            "Southern Asia": "جنوب آسيا",
            "Southern Europe": "جنوب أوروبا",
            "Western Africa": "غرب أفريقيا",
            "Western Asia": "غرب آسيا",
            "Western Europe": "غرب أوروبا",
            "Latin America & Caribbean": "أمريكا اللاتينية والكاريبي"
        ],
        "sv": [
            "Africa": "Afrika",
            "Americas": "Amerika",
            "Antarctic": "Antarktis",
            "Asia": "Asien",
            "Europe": "Europa",
            "Oceania": "Oceanien",
            "Caribbean": "Karibien",
            "Central America": "Centralamerika",
            "Central Asia": "Centralasien",
            "Eastern Africa": "Ostafrika",
            "Eastern Asia": "Ostasien",
            "Eastern Europe": "Osteuropa",
            "Melanesia": "Melanesien",
            "Micronesia": "Mikronesien",
            "Middle Africa": "Centralafrika",
            "North America": "Nordamerika",
            "Northern Africa": "Nordafrika",
            "Northern Europe": "Nordeuropa",
            "Polynesia": "Polynesien",
            "South America": "Sydamerika",
            "Southeast Asia": "Sydostasien",
            "Southern Africa": "Sodra Afrika",
            "Southern Asia": "Sydasien",
            "Southern Europe": "Sydeuropa",
            "Western Africa": "Vastafrika",
            "Western Asia": "Vastasien",
            "Western Europe": "Vasteuropa",
            "Latin America & Caribbean": "Latinamerika och Karibien"
        ],
        "fi": [
            "Africa": "Afrikka",
            "Americas": "Amerikat",
            "Antarctic": "Antarktis",
            "Asia": "Aasia",
            "Europe": "Eurooppa",
            "Oceania": "Oseania",
            "Caribbean": "Karibia",
            "Central America": "Keski-Amerikka",
            "Central Asia": "Keski-Aasia",
            "Eastern Africa": "Ita-Afrikka",
            "Eastern Asia": "Ita-Aasia",
            "Eastern Europe": "Ita-Eurooppa",
            "Melanesia": "Melanesia",
            "Micronesia": "Mikronesia",
            "Middle Africa": "Keski-Afrikka",
            "North America": "Pohjois-Amerikka",
            "Northern Africa": "Pohjois-Afrikka",
            "Northern Europe": "Pohjois-Eurooppa",
            "Polynesia": "Polynesia",
            "South America": "Etela-Amerikka",
            "Southeast Asia": "Kaakkois-Aasia",
            "Southern Africa": "Etelainen Afrikka",
            "Southern Asia": "Etela-Aasia",
            "Southern Europe": "Etela-Eurooppa",
            "Western Africa": "Lansi-Afrikka",
            "Western Asia": "Lansi-Aasia",
            "Western Europe": "Lansi-Eurooppa",
            "Latin America & Caribbean": "Latinalainen Amerikka ja Karibia"
        ],
        "da": [
            "Africa": "Afrika",
            "Americas": "Amerika",
            "Antarctic": "Antarktis",
            "Asia": "Asien",
            "Europe": "Europa",
            "Oceania": "Oceanien",
            "Caribbean": "Caribien",
            "Central America": "Mellemamerika",
            "Central Asia": "Centralasien",
            "Eastern Africa": "Ostafrika",
            "Eastern Asia": "Ostasien",
            "Eastern Europe": "Osteuropa",
            "Melanesia": "Melanesien",
            "Micronesia": "Mikronesien",
            "Middle Africa": "Centralafrika",
            "North America": "Nordamerika",
            "Northern Africa": "Nordafrika",
            "Northern Europe": "Nordeuropa",
            "Polynesia": "Polynesien",
            "South America": "Sydamerika",
            "Southeast Asia": "Sydostasien",
            "Southern Africa": "Det sydlige Afrika",
            "Southern Asia": "Sydasien",
            "Southern Europe": "Sydeuropa",
            "Western Africa": "Vestafrika",
            "Western Asia": "Vestasien",
            "Western Europe": "Vesteuropa",
            "Latin America & Caribbean": "Latinamerika og Caribien"
        ],
        "el": [
            "Africa": "Αφρική",
            "Americas": "Αμερικές",
            "Antarctic": "Ανταρκτική",
            "Asia": "Ασία",
            "Europe": "Ευρώπη",
            "Oceania": "Ωκεανία",
            "Caribbean": "Καραϊβική",
            "Central America": "Κεντρική Αμερική",
            "Central Asia": "Κεντρική Ασία",
            "Eastern Africa": "Ανατολική Αφρική",
            "Eastern Asia": "Ανατολική Ασία",
            "Eastern Europe": "Ανατολική Ευρώπη",
            "Melanesia": "Μελανησία",
            "Micronesia": "Μικρονησία",
            "Middle Africa": "Κεντρική Αφρική",
            "North America": "Βόρεια Αμερική",
            "Northern Africa": "Βόρεια Αφρική",
            "Northern Europe": "Βόρεια Ευρώπη",
            "Polynesia": "Πολυνησία",
            "South America": "Νότια Αμερική",
            "Southeast Asia": "Νοτιοανατολική Ασία",
            "Southern Africa": "Νότια Αφρική",
            "Southern Asia": "Νότια Ασία",
            "Southern Europe": "Νότια Ευρώπη",
            "Western Africa": "Δυτική Αφρική",
            "Western Asia": "Δυτική Ασία",
            "Western Europe": "Δυτική Ευρώπη",
            "Latin America & Caribbean": "Λατινική Αμερική και Καραϊβική"
        ],
        "id": [
            "Africa": "Afrika",
            "Americas": "Amerika",
            "Antarctic": "Antarktika",
            "Asia": "Asia",
            "Europe": "Eropa",
            "Oceania": "Oseania",
            "Caribbean": "Karibia",
            "Central America": "Amerika Tengah",
            "Central Asia": "Asia Tengah",
            "Eastern Africa": "Afrika Timur",
            "Eastern Asia": "Asia Timur",
            "Eastern Europe": "Eropa Timur",
            "Melanesia": "Melanesia",
            "Micronesia": "Mikronesia",
            "Middle Africa": "Afrika Tengah",
            "North America": "Amerika Utara",
            "Northern Africa": "Afrika Utara",
            "Northern Europe": "Eropa Utara",
            "Polynesia": "Polinesia",
            "South America": "Amerika Selatan",
            "Southeast Asia": "Asia Tenggara",
            "Southern Africa": "Afrika Selatan",
            "Southern Asia": "Asia Selatan",
            "Southern Europe": "Eropa Selatan",
            "Western Africa": "Afrika Barat",
            "Western Asia": "Asia Barat",
            "Western Europe": "Eropa Barat",
            "Latin America & Caribbean": "Amerika Latin dan Karibia"
        ],
        "uk": [
            "Africa": "Африка",
            "Americas": "Америки",
            "Antarctic": "Антарктика",
            "Asia": "Азія",
            "Europe": "Європа",
            "Oceania": "Океанія",
            "Caribbean": "Карибський басейн",
            "Central America": "Центральна Америка",
            "Central Asia": "Центральна Азія",
            "Eastern Africa": "Східна Африка",
            "Eastern Asia": "Східна Азія",
            "Eastern Europe": "Східна Європа",
            "Melanesia": "Меланезія",
            "Micronesia": "Мікронезія",
            "Middle Africa": "Центральна Африка",
            "North America": "Північна Америка",
            "Northern Africa": "Північна Африка",
            "Northern Europe": "Північна Європа",
            "Polynesia": "Полінезія",
            "South America": "Південна Америка",
            "Southeast Asia": "Південно-Східна Азія",
            "Southern Africa": "Південна Африка",
            "Southern Asia": "Південна Азія",
            "Southern Europe": "Південна Європа",
            "Western Africa": "Західна Африка",
            "Western Asia": "Західна Азія",
            "Western Europe": "Західна Європа",
            "Latin America & Caribbean": "Латинська Америка та Кариби"
        ],
        "zh-Hant": [
            "Africa": "非洲",
            "Americas": "美洲",
            "Antarctic": "南極洲",
            "Asia": "亞洲",
            "Europe": "歐洲",
            "Oceania": "大洋洲",
            "Caribbean": "加勒比",
            "Central America": "中美洲",
            "Central Asia": "中亞",
            "Eastern Africa": "東非",
            "Eastern Asia": "東亞",
            "Eastern Europe": "東歐",
            "Melanesia": "美拉尼西亞",
            "Micronesia": "密克羅尼西亞",
            "Middle Africa": "中非",
            "North America": "北美洲",
            "Northern Africa": "北非",
            "Northern Europe": "北歐",
            "Polynesia": "玻里尼西亞",
            "South America": "南美洲",
            "Southeast Asia": "東南亞",
            "Southern Africa": "南部非洲",
            "Southern Asia": "南亞",
            "Southern Europe": "南歐",
            "Western Africa": "西非",
            "Western Asia": "西亞",
            "Western Europe": "西歐",
            "Latin America & Caribbean": "拉丁美洲與加勒比"
        ],
        "ms": [
            "Africa": "Afrika",
            "Americas": "Amerika",
            "Antarctic": "Antartika",
            "Asia": "Asia",
            "Europe": "Eropah",
            "Oceania": "Oceania",
            "Caribbean": "Caribbean",
            "Central America": "Amerika Tengah",
            "Central Asia": "Asia Tengah",
            "Eastern Africa": "Afrika Timur",
            "Eastern Asia": "Asia Timur",
            "Eastern Europe": "Eropah Timur",
            "Melanesia": "Melanesia",
            "Micronesia": "Micronesia",
            "Middle Africa": "Afrika Tengah",
            "North America": "Amerika Utara",
            "Northern Africa": "Afrika Utara",
            "Northern Europe": "Eropah Utara",
            "Polynesia": "Polinesia",
            "South America": "Amerika Selatan",
            "Southeast Asia": "Asia Tenggara",
            "Southern Africa": "Afrika Selatan",
            "Southern Asia": "Asia Selatan",
            "Southern Europe": "Eropah Selatan",
            "Western Africa": "Afrika Barat",
            "Western Asia": "Asia Barat",
            "Western Europe": "Eropah Barat",
            "Latin America & Caribbean": "Amerika Latin dan Caribbean"
        ],
        "ro": [
            "Africa": "Africa",
            "Americas": "Americi",
            "Antarctic": "Antarctica",
            "Asia": "Asia",
            "Europe": "Europa",
            "Oceania": "Oceania",
            "Caribbean": "Caraibe",
            "Central America": "America Centrala",
            "Central Asia": "Asia Centrala",
            "Eastern Africa": "Africa de Est",
            "Eastern Asia": "Asia de Est",
            "Eastern Europe": "Europa de Est",
            "Melanesia": "Melanezia",
            "Micronesia": "Micronezia",
            "Middle Africa": "Africa Centrala",
            "North America": "America de Nord",
            "Northern Africa": "Africa de Nord",
            "Northern Europe": "Europa de Nord",
            "Polynesia": "Polinezia",
            "South America": "America de Sud",
            "Southeast Asia": "Asia de Sud-Est",
            "Southern Africa": "Africa Australa",
            "Southern Asia": "Asia de Sud",
            "Southern Europe": "Europa de Sud",
            "Western Africa": "Africa de Vest",
            "Western Asia": "Asia de Vest",
            "Western Europe": "Europa de Vest",
            "Latin America & Caribbean": "America Latina si Caraibe"
        ],
        "th": [
            "Africa": "แอฟริกา",
            "Americas": "ทวีปอเมริกา",
            "Antarctic": "แอนตาร์กติกา",
            "Asia": "เอเชีย",
            "Europe": "ยุโรป",
            "Oceania": "โอเชียเนีย",
            "Caribbean": "แคริบเบียน",
            "Central America": "อเมริกากลาง",
            "Central Asia": "เอเชียกลาง",
            "Eastern Africa": "แอฟริกาตะวันออก",
            "Eastern Asia": "เอเชียตะวันออก",
            "Eastern Europe": "ยุโรปตะวันออก",
            "Melanesia": "เมลานีเซีย",
            "Micronesia": "ไมโครนีเซีย",
            "Middle Africa": "แอฟริกากลาง",
            "North America": "อเมริกาเหนือ",
            "Northern Africa": "แอฟริกาเหนือ",
            "Northern Europe": "ยุโรปเหนือ",
            "Polynesia": "โพลินีเซีย",
            "South America": "อเมริกาใต้",
            "Southeast Asia": "เอเชียตะวันออกเฉียงใต้",
            "Southern Africa": "แอฟริกาตอนใต้",
            "Southern Asia": "เอเชียใต้",
            "Southern Europe": "ยุโรปใต้",
            "Western Africa": "แอฟริกาตะวันตก",
            "Western Asia": "เอเชียตะวันตก",
            "Western Europe": "ยุโรปตะวันตก",
            "Latin America & Caribbean": "ลาตินอเมริกาและแคริบเบียน"
        ],
        "vi": [
            "Africa": "Chau Phi",
            "Americas": "Chau My",
            "Antarctic": "Nam Cuc",
            "Asia": "Chau A",
            "Europe": "Chau Au",
            "Oceania": "Chau Dai Duong",
            "Caribbean": "Caribe",
            "Central America": "Trung My",
            "Central Asia": "Trung A",
            "Eastern Africa": "Dong Phi",
            "Eastern Asia": "Dong A",
            "Eastern Europe": "Dong Au",
            "Melanesia": "Melanesia",
            "Micronesia": "Micronesia",
            "Middle Africa": "Trung Phi",
            "North America": "Bac My",
            "Northern Africa": "Bac Phi",
            "Northern Europe": "Bac Au",
            "Polynesia": "Polynesia",
            "South America": "Nam My",
            "Southeast Asia": "Dong Nam A",
            "Southern Africa": "Nam Phi",
            "Southern Asia": "Nam A",
            "Southern Europe": "Nam Au",
            "Western Africa": "Tay Phi",
            "Western Asia": "Tay A",
            "Western Europe": "Tay Au",
            "Latin America & Caribbean": "My Latinh va Caribe"
        ],
        "cs": [
            "Africa": "Afrika",
            "Americas": "Amerika",
            "Antarctic": "Antarktida",
            "Asia": "Asie",
            "Europe": "Evropa",
            "Oceania": "Oceanie",
            "Caribbean": "Karibik",
            "Central America": "Stredni Amerika",
            "Central Asia": "Stredni Asie",
            "Eastern Africa": "Vychodni Afrika",
            "Eastern Asia": "Vychodni Asie",
            "Eastern Europe": "Vychodni Evropa",
            "Melanesia": "Melanesie",
            "Micronesia": "Mikronesie",
            "Middle Africa": "Stredni Afrika",
            "North America": "Severni Amerika",
            "Northern Africa": "Severni Afrika",
            "Northern Europe": "Severni Evropa",
            "Polynesia": "Polynesie",
            "South America": "Jizni Amerika",
            "Southeast Asia": "Jihovychodni Asie",
            "Southern Africa": "Jizni Afrika",
            "Southern Asia": "Jizni Asie",
            "Southern Europe": "Jizni Evropa",
            "Western Africa": "Zapadni Afrika",
            "Western Asia": "Zapadni Asie",
            "Western Europe": "Zapadni Evropa",
            "Latin America & Caribbean": "Latinska Amerika a Karibik"
        ],
        "hu": [
            "Africa": "Afrika",
            "Americas": "Amerikak",
            "Antarctic": "Antarktisz",
            "Asia": "Azsia",
            "Europe": "Europa",
            "Oceania": "Oceania",
            "Caribbean": "Karib-terseg",
            "Central America": "Kozep-Amerika",
            "Central Asia": "Kozep-Azsia",
            "Eastern Africa": "Kelet-Afrika",
            "Eastern Asia": "Kelet-Azsia",
            "Eastern Europe": "Kelet-Europa",
            "Melanesia": "Melanezia",
            "Micronesia": "Mikronezia",
            "Middle Africa": "Kozep-Afrika",
            "North America": "Eszak-Amerika",
            "Northern Africa": "Eszak-Afrika",
            "Northern Europe": "Eszak-Europa",
            "Polynesia": "Polinezia",
            "South America": "Del-Amerika",
            "Southeast Asia": "Delkelet-Azsia",
            "Southern Africa": "Del-Afrika",
            "Southern Asia": "Del-Azsia",
            "Southern Europe": "Del-Europa",
            "Western Africa": "Nyugat-Afrika",
            "Western Asia": "Nyugat-Azsia",
            "Western Europe": "Nyugat-Europa",
            "Latin America & Caribbean": "Latin-Amerika es a Karib-terseg"
        ],
        "nb": [
            "Africa": "Afrika",
            "Americas": "Amerika",
            "Antarctic": "Antarktis",
            "Asia": "Asia",
            "Europe": "Europa",
            "Oceania": "Oseania",
            "Caribbean": "Karibia",
            "Central America": "Mellom-Amerika",
            "Central Asia": "Sentral-Asia",
            "Eastern Africa": "Ost-Afrika",
            "Eastern Asia": "Ost-Asia",
            "Eastern Europe": "Ost-Europa",
            "Melanesia": "Melanesia",
            "Micronesia": "Mikronesia",
            "Middle Africa": "Sentral-Afrika",
            "North America": "Nord-Amerika",
            "Northern Africa": "Nord-Afrika",
            "Northern Europe": "Nord-Europa",
            "Polynesia": "Polynesia",
            "South America": "Sor-Amerika",
            "Southeast Asia": "Sorost-Asia",
            "Southern Africa": "Sor-Afrika",
            "Southern Asia": "Sor-Asia",
            "Southern Europe": "Sor-Europa",
            "Western Africa": "Vest-Afrika",
            "Western Asia": "Vest-Asia",
            "Western Europe": "Vest-Europa",
            "Latin America & Caribbean": "Latin-Amerika og Karibia"
        ],
        "ca": [
            "Africa": "Africa",
            "Americas": "Ameriques",
            "Antarctic": "Antartida",
            "Asia": "Asia",
            "Europe": "Europa",
            "Oceania": "Oceania",
            "Caribbean": "Carib",
            "Central America": "America Central",
            "Central Asia": "Asia Central",
            "Eastern Africa": "Africa Oriental",
            "Eastern Asia": "Asia Oriental",
            "Eastern Europe": "Europa Oriental",
            "Melanesia": "Melanesia",
            "Micronesia": "Micronesia",
            "Middle Africa": "Africa Central",
            "North America": "America del Nord",
            "Northern Africa": "Africa del Nord",
            "Northern Europe": "Europa del Nord",
            "Polynesia": "Polinesia",
            "South America": "America del Sud",
            "Southeast Asia": "Sud-est Asiatic",
            "Southern Africa": "Africa Austral",
            "Southern Asia": "Asia del Sud",
            "Southern Europe": "Europa del Sud",
            "Western Africa": "Africa Occidental",
            "Western Asia": "Asia Occidental",
            "Western Europe": "Europa Occidental",
            "Latin America & Caribbean": "America Llatina i Carib"
        ],
        "hr": [
            "Africa": "Afrika",
            "Americas": "Amerike",
            "Antarctic": "Antarktika",
            "Asia": "Azija",
            "Europe": "Europa",
            "Oceania": "Oceanija",
            "Caribbean": "Karibi",
            "Central America": "Sredisnja Amerika",
            "Central Asia": "Sredisnja Azija",
            "Eastern Africa": "Istocna Afrika",
            "Eastern Asia": "Istocna Azija",
            "Eastern Europe": "Istocna Europa",
            "Melanesia": "Melanezija",
            "Micronesia": "Mikronezija",
            "Middle Africa": "Sredisnja Afrika",
            "North America": "Sjeverna Amerika",
            "Northern Africa": "Sjeverna Afrika",
            "Northern Europe": "Sjeverna Europa",
            "Polynesia": "Polinezija",
            "South America": "Juzna Amerika",
            "Southeast Asia": "Jugoistocna Azija",
            "Southern Africa": "Juzna Afrika",
            "Southern Asia": "Juzna Azija",
            "Southern Europe": "Juzna Europa",
            "Western Africa": "Zapadna Afrika",
            "Western Asia": "Zapadna Azija",
            "Western Europe": "Zapadna Europa",
            "Latin America & Caribbean": "Latinska Amerika i Karibi"
        ],
        "sk": [
            "Africa": "Afrika",
            "Americas": "Ameriky",
            "Antarctic": "Antarktida",
            "Asia": "Azia",
            "Europe": "Europa",
            "Oceania": "Oceania",
            "Caribbean": "Karibik",
            "Central America": "Stredna Amerika",
            "Central Asia": "Stredna Azia",
            "Eastern Africa": "Vychodna Afrika",
            "Eastern Asia": "Vychodna Azia",
            "Eastern Europe": "Vychodna Europa",
            "Melanesia": "Melanezia",
            "Micronesia": "Mikronezia",
            "Middle Africa": "Stredna Afrika",
            "North America": "Severna Amerika",
            "Northern Africa": "Severna Afrika",
            "Northern Europe": "Severna Europa",
            "Polynesia": "Polynesia",
            "South America": "Juzna Amerika",
            "Southeast Asia": "Juhovychodna Azia",
            "Southern Africa": "Juzna Afrika",
            "Southern Asia": "Juzna Azia",
            "Southern Europe": "Juzna Europa",
            "Western Africa": "Zapadna Afrika",
            "Western Asia": "Zapadna Azia",
            "Western Europe": "Zapadna Europa",
            "Latin America & Caribbean": "Latinska Amerika a Karibik"
        ]
    ]
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

        if let languageCompatibility = languageCompatibilityScore {
            components.append((Double(languageCompatibility), weights.language))
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
        visaSourceUrl: URL?,
        visaPassportCode: String?,
        visaPassportLabel: String?,
        visaRecommendedPassportLabel: String?
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
            visaPassportCode: visaPassportCode ?? self.visaPassportCode,
            visaPassportLabel: visaPassportLabel ?? self.visaPassportLabel,
            visaRecommendedPassportLabel: visaRecommendedPassportLabel ?? self.visaRecommendedPassportLabel,
            dailySpendTotalUsd: dailySpendTotalUsd,
            dailySpendHotelUsd: dailySpendHotelUsd,
            dailySpendFoodUsd: dailySpendFoodUsd,
            dailySpendActivitiesUsd: dailySpendActivitiesUsd,
            affordabilityCategory: affordabilityCategory,
            affordabilityScore: affordabilityScore,
            affordabilityBand: affordabilityBand,
            affordabilityExplanation: affordabilityExplanation,
            languageCompatibilityScore: languageCompatibilityScore
        )
    }
}

enum CountrySort: String, CaseIterable {
    case name = "Name"
    case score = "Score"

    var localizedTitle: String {
        switch self {
        case .name:
            return String(localized: "discovery.sort.name")
        case .score:
            return String(localized: "discovery.sort.score")
        }
    }
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
            of: "[^\\p{L}\\p{N}]",
            with: "",
            options: .regularExpression
        )
    }
}
