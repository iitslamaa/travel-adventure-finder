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
        let loadStartedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.enter user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "active_generation=\(loadGeneration.uuidString) guest=\(isGuestMode)"
        )
        if isGuestMode {
            guard generation == loadGeneration else { return }
            SocialFeedDebug.log(
                "profile.vm.load.guest.start user=\(userId.uuidString) generation=\(generation.uuidString)"
            )
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
            SocialFeedDebug.log(
                "profile.vm.load.guest.finish user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
            )
            return
        }

        let startingUserId = userId
        let isOwnProfile = startingUserId == supabase.currentUserId
        let hasRenderableSeed = profile?.id == startingUserId
        SocialFeedDebug.log(
            "profile.vm.load.prepare user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
            "own=\(isOwnProfile) renderable_seed=\(hasRenderableSeed) refreshing=\(isRefreshing) " +
            "profile=\(logField(profile?.id.uuidString)) duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
        )

        // Only show full-screen loading during initial load,
        // NOT during pull-to-refresh.
        if !isRefreshing && !hasRenderableSeed {
            isLoading = true
            SocialFeedDebug.log(
                "profile.vm.load.loading_state user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "is_loading=true reason=initial_without_seed duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
            )
        } else if hasRenderableSeed {
            isLoading = false
            SocialFeedDebug.log(
                "profile.vm.load.loading_state user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "is_loading=false reason=renderable_seed duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
            )
        }
        defer {
            if !isRefreshing && !hasRenderableSeed {
                isLoading = false
                SocialFeedDebug.log(
                    "profile.vm.load.defer_loading_clear user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
            }
        }
        errorMessage = nil

        do {
            SocialFeedDebug.log(
                "profile.vm.load.network_tasks.start user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
            )
            let shouldUseProfileCache = !isRefreshing
            SocialFeedDebug.log(
                "profile.vm.load.profile_cache_policy user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "use_cache=\(shouldUseProfileCache) refreshing=\(isRefreshing)"
            )
            let profileTask = Task {
                try await loadProfileTask(
                    userId: startingUserId,
                    generation: generation,
                    isOwnProfile: isOwnProfile,
                    useCache: shouldUseProfileCache
                )
            }
            let traveledTask = Task {
                try await loadTraveledTask(
                    userId: startingUserId,
                    generation: generation,
                    useCache: shouldUseProfileCache
                )
            }
            let bucketTask = Task {
                try await loadBucketTask(
                    userId: startingUserId,
                    generation: generation,
                    useCache: shouldUseProfileCache
                )
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
                    isOwnProfile: isOwnProfile,
                    useCache: shouldUseProfileCache
                )
            }

            if hasRenderableSeed && !isRefreshing {
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.start user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "reason=renderable_seed_waiting_for_secondary"
                )
                let relationshipAwaitStartedAt = Date()
                SocialFeedDebug.log("profile.vm.load.fast_path.await_relationship.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let resolvedRelationship = try await relationshipTask.value
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.await_relationship.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "await_duration=\(SocialFeedDebug.duration(since: relationshipAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )

                guard generation == loadGeneration,
                      self.userId == startingUserId else {
                    SocialFeedDebug.log(
                        "profile.vm.load.fast_path.relationship_discard user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                        "active_generation=\(loadGeneration.uuidString) current_user=\(self.userId.uuidString)"
                    )
                    profileTask.cancel()
                    traveledTask.cancel()
                    bucketTask.cancel()
                    passportPreferencesTask.cancel()
                    return
                }

                relationshipState = resolvedRelationship
                isFriend = resolvedRelationship == .friends
                isRelationshipLoading = false
                computeOrderedLists()
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.relationship_ready user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "relationship=\(relationshipLogValue(resolvedRelationship)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )

                let traveledAwaitStartedAt = Date()
                SocialFeedDebug.log("profile.vm.load.fast_path.await_traveled.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let traveled = try await traveledTask.value
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.await_traveled.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "await_duration=\(SocialFeedDebug.duration(since: traveledAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
                let bucketAwaitStartedAt = Date()
                SocialFeedDebug.log("profile.vm.load.fast_path.await_bucket.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let bucket = try await bucketTask.value
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.await_bucket.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "await_duration=\(SocialFeedDebug.duration(since: bucketAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
                let passportAwaitStartedAt = Date()
                SocialFeedDebug.log("profile.vm.load.fast_path.await_passport.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let fetchedPassportPreferences = try await passportPreferencesTask.value
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.await_passport.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "await_duration=\(SocialFeedDebug.duration(since: passportAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.secondary_done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "traveled=\(traveled.count) bucket=\(bucket.count) relationship=\(relationshipLogValue(resolvedRelationship))"
                )
                let fullProfileAwaitStartedAt = Date()
                SocialFeedDebug.log("profile.vm.load.fast_path.await_full_profile.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let fetchedProfile = try await profileTask.value
                SocialFeedDebug.log(
                    "profile.vm.load.fast_path.await_full_profile.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "await_duration=\(SocialFeedDebug.duration(since: fullProfileAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt)) " +
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
                    "profile=\(logField(profile?.id.uuidString)) relationship=\(relationshipLogValue(relationshipState)) " +
                    "total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
                return
            }

            let profileAwaitStartedAt = Date()
            SocialFeedDebug.log("profile.vm.load.await_profile.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let fetchedProfile = try await profileTask.value
            SocialFeedDebug.log(
                "profile.vm.load.await_profile.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "await_duration=\(SocialFeedDebug.duration(since: profileAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt)) " +
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
            SocialFeedDebug.log(
                "profile.vm.load.profile_ready_for_render user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "own=\(isOwnProfile) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
            )
            if isOwnProfile {
                relationshipState = .selfProfile
                isFriend = false
                isRelationshipLoading = false
                SocialFeedDebug.log(
                    "profile.vm.load.relationship_ready_for_render user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "relationship=selfProfile total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
            } else {
                let relationshipAwaitStartedAt = Date()
                SocialFeedDebug.log("profile.vm.load.await_relationship.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
                let resolvedRelationship = try await relationshipTask.value
                SocialFeedDebug.log(
                    "profile.vm.load.await_relationship.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "await_duration=\(SocialFeedDebug.duration(since: relationshipAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )

                guard generation == loadGeneration,
                      self.userId == startingUserId else {
                    SocialFeedDebug.log(
                        "profile.vm.load.relationship_task.discard user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                        "active_generation=\(loadGeneration.uuidString) current_user=\(self.userId.uuidString)"
                    )
                    return
                }

                relationshipState = resolvedRelationship
                isFriend = resolvedRelationship == .friends
                isRelationshipLoading = false
                SocialFeedDebug.log(
                    "profile.vm.load.relationship_task.done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "relationship=\(relationshipLogValue(resolvedRelationship)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
            }
            computeOrderedLists()

            let traveledAwaitStartedAt = Date()
            SocialFeedDebug.log("profile.vm.load.await_traveled.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let traveled = try await traveledTask.value
            SocialFeedDebug.log(
                "profile.vm.load.await_traveled.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "await_duration=\(SocialFeedDebug.duration(since: traveledAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
            )
            let bucketAwaitStartedAt = Date()
            SocialFeedDebug.log("profile.vm.load.await_bucket.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let bucket = try await bucketTask.value
            SocialFeedDebug.log(
                "profile.vm.load.await_bucket.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "await_duration=\(SocialFeedDebug.duration(since: bucketAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
            )
            let passportAwaitStartedAt = Date()
            SocialFeedDebug.log("profile.vm.load.await_passport.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)")
            let fetchedPassportPreferences = try await passportPreferencesTask.value
            SocialFeedDebug.log(
                "profile.vm.load.await_passport.end user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "await_duration=\(SocialFeedDebug.duration(since: passportAwaitStartedAt)) total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
            )
            SocialFeedDebug.log(
                "profile.vm.load.secondary_tasks.done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "traveled=\(traveled.count) bucket=\(bucket.count) relationship=\(relationshipLogValue(relationshipState)) " +
                "total_duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
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
                relationship: relationshipState,
                passportPreferences: fetchedPassportPreferences
            )

            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                return
            }

            Task { [weak self] in
                SocialFeedDebug.log(
                    "profile.vm.load.secondary_data.detached.start user=\(startingUserId.uuidString) generation=\(generation.uuidString)"
                )
                await self?.loadSecondaryData(generation: generation)
                SocialFeedDebug.log(
                    "profile.vm.load.secondary_data.detached.end user=\(startingUserId.uuidString) generation=\(generation.uuidString)"
                )
            }

        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                SocialFeedDebug.log(
                    "profile.vm.load.cancelled user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
                return
            }

            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                SocialFeedDebug.log(
                    "profile.vm.load.cancelled_ns user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "duration=\(SocialFeedDebug.duration(since: loadStartedAt))"
                )
                return
            }
            errorMessage = error.localizedDescription
            SocialFeedDebug.log(
                "profile.vm.load.error user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: loadStartedAt)) error=\(SocialFeedDebug.describe(error))"
            )
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

    private func loadProfileTask(userId: UUID, generation: UUID, isOwnProfile: Bool, useCache: Bool) async throws -> Profile {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.profile_task.start user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "own=\(isOwnProfile) use_cache=\(useCache)"
        )
        do {
            let profile = try await (isOwnProfile
                ? profileService.fetchOrCreateProfile(userId: userId, useCache: useCache)
                : profileService.fetchMyProfile(userId: userId, useCache: useCache))
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

    private func loadTraveledTask(userId: UUID, generation: UUID, useCache: Bool) async throws -> Set<String> {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.traveled_task.start user=\(userId.uuidString) generation=\(generation.uuidString) use_cache=\(useCache)"
        )
        do {
            if useCache, let cached = profileService.cachedTraveledCountries(userId: userId) {
                SocialFeedDebug.log(
                    "profile.vm.load.traveled_task.cache_hit user=\(userId.uuidString) generation=\(generation.uuidString) " +
                    "duration=\(SocialFeedDebug.duration(since: startedAt)) count=\(cached.count)"
                )
                return cached
            }
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

    private func loadBucketTask(userId: UUID, generation: UUID, useCache: Bool) async throws -> Set<String> {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.bucket_task.start user=\(userId.uuidString) generation=\(generation.uuidString) use_cache=\(useCache)"
        )
        do {
            if useCache, let cached = profileService.cachedBucketListCountries(userId: userId) {
                SocialFeedDebug.log(
                    "profile.vm.load.bucket_task.cache_hit user=\(userId.uuidString) generation=\(generation.uuidString) " +
                    "duration=\(SocialFeedDebug.duration(since: startedAt)) \(SocialFeedDebug.countrySetSummary(cached))"
                )
                return cached
            }
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

    private func loadPassportPreferencesTask(
        userId: UUID,
        generation: UUID,
        isOwnProfile: Bool,
        useCache: Bool
    ) async throws -> PassportPreferences {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.passport_task.start user=\(userId.uuidString) generation=\(generation.uuidString) " +
            "own=\(isOwnProfile) use_cache=\(useCache)"
        )
        do {
            if useCache, isOwnProfile, let cached = profileService.cachedPassportPreferences(userId: userId) {
                SocialFeedDebug.log(
                    "profile.vm.load.passport_task.cache_hit user=\(userId.uuidString) generation=\(generation.uuidString) " +
                    "duration=\(SocialFeedDebug.duration(since: startedAt)) nationalities=\(cached.nationalityCountryCodes.count)"
                )
                return cached
            }
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
