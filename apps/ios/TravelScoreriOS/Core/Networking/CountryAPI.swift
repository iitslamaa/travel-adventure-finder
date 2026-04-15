//
//  CountryAPI.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/11/25.
//

import Foundation
import Supabase

enum CountryAPI {
    static let baseURL = APIConfig.baseURL
    static var countriesURL: URL { baseURL.appendingPathComponent("api/countries") }
    private static let cacheLock = NSLock()
    private static var memoryCachedCountries: [Country]?
    private static var inFlightRefreshTask: Task<[Country]?, Never>?
    private static let networkSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    static func fetchCountries() async throws -> [Country] {
        do {
            return try await fetchAndCacheCountries()
        } catch {
            if isTransientNetworkError(error), let cached = loadCachedCountries(), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }
}

// MARK: - Local-first cache + refresh-on-open (with cooldown)

extension CountryAPI {

    /// Load cached countries from disk (if present).
    /// Returns nil if no cache exists or decoding fails.
    static func loadCachedCountries() -> [Country]? {
        if let cached = withCacheLock({ memoryCachedCountries }) {
            return cached
        }

        guard let data = CountriesCache.loadData() else { return nil }
        do {
            let countries = try decodeCountries(from: data)
            updateMemoryCache(with: countries)
            return countries
        } catch {
            return nil
        }
    }

    /// Refreshes countries from the API unless we refreshed recently.
    /// - Parameter minInterval: Minimum seconds between refreshes (default: 60)
    /// - Returns: Fresh countries if refreshed, or nil if skipped/failed.
    static func refreshCountriesIfNeeded(minInterval: TimeInterval = 60) async -> [Country]? {
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: CountriesCache.lastRefreshKey)

        if last > 0, (now - last) < minInterval {
            return nil
        }

        if let inFlightTask = withCacheLock({ inFlightRefreshTask }) {
            return await inFlightTask.value
        }

        let refreshTask = Task<[Country]?, Never> {
            defer {
                withCacheLock {
                    inFlightRefreshTask = nil
                }
            }

            do {
                return try await fetchAndCacheCountries(refreshedAt: now)
            } catch {
                if isTransientNetworkError(error),
                   let cached = loadCachedCountries(),
                   !cached.isEmpty {
                    return cached
                }
                return nil
            }
        }

        withCacheLock {
            inFlightRefreshTask = refreshTask
        }

        return await refreshTask.value
    }

    // MARK: - Private helpers

    private static func withCacheLock<T>(_ work: () -> T) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return work()
    }

    private static func updateMemoryCache(with countries: [Country]) {
        withCacheLock {
            memoryCachedCountries = countries
        }
    }

    private static func fetchAndCacheCountries(refreshedAt: TimeInterval = Date().timeIntervalSince1970) async throws -> [Country] {
        let data = try await fetchCountriesData()
        let countries = try decodeCountries(from: data)
        CountriesCache.saveData(data)
        UserDefaults.standard.set(refreshedAt, forKey: CountriesCache.lastRefreshKey)
        updateMemoryCache(with: countries)
        return countries
    }

    private static func decodeCountries(from data: Data) throws -> [Country] {
        let decoder = JSONDecoder()

        struct CountriesEnvelope: Decodable {
            let countries: [CountryDTO]
        }

        let dtos: [CountryDTO]
        do {
            dtos = try decoder.decode([CountryDTO].self, from: data)
        } catch {
            do {
                let env = try decoder.decode(CountriesEnvelope.self, from: data)
                dtos = env.countries
            } catch {
                #if DEBUG
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                _ = body
                #endif
                throw error
            }
        }

        let countries = dtos.map { dto in
            Country(
                iso2: dto.iso2,
                name: dto.name,
                score: dto.score,
                region: dto.region,
                subregion: dto.subregion,
                advisoryScore: dto.advisoryScore,
                advisorySummary: nil,
                advisoryUpdatedAt: dto.advisoryUpdatedAt,
                advisoryUrl: dto.advisoryUrl,
                seasonalityScore: dto.seasonalityScore,
                seasonalityLabel: dto.seasonalityLabel,
                seasonalityBestMonths: dto.seasonalityBestMonths,
                seasonalityShoulderMonths: dto.seasonalityShoulderMonths,
                seasonalityGoodMonths: dto.seasonalityGoodMonths,
                seasonalityAvoidMonths: dto.seasonalityAvoidMonths,
                seasonalityNotes: dto.seasonalityNotes,
                visaEaseScore: dto.visaEaseScore,
                visaType: dto.visaType,
                visaAllowedDays: dto.visaAllowedDays,
                visaFeeUsd: dto.visaFeeUsd,
                visaNotes: nil,
                visaSourceUrl: dto.visaSourceUrl,
                dailySpendTotalUsd: dto.dailySpendTotalUsd,
                dailySpendHotelUsd: dto.dailySpendHotelUsd,
                dailySpendHostelUsd: dto.dailySpendHostelUsd,
                dailySpendFoodUsd: dto.dailySpendFoodUsd,
                dailySpendActivitiesUsd: dto.dailySpendActivitiesUsd,
                affordabilityCategory: dto.affordabilityCategory,
                affordabilityScore: dto.affordabilityScore,
                affordabilityBand: dto.affordabilityBand,
                affordabilityExplanation: nil,
                languageCompatibilityScore: dto.languageCompatibilityScore
            )
        }
        .validatedOverviewCoverage()

        assertOverviewDescriptionCoverage(for: countries)
        return countries
    }

    private static func fetchCountriesData() async throws -> Data {
        var request = URLRequest(url: countriesURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 12

        if let session = try? await SupabaseManager.shared.fetchCurrentSession() {
            let accessToken = session.accessToken
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await networkSession.data(for: request)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if !(200..<300).contains(http.statusCode) {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                _ = body
            }
            #endif
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func isTransientNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .networkConnectionLost,
             .notConnectedToInternet,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    private enum CountriesCache {
        static let lastRefreshKey = "countries_last_refresh_ts_v2"
        private static let fileName = "countries_cache_v3.json"

        private static var cacheURL: URL {
            let fm = FileManager.default
            let dir = (try? fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? fm.temporaryDirectory
            return dir.appendingPathComponent(fileName)
        }

        static func saveData(_ data: Data) {
            do {
                try data.write(to: cacheURL, options: [.atomic])
            } catch {
            }
        }

        static func loadData() -> Data? {
            try? Data(contentsOf: cacheURL)
        }
    }

    private static func assertOverviewDescriptionCoverage(for countries: [Country]) {
        #if DEBUG
        let missing = CountryOverviewDescriptionStore.missingDescriptionCodes(in: countries)
        assert(missing.isEmpty, "Missing country overview descriptions for codes: \(missing.joined(separator: ", "))")
        #endif
    }
}

private extension Array where Element == Country {
    func validatedOverviewCoverage() -> [Country] {
        #if DEBUG
        let missing = CountryOverviewDescriptionStore.missingDescriptionCodes(in: self)
        assert(missing.isEmpty, "Missing country overview descriptions for codes: \(missing.joined(separator: ", "))")
        #endif
        return self
    }
}
