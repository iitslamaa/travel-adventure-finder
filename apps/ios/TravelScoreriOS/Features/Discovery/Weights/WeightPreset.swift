//
//  WeightPreset.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/3/26.
//

import Foundation

struct WeightPreset: Identifiable {
    let id = UUID()
    let nameKey: String
    let descriptionKey: String
    let weights: ScoreWeights

    var name: String { NSLocalizedString(nameKey, comment: "") }
    var description: String { NSLocalizedString(descriptionKey, comment: "") }
}

extension WeightPreset {

    static let balanced = WeightPreset(
        nameKey: "discovery.weights.preset.balanced",
        descriptionKey: "discovery.weights.preset.balanced_description",
        weights: ScoreWeights(
            affordability: 0.2,
            visa: 0.2,
            advisory: 0.2,
            seasonality: 0.2,
            language: 0.2
        )
    )

    static let budget = WeightPreset(
        nameKey: "discovery.weights.preset.budget",
        descriptionKey: "discovery.weights.preset.budget_description",
        weights: ScoreWeights(
            affordability: 0.45,
            visa: 0.1,
            advisory: 0.15,
            seasonality: 0.1,
            language: 0.2
        )
    )

    static let easyTravel = WeightPreset(
        nameKey: "discovery.weights.preset.easy_travel",
        descriptionKey: "discovery.weights.preset.easy_travel_description",
        weights: ScoreWeights(
            affordability: 0.1,
            visa: 0.3,
            advisory: 0.2,
            seasonality: 0.1,
            language: 0.3
        )
    )

    static let safetyFirst = WeightPreset(
        nameKey: "discovery.weights.preset.safety_first",
        descriptionKey: "discovery.weights.preset.safety_first_description",
        weights: ScoreWeights(
            affordability: 0.1,
            visa: 0.15,
            advisory: 0.5,
            seasonality: 0.1,
            language: 0.15
        )
    )

    static let all: [WeightPreset] = [
        .balanced,
        .budget,
        .easyTravel,
        .safetyFirst
    ]
}
