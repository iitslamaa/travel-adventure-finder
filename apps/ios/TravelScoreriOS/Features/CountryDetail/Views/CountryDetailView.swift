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

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                // Header polaroid style
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .rotationEffect(.degrees(-3))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 6)

                    CountryHeaderCard(country: country)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 6)

                }
                .padding(.horizontal)

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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.vertical, 24)
        }
        .navigationTitle(country.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func scrapbookSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack {

        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white)
            .rotationEffect(.degrees(-2))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 6)

        content()
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 8, y: 6)

    }
    .padding(.horizontal)
}
