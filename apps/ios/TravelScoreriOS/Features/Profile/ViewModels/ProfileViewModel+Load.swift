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
            async let fetchedProfileTask = loadProfileTask(
                userId: startingUserId,
                generation: generation,
                isOwnProfile: isOwnProfile
            )
            async let traveledTask = loadTraveledTask(userId: startingUserId, generation: generation)
            async let bucketTask = loadBucketTask(userId: startingUserId, generation: generation)
            async let relationshipTask = loadRelationshipTask(
                userId: startingUserId,
                generation: generation,
                isOwnProfile: isOwnProfile
            )
            async let passportPreferencesTask = loadPassportPreferencesTask(
                userId: startingUserId,
                generation: generation,
                isOwnProfile: isOwnProfile
            )

            let fetchedProfile = try await fetchedProfileTask
            SocialFeedDebug.log(
                "profile.vm.load.profile_task.done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "fetched=\(fetchedProfile.id.uuidString)"
            )
            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                SocialFeedDebug.log(
                    "profile.vm.load.profile_task.discard user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "active_generation=\(loadGeneration.uuidString) current_user=\(self.userId.uuidString)"
                )
                return
            }

            profile = fetchedProfile
            let changedFriendCacheEntries = friendService.refreshCachedProfile(fetchedProfile)
            SocialFeedDebug.log(
                "profile.load.profile_applied user=\(startingUserId.uuidString) is_own=\(isOwnProfile) " +
                "username=\(logField(fetchedProfile.username)) avatar=\(logField(fetchedProfile.avatarUrl)) " +
                "friend_cache_changes=\(changedFriendCacheEntries)"
            )
            if let defaultCurrencyCode = fetchedProfile.defaultCurrencyCode {
                UserDefaults.standard.set(
                    defaultCurrencyCode,
                    forKey: "travelaf.default_currency_code"
                )
            }
            if isOwnProfile {
                relationshipState = .selfProfile
                isFriend = false
            }
            computeOrderedLists()

            let traveled = try await traveledTask
            let bucket = try await bucketTask
            let resolvedRelationship = try await relationshipTask
            let fetchedPassportPreferences = try await passportPreferencesTask
            SocialFeedDebug.log(
                "profile.vm.load.secondary_tasks.done user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                "traveled=\(traveled.count) bucket=\(bucket.count)"
            )

            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                SocialFeedDebug.log(
                    "profile.vm.load.secondary_tasks.discard user=\(startingUserId.uuidString) generation=\(generation.uuidString) " +
                    "active_generation=\(loadGeneration.uuidString) current_user=\(self.userId.uuidString)"
                )
                return
            }

            viewedTraveledCountries = traveled
            viewedBucketListCountries = bucket
            relationshipState = resolvedRelationship
            isFriend = resolvedRelationship == .friends
            mutualLanguages = []
            mutualBucketCountries = []
            mutualTraveledCountries = []
            passportPreferences = fetchedPassportPreferences
            computeOrderedLists()
            hasLoadedCoreData = true
            hasLoadedPassportContext = true

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

    private func loadProfileTask(userId: UUID, generation: UUID, isOwnProfile: Bool) async throws -> Profile {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.load.profile_task.start user=\(userId.uuidString) generation=\(generation.uuidString) own=\(isOwnProfile)"
        )
        do {
            let profile = try await (isOwnProfile
                ? profileService.fetchOrCreateProfile(userId: userId)
                : profileService.fetchMyProfile(userId: userId, useCache: false))
            SocialFeedDebug.log(
                "profile.vm.load.profile_task.success user=\(userId.uuidString) generation=\(generation.uuidString) " +
                "duration=\(SocialFeedDebug.duration(since: startedAt)) fetched=\(profile.id.uuidString)"
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
                "duration=\(SocialFeedDebug.duration(since: startedAt)) count=\(bucket.count)"
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
