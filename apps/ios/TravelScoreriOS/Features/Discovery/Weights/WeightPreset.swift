//
//  WeightPreset.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/3/26.
//

import Foundation

struct WeightPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let weights: ScoreWeights
}

extension WeightPreset {

    static let balanced = WeightPreset(
        name: "Balanced",
        description: "Even mix of affordability, safety, and visa access",
        weights: ScoreWeights(
            affordability: 0.2,
            visa: 0.2,
            advisory: 0.4,
            seasonality: 0.2
        )
    )

    static let budget = WeightPreset(
        name: "Budget",
        description: "Prioritize cheaper destinations",
        weights: ScoreWeights(
            affordability: 0.55,
            visa: 0.15,
            advisory: 0.15,
            seasonality: 0.15
        )
    )

    static let easyTravel = WeightPreset(
        name: "Easy Travel",
        description: "Visa-free and convenient destinations",
        weights: ScoreWeights(
            affordability: 0.15,
            visa: 0.45,
            advisory: 0.25,
            seasonality: 0.15
        )
    )

    static let safetyFirst = WeightPreset(
        name: "Safety First",
        description: "Prefer destinations with strong safety ratings",
        weights: ScoreWeights(
            affordability: 0.1,
            visa: 0.15,
            advisory: 0.6,
            seasonality: 0.15
        )
    )

    static let all: [WeightPreset] = [
        .balanced,
        .budget,
        .easyTravel,
        .safetyFirst
    ]
}
