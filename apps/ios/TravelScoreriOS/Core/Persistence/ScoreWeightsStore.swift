//
//  ScoreWeightsStore.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/22/26.
//

import Foundation
import Combine
import Supabase

final class ScoreWeightsStore: ObservableObject {

    private struct StoredPreferences: Codable {
        let weights: ScoreWeights
        let selectedMonth: Int
        let excludeVisitedCountries: Bool
    }

    private struct RemotePreferencesRow: Decodable {
        let advisory: Double?
        let seasonality: Double?
        let visa: Double?
        let affordability: Double?
        let language: Double?
        let selected_month: Int?
        let exclude_visited_countries: Bool?

        var hasMissingPersistedValue: Bool {
            advisory == nil ||
            seasonality == nil ||
            visa == nil ||
            affordability == nil ||
            language == nil ||
            selected_month == nil ||
            exclude_visited_countries == nil
        }
    }

    private struct RemotePreferencesUpsert: Encodable {
        let user_id: UUID
        let advisory: Double
        let seasonality: Double
        let visa: Double
        let affordability: Double
        let language: Double
        let selected_month: Int
        let exclude_visited_countries: Bool
        let updated_at: String
    }

    @Published var weights: ScoreWeights {
        didSet {
            save()
        }
    }

    @Published var selectedMonth: Int {
        didSet {
            let clamped = Self.clampMonth(selectedMonth)
            if clamped != selectedMonth {
                selectedMonth = clamped
                return
            }
            save()
        }
    }

    @Published var excludeVisitedCountries: Bool {
        didSet {
            save()
        }
    }

    private let key = "score_preferences"
    private let legacyWeightsKey = "score_weights"
    
    init() {
        let currentMonth = Self.clampMonth(Calendar.current.component(.month, from: Date()))

        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StoredPreferences.self, from: data) {
            self.weights = decoded.weights
            self.selectedMonth = Self.clampMonth(decoded.selectedMonth)
            self.excludeVisitedCountries = decoded.excludeVisitedCountries
        } else if let data = UserDefaults.standard.data(forKey: legacyWeightsKey),
                  let decoded = try? JSONDecoder().decode(ScoreWeights.self, from: data) {
            self.weights = decoded
            self.selectedMonth = currentMonth
            self.excludeVisitedCountries = false
        } else {
            self.weights = .default
            self.selectedMonth = currentMonth
            self.excludeVisitedCountries = false
        }
    }
    
    func resetToDefault() {
        weights = .default
        excludeVisitedCountries = false
    }

    func applyPreset(_ preset: WeightPreset) {
        weights = preset.weights
    }

    func updatePreferences(weights: ScoreWeights, selectedMonth: Int, excludeVisitedCountries: Bool) {
        self.weights = weights
        self.selectedMonth = Self.clampMonth(selectedMonth)
        self.excludeVisitedCountries = excludeVisitedCountries
    }

    func hydrateFromSupabase(userId: UUID, supabase: SupabaseManager) async {
        do {
            let response: PostgrestResponse<[RemotePreferencesRow]> = try await supabase.client
                .from("user_score_preferences")
                .select("advisory, seasonality, visa, affordability, language, selected_month, exclude_visited_countries")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()

            guard let row = response.value.first else {
                try await savePreferencesToSupabase(userId: userId, supabase: supabase)
                return
            }

            let mergedWeights = ScoreWeights(
                affordability: row.affordability ?? weights.affordability,
                visa: row.visa ?? weights.visa,
                advisory: row.advisory ?? weights.advisory,
                seasonality: row.seasonality ?? weights.seasonality,
                language: row.language ?? weights.language
            )
            let mergedSelectedMonth = Self.clampMonth(row.selected_month ?? selectedMonth)
            let mergedExcludeVisitedCountries = row.exclude_visited_countries ?? excludeVisitedCountries

            updatePreferences(
                weights: mergedWeights,
                selectedMonth: mergedSelectedMonth,
                excludeVisitedCountries: mergedExcludeVisitedCountries
            )

            if row.hasMissingPersistedValue {
                try await savePreferencesToSupabase(userId: userId, supabase: supabase)
            }
        } catch {
            SocialFeedDebug.log("score_preferences.remote.hydrate.error user=\(userId.uuidString) error=\(SocialFeedDebug.describe(error))")
        }
    }

    func savePreferencesToSupabase(userId: UUID, supabase: SupabaseManager) async throws {
        let payload = RemotePreferencesUpsert(
            user_id: userId,
            advisory: weights.advisory,
            seasonality: weights.seasonality,
            visa: weights.visa,
            affordability: weights.affordability,
            language: weights.language,
            selected_month: Self.clampMonth(selectedMonth),
            exclude_visited_countries: excludeVisitedCountries,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase.client
            .from("user_score_preferences")
            .upsert(payload)
            .execute()
    }
    
    private func save() {
        let payload = StoredPreferences(
            weights: weights,
            selectedMonth: Self.clampMonth(selectedMonth),
            excludeVisitedCountries: excludeVisitedCountries
        )

        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.removeObject(forKey: legacyWeightsKey)
        }
    }

    private static func clampMonth(_ month: Int) -> Int {
        min(max(month, 1), 12)
    }
}

extension ScoreWeightsStore {

    var totalWeight: Double {
        weights.advisory +
        weights.visa +
        weights.affordability +
        weights.seasonality +
        weights.language
    }

    func percentage(for keyPath: KeyPath<ScoreWeights, Double>) -> Int {
        let total = totalWeight
        guard total > 0 else { return 0 }
        let value = weights[keyPath: keyPath]
        return Int(((value / total) * 100).rounded())
    }

    var advisoryPercentage: Int {
        percentage(for: \.advisory)
    }

    var visaPercentage: Int {
        percentage(for: \.visa)
    }

    var affordabilityPercentage: Int {
        percentage(for: \.affordability)
    }

    var seasonalityPercentage: Int {
        percentage(for: \.seasonality)
    }

    var languagePercentage: Int {
        percentage(for: \.language)
    }

    var selectedMonthShortName: String {
        let names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        let month = Self.clampMonth(selectedMonth)
        return names[month - 1]
    }
}
