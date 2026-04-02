//
//  BucketListView.swift
//  TravelScoreriOS
//

import SwiftUI

struct BucketListView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var bucketListStore: BucketListStore
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var traveledStore: TraveledStore
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset
    @State private var countries: [Country] = []
    @State private var bucketCountryIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var hasLoadedOnce: Bool = false
    @State private var showingAddCountries = false

    private var bucketedCountries: [Country] {
        countries
            .filter { bucketCountryIds.contains($0.id) }
            .sorted { $0.localizedDisplayName.localizedCaseInsensitiveCompare($1.localizedDisplayName) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("common.loading")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bucketedCountries.isEmpty {
                ContentUnavailableView(
                    PlanningListKind.bucket.emptyTitle,
                    systemImage: PlanningListKind.bucket.emptySystemImage,
                    description: Text(PlanningListKind.bucket.emptyDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(bucketedCountries) { country in
                            NavigationLink {
                                CountryDetailView(country: country)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(country.flagEmoji)
                                        .font(.largeTitle)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(country.localizedDisplayName)
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
        .navigationTitle("planning.bucket_list.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddCountries = true
                } label: {
                    Text("common.edit")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
        }
        .sheet(isPresented: $showingAddCountries) {
            NavigationStack {
                PlanningCountryPickerView(
                    kind: .bucket,
                    countries: countries,
                    selectedIds: bucketCountryIds,
                    otherSelectedIds: traveledStore.ids,
                    onSave: { updatedIds in
                        Task {
                            await saveBucketCountries(updatedIds)
                        }
                    }
                )
            }
            .presentationDragIndicator(.visible)
        }
        .task {
            await loadBucketListIfNeeded()
        }
        .onReceive(bucketListStore.$ids) { ids in
            bucketCountryIds = ids
        }
    }

    @MainActor
    private func loadBucketListIfNeeded() async {
        if countries.isEmpty,
           let cached = CountryAPI.loadCachedCountries(),
           !cached.isEmpty {
            countries = cached
        }

        if bucketCountryIds.isEmpty || !hasLoadedOnce {
            bucketCountryIds = bucketListStore.ids
        }

        let shouldShowBlockingLoad = !hasLoadedOnce && countries.isEmpty && bucketCountryIds.isEmpty
        isLoading = shouldShowBlockingLoad
        hasLoadedOnce = true

        let isAuthenticated = sessionManager.isAuthenticated
        let userId = sessionManager.userId
        let service = ProfileService(supabase: SupabaseManager.shared)
        async let freshCountriesTask = CountryAPI.refreshCountriesIfNeeded(minInterval: 60)
        async let profileLoadTask: Void = {
            guard isAuthenticated else { return }
            await profileVM.loadIfNeeded()
        }()
        async let bucketFetchTask: Set<String>? = {
            guard let userId else { return nil }
            return try? await service.fetchBucketListCountries(userId: userId)
        }()

        _ = await profileLoadTask

        if let bucket = await bucketFetchTask {
            bucketCountryIds = bucket
            bucketListStore.replace(with: bucket)
        }

        if let fresh = await freshCountriesTask, !fresh.isEmpty {
            countries = fresh
        }

        isLoading = false
    }

    @MainActor
    private func saveBucketCountries(_ updatedIds: Set<String>) async {
        let previousIds = bucketCountryIds

        if sessionManager.isAuthenticated {
            if profileVM.viewedBucketListCountries != bucketCountryIds {
                profileVM.viewedBucketListCountries = bucketCountryIds
                profileVM.computeOrderedLists()
            }

            let removals = previousIds.subtracting(updatedIds).sorted()
            let additions = updatedIds.subtracting(previousIds).sorted()

            for countryId in removals {
                await profileVM.toggleBucket(countryId)
            }

            for countryId in additions {
                await profileVM.toggleBucket(countryId)
            }

            let latestIds = profileVM.viewedBucketListCountries
            bucketCountryIds = latestIds
            bucketListStore.replace(with: latestIds)
        } else {
            bucketCountryIds = updatedIds
            bucketListStore.replace(with: updatedIds)
        }
    }
}

#Preview {
    NavigationStack {
        BucketListView()
    }
}
