//
//  CountryListView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/10/25.
//

import SwiftUI

enum SortOrder {
    case ascending
    case descending
}

struct CountryListView: View {

    let showsSearchBar: Bool
    @Binding var searchText: String
    let countries: [Country]
    @Binding var sort: CountrySort
    @Binding var sortOrder: SortOrder

    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @EnvironmentObject private var profileVM: ProfileViewModel
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset

    @State private var visibleCountries: [Country] = []
    @State private var selectedCountry: Country?
    @FocusState private var isSearchFocused: Bool

    private enum QuickConfirm {
        case bucket
        case visited
    }

    @State private var quickConfirmByCountryId: [String: QuickConfirm] = [:]

    private func flashConfirm(_ type: QuickConfirm, for id: String) {
        quickConfirmByCountryId[id] = type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if quickConfirmByCountryId[id] == type {
                quickConfirmByCountryId[id] = nil
            }
        }
    }

    private func scheduleRecomputeVisible() {

        var recalculatedCountries: [Country] = []
        let weights = weightsStore.weights

        for country in countries {
            var updated = country

            var components: [(value: Double, weight: Double)] = []

            if let advisory = country.travelSafeScore {
                components.append((Double(advisory), weights.advisory))
            }

            if let visa = country.visaEaseScore {
                components.append((Double(visa), weights.visa))
            }

            if let affordabilityScore = country.affordabilityScore {
                components.append((Double(affordabilityScore), weights.affordability))
            }

            if components.isEmpty {
                updated.score = nil
            } else {
                let totalWeight = components.reduce(0) { $0 + $1.weight }
                let weightedSum = components.reduce(0) { $0 + ($1.value * $1.weight) }

                if totalWeight > 0 {
                    let normalizedScore = weightedSum / totalWeight
                    updated.score = Int(normalizedScore.rounded())
                } else {
                    updated.score = nil
                }
            }

            recalculatedCountries.append(updated)
        }

        let snapshotSearch = searchText
        let snapshotSort = sort
        let snapshotSortOrder = sortOrder

        let filtered: [Country]
        if snapshotSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = recalculatedCountries
        } else {
            filtered = recalculatedCountries.filter {
                $0.name.localizedCaseInsensitiveContains(snapshotSearch)
            }
        }

        let baseSorted: [Country]
        switch snapshotSort {
        case .name:
            baseSorted = filtered.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .score:
            baseSorted = filtered.sorted { ($0.score ?? Int.min) > ($1.score ?? Int.min) }
        }

        let result: [Country]

        if snapshotSort == .score {
            result = baseSorted
        } else {
            switch snapshotSortOrder {
            case .ascending: result = baseSorted
            case .descending: result = Array(baseSorted.reversed())
            }
        }

        visibleCountries = result
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsSearchBar {
                searchBar
            }

            countryScroll
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 8)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .padding(.horizontal, 22)
        .padding(.bottom, floatingTabBarInset)
        .frame(maxWidth: .infinity)
        .navigationDestination(item: $selectedCountry) { country in
            CountryDetailView(country: country)
        }
        .onAppear { scheduleRecomputeVisible() }
        .onChange(of: searchText) { _, _ in scheduleRecomputeVisible() }
        .onChange(of: sort) { _, _ in scheduleRecomputeVisible() }
        .onChange(of: sortOrder) { _, _ in scheduleRecomputeVisible() }
        .onChange(of: countries) { _, _ in scheduleRecomputeVisible() }
        .onReceive(weightsStore.$weights) { _ in scheduleRecomputeVisible() }
    }

    private var searchBar: some View {
        LocalFloatingSearchBar(
            text: $searchText,
            isFocused: $isSearchFocused
        )
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var countryScroll: some View {
        List {
            ForEach(visibleCountries, id: \.id) { country in
                SwipeableCountryRow(
                    country: country,
                    isBucketed: profileVM.viewedBucketListCountries.contains(country.id),
                    isVisited: profileVM.viewedTraveledCountries.contains(country.id),
                    showConfirm: quickConfirmByCountryId[country.id] != nil,
                    onTap: {
                        selectedCountry = country
                    },
                    onBucket: {
                        Task {
                            await profileVM.toggleBucket(country.id)
                            flashConfirm(.bucket, for: country.id)
                        }
                    },
                    onVisited: {
                        Task {
                            await profileVM.toggleTraveled(country.id)
                            flashConfirm(.visited, for: country.id)
                        }
                    }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
            }
        }
        .frame(maxHeight: .infinity)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private var backgroundView: some View {
        Image("country-list")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

private struct LocalFloatingSearchBar: View {

    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {

        HStack(spacing: 10) {

            Image(systemName: "magnifyingglass")
                .foregroundColor(.black)

            TextField(
                "",
                text: $text,
                prompt: Text("Search countries or territories")
                    .foregroundStyle(Color.black.opacity(0.28))
            )
                .focused(isFocused)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .frame(maxWidth: .infinity)
                .frame(height: 28)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.94, green: 0.92, blue: 0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

private struct SwipeableCountryRow: View {
    let country: Country
    let isBucketed: Bool
    let isVisited: Bool
    let showConfirm: Bool
    let onTap: () -> Void
    let onBucket: () -> Void
    let onVisited: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(country.flagEmoji)
                .font(.system(size: 22))
                .frame(width: 28, alignment: .leading)

            Text(country.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            if showConfirm {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if let score = country.score {
                ScorePill(score: score)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onVisited) {
                Label("Visited", systemImage: isVisited ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .tint(.green)

            Button(action: onBucket) {
                Label("Bucket", systemImage: isBucketed ? "star.fill" : "star")
            }
            .tint(.yellow)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 58)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
