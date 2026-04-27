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

enum CountryListMode {
    case discovery
    case picker(
        kind: PlanningListKind,
        selectedIds: Set<String>,
        otherSelectedIds: Set<String>,
        onSelect: (Country) -> Void
    )
}

struct CountryListView: View {

    let showsSearchBar: Bool
    @Binding var searchText: String
    let countries: [Country]
    var appliesWeighting: Bool = true
    @Binding var sort: CountrySort
    @Binding var sortOrder: SortOrder
    var mode: CountryListMode = .discovery

    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var bucketListStore: BucketListStore
    @EnvironmentObject private var traveledStore: TraveledStore
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset

    @State private var visibleCountries: [Country] = []
    @State private var selectedCountry: Country?
    @State private var toast: CountryListToast?
    @FocusState private var isSearchFocused: Bool

    private func showToast(_ toast: CountryListToast) {
        self.toast = toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if self.toast?.id == toast.id {
                self.toast = nil
            }
        }
    }

    private func scheduleRecomputeVisible() {
        let displayCountries: [Country]
        if appliesWeighting {
            let weights = weightsStore.weights
            displayCountries = countries.map {
                $0.applyingOverallScore(
                    using: weights,
                    selectedMonth: weightsStore.selectedMonth
                )
            }
        } else {
            displayCountries = countries
        }

        let snapshotSearch = searchText
        let snapshotSort = sort
        let snapshotSortOrder = sortOrder

        let filtered: [Country]
        if snapshotSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = displayCountries
        } else {
            let normalizedSearch = snapshotSearch.normalizedSearchKey
            filtered = displayCountries.filter { country in
                country.localizedSearchableNames.contains {
                    $0.normalizedSearchKey.contains(normalizedSearch)
                }
            }
        }

        let baseSorted: [Country]
        switch snapshotSort {
        case .name:
            baseSorted = filtered.sorted {
                $0.localizedDisplayName.localizedCaseInsensitiveCompare($1.localizedDisplayName) == .orderedAscending
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
        .overlay(alignment: .top) {
            if let toast {
                CountryListToastView(toast: toast)
                    .padding(.horizontal, 18)
                    .padding(.top, showsSearchBar ? 64 : 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: toast?.id)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, floatingTabBarInset + 10)
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
        .onReceive(weightsStore.$selectedMonth) { _ in scheduleRecomputeVisible() }
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
                row(for: country)
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

    @ViewBuilder
    private func row(for country: Country) -> some View {
        switch mode {
        case .discovery:
            SwipeableCountryRow(
                country: country,
                isBucketed: bucketListStore.ids.contains(country.id),
                isVisited: traveledStore.ids.contains(country.id),
                onTap: {
                    selectedCountry = country
                },
                onBucket: {
                    Task {
                        let wasBucketed = bucketListStore.ids.contains(country.id)
                        await toggleBucket(country.id)
                        showToast(
                            .bucket(
                                countryName: country.localizedDisplayName,
                                didAdd: !wasBucketed
                            )
                        )
                    }
                },
                onVisited: {
                    Task {
                        let wasVisited = traveledStore.ids.contains(country.id)
                        await toggleVisited(country.id)
                        showToast(
                            .visited(
                                countryName: country.localizedDisplayName,
                                didAdd: !wasVisited
                            )
                        )
                    }
                }
            )
        case let .picker(kind, selectedIds, otherSelectedIds, onSelect):
            PlanningSelectableCountryRow(
                country: country,
                kind: kind,
                isInTargetList: selectedIds.contains(country.id),
                isInOtherList: otherSelectedIds.contains(country.id),
                onTap: {
                    onSelect(country)
                }
            )
        }
    }

    @MainActor
    private func toggleBucket(_ countryId: String) async {
        if sessionManager.isAuthenticated {
            if profileVM.viewedBucketListCountries != bucketListStore.ids {
                profileVM.viewedBucketListCountries = bucketListStore.ids
                profileVM.computeOrderedLists()
            }

            await profileVM.toggleBucket(countryId)
            bucketListStore.replace(with: profileVM.viewedBucketListCountries)
        } else {
            bucketListStore.toggle(countryId)
        }
    }

    @MainActor
    private func toggleVisited(_ countryId: String) async {
        if sessionManager.isAuthenticated {
            if profileVM.viewedTraveledCountries != traveledStore.ids {
                profileVM.viewedTraveledCountries = traveledStore.ids
                profileVM.computeOrderedLists()
            }

            await profileVM.toggleTraveled(countryId)
            traveledStore.replace(with: profileVM.viewedTraveledCountries)
        } else {
            traveledStore.toggle(countryId)
        }
    }
}

private struct CountryListToast: Identifiable {
    let id = UUID()
    let message: String
    let systemImage: String
    let tint: Color

    static func bucket(countryName: String, didAdd: Bool) -> CountryListToast {
        let key = didAdd
            ? "discovery.country_list.toast.bucket_added_format"
            : "discovery.country_list.toast.bucket_removed_format"
        return CountryListToast(
            message: String(format: String(localized: String.LocalizationValue(key)), locale: AppDisplayLocale.current, countryName),
            systemImage: didAdd ? "bookmark.fill" : "bookmark.slash",
            tint: .yellow
        )
    }

    static func visited(countryName: String, didAdd: Bool) -> CountryListToast {
        let key = didAdd
            ? "discovery.country_list.toast.visited_added_format"
            : "discovery.country_list.toast.visited_removed_format"
        return CountryListToast(
            message: String(format: String(localized: String.LocalizationValue(key)), locale: AppDisplayLocale.current, countryName),
            systemImage: didAdd ? "checkmark.circle.fill" : "minus.circle",
            tint: .green
        )
    }
}

private struct CountryListToastView: View {
    let toast: CountryListToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black.opacity(0.78))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(toast.tint.opacity(0.28))
                )

            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black.opacity(0.82))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
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
                prompt: Text("discovery.country_list.search_placeholder")
                    .foregroundStyle(Color.black.opacity(0.28))
            )
                .focused(isFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(.black)
                .tint(.black)
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
    let onTap: () -> Void
    let onBucket: () -> Void
    let onVisited: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(country.flagEmoji)
                .font(.system(size: 22))
                .frame(width: 28, alignment: .leading)

            Text(country.localizedDisplayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            trailingIndicators
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
                swipeActionLabel(
                    title: "planning.list_kind.visited.short",
                    systemImage: isVisited ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            .tint(isVisited ? .green : Color(red: 0.32, green: 0.72, blue: 0.40))

            Button(action: onBucket) {
                swipeActionLabel(
                    title: "planning.list_kind.bucket.short",
                    systemImage: isBucketed ? "bookmark.fill" : "bookmark"
                )
            }
            .tint(isBucketed ? .yellow : Color(red: 0.95, green: 0.72, blue: 0.22))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 58)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var trailingIndicators: some View {
        HStack(spacing: 8) {
            if isBucketed || isVisited {
                HStack(spacing: 5) {
                    if isBucketed {
                        membershipIcon(systemImage: "bookmark.fill", tint: .yellow)
                    }

                    if isVisited {
                        membershipIcon(systemImage: "checkmark.circle.fill", tint: .green)
                    }
                }
            }

            if let score = country.score {
                ScorePill(score: score)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func membershipIcon(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.black.opacity(0.72))
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(tint.opacity(0.28))
            )
            .overlay(
                Circle()
                    .stroke(tint.opacity(0.5), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func swipeActionLabel(title: LocalizedStringKey, systemImage: String) -> some View {
        if #available(iOS 26.0, *) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        } else {
            Label(title, systemImage: systemImage)
        }
    }
}

private struct PlanningSelectableCountryRow: View {
    let country: Country
    let kind: PlanningListKind
    let isInTargetList: Bool
    let isInOtherList: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(country.flagEmoji)
                    .font(.system(size: 22))
                    .frame(width: 28, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(country.localizedDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isInOtherList {
                        Text(kind.otherListLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.72))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.08))
                            )
                    }
                }

                Spacer(minLength: 12)

                if isInTargetList {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                } else if let score = country.score {
                    ScorePill(score: score)
                } else {
                    Image(systemName: kind.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(isInTargetList ? 0.52 : 0.80))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(isInTargetList ? 0.05 : 0.03), lineWidth: 1)
            )
            .opacity(isInTargetList ? 0.72 : 1.0)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 58)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
