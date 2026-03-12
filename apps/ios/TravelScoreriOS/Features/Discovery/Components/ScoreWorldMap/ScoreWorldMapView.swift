//
//  ScoreWorldMapView.swift
//  TravelScoreriOS
//

import SwiftUI

struct ScoreWorldMapView: View {
    
    let countries: [Country]
    
    @State private var selectedCountryISO: String? = nil
    @State private var isLoadingMap: Bool = true
    @State private var shouldMountMap: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            if shouldMountMap {
                ScoreWorldMapRepresentable(
                    countries: countries,
                    highlightedISOs: [],
                    selectedCountryISO: $selectedCountryISO,
                    isLoading: $isLoadingMap
                )
                .ignoresSafeArea()
                .allowsHitTesting(!isLoadingMap)
            } else {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }
            
            if isLoadingMap {
                LoadingOverlayView()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: isLoadingMap)
            }
            
            if let iso = selectedCountryISO,
               let country = matchedCountry(for: iso) {
                
                ScoreCountryDrawerView(
                    country: country,
                    onDismiss: { selectedCountryISO = nil }
                )
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: selectedCountryISO)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                shouldMountMap = true
            }
        }
        .preferredColorScheme(nil)
    }
    
    private func matchedCountry(for iso: String) -> Country? {
        countries.first { $0.iso2.uppercased() == iso.uppercased() }
        ?? countries.first { $0.name == iso }
    }
}
