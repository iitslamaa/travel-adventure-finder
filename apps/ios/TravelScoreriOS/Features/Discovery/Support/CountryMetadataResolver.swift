//
//  CountryMetadataResolver.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation

final class CountryMetadataResolver {

    private struct CountryMeta {
        let name: String
        let score: Double?
        let region: String?

        let advisory: Double?
        let affordability: Double?
        let visaEase: Double?
        let seasonality: Double?
    }

    private var countryMetaByISO: [String: CountryMeta] = [:]

    // MARK: - Public API

    func loadIfNeeded() async {
        if !countryMetaByISO.isEmpty { return }

        do {
            let countries: [Country]
            if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
                countries = cached
            } else if let refreshed = await CountryAPI.refreshCountriesIfNeeded(minInterval: 60), !refreshed.isEmpty {
                countries = refreshed
            } else {
                countries = try await CountryAPI.fetchCountries()
            }

            var map: [String: CountryMeta] = [:]

            for c in countries {
                let iso = c.iso2.uppercased()

                let advisoryScore: Double? = {
                    if let v = c.advisoryScore {
                        return Double(v)
                    }
                    return nil
                }()

                let dailyTotal = c.dailySpendTotalUsd
                let affordabilityScore = affordabilityFromDailySpend(totalUsd: dailyTotal)

                let visaEase = c.visaEaseScore.map(Double.init)
                let seasonality = c.seasonalityScore.map(Double.init)
                let scoreDouble = c.score.map(Double.init)

                map[iso] = CountryMeta(
                    name: c.name,
                    score: scoreDouble,
                    region: c.region,
                    advisory: advisoryScore,
                    affordability: affordabilityScore,
                    visaEase: visaEase,
                    seasonality: seasonality
                )
            }

            countryMetaByISO = map

        } catch {
        }
    }

    func enrich(_ list: [SeasonalityCountry]) -> [SeasonalityCountry] {
        guard !countryMetaByISO.isEmpty else { return list }

        return list.map { c in
            let iso = c.isoCode.uppercased()
            if let meta = countryMetaByISO[iso] {
                return SeasonalityCountry(
                    isoCode: c.isoCode,
                    name: meta.name,
                    score: meta.score ?? c.score,
                    region: meta.region ?? c.region,
                    scores: makeSnapshot(
                        advisory: meta.advisory ?? c.scores?.advisory,
                        seasonality: meta.seasonality ?? c.scores?.seasonality,
                        affordability: meta.affordability ?? c.scores?.affordability,
                        visaEase: meta.visaEase ?? c.scores?.visaEase
                    )
                )
            }
            return c
        }
    }

    // MARK: - Helpers


    private func affordabilityFromDailySpend(totalUsd: Double?) -> Double? {
        guard let totalUsd else { return nil }
        let minUsd: Double = 35
        let maxUsd: Double = 250
        let clamped = min(max(totalUsd, minUsd), maxUsd)
        let t = (clamped - minUsd) / (maxUsd - minUsd)
        return (1.0 - t) * 100.0
    }

    private func makeSnapshot(
        advisory: Double?,
        seasonality: Double?,
        affordability: Double?,
        visaEase: Double?
    ) -> SeasonalityCountry.ScoreSnapshot? {
        if advisory == nil && seasonality == nil && affordability == nil && visaEase == nil { return nil }

        return SeasonalityCountry.ScoreSnapshot(
            advisory: advisory,
            seasonality: seasonality,
            affordability: affordability,
            visaEase: visaEase
        )
    }
}
