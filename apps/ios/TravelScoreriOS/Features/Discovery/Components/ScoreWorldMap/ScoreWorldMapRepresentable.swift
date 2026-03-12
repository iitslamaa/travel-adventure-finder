//
//  ScoreWorldMapRepresentable.swift
//  TravelScoreriOS
//

import SwiftUI
import MapKit

struct ScoreWorldMapRepresentable: UIViewRepresentable {
    
    private let instanceId = UUID()
    private static var cachedSimplified: [MKOverlay]?
    private static var cachedFull: [MKOverlay]?
    
    let countries: [Country]
    let highlightedISOs: [String]
    @Binding var selectedCountryISO: String?
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.overrideUserInterfaceStyle = .unspecified
        mapView.backgroundColor = .clear
        mapView.isOpaque = false
        
        let config = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.preferredConfiguration = config
        
        mapView.mapType = .mutedStandard
        mapView.showsBuildings = false
        mapView.pointOfInterestFilter = .excludingAll
        
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
        
        loadPolygons(into: mapView)
        
        context.coordinator.mapView = mapView
        
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(ScoreWorldMapCoordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.selectedCountryISO = selectedCountryISO
        context.coordinator.updateHighlights(highlightedISOs)

        guard let iso = selectedCountryISO?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        else {
            return
        }
        
        // Ensure full dataset overlays are loaded when selecting
        if Self.cachedFull == nil {
            let fullPolygons = WorldGeoJSONLoader.loadPolygons(selectedIso: iso)
            Self.cachedFull = fullPolygons
        }

        if let full = Self.cachedFull,
           uiView.overlays.count != full.count {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlays(full)
        }
        
        // 🔥 STRICT HARDCODE ZOOM OVERRIDES (Profile map only)
        let overrides: [String: MKCoordinateRegion] = [

            // Bonaire
            "BQ": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 12.18, longitude: -68.25),
                span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
            ),

            // American Samoa
            "AS": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -14.27, longitude: -170.70),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
            ),

            // China (mainland)
            "CN": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.0, longitude: 103.0),
                span: MKCoordinateSpan(latitudeDelta: 28.0, longitudeDelta: 28.0)
            ),

            // Algeria
            "DZ": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 28.0, longitude: 2.6),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            ),

            // Fiji
            "FJ": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -17.8, longitude: 178.0),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            ),

            // United Kingdom (mainland only)
            "GB": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 54.5, longitude: -3.0),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            ),

            // Kiribati
            "KI": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 1.9, longitude: -157.4),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 30.0)
            ),

            // New Zealand
            "NZ": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -41.0, longitude: 173.0),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 12.0)
            ),

            // Russia
            "RU": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 60.0, longitude: 100.0),
                span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 100.0)
            ),

            // Solomon Islands
            "SB": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -9.6, longitude: 160.2),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            ),

            // Sierra Leone
            "SL": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 8.6, longitude: -11.8),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            ),

            // Suriname
            "SR": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 4.0, longitude: -56.0),
                span: MKCoordinateSpan(latitudeDelta: 7.0, longitudeDelta: 7.0)
            ),

            // France (mainland only – slightly more zoomed out)
            "FR": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46.5, longitude: 2.5),
                span: MKCoordinateSpan(latitudeDelta: 11.0, longitudeDelta: 11.0)
            ),

            // United States (mainland focus – further zoomed out)
            "US": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.6),
                span: MKCoordinateSpan(latitudeDelta: 40.0, longitudeDelta: 70.0)
            ),

            // Singapore
            "SG": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 1.35, longitude: 103.82),
                span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
            ),

            // French Southern Territories
            "TF": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -49.3, longitude: 69.2),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            ),

            // Saint Helena
            "SH": MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -15.96, longitude: -5.72),
                span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
            ),
        ]

        if context.coordinator.lastZoomedISO != iso {
            if let override = overrides[iso] {
                uiView.setRegion(override, animated: true)
                context.coordinator.lastZoomedISO = iso
            } else {
                context.coordinator.zoomToCountry(iso: iso)
            }
        }
    }
    
    static func dismantleUIView(_ uiView: MKMapView, coordinator: ScoreWorldMapCoordinator) {
        uiView.delegate = nil
        uiView.removeOverlays(uiView.overlays)
        uiView.gestureRecognizers?.forEach { uiView.removeGestureRecognizer($0) }
    }
    
    func makeCoordinator() -> ScoreWorldMapCoordinator {
        let coordinator = ScoreWorldMapCoordinator(
            countries: countries,
            highlightedISOs: highlightedISOs
        )

        coordinator.onSelectionChange = { newValue in
            DispatchQueue.main.async {
                self.selectedCountryISO = newValue
            }
        }

        return coordinator
    }
}

// MARK: - Private Helpers

private extension ScoreWorldMapRepresentable {
    
    func loadPolygons(into mapView: MKMapView) {

        // World view always starts with simplified dataset
        if let polygons = Self.cachedSimplified {
            mapView.addOverlays(polygons)
            DispatchQueue.main.async { isLoading = false }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let polygons = WorldGeoJSONLoader.loadPolygons(selectedIso: nil)

            DispatchQueue.main.async {
                Self.cachedSimplified = polygons
                mapView.addOverlays(polygons)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoading = false
                }
            }
        }
    }
}
