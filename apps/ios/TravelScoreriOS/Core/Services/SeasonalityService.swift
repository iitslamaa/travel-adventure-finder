//
//  SeasonalityService.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 12/2/25.
//

import Foundation

enum SeasonalityServiceError: Error {
    case invalidURL
    case badResponse
}

final class SeasonalityService {
    private let baseURL = APIConfig.baseURL

    func fetchSeasonality(forMonth month: Int) async throws -> SeasonalityResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/seasonality"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "month", value: String(month))
        ]

        guard let url = components?.url else {
            throw SeasonalityServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            #if DEBUG
            if let http = response as? HTTPURLResponse {
                print("[SeasonalityService] ❌ Status: \(http.statusCode)")
            } else {
                print("[SeasonalityService] ❌ Non-HTTP response")
            }
            #endif
            throw SeasonalityServiceError.badResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Handle both possible backend shapes defensively
        // 1) { month, peakCountries, shoulderCountries }
        // 2) direct SeasonalityResponse
        do {
            return try decoder.decode(SeasonalityResponse.self, from: data)
        } catch {
            #if DEBUG
            print("[SeasonalityService] ❌ Decode failed:", error)
            #endif
            throw error
        }
    }
}
