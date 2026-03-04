//
//  SeasonalityCache.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation

enum SeasonalityCache {
    private static let filePrefix = "seasonality_month_"
    private static let fileSuffix = "_v1.json"
    private static let refreshKeyPrefix = "seasonality_last_refresh_month_"
    private static let refreshKeySuffix = "_v1"

    struct Payload: Codable {
        let month: Int
        let peak: [CountryItem]
        let shoulder: [CountryItem]
        let savedAt: TimeInterval

        var peakCountries: [SeasonalityCountry] { peak.map { $0.toModel() } }
        var shoulderCountries: [SeasonalityCountry] { shoulder.map { $0.toModel() } }
    }

    struct CountryItem: Codable {
        let isoCode: String
        let name: String?
        let score: Double?
        let region: String?
        let scores: ScoreItem?

        struct ScoreItem: Codable {
            let advisory: Double?
            let seasonality: Double?
            let affordability: Double?
            let visaEase: Double?
        }

        init(from model: SeasonalityCountry) {
            self.isoCode = model.isoCode
            self.name = model.name
            self.score = model.score
            self.region = model.region
            if let s = model.scores {
                self.scores = ScoreItem(
                    advisory: s.advisory,
                    seasonality: s.seasonality,
                    affordability: s.affordability,
                    visaEase: s.visaEase
                )
            } else {
                self.scores = nil
            }
        }

        func toModel() -> SeasonalityCountry {
            let snapshot: SeasonalityCountry.ScoreSnapshot? = {
                guard let s = scores else { return nil }
                return SeasonalityCountry.ScoreSnapshot(
                    advisory: s.advisory,
                    seasonality: s.seasonality,
                    affordability: s.affordability,
                    visaEase: s.visaEase
                )
            }()

            return SeasonalityCountry(
                isoCode: isoCode,
                name: name,
                score: score,
                region: region,
                scores: snapshot
            )
        }
    }

    static func save(month: Int, peak: [SeasonalityCountry], shoulder: [SeasonalityCountry]) {
        let payload = Payload(
            month: month,
            peak: peak.map { CountryItem(from: $0) },
            shoulder: shoulder.map { CountryItem(from: $0) },
            savedAt: Date().timeIntervalSince1970
        )
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(payload)
            try data.write(to: fileURL(for: month), options: [.atomic])
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: refreshKey(for: month))
        } catch {
        }
    }

    static func load(month: Int) -> (month: Int, peak: [SeasonalityCountry], shoulder: [SeasonalityCountry])? {
        do {
            let data = try Data(contentsOf: fileURL(for: month))
            let decoder = JSONDecoder()
            let payload = try decoder.decode(Payload.self, from: data)
            return (payload.month, payload.peakCountries, payload.shoulderCountries)
        } catch {
            return nil
        }
    }

    static func shouldRefresh(month: Int, minInterval: TimeInterval) -> Bool {
        let last = UserDefaults.standard.double(forKey: refreshKey(for: month))
        guard last > 0 else { return true }
        return (Date().timeIntervalSince1970 - last) >= minInterval
    }

    private static func refreshKey(for month: Int) -> String {
        "\(refreshKeyPrefix)\(month)\(refreshKeySuffix)"
    }

    private static func fileURL(for month: Int) -> URL {
        let fm = FileManager.default
        let dir = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        return dir.appendingPathComponent("\(filePrefix)\(month)\(fileSuffix)")
    }
}
