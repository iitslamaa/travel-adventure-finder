//
//  WhenToGoModels.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 1/22/26.
//

import Foundation

enum SeasonType: String, Codable, Hashable {
    case peak
    case good
    case shoulder
    case poor
}

struct WhenToGoItem: Identifiable, Hashable {
    let country: Country
    let seasonType: SeasonType
    let seasonalityScore: Int

    var id: String { country.iso2 }
}
