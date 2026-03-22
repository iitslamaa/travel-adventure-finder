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
        return Locale.autoupdatingCurrent.localizedString(forRegionCode: upper) ?? name
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

    private var localizedAffordabilityContent: (headline: String?, body: String?) {
        if Self.currentLanguageCode == "en" {
            if let englishHeadline = splitHeadline(from: affordabilityExplanation) {
                return (englishHeadline, splitBody(from: affordabilityExplanation))
            }
        }

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
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("pt") { return "pt" }
        if preferred.hasPrefix("fr") { return "fr" }
        if preferred.hasPrefix("es") { return "es" }
        if preferred.hasPrefix("de") { return "de" }
        if preferred.hasPrefix("it") { return "it" }
        return "en"
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
            of: "[^a-z0-9]",
            with: "",
            options: .regularExpression
        )
    }
}
