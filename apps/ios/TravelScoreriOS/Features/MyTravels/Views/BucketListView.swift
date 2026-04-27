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
            SocialFeedDebug.log(
                "bucket.view.store_receive before_\(SocialFeedDebug.countrySetSummary(bucketCountryIds)) incoming_\(SocialFeedDebug.countrySetSummary(ids))"
            )
            bucketCountryIds = ids
        }
    }

    @MainActor
    private func loadBucketListIfNeeded() async {
        SocialFeedDebug.log(
            "bucket.view.load.start has_loaded=\(hasLoadedOnce) local_\(SocialFeedDebug.countrySetSummary(bucketCountryIds)) store_\(SocialFeedDebug.countrySetSummary(bucketListStore.ids)) user=\(sessionManager.userId?.uuidString ?? "nil")"
        )
        if countries.isEmpty,
           let cached = CountryAPI.loadCachedCountries(),
           !cached.isEmpty {
            countries = cached
            SocialFeedDebug.log("bucket.view.load.countries_cache count=\(cached.count)")
        }

        if bucketCountryIds.isEmpty || !hasLoadedOnce {
            bucketCountryIds = bucketListStore.ids
            SocialFeedDebug.log(
                "bucket.view.load.seed_from_store local_\(SocialFeedDebug.countrySetSummary(bucketCountryIds))"
            )
        }

        let shouldShowBlockingLoad = !hasLoadedOnce && countries.isEmpty && bucketCountryIds.isEmpty
        isLoading = shouldShowBlockingLoad
        hasLoadedOnce = true

        let userId = sessionManager.userId
        let service = ProfileService(supabase: SupabaseManager.shared)
        async let freshCountriesTask = CountryAPI.refreshCountriesIfNeeded(minInterval: 60)
        async let bucketFetchTask: Set<String>? = {
            guard let userId else { return nil }
            return try? await service.fetchBucketListCountries(userId: userId)
        }()

        if let bucket = await bucketFetchTask {
            SocialFeedDebug.log(
                "bucket.view.load.remote_bucket user=\(userId?.uuidString ?? "nil") remote_\(SocialFeedDebug.countrySetSummary(bucket)) before_local_\(SocialFeedDebug.countrySetSummary(bucketCountryIds))"
            )
            bucketCountryIds = bucket
            bucketListStore.replace(with: bucket)
        } else {
            SocialFeedDebug.log("bucket.view.load.remote_bucket.nil user=\(userId?.uuidString ?? "nil")")
        }

        if let fresh = await freshCountriesTask, !fresh.isEmpty {
            countries = fresh
            SocialFeedDebug.log("bucket.view.load.countries_fresh count=\(fresh.count)")
        }

        isLoading = false
        SocialFeedDebug.log(
            "bucket.view.load.end local_\(SocialFeedDebug.countrySetSummary(bucketCountryIds)) store_\(SocialFeedDebug.countrySetSummary(bucketListStore.ids))"
        )
    }

    @MainActor
    private func saveBucketCountries(_ updatedIds: Set<String>) async {
        let previousIds = bucketCountryIds
        SocialFeedDebug.log(
            "bucket.view.save.start auth=\(sessionManager.isAuthenticated) previous_\(SocialFeedDebug.countrySetSummary(previousIds)) updated_\(SocialFeedDebug.countrySetSummary(updatedIds)) profile_before_\(SocialFeedDebug.countrySetSummary(profileVM.viewedBucketListCountries)) store_before_\(SocialFeedDebug.countrySetSummary(bucketListStore.ids))"
        )

        if sessionManager.isAuthenticated {
            if profileVM.viewedBucketListCountries != bucketCountryIds {
                SocialFeedDebug.log(
                    "bucket.view.save.profile_seed previous_profile_\(SocialFeedDebug.countrySetSummary(profileVM.viewedBucketListCountries)) seed_\(SocialFeedDebug.countrySetSummary(bucketCountryIds))"
                )
                profileVM.viewedBucketListCountries = bucketCountryIds
                profileVM.computeOrderedLists()
            }

            let removals = previousIds.subtracting(updatedIds).sorted()
            let additions = updatedIds.subtracting(previousIds).sorted()
            SocialFeedDebug.log(
                "bucket.view.save.diff removals=[\(removals.joined(separator: ","))] additions=[\(additions.joined(separator: ","))]"
            )

            for countryId in removals {
                SocialFeedDebug.log("bucket.view.save.remove.begin country=\(countryId)")
                await profileVM.toggleBucket(countryId, recordActivity: false)
                SocialFeedDebug.log(
                    "bucket.view.save.remove.end country=\(countryId) profile_now_\(SocialFeedDebug.countrySetSummary(profileVM.viewedBucketListCountries))"
                )
            }

            for countryId in additions {
                SocialFeedDebug.log("bucket.view.save.add.begin country=\(countryId)")
                await profileVM.toggleBucket(countryId, recordActivity: false)
                SocialFeedDebug.log(
                    "bucket.view.save.add.end country=\(countryId) profile_now_\(SocialFeedDebug.countrySetSummary(profileVM.viewedBucketListCountries))"
                )
            }

            if let userId = sessionManager.userId, !additions.isEmpty {
                try? await SocialActivityService().recordCountryListActivity(
                    actorUserId: userId,
                    eventType: .bucketListAdded,
                    countryIds: additions
                )
            }

            let latestIds = profileVM.viewedBucketListCountries
            SocialFeedDebug.log(
                "bucket.view.save.apply_latest latest_\(SocialFeedDebug.countrySetSummary(latestIds)) desired_\(SocialFeedDebug.countrySetSummary(updatedIds))"
            )
            bucketCountryIds = latestIds
            bucketListStore.replace(with: latestIds)
        } else {
            bucketCountryIds = updatedIds
            bucketListStore.replace(with: updatedIds)
        }
        SocialFeedDebug.log(
            "bucket.view.save.end local_\(SocialFeedDebug.countrySetSummary(bucketCountryIds)) profile_\(SocialFeedDebug.countrySetSummary(profileVM.viewedBucketListCountries)) store_\(SocialFeedDebug.countrySetSummary(bucketListStore.ids))"
        )
    }
}

#Preview {
    NavigationStack {
        BucketListView()
    }
}
