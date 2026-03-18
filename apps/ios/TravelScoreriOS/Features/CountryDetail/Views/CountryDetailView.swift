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
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var bucketListStore: BucketListStore
    @EnvironmentObject private var traveledStore: TraveledStore
    @StateObject private var visaStore = VisaRequirementsStore.shared
    @State private var scrollAnchor: String? = nil

    private var displayedCountry: Country {
        country.applyingOverallScore(using: weightsStore.weights, selectedMonth: weightsStore.selectedMonth)
    }

    private var isBucketed: Bool {
        bucketListStore.ids.contains(country.id)
    }

    private var isVisited: Bool {
        traveledStore.ids.contains(country.id)
    }

    @MainActor
    private func refreshCountryIfAvailable() async {
        let iso2 = country.iso2.uppercased()

        if let cached = CountryAPI.loadCachedCountries()?.first(where: { $0.iso2.uppercased() == iso2 }) {
            country = cached
        }

        if let refreshed = await CountryAPI.refreshCountriesIfNeeded(minInterval: 0)?
            .first(where: { $0.iso2.uppercased() == iso2 }) {
            country = refreshed
            return
        }

        if let fetched = try? await CountryAPI.fetchCountries()
            .first(where: { $0.iso2.uppercased() == iso2 }) {
            country = fetched
        }
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
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 10) {
                PlanningListActionButton(kind: .bucket, isActive: isBucketed) {
                    Task {
                        await toggleBucket()
                    }
                }

                PlanningListActionButton(kind: .visited, isActive: isVisited) {
                    Task {
                        await toggleVisited()
                    }
                }
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
        .task(id: country.iso2.uppercased()) {
            await refreshCountryIfAvailable()
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

    @MainActor
    private func toggleBucket() async {
        if sessionManager.isAuthenticated {
            if profileVM.viewedBucketListCountries != bucketListStore.ids {
                profileVM.viewedBucketListCountries = bucketListStore.ids
                profileVM.computeOrderedLists()
            }

            await profileVM.toggleBucket(country.id)
            bucketListStore.replace(with: profileVM.viewedBucketListCountries)
        } else {
            bucketListStore.toggle(country.id)
        }
    }

    @MainActor
    private func toggleVisited() async {
        if sessionManager.isAuthenticated {
            if profileVM.viewedTraveledCountries != traveledStore.ids {
                profileVM.viewedTraveledCountries = traveledStore.ids
                profileVM.computeOrderedLists()
            }

            await profileVM.toggleTraveled(country.id)
            traveledStore.replace(with: profileVM.viewedTraveledCountries)
        } else {
            traveledStore.toggle(country.id)
        }
    }
}
