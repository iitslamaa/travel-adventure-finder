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
        let startingUserId = userId
        let isOwnProfile = startingUserId == supabase.currentUserId

        // Only show full-screen loading during initial load,
        // NOT during pull-to-refresh.
        if !isRefreshing {
            isLoading = true
        }
        defer {
            if !isRefreshing {
                isLoading = false
            }
        }
        errorMessage = nil

        do {
            async let fetchedProfileTask: Profile = isOwnProfile
                ? profileService.fetchOrCreateProfile(userId: startingUserId)
                : profileService.fetchMyProfile(userId: startingUserId)
            async let traveledTask = profileService.fetchTraveledCountries(userId: startingUserId)
            async let bucketTask = profileService.fetchBucketListCountries(userId: startingUserId)
            async let relationshipTask = resolvedRelationshipState(for: startingUserId)

            let fetchedProfile = try await fetchedProfileTask
            let traveled = try await traveledTask
            let bucket = try await bucketTask
            let resolvedRelationship = try await relationshipTask

            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                return
            }

            profile = fetchedProfile
            viewedTraveledCountries = traveled
            viewedBucketListCountries = bucket
            relationshipState = resolvedRelationship
            isFriend = resolvedRelationship == .friends
            mutualLanguages = []
            mutualBucketCountries = []
            mutualTraveledCountries = []
            computeOrderedLists()
            hasLoadedCoreData = true

            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                return
            }

            Task { [weak self] in
                await self?.loadSecondaryData(generation: generation)
            }

        } catch {
            print("❌ load() failed:", error)
            errorMessage = error.localizedDescription
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
