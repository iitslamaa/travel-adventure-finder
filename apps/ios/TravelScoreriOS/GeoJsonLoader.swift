//
//  GeoJsonLoader.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/28/26.
//

import Foundation
import MapKit

enum GeoDataset {
    case full
    case simplified
    
    var fileName: String {
        switch self {
        case .full:
            return "travelaf.world.full"
        case .simplified:
            return "travelaf.world.simplified"
        }
    }
}

final class GeoJsonLoader {
    
    static func load(_ dataset: GeoDataset) -> [MKGeoJSONFeature] {
        guard
            let url = Bundle.main.url(
                forResource: dataset.fileName,
                withExtension: "geo.json"
            ),
            let data = try? Data(contentsOf: url)
        else {
            print("❌ Failed to load \(dataset.fileName)")
            return []
        }
        
        do {
            let decoded = try MKGeoJSONDecoder().decode(data)
            return decoded.compactMap { $0 as? MKGeoJSONFeature }
        } catch {
            print("❌ GeoJSON decode error:", error)
            return []
        }
    }
}
