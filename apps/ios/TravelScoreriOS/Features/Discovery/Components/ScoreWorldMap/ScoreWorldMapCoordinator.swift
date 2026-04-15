//
//  ScoreWorldMapCoordinator.swift
//  TravelScoreriOS
//

import Foundation
import SwiftUI
import MapKit

final class ScoreWorldMapCoordinator: NSObject, MKMapViewDelegate {
    
    private let coordinatorId = UUID()
    
    private func normalizeISO(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
    
    private func selectedBorderWidth(for mapView: MKMapView) -> CGFloat {
        // Stroke width must scale down at world-zoom for very complex polygons (e.g. China),
        // otherwise MapKit’s path simplification + anti-aliasing makes edges look “blobby/jagged”.
        let delta = mapView.region.span.longitudeDelta

        if delta > 120 { return 0.8 }   // very zoomed out (whole world)
        if delta > 60  { return 1.1 }   // continent-scale
        if delta > 30  { return 1.4 }   // country-scale
        if delta > 15  { return 1.7 }   // regional
        return 2.0                     // close-in
    }

    private func polygonIdentifier(for polygon: CountryPolygon) -> String? {
        if let iso = polygon.isoCode, iso != "-99" {
            return iso.uppercased()
        }
        return polygon.countryName?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
    
    private func overlaysSummary(_ mapView: MKMapView) -> String {
        let total = mapView.overlays.count
        let countryPolys = mapView.overlays.compactMap { $0 as? CountryPolygon }
        let isoCount = countryPolys.compactMap { $0.isoCode }.count
        let nameCount = countryPolys.compactMap { $0.countryName }.count
        let dash99Count = countryPolys.filter { $0.isoCode == "-99" }.count
        return "overlays=\(total) countryPolys=\(countryPolys.count) iso=\(isoCount) name=\(nameCount) iso(-99)=\(dash99Count)"
    }

    private func gestureSummary(_ gesture: UITapGestureRecognizer, in mapView: MKMapView) -> String {
        let p = gesture.location(in: mapView)
        let c = mapView.convert(p, toCoordinateFrom: mapView)
        return "point=(\(String(format: "%.1f", p.x)),\(String(format: "%.1f", p.y))) coord=(\(String(format: "%.4f", c.latitude)),\(String(format: "%.4f", c.longitude)))"
    }
    
    // MARK: - State
    
    var highlightedISOs: [String]
    var selectedCountryISO: String?
    var onSelectionChange: ((String?) -> Void)?
    weak var mapView: MKMapView?
    
    var lastZoomedISO: String?
    
    // MARK: - Init
    
    init(
        countries: [Country],
        highlightedISOs: [String]
    ) {
        self.highlightedISOs = highlightedISOs.map { $0.uppercased() }
        super.init()
    }
    
    // MARK: - Tap Handling
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let mapView = mapView else { return }
        
        let tapPoint = gesture.location(in: mapView)
        let coordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
        let mapPoint = MKMapPoint(coordinate)
        
        var checked: Int = 0
        var rendererMissing: Int = 0
        var notCountryPoly: Int = 0
        var hitCount: Int = 0

        for overlay in mapView.overlays {
            checked += 1
            guard let polygon = overlay as? CountryPolygon else {
                notCountryPoly += 1
                continue
            }

            guard let renderer = mapView.renderer(for: overlay) as? MKMultiPolygonRenderer else {
                rendererMissing += 1
                continue
            }

            renderer.createPath()
            let point = renderer.point(for: mapPoint)
            
            if let path = renderer.path,
               path.contains(point) {
                
                hitCount += 1

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

                // Force repaint immediately after selection
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
    
    // MARK: - Overlay Rebuild (Deterministic Redraw)
    
    func rebuildOverlays() {
        guard let mapView = mapView else {
            return
        }

        let overlays = mapView.overlays

        // Remove all overlays
        mapView.removeOverlays(overlays)

        // Re-add all overlays (forces rendererFor to run again)
        mapView.addOverlays(overlays)

        // Ensure selected country overlays render on top
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

        // Determine if country is extremely large in map space
        let worldWidth = MKMapRect.world.size.width
        let countryWidthRatio = combinedRect.size.width / worldWidth

        // If country spans a large portion of the world, zoom slightly tighter
        if countryWidthRatio > 0.15 {
            let insetX = combinedRect.size.width * 0.15
            let insetY = combinedRect.size.height * 0.15

            let tighterRect = MKMapRect(
                x: combinedRect.origin.x + insetX,
                y: combinedRect.origin.y + insetY,
                width: combinedRect.size.width - (insetX * 2),
                height: combinedRect.size.height - (insetY * 2)
            )

            mapView.setVisibleMapRect(tighterRect, edgePadding: padding, animated: true)
        } else {
            mapView.setVisibleMapRect(combinedRect, edgePadding: padding, animated: true)
        }
    }
    
    // MARK: - Renderer
    
    func mapView(_ mapView: MKMapView,
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        guard let polygon = overlay as? CountryPolygon else {
            return MKOverlayRenderer(overlay: overlay)
        }
        
        let renderer = MKMultiPolygonRenderer(overlay: polygon)
        
        let normalizedSelected = selectedCountryISO?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        let identifier = polygonIdentifier(for: polygon)
        
        let isHighlighted = highlightedISOs.contains(identifier ?? "")
        let isSelected = (identifier == normalizedSelected)
        
        // Default
        renderer.lineWidth = 0.5
        renderer.strokeColor = UIColor.clear
        renderer.fillColor = UIColor.clear
        renderer.alpha = 1.0
        
        if isSelected {
            renderer.fillColor = UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 1.0)
            let delta = mapView.region.span.longitudeDelta
            let vertexCount = polygon.polygons.reduce(0) { $0 + $1.pointCount }
            let isComplex = vertexCount > 5000

            // Always show stroke for China and Antarctica
            if polygon.isoCode == "CN" || polygon.isoCode == "AQ" {
                renderer.strokeColor = UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 0.9)
                renderer.lineWidth = 2.0
            }
            else if isComplex && delta > 60 {
                renderer.strokeColor = UIColor.clear
                renderer.lineWidth = 0
            }
            else {
                renderer.strokeColor = UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 0.9)
                renderer.lineWidth = 2.0
            }
            renderer.lineJoin = .round
            renderer.lineCap = .round
        }
        else if isHighlighted {
            renderer.fillColor = UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.25)
        }
        
        return renderer
    }
}
