//
//  BucketListView.swift
//  TravelScoreriOS
//

import SwiftUI

struct BucketListView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var countries: [Country] = []
    @State private var bucketCountryIds: Set<String> = []
    @State private var isLoading: Bool = true

    private var bucketedCountries: [Country] {
        countries
            .filter { bucketCountryIds.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bucketedCountries.isEmpty {
                ContentUnavailableView(
                    "No Bucket List Yet",
                    systemImage: "bookmark",
                    description: Text("Swipe left on a country and tap 🪣 Bucket to save it here.")
                )
            } else {
                List(bucketedCountries) { country in
                    NavigationLink(value: country) {
                        HStack(spacing: 12) {
                            Text(country.flagEmoji)
                                .font(.largeTitle)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(country.name)
                                    .font(.headline)
                            }

                            Spacer()

                            if let score = country.score {
                                ScorePill(score: score)
                            } else {
                                Text("—")
                                    .font(.caption.bold())
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
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("🪣 Bucket List")
        .navigationDestination(for: Country.self) { country in
            CountryDetailView(country: country)
        }
        .task {
            isLoading = true
            // 1) Show cached data immediately (fast/offline)
            if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
                countries = cached
            }

            // 2) Try to refresh from API
            if let fresh = await CountryAPI.refreshCountriesIfNeeded(minInterval: 60), !fresh.isEmpty {
                countries = fresh
            }

            // Fetch bucket list for current user (identity-scoped)
            if let userId = sessionManager.userId {
                let service = ProfileService(supabase: SupabaseManager.shared)
                if let bucket = try? await service.fetchBucketListCountries(userId: userId) {
                    bucketCountryIds = bucket
                }
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        BucketListView()
    }
}
