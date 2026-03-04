//
//  DiscoveryView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/9/26.
//

import SwiftUI

struct DiscoveryCountryListView: View {

    @EnvironmentObject private var profileVM: ProfileViewModel

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var sort: CountrySort = .name
    @State private var sortOrder: SortOrder = .ascending
    @State private var countries: [Country] = CountryAPI.loadCachedCountries() ?? []
    @State private var didRunInitialLoad = false

    @MainActor
    private func reloadCountries() async {
        if let fresh = CountryAPI.loadCachedCountries(), !fresh.isEmpty {
            countries = fresh
        }
        await profileVM.loadIfNeeded()
    }

    @MainActor
    private func loadCountriesWithRetry() async {
        let delays: [UInt64] = [0, 200_000_000, 500_000_000, 1_000_000_000]

        for (idx, delay) in delays.enumerated() {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }

            if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
                countries = cached
                return
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            DiscoveryControlsView(
                sort: $sort,
                sortOrder: $sortOrder
            )
            .padding(.horizontal)
            .padding(.top, 8)

            CountryListView(
                showsSearchBar: false,
                searchText: searchText,
                countries: countries,
                sort: $sort,
                sortOrder: $sortOrder
            )
            .scrollDismissesKeyboard(.interactively)
        }
        .refreshable {
            await reloadCountries()
        }
        .task {
            guard !didRunInitialLoad else { return }
            didRunInitialLoad = true

            await loadCountriesWithRetry()
            await profileVM.loadIfNeeded()

            if countries.isEmpty, let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
                countries = cached
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FloatingSearchBar(text: $searchText, isFocused: $isSearchFocused)
        }
        .navigationDestination(for: String.self) { countryId in
            if let country = countries.first(where: { $0.id == countryId }) {
                CountryDetailView(country: country)
            } else {
                Text("Country not found")
            }
        }
        .onDisappear {
            isSearchFocused = false
        }
    }
}

struct DiscoveryView: View {

    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @State private var showingWeights = false

    private var countries: [Country] {
        CountryAPI.loadCachedCountries() ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                Spacer(minLength: 10)

                Text("Explore")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Discover destinations, visualize the world, and find the best time to travel.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Top row
                HStack(spacing: 16) {

                    NavigationLink {
                        DiscoveryCountryListView()
                    } label: {
                        DiscoverySquareCard(
                            title: "Countries",
                            subtitle: "Browse every destination",
                            icon: "globe.americas"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WhenToGoView(
                            countries: countries,
                            weightsStore: weightsStore
                        )
                    } label: {
                        DiscoverySquareCard(
                            title: "When To Go",
                            subtitle: "Find peak seasons",
                            icon: "calendar"
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Large map card
                NavigationLink {
                    DiscoveryMapView(countries: countries)
                } label: {
                    DiscoveryWideCard(
                        title: "Explore the World",
                        subtitle: "Open the interactive world map",
                        icon: "map.fill"
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingWeights = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showingWeights) {
            NavigationStack {
                CustomWeightsView()
            }
        }
    }
}

struct DiscoverySquareCard: View {

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

struct DiscoveryWideCard: View {

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

struct FloatingSearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search countries and territories", text: $text)
                    .focused(isFocused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit { isFocused.wrappedValue = false }

                if isFocused.wrappedValue && !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if isFocused.wrappedValue {
                    Button {
                        isFocused.wrappedValue = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 10)
        .background(.ultraThinMaterial)
        .shadow(radius: 6)
        .padding(.top, 0)
    }
}

#Preview {
    NavigationStack {
        DiscoveryCountryListView()
    }
}
