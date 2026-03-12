//
//  CountryDetailView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/11/25.
//

import SwiftUI

struct CountryDetailView: View {
    @State var country: Country
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @StateObject private var visaStore = VisaRequirementsStore.shared
    @State private var scrollAnchor: String? = nil

    private var displayedCountry: Country {
        country.applyingOverallScore(using: weightsStore.weights, selectedMonth: weightsStore.selectedMonth)
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                
                LazyVStack(spacing: 28) {
                    
                    // Header polaroid style
                    CountryHeaderCard(country: displayedCountry)
                        .padding()
                        .background(
                            Theme.countryDetailCardBackground(corner: 20)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
                    
                    // Advisory card stack
                    scrapbookSection {
                        CountryAdvisoryCard(
                            country: displayedCountry,
                            weightPercentage: weightsStore.advisoryPercentage
                        )
                    }
                    
                    // Seasonality card stack
                    scrapbookSection {
                        CountrySeasonalityCard(
                            country: displayedCountry,
                            weightPercentage: weightsStore.seasonalityPercentage
                        )
                    }
                    
                    // Visa card stack
                    scrapbookSection {
                        CountryVisaCard(
                            country: displayedCountry,
                            weightPercentage: weightsStore.visaPercentage
                        )
                    }
                    
                    // Affordability card stack
                    if displayedCountry.affordabilityScore != nil {
                        scrapbookSection {
                            CountryAffordabilityCard(
                                country: displayedCountry,
                                weightPercentage: weightsStore.affordabilityPercentage
                            )
                        }
                    }
                }
                .id("countryDetailTop")
                .padding(.top, 24)
                .padding(.horizontal)
                .safeAreaPadding(.bottom)
            }
        }
        .background(
            ZStack {
                Image("travel5")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color(red: 0.97, green: 0.95, blue: 0.90)
                    .opacity(0.22)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.08),
                        Color.black.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .preferredColorScheme(.light)
        .task(id: country.iso2.uppercased()) {
            country = await visaStore.hydrate(country: country)
        }
    }
    
    private func scrapbookSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(
                Theme.countryDetailCardBackground(corner: 20)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
    }
}
