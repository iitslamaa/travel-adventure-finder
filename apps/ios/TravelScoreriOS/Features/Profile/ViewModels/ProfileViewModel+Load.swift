//
//  ProfileViewModel+Load.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/19/26.
//

import Foundation
import Supabase
import Auth

extension ProfileViewModel {

    // MARK: - Load

    func load(generation: UUID) async {
        SocialFeedDebug.log(
            "profile.vm.load.enter user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "active_generation=\(loadGeneration.uuidString) guest=\(isGuestMode)"
        )
        if isGuestMode {
            guard generation == loadGeneration else { return }
            profile = nil
            viewedTraveledCountries = []
            viewedBucketListCountries = []
            relationshipState = .none
            isFriend = false
            mutualLanguages = []
            mutualBucketCountries = []
            mutualTraveledCountries = []
            mutualFriends = []
            friends = []
            pendingRequestCount = 0
            passportPreferences = .empty
            computeOrderedLists()
            hasLoadedCoreData = true
            hasLoadedPassportContext = true
            isLoading = false
            errorMessage = nil
            return
        }

        let startingUserId = userId
        let isOwnProfile = startingUserId == supabase.currentUserId
        let hasRenderableSeed = profile?.id == startingUserId
        SocialFeedDebug.log(
            "profile.vm.load.prepare user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
            "own=\(isOwnProfile) renderable_seed=\(hasRenderableSeed) refreshing=\(isRefreshing) " +
            "profile=\(logField(profile?.id.uuidString))"
        )

        // Only show full-screen loading during initial load,
        // NOT during pull-to-refresh.
        if !isRefreshing && !hasRenderableSeed {
            isLoading = true
        } else if hasRenderableSeed {
            isLoading = false
        }
        defer {
            if !isRefreshing && !hasRenderableSeed {
                isLoading = false
            }
        }
        errorMessage = nil

        do {
            SocialFeedDebug.log(
                "profile.vm.load.network_tasks.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)"
            )
            let profileTask = Task {
                try await loadProfileTask(
                    userId: startingUserId,
                    generation: generation,
                    isOwnProfile: isOwnProfile
                )
            }
            let traveledTask = Task {
                try await loadTraveledTask(userId: startingUserId, generation: generation)
            }
            let bucketTask = Task {
                try await loadBucketTask(userId: startingUserId, generation: generation)
            }
            let relationshipTask = Task {
                try await loadRelationshipTask(
                    userId: startingUserId,
                    generation: generation,
                    isOwnProfile: isOwnProfile
                )
            }
            let passportPreferencesTask = Task {
                try await loadPassportPreferencesTask(
                    userId: startingUserId,
                    generation: generation,
                    isOwnProfile: isOwnProfile
                )
            }

            if hasRenderableSeed && !isRefreshing {
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.start user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "reason=renderable_seed_waiting_for_secondary"
                )
                SocialFeedDebug.log("profile.vm.load.fast_path.await_traveled user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let traveled = try await traveledTask.value
                SocialFeedDebug.log("profile.vm.load.fast_path.await_bucket user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let bucket = try await bucketTask.value
                SocialFeedDebug.log("profile.vm.load.fast_path.await_relationship user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let resolvedRelationship = try await relationshipTask.value
                SocialFeedDebug.log("profile.vm.load.fast_path.await_passport user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let fetchedPassportPreferences = try await passportPreferencesTask.value
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.secondary_done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "traveled=\(traveled.count) bucket=\(bucket.count) relationship=\(relationshipLogValue(resolvedRelationship))"
                )
                SocialFeedDebug.log("profile.vm.load.fast_path.await_full_profile user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let fetchedProfile = try await profileTask.value
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.full_profile_done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "fetched=\(fetchedProfile.id.uuidString) \(profileDetailDebugSummary(fetchedProfile))"
                )

                guard generation == loadGeneration,
                      self.userId == startingUserId else {
                    SocialFeedDebug.log(
                        "profile.vm.load.fast_path.discard user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                        "active_generation=\(loadGeneration.uuidString) current_user=\(self.userId.uuidString)"
                    )
                    profileTask.cancel()
                    return
                }

                applyFetchedProfile(fetchedProfile, userId: startingUserId, isOwnProfile: isOwnProfile)
                applyLoadedContext(
                    traveled: traveled,
                    bucket: bucket,
                    relationship: resolvedRelationship,
                    passportPreferences: fetchedPassportPreferences
                )
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.ready user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "profile=\(logField(profile?.id.uuidString)) relationship=\(relationshipLogValue(relationshipState))"
                )
                return
            }

            SocialFeedDebug.log("profile.vm.load.await_profile user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let fetchedProfile = try await profileTask.value
            SocialFeedDebug.log(
                "profile.vm.load.profile_task.done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "fetched=\(fetchedProfile.id.uuidString) \(profileDetailDebugSummary(fetchedProfile))"
            )
            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                SocialFeedDebug.log(
                    "profile.vm.load.profile_task.discard user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "active_generation=\(loadGeneration.uuidString) current_user=\(self.userId.uuidString)"
                )
                return
            }

            applyFetchedProfile(fetchedProfile, userId: startingUserId, isOwnProfile: isOwnProfile)
            if isOwnProfile {
                relationshipState = .selfProfile
                isFriend = false
            }
            computeOrderedLists()

            SocialFeedDebug.log("profile.vm.load.await_traveled user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let traveled = try await traveledTask.value
            SocialFeedDebug.log("profile.vm.load.await_bucket user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let bucket = try await bucketTask.value
            SocialFeedDebug.log("profile.vm.load.await_relationship user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let resolvedRelationship = try await relationshipTask.value
            SocialFeedDebug.log("profile.vm.load.await_passport user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let fetchedPassportPreferences = try await passportPreferencesTask.value
            SocialFeedDebug.log(
                "profile.vm.load.secondary_tasks.done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "traveled=\(traveled.count) bucket=\(bucket.count) relationship=\(relationshipLogValue(resolvedRelationship))"
            )

            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                SocialFeedDebug.log(
                    "profile.vm.load.secondary_tasks.discard user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "active_generation=\(loadGeneration.uuidString) current_user=\(self.userId.uuidString)"
                )
                return
            }

            applyLoadedContext(
                traveled: traveled,
                bucket: bucket,
                relationship: resolvedRelationship,
                passportPreferences: fetchedPassportPreferences
            )

            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                return
            }

            Task { [weak self] in
                await self?.loadSecondaryData(generation: generation)
            }

        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }

            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }

            print("❌ load() failed:", error)
            errorMessage = error.localizedDescription
        }
    }

    private func logField(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "nil" : trimmed
    }

    private func relationshipLogValue(_ state: RelationshipState) -> String {
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

    private func applyFetchedProfile(_ fetchedProfile: Profile, userId: UUID, isOwnProfile: Bool) {
        profile = fetchedProfile
        let changedFriendCacheEntries = friendService.refreshCachedProfile(fetchedProfile)
        SocialFeedDebug.log(
            "profile.load.profile_applied user=\(userId.uuidString) is_own=\(isOwnProfile) " +
            "username=\(logField(fetchedProfile.username)) avatar=\(logField(fetchedProfile.avatarUrl)) " +
            "\(profileDetailDebugSummary(fetchedProfile)) friend_cache_changes=\(changedFriendCacheEntries)"
        )
        if let defaultCurrencyCode = fetchedProfile.defaultCurrencyCode {
            UserDefaults.standard.set(
                defaultCurrencyCode,
                forKey: "travelaf.default_currency_code"
            )
        }
    }

    private func applyLoadedContext(
        traveled: Set<String>,
        bucket: Set<String>,
        relationship: RelationshipState,
        passportPreferences fetchedPassportPreferences: PassportPreferences
    ) {
        viewedTraveledCountries = traveled
        viewedBucketListCountries = bucket
        relationshipState = relationship
        isFriend = relationship == .friends
        mutualLanguages = []
        mutualBucketCountries = []
        mutualTraveledCountries = []
        passportPreferences = fetchedPassportPreferences
        computeOrderedLists()
        hasLoadedCoreData = true
        hasLoadedPassportContext = true
    }

    private func applyBackgroundProfileRefresh(
        _ fetchedProfile: Profile,
        userId: UUID,
        generation: UUID,
        startedAt: Date
    ) {
        guard generation == loadGeneration,
              self.userId == userId else {
            SocialFeedDebug.log(
                "profile.vm.load.fast_path.profile_refresh.discard user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) active_generation=\(loadGeneration.uuidString) " +
                "current_user=\(self.userId.uuidString)"
            )
            return
        }

        applyFetchedProfile(fetchedProfile, userId: userId, isOwnProfile: userId == supabase.currentUserId)
        computeOrderedLists()
        SocialFeedDebug.log(
            "profile.vm.load.fast_path.profile_refresh.applied user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "duration=\(SocialFeedDebug.duration(since: startedAt)) username=\(logField(fetchedProfile.username)) " +
            "avatar=\(logField(fetchedProfile.avatarUrl))"
        )
    }

    private func logBackgroundProfileRefreshError(
        userId: UUID,
        generation: UUID,
        startedAt: Date,
        error: Error
    ) {
        SocialFeedDebug.log(
            "profile.vm.load.fast_path.profile_refresh.error user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
        )
    }

    private func profileDetailDebugSummary(_ profile: Profile) -> String {
        [
            "languages=\(profile.languages.count)",
            "lived=\(profile.livedCountries.count)",
            "travel_style=\(profile.travelStyle.count)",
            "travel_mode=\(profile.travelMode.count)",
            "next=\(logField(profile.nextDestination))",
            "current=\(logField(profile.currentCountry))",
            "favorites=\(profile.favoriteCountries?.count ?? 0)",
            "onboarding=\(profile.onboardingCompleted.map(String.init) ?? "nil")",
            "friend_count=\(profile.friendCount)"
        ].joined(separator: " ")
    }

    private func loadProfileTask(userId: UUID, generation: UUID, isOwnProfile: Bool) async throws -> Profile {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.profile_task.start user=\(userId.uuidString) generation=\(generation.uuidString) own=\(isOwnProfile)"
        )
        do {
            let profile = try await (isOwnProfile
                ? profileService.fetchOrCreateProfile(userId: userId, useCache: false)
                : profileService.fetchMyProfile(userId: userId, useCache: false))
            SocialFeedDebug.log(
                "profile.vm.load.profile_task.success user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) fetched=\(profile.id.uuidString) " +
                profileDetailDebugSummary(profile)
            )
            return profile
        } catch {
            SocialFeedDebug.log(
                "profile.vm.load.profile_task.error user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    private func loadTraveledTask(userId: UUID, generation: UUID) async throws -> Set<String> {
        let startedAt = Date()
        SocialFeedDebug.log("profile.vm.load.traveled_task.start user=\(userId.uuidString) generation=\(generation.uuidString)")
        do {
            let traveled = try await profileService.fetchTraveledCountries(userId: userId)
            SocialFeedDebug.log(
                "profile.vm.load.traveled_task.success user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) count=\(traveled.count)"
            )
            return traveled
        } catch {
            SocialFeedDebug.log(
                "profile.vm.load.traveled_task.error user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    private func loadBucketTask(userId: UUID, generation: UUID) async throws -> Set<String> {
        let startedAt = Date()
        SocialFeedDebug.log("profile.vm.load.bucket_task.start user=\(userId.uuidString) generation=\(generation.uuidString)")
        do {
            let bucket = try await profileService.fetchBucketListCountries(userId: userId)
            SocialFeedDebug.log(
                "profile.vm.load.bucket_task.success user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) \(SocialFeedDebug.countrySetSummary(bucket))"
            )
            return bucket
        } catch {
            SocialFeedDebug.log(
                "profile.vm.load.bucket_task.error user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    private func loadRelationshipTask(userId: UUID, generation: UUID, isOwnProfile: Bool) async throws -> RelationshipState {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.relationship_task.start user=\(userId.uuidString) generation=\(generation.uuidString) own=\(isOwnProfile)"
        )
        do {
            let relationship: RelationshipState = isOwnProfile ? .selfProfile : try await resolvedRelationshipState(for: userId)
            SocialFeedDebug.log(
                "profile.vm.load.relationship_task.success user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            return relationship
        } catch {
            SocialFeedDebug.log(
                "profile.vm.load.relationship_task.error user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    private func loadPassportPreferencesTask(userId: UUID, generation: UUID, isOwnProfile: Bool) async throws -> PassportPreferences {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.passport_task.start user=\(userId.uuidString) generation=\(generation.uuidString) own=\(isOwnProfile)"
        )
        do {
            let preferences: PassportPreferences = isOwnProfile
                ? try await profileService.fetchPassportPreferences(userId: userId)
                : .empty
            SocialFeedDebug.log(
                "profile.vm.load.passport_task.success user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            return preferences
        } catch {
            SocialFeedDebug.log(
                "profile.vm.load.passport_task.error user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    func refreshProfile() async {
        let generation = UUID()
        loadGeneration = generation
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.load(generation: generation)
        }
    }

    private func resolvedRelationshipState(for viewedUserId: UUID) async throws -> RelationshipState {
        if isGuestMode {
            return .none
        }

        _ = try? await supabase.client.auth.session

        guard let currentUserId = supabase.currentUserId else {
            return .none
        }

        return try await friendService.fetchRelationshipState(
            currentUserId: currentUserId,
            otherUserId: viewedUserId
        )
    }
}
