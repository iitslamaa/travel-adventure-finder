//
//  DiscoveryMapView.swift
//  TravelScoreriOS
//

import SwiftUI

struct DiscoveryMapView: View {
    
    let countries: [Country]
    
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    
    @State private var selectedCountryISO: String? = nil
    @State private var isLoadingMap: Bool = true
    @State private var shouldMountMap: Bool = false

    private var displayedCountries: [Country] {
        countries.map {
            $0.applyingOverallScore(
                using: weightsStore.weights,
                selectedMonth: weightsStore.selectedMonth
            )
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            if shouldMountMap {
                DiscoveryMapRepresentable(
                    countries: displayedCountries,
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
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .safeAreaPadding(.bottom)
                .zIndex(2)
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
        displayedCountries.first { $0.iso2.uppercased() == iso.uppercased() }
        ?? displayedCountries.first { $0.name == iso }
    }
}
