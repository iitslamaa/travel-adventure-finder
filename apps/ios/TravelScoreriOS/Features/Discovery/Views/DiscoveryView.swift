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
            } else {
                print("🟡 Discovery initial load: countries still empty (attempt \(idx + 1)/\(delays.count))")
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
        VStack(spacing: 24) {

            Spacer()

            NavigationLink {
                DiscoveryCountryListView()
            } label: {
                Label("Explore Countries", systemImage: "list.bullet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            NavigationLink {
                DiscoveryMapView(countries: countries)
            } label: {
                Label("Explore Map", systemImage: "map")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            NavigationLink {
                WhenToGoView(
                    countries: countries,
                    weightsStore: weightsStore
                )
            } label: {
                Label("When To Go", systemImage: "calendar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer()
        }
        .padding()
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
