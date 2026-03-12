//
//  WorldMapView.swift
//  TravelScoreriOS
//

import SwiftUI
import MapKit

struct WorldMapView: UIViewRepresentable {

    private static var cachedSimplified: [MKOverlay]?
    private static var cachedFull: [MKOverlay]?

    let highlightedCountryCodes: [String]
    @Binding var selectedCountryISO: String?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.overrideUserInterfaceStyle = .unspecified

        mapView.mapType = .mutedStandard
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.delegate = context.coordinator

        mapView.setVisibleMapRect(
            MKMapRect.world,
            edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
            animated: false
        )

        // World view always starts with simplified dataset
        if let cached = WorldMapView.cachedSimplified {
            mapView.addOverlays(cached)
        } else {
            let polygons = WorldGeoJSONLoader.loadPolygons(selectedIso: nil)
            WorldMapView.cachedSimplified = polygons
            mapView.addOverlays(polygons)
        }

        context.coordinator.mapView = mapView

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {

        context.coordinator.highlightedCountryCodes =
            highlightedCountryCodes.map { $0.uppercased() }

        // Always attempt zoom when a country is selected
        guard let iso = selectedCountryISO?.uppercased() else { return }

        // Ensure full dataset overlays are loaded when selecting
        if WorldMapView.cachedFull == nil {
            let fullPolygons = WorldGeoJSONLoader.loadPolygons(selectedIso: iso)
            WorldMapView.cachedFull = fullPolygons
        }

        // Replace overlays with full dataset if not already applied
        if let full = WorldMapView.cachedFull,
           uiView.overlays.count != full.count {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlays(full)
        }


        let matching = uiView.overlays
            .compactMap { $0 as? CountryPolygon }
            .filter { $0.isoCode?.uppercased() == iso }

        guard !matching.isEmpty else { return }

        // 🔥 CRITICAL: async to avoid SwiftUI mutation cycle
        DispatchQueue.main.async {
            context.coordinator.zoomToCountry(polygons: matching, animated: true)
            context.coordinator.lastZoomedISO = iso
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            highlightedCountryCodes: highlightedCountryCodes,
            selectedCountryISO: $selectedCountryISO
        )
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {

        var highlightedCountryCodes: [String]
        @Binding var selectedCountryISO: String?
        weak var mapView: MKMapView?
        var lastZoomedISO: String?

        init(highlightedCountryCodes: [String],
             selectedCountryISO: Binding<String?>) {
            self.highlightedCountryCodes = highlightedCountryCodes
            self._selectedCountryISO = selectedCountryISO
        }

        // 🔥 ONLY set selection here. DO NOT zoom.
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }

            let tapPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)

            for overlay in mapView.overlays {
                guard let polygon = overlay as? CountryPolygon,
                      let renderer = mapView.renderer(for: overlay) as? MKMultiPolygonRenderer else { continue }

                renderer.createPath()
                let point = renderer.point(for: mapPoint)

                if let path = renderer.path,
                   path.contains(point),
                   let iso = polygon.isoCode?.uppercased() {

                    selectedCountryISO = iso
                    break
                }
            }
        }

        func zoomToCountry(polygons: [CountryPolygon], animated: Bool) {
            guard let mapView = mapView else { return }
            guard !polygons.isEmpty else { return }

            var combinedRect = polygons.first!.boundingMapRect
            for polygon in polygons.dropFirst() {
                combinedRect = combinedRect.union(polygon.boundingMapRect)
            }

            mapView.setVisibleMapRect(
                combinedRect,
                edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60),
                animated: animated
            )
        }

        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

            guard let multi = overlay as? CountryPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKMultiPolygonRenderer(multiPolygon: multi)

            let geoISO = multi.isoCode?.uppercased()
            let isHighlighted = geoISO != nil &&
                highlightedCountryCodes.contains(geoISO!)
            let isSelected = geoISO == selectedCountryISO?.uppercased()

            renderer.fillColor = isHighlighted
                ? UIColor.systemYellow.withAlphaComponent(isSelected ? 0.85 : 0.6)
                : UIColor.systemGray.withAlphaComponent(0.2)

            renderer.strokeColor = isSelected
                ? UIColor.systemYellow
                : UIColor.black.withAlphaComponent(0.2)

            renderer.lineWidth = isSelected ? 2.5 : 0.5

            return renderer
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
