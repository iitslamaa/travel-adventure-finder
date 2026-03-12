//
//  CountryDetailView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/11/25.
//

import SwiftUI

struct CountryDetailView: View {
    private let isTravelSafetyEnabled = false
    @State var country: Country
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @State private var scrollAnchor: String? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                
                LazyVStack(spacing: 28) {
                    
                    // Header polaroid style
                    CountryHeaderCard(country: country)
                        .padding()
                        .background(
                            Theme.countryDetailCardBackground(corner: 20)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
                    
                    // Advisory card stack
                    scrapbookSection {
                        CountryAdvisoryCard(
                            country: country,
                            weightPercentage: weightsStore.advisoryPercentage
                        )
                    }
                    
                    // Seasonality card stack
                    scrapbookSection {
                        CountrySeasonalityCard(
                            country: country,
                            weightPercentage: 0
                        )
                    }
                    
                    // Visa card stack
                    scrapbookSection {
                        CountryVisaCard(
                            country: country,
                            weightPercentage: weightsStore.visaPercentage
                        )
                    }
                    
                    // Affordability card stack
                    if country.affordabilityScore != nil {
                        scrapbookSection {
                            CountryAffordabilityCard(
                                country: country,
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
