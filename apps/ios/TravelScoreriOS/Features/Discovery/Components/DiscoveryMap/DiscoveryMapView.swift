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
    @State private var isVisible: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            if shouldMountMap {
                DiscoveryMapRepresentable(
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
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .safeAreaPadding(.bottom)
                .zIndex(2)
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: selectedCountryISO)
            }
        }
        .onAppear {
            isVisible = true
            selectedCountryISO = nil
            isLoadingMap = true
            shouldMountMap = false

            DispatchQueue.main.async {
                guard isVisible else { return }
                shouldMountMap = true
            }
        }
        .onDisappear {
            isVisible = false
            selectedCountryISO = nil
            isLoadingMap = true
            shouldMountMap = false
        }
        .preferredColorScheme(nil)
    }
    
    private func matchedCountry(for iso: String) -> Country? {
        let normalizedISO = iso.uppercased()
        return countries.first { $0.iso2.uppercased() == normalizedISO }
            ?? countries.first { $0.name == iso }
    }
}
