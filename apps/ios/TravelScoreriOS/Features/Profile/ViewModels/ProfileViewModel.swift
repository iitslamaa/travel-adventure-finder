//
//  ProfileViewModel.swift
//  TravelScoreriOS
//


import Foundation
import Combine
import PostgREST
import Supabase

enum RelationshipState: Equatable {
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
        didSet {
            SocialFeedDebug.log(
                "profile.vm.state.profile user=\(userId.uuidString) old=\(debugLogField(oldValue?.id.uuidString)) " +
                "new=\(debugLogField(profile?.id.uuidString)) username=\(debugLogField(profile?.username)) " +
                "languages=\(profile?.languages.count ?? 0) lived=\(profile?.livedCountries.count ?? 0) " +
                "travel_style=\(profile?.travelStyle.count ?? 0) travel_mode=\(profile?.travelMode.count ?? 0) " +
                "friend_count=\(profile?.friendCount ?? -1)"
            )
        }
    }
    @Published var isLoading = false {
        didSet {
            guard oldValue != isLoading else { return }
            SocialFeedDebug.log("profile.vm.state.is_loading user=\(userId.uuidString) old=\(oldValue) new=\(isLoading)")
        }
    }
    @Published var errorMessage: String? {
        didSet {
            guard oldValue != errorMessage else { return }
            SocialFeedDebug.log(
                "profile.vm.state.error user=\(userId.uuidString) old=\(debugLogField(oldValue)) new=\(debugLogField(errorMessage))"
            )
        }
    }
    @Published var isFriend: Bool = false {
        didSet {
            guard oldValue != isFriend else { return }
            SocialFeedDebug.log("profile.vm.state.is_friend user=\(userId.uuidString) old=\(oldValue) new=\(isFriend)")
        }
    }
    @Published var isFriendLoading: Bool = false {
        didSet {
            guard oldValue != isFriendLoading else { return }
            SocialFeedDebug.log("profile.vm.state.is_friend_loading user=\(userId.uuidString) old=\(oldValue) new=\(isFriendLoading)")
        }
    }
    @Published var relationshipState: RelationshipState = .none {
        didSet {
            guard oldValue != relationshipState else { return }
            SocialFeedDebug.log(
                "profile.vm.state.relationship user=\(userId.uuidString) old=\(debugRelationship(oldValue)) new=\(debugRelationship(relationshipState))"
            )
        }
    }
    @Published var isRelationshipLoading: Bool = false {
        didSet {
            guard oldValue != isRelationshipLoading else { return }
            SocialFeedDebug.log(
                "profile.vm.state.relationship_loading user=\(userId.uuidString) old=\(oldValue) new=\(isRelationshipLoading)"
            )
        }
    }
    @Published var isRefreshing: Bool = false {
        didSet {
            guard oldValue != isRefreshing else { return }
            SocialFeedDebug.log("profile.vm.state.refreshing user=\(userId.uuidString) old=\(oldValue) new=\(isRefreshing)")
        }
    }
    @Published var viewedTraveledCountries: Set<String> = [] {
        didSet {
            SocialFeedDebug.log(
                "profile.vm.state.traveled user=\(userId.uuidString) old=\(oldValue.count) new=\(viewedTraveledCountries.count)"
            )
            ReviewTriggerService.shared
                .evaluateAndTriggerReviewIfEligible(
                    visitedCount: viewedTraveledCountries.count
                )
        }
    }
    @Published var viewedBucketListCountries: Set<String> = [] {
        didSet {
            SocialFeedDebug.log(
                "profile.vm.state.bucket user=\(userId.uuidString) old_\(SocialFeedDebug.countrySetSummary(oldValue)) " +
                "new_\(SocialFeedDebug.countrySetSummary(viewedBucketListCountries))"
            )
        }
    }
    @Published var friends: [Profile] = [] {
        didSet {
            SocialFeedDebug.log(
                "profile.vm.state.friends user=\(userId.uuidString) old=\(oldValue.count) new=\(friends.count)"
            )
        }
    }
    @Published var mutualBucketCountries: [String] = [] {
        didSet { SocialFeedDebug.log("profile.vm.state.mutual_bucket user=\(userId.uuidString) old=\(oldValue.count) new=\(mutualBucketCountries.count)") }
    }
    @Published var mutualTraveledCountries: [String] = [] {
        didSet { SocialFeedDebug.log("profile.vm.state.mutual_traveled user=\(userId.uuidString) old=\(oldValue.count) new=\(mutualTraveledCountries.count)") }
    }
    @Published var mutualLanguages: [String] = [] {
        didSet { SocialFeedDebug.log("profile.vm.state.mutual_languages user=\(userId.uuidString) old=\(oldValue.count) new=\(mutualLanguages.count)") }
    }
    @Published var pendingRequestCount: Int = 0 {
        didSet {
            guard oldValue != pendingRequestCount else { return }
            SocialFeedDebug.log("profile.vm.state.pending_requests user=\(userId.uuidString) old=\(oldValue) new=\(pendingRequestCount)")
        }
    }
    @Published var mutualFriends: [Profile] = [] {
        didSet { SocialFeedDebug.log("profile.vm.state.mutual_friends user=\(userId.uuidString) old=\(oldValue.count) new=\(mutualFriends.count)") }
    }
    @Published var orderedBucketListCountries: [String] = [] {
        didSet { SocialFeedDebug.log("profile.vm.state.ordered_bucket user=\(userId.uuidString) old=\(oldValue.count) new=\(orderedBucketListCountries.count)") }
    }
    @Published var orderedTraveledCountries: [String] = [] {
        didSet { SocialFeedDebug.log("profile.vm.state.ordered_traveled user=\(userId.uuidString) old=\(oldValue.count) new=\(orderedTraveledCountries.count)") }
    }
    @Published var hasLoadedCoreData: Bool = false {
        didSet {
            guard oldValue != hasLoadedCoreData else { return }
            SocialFeedDebug.log("profile.vm.state.has_core user=\(userId.uuidString) old=\(oldValue) new=\(hasLoadedCoreData)")
        }
    }
    @Published var hasLoadedPassportContext: Bool = false {
        didSet {
            guard oldValue != hasLoadedPassportContext else { return }
            SocialFeedDebug.log("profile.vm.state.has_passport_context user=\(userId.uuidString) old=\(oldValue) new=\(hasLoadedPassportContext)")
        }
    }
    @Published var passportPreferences: PassportPreferences = .empty {
        didSet {
            SocialFeedDebug.log(
                "profile.vm.state.passport user=\(userId.uuidString) old_nationalities=\(oldValue.nationalityCountryCodes.count) " +
                "new_nationalities=\(passportPreferences.nationalityCountryCodes.count) old_passport=\(debugLogField(oldValue.passportCountryCode)) " +
                "new_passport=\(debugLogField(passportPreferences.passportCountryCode))"
            )
        }
    }
    
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
        SocialFeedDebug.log(
            "profile.vm.reload.enter user=\(userId.uuidString) profile=\(debugLogField(profile?.id.uuidString)) " +
            "has_core=\(hasLoadedCoreData) has_task=\(loadTask != nil)"
        )
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
        SocialFeedDebug.log(
            "profile.vm.reload.exit user=\(userId.uuidString) profile=\(debugLogField(profile?.id.uuidString)) " +
            "has_core=\(hasLoadedCoreData) error=\(debugLogField(errorMessage))"
        )
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
        let isSwitchingUsers = profile?.id != nil && profile?.id != userId
        let cachedProfile = profileService.cachedProfile(userId: userId)
        let cachedTraveled = profileService.cachedTraveledCountries(userId: userId)
        let cachedBucket = profileService.cachedBucketListCountries(userId: userId)
        SocialFeedDebug.log(
            "profile.vm.load_if_needed.cache_state user=\(userId.uuidString) switching=\(isSwitchingUsers) " +
            "cached_profile=\(cachedProfile != nil) cached_traveled=\(cachedTraveled != nil) cached_bucket=\(cachedBucket != nil)"
        )
        if let cachedProfile {
            SocialFeedDebug.log(
                "profile.vm.load_if_needed.apply_cached_profile user=\(userId.uuidString) " +
                "username=\(debugLogField(cachedProfile.username)) languages=\(cachedProfile.languages.count)"
            )
            profile = cachedProfile
        } else if isSwitchingUsers {
            SocialFeedDebug.log("profile.vm.load_if_needed.clear_profile user=\(userId.uuidString) reason=switching_no_cache")
            profile = nil
        }

        if let cachedTraveled {
            SocialFeedDebug.log("profile.vm.load_if_needed.apply_cached_traveled user=\(userId.uuidString) count=\(cachedTraveled.count)")
            viewedTraveledCountries = cachedTraveled
        } else if isSwitchingUsers {
            SocialFeedDebug.log("profile.vm.load_if_needed.clear_traveled user=\(userId.uuidString) reason=switching_no_cache")
            viewedTraveledCountries = []
        }

        if let cachedBucket {
            SocialFeedDebug.log(
                "profile.vm.load_if_needed.apply_cached_bucket user=\(userId.uuidString) \(SocialFeedDebug.countrySetSummary(cachedBucket))"
            )
            viewedBucketListCountries = cachedBucket
        } else if isSwitchingUsers {
            SocialFeedDebug.log("profile.vm.load_if_needed.clear_bucket user=\(userId.uuidString) reason=switching_no_cache")
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
        SocialFeedDebug.log(
            "profile.vm.load_if_needed.after_seed user=\(userId.uuidString) profile=\(debugLogField(profile?.id.uuidString)) " +
            "traveled=\(viewedTraveledCountries.count) bucket_\(SocialFeedDebug.countrySetSummary(viewedBucketListCountries)) is_loading=\(isLoading)"
        )

        isRelationshipLoading = true
        defer {
            isRelationshipLoading = false
        }

        cancelInFlightWork()

        let generation = UUID()
        loadGeneration = generation
        SocialFeedDebug.log(
            "profile.vm.load_if_needed.start_task user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "is_loading=\(isLoading)"
        )

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.load(generation: generation)
        }
        loadTask = task

        await task.value
        if loadTask == task {
            loadTask = nil
        }
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
        SocialFeedDebug.log(
            "profile.vm.session_warmup.enter user=\(userId.uuidString) guest=\(isGuestMode) current_user=\(supabase.currentUserId?.uuidString ?? "nil") has_passport=\(hasLoadedPassportContext)"
        )
        guard !isGuestMode else {
            SocialFeedDebug.log("profile.vm.session_warmup.skip user=\(userId.uuidString) reason=guest")
            return
        }
        guard userId == supabase.currentUserId else {
            SocialFeedDebug.log("profile.vm.session_warmup.skip user=\(userId.uuidString) reason=not_current_user")
            return
        }

        if hasLoadedPassportContext {
            SocialFeedDebug.log("profile.vm.session_warmup.skip user=\(userId.uuidString) reason=passport_loaded")
            return
        }

        if let existingTask = sessionWarmupTask {
            SocialFeedDebug.log("profile.vm.session_warmup.await_existing user=\(userId.uuidString)")
            await existingTask.value
            SocialFeedDebug.log("profile.vm.session_warmup.existing_done user=\(userId.uuidString)")
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
        SocialFeedDebug.log("profile.vm.session_warmup.done user=\(userId.uuidString) has_passport=\(hasLoadedPassportContext)")
    }

    func loadPassportContextIfNeeded() async {
        SocialFeedDebug.log(
            "profile.vm.passport_if_needed.enter user=\(userId.uuidString) has_passport=\(hasLoadedPassportContext) guest=\(isGuestMode)"
        )
        guard !hasLoadedPassportContext else {
            SocialFeedDebug.log("profile.vm.passport_if_needed.skip user=\(userId.uuidString) reason=already_loaded")
            return
        }

        if isGuestMode {
            passportPreferences = .empty
            hasLoadedPassportContext = true
            SocialFeedDebug.log("profile.vm.passport_if_needed.guest_done user=\(userId.uuidString)")
            return
        }

        guard userId == supabase.currentUserId else {
            hasLoadedPassportContext = true
            SocialFeedDebug.log("profile.vm.passport_if_needed.skip user=\(userId.uuidString) reason=not_current_user")
            return
        }

        if let cachedPassportPreferences = profileService.cachedPassportPreferences(userId: userId) {
            SocialFeedDebug.log(
                "profile.vm.passport_if_needed.cache_hit user=\(userId.uuidString) nationalities=\(cachedPassportPreferences.nationalityCountryCodes.count)"
            )
            passportPreferences = cachedPassportPreferences
            hasLoadedPassportContext = true
            return
        }

        if let existingTask = passportContextTask {
            SocialFeedDebug.log("profile.vm.passport_if_needed.await_existing user=\(userId.uuidString)")
            await existingTask.value
            SocialFeedDebug.log("profile.vm.passport_if_needed.existing_done user=\(userId.uuidString)")
            return
        }

        let startingUserId = userId
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.loadPassportContext(for: startingUserId)
        }
        passportContextTask = task
        await task.value
        SocialFeedDebug.log("profile.vm.passport_if_needed.done user=\(userId.uuidString) has_passport=\(hasLoadedPassportContext)")
    }

    func cancelInFlightWork() {
        SocialFeedDebug.log(
            "profile.vm.cancel_in_flight user=\(userId.uuidString) load_task=\(loadTask != nil) passport_task=\(passportContextTask != nil)"
        )
        loadTask?.cancel()
        loadTask = nil
        passportContextTask?.cancel()
        passportContextTask = nil
    }

    func loadSecondaryData(generation: UUID) async {
        let viewedUserId = userId
        SocialFeedDebug.log(
            "profile.vm.secondary.enter user=\(viewedUserId.uuidString) generation=\(generation.uuidString) current_user=\(supabase.currentUserId?.uuidString ?? "nil")"
        )

        if viewedUserId == supabase.currentUserId {
            SocialFeedDebug.log("profile.vm.secondary.pending_requests.start user=\(viewedUserId.uuidString)")
            await loadPendingRequestCount()
            SocialFeedDebug.log("profile.vm.secondary.pending_requests.end user=\(viewedUserId.uuidString) count=\(pendingRequestCount)")
            return
        }

        guard let currentUserId = supabase.currentUserId else {
            SocialFeedDebug.log("profile.vm.secondary.skip user=\(viewedUserId.uuidString) reason=current_user_nil")
            return
        }

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
                SocialFeedDebug.log(
                    "profile.vm.secondary.discard user=\(viewedUserId.uuidString) generation=\(generation.uuidString) " +
                    "active_generation=\(loadGeneration.uuidString) current_viewed_user=\(self.userId.uuidString)"
                )
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
            SocialFeedDebug.log(
                "profile.vm.secondary.success user=\(viewedUserId.uuidString) mutual_traveled=\(mutualTraveledCountries.count) " +
                "mutual_bucket=\(mutualBucketCountries.count) mutual_languages=\(mutualLanguages.count) mutual_friends=\(mutualFriends.count)"
            )
        } catch {
            SocialFeedDebug.log("profile.vm.secondary.error user=\(viewedUserId.uuidString) error=\(SocialFeedDebug.describe(error))")
        }
    }

    func ensureFriendsLoaded() async {
        SocialFeedDebug.log("profile.vm.friends_if_needed.enter user=\(userId.uuidString) existing=\(friends.count)")
        guard friends.isEmpty else {
            SocialFeedDebug.log("profile.vm.friends_if_needed.skip user=\(userId.uuidString) reason=already_loaded")
            return
        }

        do {
            friends = try await friendService.fetchFriends(for: userId)
            SocialFeedDebug.log("profile.vm.friends_if_needed.success user=\(userId.uuidString) count=\(friends.count)")
        } catch {
            SocialFeedDebug.log("profile.vm.friends_if_needed.error user=\(userId.uuidString) error=\(SocialFeedDebug.describe(error))")
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
        let startedAt = Date()
        SocialFeedDebug.log("profile.vm.passport_context.start user=\(startingUserId.uuidString)")

        do {
            let fetchedPassportPreferences = try await profileService.fetchPassportPreferences(userId: startingUserId)

            guard self.userId == startingUserId else {
                SocialFeedDebug.log(
                    "profile.vm.passport_context.discard user=\(startingUserId.uuidString) current_user=\(self.userId.uuidString)"
                )
                return
            }

            passportPreferences = fetchedPassportPreferences
            hasLoadedPassportContext = true
            SocialFeedDebug.log(
                "profile.vm.passport_context.success user=\(startingUserId.uuidString) nationalities=\(fetchedPassportPreferences.nationalityCountryCodes.count) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                SocialFeedDebug.log("profile.vm.passport_context.cancelled user=\(startingUserId.uuidString) kind=url")
                return
            }

            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                SocialFeedDebug.log("profile.vm.passport_context.cancelled user=\(startingUserId.uuidString) kind=nsurl")
                return
            }

            SocialFeedDebug.log(
                "profile.vm.passport_context.error user=\(startingUserId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) " +
                "error=\(SocialFeedDebug.describe(error))"
            )
        }
    }

    private func currentUserProfile(userId: UUID) async throws -> Profile {
        if let cachedProfile = profileService.cachedProfile(userId: userId) {
            SocialFeedDebug.log("profile.vm.current_user_profile.cache_hit user=\(userId.uuidString)")
            return cachedProfile
        }

        SocialFeedDebug.log("profile.vm.current_user_profile.network user=\(userId.uuidString)")
        return try await profileService.fetchMyProfile(userId: userId)
    }

    private func debugRelationship(_ state: RelationshipState) -> String {
        switch state {
        case .selfProfile:
            return "selfProfile"
        case .none:
            return "none"
        case .requestSent:
            return "requestSent"
        case .requestReceived:
            return "requestReceived"
        case .friends:
            return "friends"
        }
    }
}
