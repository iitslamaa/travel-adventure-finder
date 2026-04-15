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
            async let passportPreferencesTask: PassportPreferences = isOwnProfile
                ? profileService.fetchPassportPreferences(userId: startingUserId)
                : .empty

            let fetchedProfile = try await fetchedProfileTask
            let traveled = try await traveledTask
            let bucket = try await bucketTask
            let resolvedRelationship = try await relationshipTask
            let fetchedPassportPreferences = try await passportPreferencesTask

            guard generation == loadGeneration,
                  self.userId == startingUserId else {
                return
            }

            profile = fetchedProfile
            if let defaultCurrencyCode = fetchedProfile.defaultCurrencyCode {
                UserDefaults.standard.set(
                    defaultCurrencyCode,
                    forKey: "travelaf.default_currency_code"
                )
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
