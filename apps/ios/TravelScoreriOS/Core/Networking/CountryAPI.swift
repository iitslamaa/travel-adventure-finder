//
//  CountryAPI.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/11/25.
//

import Foundation
import Supabase

private enum CountryAPIDebugLog {
    static func message(_ text: String) {
#if DEBUG
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        print("🌐 [CountryAPI] \(timestamp) \(text)")
#endif
    }
}

enum CountryAPI {
    static let baseURL = APIConfig.baseURL
    static var countriesURL: URL { baseURL.appendingPathComponent("api/countries") }
    private static let cacheLock = NSLock()
    private static var memoryCachedCountries: [Country]?
    private static var inFlightRefreshTask: Task<[Country]?, Never>?
    private static let requestTimeout: TimeInterval = 4
    private static let resourceTimeout: TimeInterval = 6
    private static let networkSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private struct CountriesResponsePayload {
        let data: Data
        let etag: String?
    }

    static func fetchCountries() async throws -> [Country] {
        let startedAt = Date()
        do {
            let countries = try await fetchAndCacheCountries()
            CountryAPIDebugLog.message(
                "fetchCountries source=remote count=\(countries.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
            )
            return countries
        } catch {
            if isTransientNetworkError(error), let cached = loadCachedCountries(), !cached.isEmpty {
                CountryAPIDebugLog.message(
                    "fetchCountries source=cache-fallback count=\(cached.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms error=\(error.localizedDescription)"
                )
                return cached
            }
            CountryAPIDebugLog.message(
                "fetchCountries failed duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms error=\(error.localizedDescription)"
            )
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
        let startedAt = Date()
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: CountriesCache.lastRefreshKey)

        if last > 0, (now - last) < minInterval {
            CountryAPIDebugLog.message(
                "refreshCountriesIfNeeded skipped reason=cooldown age=\(Int(now - last))s minInterval=\(Int(minInterval))s duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
            )
            return nil
        }

        if let inFlightTask = withCacheLock({ inFlightRefreshTask }) {
            CountryAPIDebugLog.message("refreshCountriesIfNeeded joined in-flight request")
            return await inFlightTask.value
        }

        let refreshTask = Task<[Country]?, Never> {
            defer {
                withCacheLock {
                    inFlightRefreshTask = nil
                }
            }

            do {
                let countries = try await fetchAndCacheCountries(refreshedAt: now)
                CountryAPIDebugLog.message(
                    "refreshCountriesIfNeeded applied source=remote count=\(countries.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
                )
                return countries
            } catch {
                if isTransientNetworkError(error),
                   let cached = loadCachedCountries(),
                   !cached.isEmpty {
                    CountryAPIDebugLog.message(
                        "refreshCountriesIfNeeded source=cache-fallback count=\(cached.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms error=\(error.localizedDescription)"
                    )
                    return cached
                }
                CountryAPIDebugLog.message(
                    "refreshCountriesIfNeeded failed duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms error=\(error.localizedDescription)"
                )
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
        let response = try await fetchCountriesData()
        let data = response.data
        let countries = try decodeCountries(from: data)
        CountriesCache.saveData(data)
        CountriesCache.saveETag(response.etag)
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
                currencyCode: dto.currencyCode,
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

    private static func fetchCountriesData() async throws -> CountriesResponsePayload {
        let startedAt = Date()
        var request = URLRequest(url: countriesURL)
        request.httpMethod = "GET"
        request.timeoutInterval = requestTimeout
        if let etag = CountriesCache.loadETag(), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        if let session = try? await SupabaseManager.shared.fetchCurrentSession() {
            let accessToken = session.accessToken
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await networkSession.data(for: request)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 304 {
            guard let cached = CountriesCache.loadData() else {
                throw URLError(.badServerResponse)
            }
            let etag = http.value(forHTTPHeaderField: "ETag") ?? CountriesCache.loadETag()
            CountryAPIDebugLog.message(
                "fetchCountriesData status=304 bytes=\(cached.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
            )
            return CountriesResponsePayload(data: cached, etag: etag)
        }

        if !(200..<300).contains(http.statusCode) {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                _ = body
            }
            #endif
            throw URLError(.badServerResponse)
        }
        let etag = http.value(forHTTPHeaderField: "ETag")
        CountryAPIDebugLog.message(
            "fetchCountriesData status=\(http.statusCode) bytes=\(data.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
        )
        return CountriesResponsePayload(data: data, etag: etag)
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
        private static let etagKey = "countries_cache_etag_v1"
        private static let fileName = "countries_cache_v3.json"
        private static let legacyFileNames = ["countries_cache_v4.json"]

        private static var cacheURL: URL {
            cacheURL(for: fileName)
        }

        private static func cacheURL(for fileName: String) -> URL {
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
            if let data = try? Data(contentsOf: cacheURL) {
                return data
            }

            for legacyFileName in legacyFileNames {
                let legacyURL = cacheURL(for: legacyFileName)
                if let data = try? Data(contentsOf: legacyURL) {
                    saveData(data)
                    return data
                }
            }

            return nil
        }

        static func saveETag(_ etag: String?) {
            UserDefaults.standard.set(etag, forKey: etagKey)
        }

        static func loadETag() -> String? {
            UserDefaults.standard.string(forKey: etagKey)
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
