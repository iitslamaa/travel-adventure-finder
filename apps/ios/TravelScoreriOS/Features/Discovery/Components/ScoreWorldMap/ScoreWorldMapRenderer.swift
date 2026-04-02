//
//  ScoreWorldMapRenderer.swift
//  TravelScoreriOS
//

import Foundation
import SwiftUI
import MapKit

enum ScoreWorldMapRenderer {
    private static func isTinyCountry(_ polygon: CountryPolygon) -> Bool {
        let worldRect = MKMapRect.world
        let widthRatio = polygon.boundingMapRect.size.width / worldRect.size.width
        let heightRatio = polygon.boundingMapRect.size.height / worldRect.size.height
        let areaRatio = polygon.boundingMapRect.size.width * polygon.boundingMapRect.size.height
            / (worldRect.size.width * worldRect.size.height)

        return max(widthRatio, heightRatio) < 0.012 || areaRatio < 0.000015
    }

    private static func legacyMapColor(for score: Int?) -> UIColor {
        guard let score else {
            return UIColor.systemGray.withAlphaComponent(0.15)
        }

        switch score {
        case 80...100:
            return .systemGreen
        case 60..<80:
            return .systemYellow
        case 40..<60:
            return .systemOrange
        default:
            return .systemRed
        }
    }
    
    // MARK: - Public Renderer Factory
    
    static func makeRenderer(
        for polygon: CountryPolygon,
        selectedISO: String?,
        highlightedTokens: Set<String>,
        countryLookup: [String: Country]
    ) -> MKOverlayRenderer {
        
        let renderer = MKMultiPolygonRenderer(multiPolygon: polygon)
        renderer.lineJoin = .round
        renderer.lineCap = .round
        let isTiny = isTinyCountry(polygon)
        
        let geoISO = polygon.isoCode?.uppercased()
        let geoName = polygon.countryName?.uppercased()
        
        let selectedTokens = buildHighlightTokens(from: selectedISO.map { [$0] } ?? [])
        
        let identifier: String? = {
            if let iso = geoISO, iso != "-99" {
                return iso
            }
            return geoName
        }()
        
        let isSelected =
            (geoISO != nil && selectedTokens.contains(geoISO!)) ||
            (geoISO != nil && selectedTokens.contains(String(geoISO!.prefix(2)))) ||
            (geoName != nil && selectedTokens.contains(geoName!))
        
        // Highlight-only mode (no score coloring)
        if countryLookup.isEmpty {
            
            let isHighlighted =
                (geoISO != nil && highlightedTokens.contains(geoISO!)) ||
                (geoISO != nil && highlightedTokens.contains(String(geoISO!.prefix(2)))) ||
                (geoName != nil && highlightedTokens.contains(geoName!))
            
            if isHighlighted {
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.6)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = isTiny ? 0.8 : 1.5
            } else {
                renderer.fillColor = UIColor.systemGray.withAlphaComponent(isTiny ? 0.28 : 0.15)
                renderer.strokeColor = UIColor.black.withAlphaComponent(isTiny ? 0.08 : 0.2)
                renderer.lineWidth = isTiny ? 0.15 : 0.5
            }
            
            return renderer
        }
        
        if let id = identifier,
           let country = countryLookup[id] {
            let baseColor = legacyMapColor(for: country.score)
            
            renderer.fillColor = isSelected
                ? baseColor.withAlphaComponent(isTiny ? 0.95 : 0.85)
                : baseColor.withAlphaComponent(isTiny ? 0.78 : 0.6)
            
        } else {
            renderer.fillColor = UIColor.systemGray.withAlphaComponent(isTiny ? 0.28 : 0.15)
        }
        
        renderer.strokeColor = isSelected
            ? UIColor.systemOrange
            : UIColor.black.withAlphaComponent(isTiny ? 0.08 : 0.2)
        
        renderer.lineWidth = isSelected
            ? (isTiny ? 1.0 : 2.5)
            : (isTiny ? 0.15 : 0.5)
        
        return renderer
    }
    
    // MARK: - Token Builder
    
    static func buildHighlightTokens(from isos: [String]) -> Set<String> {
        
        var tokens = Set<String>()
        
        for iso in isos {
            let up = iso.uppercased()
            
            tokens.insert(up)
            tokens.insert(String(up.prefix(2)))
            
            if let nameLocal = Locale.current
                .localizedString(forRegionCode: up)?
                .uppercased() {
                tokens.insert(nameLocal)
            }
            
            if let nameEN = Locale(identifier: "en_US")
                .localizedString(forRegionCode: up)?
                .uppercased() {
                tokens.insert(nameEN)
            }
        }
        
        return tokens
    }
}
