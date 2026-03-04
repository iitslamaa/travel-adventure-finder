//
//  ScoreWeightsStore.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/22/26.
//

import Foundation
import Combine

final class ScoreWeightsStore: ObservableObject {
    
    @Published var weights: ScoreWeights {
        didSet {
            save()
        }
    }
    
    private let key = "score_weights"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ScoreWeights.self, from: data) {
            self.weights = decoded
            // Ensure legacy seasonality weight does not affect calculations
            self.weights.seasonality = 0
        } else {
            self.weights = .default
            // Ensure seasonality starts at zero going forward
            self.weights.seasonality = 0
        }
    }
    
    func resetToDefault() {
        weights = .default
    }

    func applyPreset(_ preset: WeightPreset) {
        var newWeights = preset.weights

        // Seasonality remains disabled globally for now
        newWeights.seasonality = 0

        weights = newWeights
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(weights) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

extension ScoreWeightsStore {

    var totalWeight: Double {
        weights.advisory +
        weights.visa +
        weights.affordability
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
}
