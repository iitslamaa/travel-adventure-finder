//
//  DiscoveryMapView.swift
//  TravelScoreriOS
//

import SwiftUI

struct DiscoveryMapView: View {
    
    let countries: [Country]
    
    @State private var selectedCountryISO: String? = nil
    @State private var isLoadingMap: Bool = true
    @State private var shouldMountMap: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            if shouldMountMap {
                DiscoveryMapRepresentable(
                    countries: countries,
                    highlightedISOs: [],
                    selectedCountryISO: $selectedCountryISO,
                    isLoading: $isLoadingMap
                )
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(!isLoadingMap)
            } else {
                Color(.systemBackground)
                    .ignoresSafeArea(edges: .top)
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
    }
    
    private func matchedCountry(for iso: String) -> Country? {
        countries.first { $0.iso2.uppercased() == iso.uppercased() }
        ?? countries.first { $0.name == iso }
    }
}
