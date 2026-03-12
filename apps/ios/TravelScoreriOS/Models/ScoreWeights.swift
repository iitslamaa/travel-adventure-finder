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
    
    static let `default` = ScoreWeights(
        affordability: 0.2,
        visa: 0.2,
        advisory: 0.4,
        seasonality: 0.2
    )
}
