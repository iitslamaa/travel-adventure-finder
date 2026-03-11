//
//  ProfileViewModel.swift
//  TravelScoreriOS
//


import Foundation
import Combine
import PostgREST
import Supabase

enum RelationshipState {
    case selfProfile
    case none
    case requestSent
    case requestReceived
    case friends
}

@MainActor
final class ProfileViewModel: ObservableObject {
    
    // MARK: - Published state
    @Published var profile: Profile? {
        didSet { }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFriend: Bool = false
    @Published var isFriendLoading: Bool = false
    @Published var relationshipState: RelationshipState = .none
    @Published var isRelationshipLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var viewedTraveledCountries: Set<String> = [] {
        didSet {
            ReviewTriggerService.shared
                .evaluateAndTriggerReviewIfEligible(
                    visitedCount: viewedTraveledCountries.count
                )
        }
    }
    @Published var viewedBucketListCountries: Set<String> = [] {
        didSet { }
    }
    @Published var friends: [Profile] = [] {
        didSet { }
    }
    @Published var mutualBucketCountries: [String] = []
    @Published var mutualTraveledCountries: [String] = []
    @Published var mutualLanguages: [String] = []
    @Published var pendingRequestCount: Int = 0
    @Published var mutualFriends: [Profile] = []
    @Published var orderedBucketListCountries: [String] = [] {
        didSet { }
    }
    @Published var orderedTraveledCountries: [String] = [] {
        didSet { }
    }
    @Published var hasLoadedCoreData: Bool = false
    
    // MARK: - Dependencies
    let profileService: ProfileService
    let friendService: FriendService
    let supabase = SupabaseManager.shared

    // ✅ Identity is now immutable (no rebinding)
    let userId: UUID

    var loadTask: Task<Void, Never>?
    var loadGeneration: UUID = UUID()
    
    // MARK: - Init
    init(
        userId: UUID,
        profileService: ProfileService,
        friendService: FriendService
    ) {
        self.userId = userId
        self.profileService = profileService
        self.friendService = friendService
    }
    
    // MARK: - Pull to Refresh Support

    /// Forces a full reload even if the same user is already bound.
    /// This is used by `.refreshable` in ProfileView.
    func reloadProfile() async {
        isRefreshing = true
        errorMessage = nil

        cancelInFlightWork()

        let generation = UUID()
        loadGeneration = generation

        loadTask = Task { [weak self] in
            await self?.load(generation: generation)
        }

        await loadTask?.value

        isRefreshing = false
    }
    
    // MARK: - Identity-Safe Lifecycle

    func loadIfNeeded() async {
        guard !hasLoadedCoreData || profile?.id != userId else { return }

        errorMessage = nil
        isRelationshipLoading = true

        let isSwitchingUsers = profile?.id != nil && profile?.id != userId
        let cachedProfile = profileService.cachedProfile(userId: userId)
        let cachedTraveled = profileService.cachedTraveledCountries(userId: userId)
        let cachedBucket = profileService.cachedBucketListCountries(userId: userId)

        if let cachedProfile {
            profile = cachedProfile
        } else if isSwitchingUsers {
            profile = nil
        }

        if let cachedTraveled {
            viewedTraveledCountries = cachedTraveled
        } else if isSwitchingUsers {
            viewedTraveledCountries = []
        }

        if let cachedBucket {
            viewedBucketListCountries = cachedBucket
        } else if isSwitchingUsers {
            viewedBucketListCountries = []
        }

        if isSwitchingUsers {
            relationshipState = .none
            friends = []
            orderedBucketListCountries = []
            orderedTraveledCountries = []
            mutualFriends = []
            mutualBucketCountries = []
            mutualTraveledCountries = []
            mutualLanguages = []
        }

        computeOrderedLists()
        isLoading = cachedProfile == nil && cachedTraveled == nil && cachedBucket == nil

        cancelInFlightWork()

        let generation = UUID()
        loadGeneration = generation

        loadTask = Task { [weak self] in
            await self?.load(generation: generation)
        }

        await loadTask?.value
        isRelationshipLoading = false
    }

    func cancelInFlightWork() {
        loadTask?.cancel()
        loadTask = nil
    }

    func loadSecondaryData(generation: UUID) async {
        let viewedUserId = userId

        if viewedUserId == supabase.currentUserId {
            await loadPendingRequestCount()
            return
        }

        guard let currentUserId = supabase.currentUserId else { return }

        async let myTraveledTask = profileService.fetchTraveledCountries(userId: currentUserId)
        async let myBucketTask = profileService.fetchBucketListCountries(userId: currentUserId)
        async let myProfileTask = profileService.fetchMyProfile(userId: currentUserId)
        async let mutualFriendsTask = friendService.fetchMutualFriends(
            currentUserId: currentUserId,
            otherUserId: viewedUserId
        )

        do {
            let myTraveled = try await myTraveledTask
            let myBucket = try await myBucketTask
            let myProfile = try await myProfileTask
            let fetchedMutualFriends = try await mutualFriendsTask

            guard generation == loadGeneration,
                  self.userId == viewedUserId else {
                return
            }

            let normalizedMyTraveled = Set(
                myTraveled.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            )
            let normalizedMyBucket = Set(
                myBucket.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            )
            let normalizedViewedTraveled = Set(
                viewedTraveledCountries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            )
            let normalizedViewedBucket = Set(
                viewedBucketListCountries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            )

            mutualTraveledCountries = Array(normalizedMyTraveled.intersection(normalizedViewedTraveled))
            mutualBucketCountries = Array(normalizedMyBucket.intersection(normalizedViewedBucket))

            if let viewedLanguages = profile?.languages {
                let myLanguageCodes = Set(myProfile.languages.map { $0.code.uppercased() })
                let viewedLanguageCodes = Set(viewedLanguages.map { $0.code.uppercased() })
                mutualLanguages = Array(myLanguageCodes.intersection(viewedLanguageCodes))
            }

            mutualFriends = fetchedMutualFriends
            computeOrderedLists()
        } catch {
            print("❌ secondary profile load failed:", error)
        }
    }

    func ensureFriendsLoaded() async {
        guard friends.isEmpty else { return }

        do {
            friends = try await friendService.fetchFriends(for: userId)
        } catch {
            print("❌ failed to load friends list:", error)
        }
    }
    
    // MARK: - Optimistic Avatar Update (Meta Gold Standard)
    func updateAvatarLocally(to newUrl: String?) {
        guard var current = profile else { return }
        current.avatarUrl = newUrl
        profile = current
    }
}
