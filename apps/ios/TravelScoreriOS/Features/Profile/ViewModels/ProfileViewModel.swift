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
    @Published var hasLoadedPassportContext: Bool = false
    @Published var passportPreferences: PassportPreferences = .empty
    
    // MARK: - Dependencies
    let profileService: ProfileService
    let friendService: FriendService
    let supabase = SupabaseManager.shared
    let isGuestMode: Bool

    // ✅ Identity is now immutable (no rebinding)
    let userId: UUID

    var loadTask: Task<Void, Never>?
    var passportContextTask: Task<Void, Never>?
    var sessionWarmupTask: Task<Void, Never>?
    var loadGeneration: UUID = UUID()

    var passportNationalities: [String] {
        get { passportPreferences.nationalityCountryCodes }
        set {
            passportPreferences = PassportPreferences(
                nationalityCountryCodes: newValue,
                passportCountryCode: passportPreferences.passportCountryCode
            )
        }
    }

    var visaPassportCountryCode: String? {
        get { passportPreferences.passportCountryCode }
        set {
            passportPreferences = PassportPreferences(
                nationalityCountryCodes: passportPreferences.nationalityCountryCodes,
                passportCountryCode: newValue
            )
        }
    }

    var effectivePassportCountryCode: String? {
        passportPreferences.effectivePassportCountryCode
    }
    
    // MARK: - Init
    init(
        userId: UUID,
        profileService: ProfileService,
        friendService: FriendService,
        isGuestMode: Bool = false
    ) {
        self.userId = userId
        self.profileService = profileService
        self.friendService = friendService
        self.isGuestMode = isGuestMode
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
        SocialFeedDebug.log(
            "profile.vm.load_if_needed.enter user=\(userId.uuidString) profile=\(debugLogField(profile?.id.uuidString)) " +
            "has_loaded_core=\(hasLoadedCoreData) is_loading=\(isLoading) has_task=\(loadTask != nil)"
        )

        guard !hasLoadedCoreData || profile?.id != userId else {
            SocialFeedDebug.log(
                "profile.vm.load_if_needed.skip user=\(userId.uuidString) reason=already_loaded " +
                "profile=\(debugLogField(profile?.id.uuidString))"
            )
            return
        }

        if let existingTask = loadTask {
            SocialFeedDebug.log("profile.vm.load_if_needed.await_existing user=\(userId.uuidString)")
            await existingTask.value
            SocialFeedDebug.log(
                "profile.vm.load_if_needed.existing_done user=\(userId.uuidString) profile=\(debugLogField(profile?.id.uuidString))"
            )
            return
        }

        errorMessage = nil
        isRelationshipLoading = true

        let isSwitchingUsers = profile?.id != nil && profile?.id != userId
        let cachedProfile = profileService.cachedProfile(userId: userId)
        let cachedTraveled = profileService.cachedTraveledCountries(userId: userId)
        let cachedBucket = profileService.cachedBucketListCountries(userId: userId)
        SocialFeedDebug.log(
            "profile.vm.load_if_needed.cache_state user=\(userId.uuidString) switching=\(isSwitchingUsers) " +
            "cached_profile=\(cachedProfile != nil) cached_traveled=\(cachedTraveled != nil) cached_bucket=\(cachedBucket != nil)"
        )
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
            passportPreferences = .empty
            hasLoadedPassportContext = false
        }

        computeOrderedLists()
        isLoading = cachedProfile == nil && cachedTraveled == nil && cachedBucket == nil && profile?.id != userId

        cancelInFlightWork()

        let generation = UUID()
        loadGeneration = generation
        SocialFeedDebug.log(
            "profile.vm.load_if_needed.start_task user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "is_loading=\(isLoading)"
        )

        loadTask = Task { [weak self] in
            await self?.load(generation: generation)
        }

        await loadTask?.value
        isRelationshipLoading = false
        SocialFeedDebug.log(
            "profile.vm.load_if_needed.complete user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "profile=\(debugLogField(profile?.id.uuidString)) is_loading=\(isLoading) has_loaded_core=\(hasLoadedCoreData)"
        )
    }

    private func debugLogField(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "nil" }
        return value
    }

    func warmSessionCachesIfNeeded() async {
        guard !isGuestMode else { return }
        guard userId == supabase.currentUserId else { return }

        if hasLoadedPassportContext {
            return
        }

        if let existingTask = sessionWarmupTask {
            await existingTask.value
            return
        }

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            defer { self.sessionWarmupTask = nil }

            if !self.hasLoadedPassportContext {
                await self.loadPassportContextIfNeeded()
            }
        }

        sessionWarmupTask = task
        await task.value
    }

    func loadPassportContextIfNeeded() async {
        guard !hasLoadedPassportContext else { return }

        if isGuestMode {
            passportPreferences = .empty
            hasLoadedPassportContext = true
            return
        }

        guard userId == supabase.currentUserId else {
            hasLoadedPassportContext = true
            return
        }

        if let cachedPassportPreferences = profileService.cachedPassportPreferences(userId: userId) {
            passportPreferences = cachedPassportPreferences
            hasLoadedPassportContext = true
            return
        }

        if let existingTask = passportContextTask {
            await existingTask.value
            return
        }

        let startingUserId = userId
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.loadPassportContext(for: startingUserId)
        }
        passportContextTask = task
        await task.value
    }

    func cancelInFlightWork() {
        loadTask?.cancel()
        loadTask = nil
        passportContextTask?.cancel()
        passportContextTask = nil
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
        async let myProfileTask = currentUserProfile(userId: currentUserId)
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

    private func loadPassportContext(for startingUserId: UUID) async {
        defer { passportContextTask = nil }

        do {
            let fetchedPassportPreferences = try await profileService.fetchPassportPreferences(userId: startingUserId)

            guard self.userId == startingUserId else { return }

            passportPreferences = fetchedPassportPreferences
            hasLoadedPassportContext = true
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }

            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }
        }
    }

    private func currentUserProfile(userId: UUID) async throws -> Profile {
        if let cachedProfile = profileService.cachedProfile(userId: userId) {
            return cachedProfile
        }

        return try await profileService.fetchMyProfile(userId: userId)
    }
}
