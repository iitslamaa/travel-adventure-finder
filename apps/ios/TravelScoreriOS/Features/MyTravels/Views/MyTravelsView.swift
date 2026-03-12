//
//  MyTravelsView.swift
//  TravelScoreriOS
//

import SwiftUI

struct MyTravelsView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var traveledStore: TraveledStore
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
                ScrollView {
                    LazyVStack(spacing: 16) {
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
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.94))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(.white.opacity(0.34), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.10), radius: 8, y: 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, floatingTabBarInset + 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("🎒 My Travels")
        .task {
            await loadVisitedListIfNeeded()
        }
        .onReceive(traveledStore.$ids) { ids in
            traveledCountryIds = ids
        }
    }

    @MainActor
    private func loadVisitedListIfNeeded() async {
        if countries.isEmpty,
           let cached = CountryAPI.loadCachedCountries(),
           !cached.isEmpty {
            countries = cached
        }

        if traveledCountryIds.isEmpty || !hasLoadedOnce {
            traveledCountryIds = traveledStore.ids
        }

        let shouldShowBlockingLoad = !hasLoadedOnce && countries.isEmpty && traveledCountryIds.isEmpty
        isLoading = shouldShowBlockingLoad
        hasLoadedOnce = true

        async let freshCountriesTask = CountryAPI.refreshCountriesIfNeeded(minInterval: 60)

        if let userId = sessionManager.userId {
            let service = ProfileService(supabase: SupabaseManager.shared)
            if let traveled = try? await service.fetchTraveledCountries(userId: userId) {
                traveledCountryIds = traveled
                traveledStore.replace(with: traveled)
            }
        }

        if let fresh = await freshCountriesTask, !fresh.isEmpty {
            countries = fresh
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        MyTravelsView()
    }
}
