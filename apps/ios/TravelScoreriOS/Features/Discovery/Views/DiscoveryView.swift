//
//  DiscoveryView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/9/26.
//

import SwiftUI

struct DiscoveryCountryListView: View {

    @EnvironmentObject private var profileVM: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @StateObject private var visaStore = VisaRequirementsStore.shared

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var sort: CountrySort = .name
    @State private var sortOrder: SortOrder = .ascending
    @State private var countries: [Country] = CountryAPI.loadCachedCountries() ?? []
    @State private var didRunInitialLoad = false

    @MainActor
    private func applyCurrentWeightsAndVisa(to countries: [Country]) async -> [Country] {
        let visaHydrated = await visaStore.hydrate(countries: countries)
        return visaHydrated.map { $0.applyingOverallScore(using: weightsStore.weights) }
    }

    @MainActor
    private func reloadCountries() async {
        if let fresh = CountryAPI.loadCachedCountries(), !fresh.isEmpty {
            countries = await applyCurrentWeightsAndVisa(to: fresh)
        }
        await profileVM.loadIfNeeded()
    }

    @MainActor
    private func loadCountriesWithRetry() async {
        let delays: [UInt64] = [0, 200_000_000, 500_000_000, 1_000_000_000]

        for (_, delay) in delays.enumerated() {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }

            if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
                countries = await applyCurrentWeightsAndVisa(to: cached)
                return
            }
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Theme.chromeIconButtonBackground(size: 44)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)

                DiscoveryControlsView(
                    sort: $sort,
                    sortOrder: $sortOrder
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            CountryListView(
                showsSearchBar: true,
                searchText: $searchText,
                countries: countries,
                sort: $sort,
                sortOrder: $sortOrder
            )
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            Theme.pageBackground("travel1")
                .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await reloadCountries()
        }
        .task {
            guard !didRunInitialLoad else { return }
            didRunInitialLoad = true

            await loadCountriesWithRetry()
            await profileVM.loadIfNeeded()

            if countries.isEmpty, let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
                countries = await applyCurrentWeightsAndVisa(to: cached)
            }
        }
        .onReceive(weightsStore.$weights) { _ in
            countries = countries.map { $0.applyingOverallScore(using: weightsStore.weights) }
        }
        .onDisappear {
            isSearchFocused = false
        }
    }
}

struct DiscoveryView: View {

    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var showingWeights = false

    private var countries: [Country] {
        (CountryAPI.loadCachedCountries() ?? []).map {
            $0.applyingOverallScore(using: weightsStore.weights)
        }
    }

    var body: some View {
        let _ = print("🧪 DEBUG: DiscoveryView.body recomputed")
        ZStack {
            Theme.pageBackground("travel1")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("Explore")
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 24) {

                            NavigationLink {
                                DiscoveryCountryListView()
                            } label: {
                                Theme.featureCard(
                                    icon: "globe.americas",
                                    title: "Countries",
                                    subtitle: "Browse every destination"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.black)
                                }
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                WhenToGoView(
                                    countries: countries,
                                    weightsStore: weightsStore
                                )
                            } label: {
                                Theme.featureCard(
                                    icon: "calendar",
                                    title: "When To Go",
                                    subtitle: "Find peak seasons"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.black)
                                }
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                DiscoveryMapView(countries: countries)
                            } label: {
                                Theme.featureCard(
                                    icon: "map.fill",
                                    title: "Explore the World",
                                    subtitle: "Open the interactive world map"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.black)
                                }
                            }
                            .buttonStyle(.plain)

                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)

                        Spacer(minLength: 20)
                    }
                    .frame(maxWidth: .infinity)
                    .background(.clear)
                    .padding(.horizontal, 24)
                }
            }

            VStack {
                HStack {
                    Button {
                        showingWeights = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(TAFTypography.title(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }
        }
        .background(Color.clear)
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingWeights) {
            NavigationStack {
                CustomWeightsView(
                    userId: sessionManager.userId,
                    initialWeights: weightsStore.weights
                )
                    .environmentObject(weightsStore)
            }
        }
        .onAppear {
            print("🧪 DEBUG: DiscoveryView appeared on screen")
        }
    }

    struct DiscoverySquareCard: View {

        let title: String
        let subtitle: String
        let icon: String

        var body: some View {
            ZStack {

                VStack(spacing: 0) {

                    VStack {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.top, 18)

                    VStack(spacing: 4) {
                        Text(title)
                            .font(.headline)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.spacingMedium)
                    .padding(.vertical, 8)

                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.95, blue: 0.90))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
            }
        }
    }

    struct DiscoveryWideCard: View {

        let title: String
        let subtitle: String
        let icon: String

        var body: some View {
            ZStack {

                VStack(spacing: 0) {

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.headline)

                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.black)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.black)
                    }
                    .padding(Theme.spacingMedium)

                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.95, blue: 0.90))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
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
                        .foregroundColor(.black)

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
                                .foregroundColor(.black)
                        }
                        .buttonStyle(.plain)
                    }

                    if isFocused.wrappedValue {
                        Button {
                            isFocused.wrappedValue = false
                        } label: {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.black)
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
                .padding(Theme.spacingSmall)
                .background(
                    Theme.cardBackground(corner: 14)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 10)
            .background(.ultraThinMaterial)
            .shadow(radius: 8)
            .padding(.top, 0)
        }
    }

    #Preview {
        DiscoveryCountryListView()
    }
}
