//
//  MyTravelsView.swift
//  TravelScoreriOS
//

import SwiftUI

struct MyTravelsView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset
    @State private var countries: [Country] = []
    @State private var traveledCountryIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var hasLoadedOnce: Bool = false

    private var visitedCountries: [Country] {
        countries
            .filter { traveledCountryIds.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visitedCountries.isEmpty {
                ContentUnavailableView(
                    "No trips yet",
                    systemImage: "backpack",
                    description: Text("Swipe left on a country and tap 📝 Visited to track places you’ve already been.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(visitedCountries) { country in
                        NavigationLink {
                            CountryDetailView(country: country)
                        } label: {
                            HStack(spacing: 12) {
                                Text(country.flagEmoji)
                                    .font(.largeTitle)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(country.name)
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
                                }

                                Spacer()

                                if let score = country.score {
                                    ScorePill(score: score)
                                } else {
                                    Text("—")
                                        .font(.caption.bold())
                                        .foregroundColor(Theme.textPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.gray.opacity(0.15))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(16)
                            .background(Theme.cardBackground())
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.bottom, floatingTabBarInset)
            }
        }
        .navigationTitle("🎒 My Travels")
        .task {
            await loadVisitedListIfNeeded()
        }
    }

    @MainActor
    private func loadVisitedListIfNeeded() async {
        let shouldShowBlockingLoad = !hasLoadedOnce && countries.isEmpty && traveledCountryIds.isEmpty

        if shouldShowBlockingLoad {
            isLoading = true
        }

        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        if countries.isEmpty,
           let cached = CountryAPI.loadCachedCountries(),
           !cached.isEmpty {
            countries = cached
        }

        if let fresh = await CountryAPI.refreshCountriesIfNeeded(minInterval: 60), !fresh.isEmpty {
            countries = fresh
        }

        if let userId = sessionManager.userId {
            let service = ProfileService(supabase: SupabaseManager.shared)
            if let traveled = try? await service.fetchTraveledCountries(userId: userId) {
                traveledCountryIds = traveled
            }
        }
    }
}

#Preview {
    NavigationStack {
        MyTravelsView()
    }
}
