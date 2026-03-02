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
        guard profile?.id != userId else { return }

        isLoading = true
        errorMessage = nil
        isRelationshipLoading = true

        // 🔒 Reset visible state to prevent stale UI flash
        profile = nil
        relationshipState = .none
        friends = []
        viewedTraveledCountries = []
        viewedBucketListCountries = []
        orderedBucketListCountries = []
        orderedTraveledCountries = []
        mutualFriends = []
        mutualBucketCountries = []
        mutualTraveledCountries = []
        mutualLanguages = []

        cancelInFlightWork()

        let generation = UUID()
        loadGeneration = generation

        loadTask = Task { [weak self] in
            await self?.load(generation: generation)
        }

        await loadTask?.value
        isRelationshipLoading = false
        isLoading = false
    }

    func cancelInFlightWork() {
        loadTask?.cancel()
        loadTask = nil
    }
    
    // MARK: - Optimistic Avatar Update (Meta Gold Standard)
    func updateAvatarLocally(to newUrl: String?) {
        guard var current = profile else { return }
        current.avatarUrl = newUrl
        profile = current
    }
}
