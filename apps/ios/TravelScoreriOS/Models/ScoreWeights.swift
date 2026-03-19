//
//  ScoreWeights.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/22/26.
//

import Foundation

struct ScoreWeights: Codable {
    var affordability: Double
    var visa: Double
    var advisory: Double
    var seasonality: Double
    var language: Double

    private enum CodingKeys: String, CodingKey {
        case affordability
        case visa
        case advisory
        case seasonality
        case language
    }

    init(
        affordability: Double,
        visa: Double,
        advisory: Double,
        seasonality: Double,
        language: Double
    ) {
        self.affordability = affordability
        self.visa = visa
        self.advisory = advisory
        self.seasonality = seasonality
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        affordability = try container.decode(Double.self, forKey: .affordability)
        visa = try container.decode(Double.self, forKey: .visa)
        advisory = try container.decode(Double.self, forKey: .advisory)
        seasonality = try container.decode(Double.self, forKey: .seasonality)
        language = try container.decodeIfPresent(Double.self, forKey: .language) ?? 0
    }
    
    static let `default` = ScoreWeights(
        affordability: 0.2,
        visa: 0.2,
        advisory: 0.2,
        seasonality: 0.2,
        language: 0.2
    )
}
