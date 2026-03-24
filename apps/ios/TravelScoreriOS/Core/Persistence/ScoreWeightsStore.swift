//
//  ScoreWeightsStore.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/22/26.
//

import Foundation
import Combine

final class ScoreWeightsStore: ObservableObject {

    private struct StoredPreferences: Codable {
        let weights: ScoreWeights
        let selectedMonth: Int
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

    private let key = "score_preferences"
    private let legacyWeightsKey = "score_weights"
    
    init() {
        let currentMonth = Self.clampMonth(Calendar.current.component(.month, from: Date()))

        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StoredPreferences.self, from: data) {
            self.weights = decoded.weights
            self.selectedMonth = Self.clampMonth(decoded.selectedMonth)
        } else if let data = UserDefaults.standard.data(forKey: legacyWeightsKey),
                  let decoded = try? JSONDecoder().decode(ScoreWeights.self, from: data) {
            self.weights = decoded
            self.selectedMonth = currentMonth
        } else {
            self.weights = .default
            self.selectedMonth = currentMonth
        }
    }
    
    func resetToDefault() {
        weights = .default
    }

    func applyPreset(_ preset: WeightPreset) {
        weights = preset.weights
    }

    func updatePreferences(weights: ScoreWeights, selectedMonth: Int) {
        self.weights = weights
        self.selectedMonth = Self.clampMonth(selectedMonth)
    }
    
    private func save() {
        let payload = StoredPreferences(
            weights: weights,
            selectedMonth: Self.clampMonth(selectedMonth)
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
