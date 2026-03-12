import Foundation
import SwiftUI
import MapKit

final class DiscoveryMapCoordinator: NSObject, MKMapViewDelegate {
    
    private let coordinatorId = UUID()
    
    // Cache renderers so MapKit doesn't recreate hundreds of them repeatedly
    private var rendererCache: [ObjectIdentifier: MKOverlayRenderer] = [:]
    
    private func normalizeISO(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
    
    private func selectedBorderWidth(for mapView: MKMapView) -> CGFloat {
        let delta = mapView.region.span.longitudeDelta

        if delta > 120 { return 0.8 }
        if delta > 60  { return 1.1 }
        if delta > 30  { return 1.4 }
        if delta > 15  { return 1.7 }
        return 2.0
    }

    private func polygonIdentifier(for polygon: CountryPolygon) -> String? {
        if let iso = polygon.isoCode, iso != "-99" {
            return iso.uppercased()
        }
        return polygon.countryName?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
    
    // MARK: - State
    
    var highlightedISOs: [String]
    var selectedCountryISO: String?
    var onSelectionChange: ((String?) -> Void)?
    weak var mapView: MKMapView?
    
    var lastZoomedISO: String?
    private var countryLookup: [String: Country]
    
    // MARK: - Init
    
    init(
        countries: [Country],
        highlightedISOs: [String]
    ) {
        self.highlightedISOs = highlightedISOs.map { $0.uppercased() }
        self.countryLookup = DiscoveryMapCoordinator.buildCountryLookup(from: countries)

        super.init()
    }

    private static func buildCountryLookup(from countries: [Country]) -> [String: Country] {
        var lookup: [String: Country] = [:]
        for country in countries {
            lookup[country.id.uppercased()] = country
        }
        return lookup
    }

    func updateCountries(_ countries: [Country]) {
        let nextLookup = Self.buildCountryLookup(from: countries)
        guard nextLookup != countryLookup else { return }
        countryLookup = nextLookup
        rebuildOverlays()
    }
    
    // MARK: - Tap Handling
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let mapView = mapView else { return }
        
        let tapPoint = gesture.location(in: mapView)
        let coordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
        let mapPoint = MKMapPoint(coordinate)
        
        for overlay in mapView.overlays {
            guard let polygon = overlay as? CountryPolygon else { continue }
            guard let renderer = mapView.renderer(for: overlay) as? MKMultiPolygonRenderer else { continue }
            
            renderer.createPath()
            let point = renderer.point(for: mapPoint)
            
            if let path = renderer.path,
               path.contains(point) {
                
                let identifier: String? = {
                    if let iso = polygon.isoCode, iso != "-99" {
                        return iso
                    }
                    return polygon.countryName
                }()

                if selectedCountryISO != identifier {
                    selectedCountryISO = identifier
                    onSelectionChange?(identifier)
                }

                rebuildOverlays()
                break
            }
        }
    }
    
    // MARK: - Highlight Updates
    
    func updateHighlights(_ newISOs: [String]) {
        self.highlightedISOs = newISOs.map { $0.uppercased() }
        rebuildOverlays()
    }
    
    // MARK: - Overlay Rebuild
    
    func rebuildOverlays() {
        guard let mapView = mapView else { return }

        // Clear renderer cache so selection/highlight styling can update
        rendererCache.removeAll()

        let overlays = mapView.overlays

        mapView.removeOverlays(overlays)
        mapView.addOverlays(overlays)

        if let selected = normalizeISO(selectedCountryISO) {
            let selectedOverlays = overlays.compactMap { $0 as? CountryPolygon }
                .filter { polygonIdentifier(for: $0) == selected }

            if !selectedOverlays.isEmpty {
                mapView.removeOverlays(selectedOverlays)
                mapView.addOverlays(selectedOverlays)
            }
        }
    }
    
    // MARK: - Zoom
    
    func zoomToCountry(iso: String) {
        guard let mapView = mapView else { return }
        
        let matching = mapView.overlays
            .compactMap { $0 as? CountryPolygon }
            .filter { $0.isoCode?.uppercased() == iso }
        
        guard !matching.isEmpty else { return }
        
        var combinedRect = matching.first!.boundingMapRect
        for polygon in matching.dropFirst() {
            combinedRect = combinedRect.union(polygon.boundingMapRect)
        }
        
        let padding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        mapView.setVisibleMapRect(combinedRect, edgePadding: padding, animated: true)
    }
    
    // MARK: - Renderer
    
    func mapView(_ mapView: MKMapView,
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        guard let polygon = overlay as? CountryPolygon else {
            return MKOverlayRenderer(overlay: overlay)
        }

        let key = ObjectIdentifier(overlay)

        if let cached = rendererCache[key] {
            return cached
        }

        let normalizedSelected = selectedCountryISO?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let renderer = DiscoveryMapRenderer.makeRenderer(
            for: polygon,
            selectedISO: normalizedSelected,
            highlightedTokens: Set(highlightedISOs),
            countryLookup: countryLookup
        )

        rendererCache[key] = renderer

        return renderer
    }
}
