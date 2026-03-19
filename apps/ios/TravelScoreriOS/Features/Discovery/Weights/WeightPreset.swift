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
            advisory: 0.2,
            seasonality: 0.2,
            language: 0.2
        )
    )

    static let budget = WeightPreset(
        name: "Budget",
        description: "Prioritize cheaper destinations",
        weights: ScoreWeights(
            affordability: 0.45,
            visa: 0.1,
            advisory: 0.15,
            seasonality: 0.1,
            language: 0.2
        )
    )

    static let easyTravel = WeightPreset(
        name: "Easy Travel",
        description: "Visa-free and convenient destinations",
        weights: ScoreWeights(
            affordability: 0.1,
            visa: 0.3,
            advisory: 0.2,
            seasonality: 0.1,
            language: 0.3
        )
    )

    static let safetyFirst = WeightPreset(
        name: "Safety First",
        description: "Prefer destinations with strong safety ratings",
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
