//
//  DataLoader.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/11/25.
//

import Foundation

enum DataLoader {

    // MARK: - Backend-controlled refresh


    private static let metaCacheKey = "cached_meta_v1"

    static func loadInitialDataIfNeeded() async {
        do {
            let remoteMeta = try await fetchRemoteMeta()
            let localMeta = loadCachedMeta()

            if localMeta != remoteMeta {
                
                await refreshRemoteData()
                saveCachedMeta(remoteMeta)
            } else {
                
            }
        } catch {
            print("❌ Meta check failed:", error)
        }
    }

    private static func fetchRemoteMeta() async throws -> MetaDTO {
        let url = APIConfig.baseURL.appendingPathComponent("/api/meta")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(MetaDTO.self, from: data)
    }

    private static func loadCachedMeta() -> MetaDTO? {
        guard let data = UserDefaults.standard.data(forKey: metaCacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode(MetaDTO.self, from: data)
    }

    private static func saveCachedMeta(_ meta: MetaDTO) {
        if let data = try? JSONEncoder().encode(meta) {
            UserDefaults.standard.set(data, forKey: metaCacheKey)
        }
    }

    private static func refreshRemoteData() async {
        // Countries are globally cached and safe to refresh here
        _ = await CountryAPI.refreshCountriesIfNeeded(minInterval: 0)

        // Seasonality is view-driven and refreshes via SeasonalityViewModel
        // (on appear / month change), so we do not trigger it here.
    }
}
