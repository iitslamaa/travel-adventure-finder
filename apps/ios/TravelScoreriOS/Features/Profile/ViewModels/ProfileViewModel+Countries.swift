//
//  ProfileViewModel+Countries.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/19/26.
//

import Foundation
import Supabase

extension ProfileViewModel {

    // MARK: - Bucket Toggle

    func toggleBucket(_ countryId: String) async {
        if isGuestMode {
            let wasInBucket = viewedBucketListCountries.contains(countryId)
            if wasInBucket {
                viewedBucketListCountries.remove(countryId)
            } else {
                viewedBucketListCountries.insert(countryId)
            }
            computeOrderedLists()
            return
        }

        guard let currentUserId = supabase.currentUserId else {
            print("❌ toggleBucket: No current user")
            return
        }

        let wasInBucket = viewedBucketListCountries.contains(countryId)

        // Optimistic UI update
        if wasInBucket {
            viewedBucketListCountries.remove(countryId)
        } else {
            viewedBucketListCountries.insert(countryId)
        }

        computeOrderedLists()

        do {
            if wasInBucket {
                try await profileService.removeFromBucketList(
                    userId: currentUserId,
                    countryCode: countryId
                )
            } else {
                try await profileService.addToBucketList(
                    userId: currentUserId,
                    countryCode: countryId
                )

                try? await SocialActivityService().recordActivity(
                    actorUserId: currentUserId,
                    eventType: .bucketListAdded,
                    metadata: ["country_code": countryId.uppercased()]
                )
            }

            NotificationCenter.default.post(name: .socialActivityUpdated, object: nil)
        } catch {
            // Rollback if server write fails
            if wasInBucket {
                viewedBucketListCountries.insert(countryId)
            } else {
                viewedBucketListCountries.remove(countryId)
            }

            computeOrderedLists()

            print("❌ toggleBucket rolled back due to error:", error)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Traveled Toggle

    func toggleTraveled(_ countryId: String) async {
        if isGuestMode {
            let wasVisited = viewedTraveledCountries.contains(countryId)
            if wasVisited {
                viewedTraveledCountries.remove(countryId)
            } else {
                viewedTraveledCountries.insert(countryId)
            }
            computeOrderedLists()
            return
        }

        let currentUserId = self.userId

        let wasVisited = viewedTraveledCountries.contains(countryId)

        // Optimistic UI update
        if wasVisited {
            viewedTraveledCountries.remove(countryId)
        } else {
            viewedTraveledCountries.insert(countryId)
        }

        computeOrderedLists()

        do {
            if wasVisited {
                try await supabase.client
                    .from("user_traveled")
                    .delete()
                    .eq("user_id", value: currentUserId.uuidString)
                    .eq("country_id", value: countryId)
                    .execute()
            } else {
                try await supabase.client
                    .from("user_traveled")
                    .insert([
                        "user_id": currentUserId.uuidString,
                        "country_id": countryId
                    ])
                    .execute()

                try? await SocialActivityService().recordActivity(
                    actorUserId: currentUserId,
                    eventType: .countryVisited,
                    metadata: ["country_code": countryId.uppercased()]
                )
            }

            NotificationCenter.default.post(name: .socialActivityUpdated, object: nil)
        } catch {
            // Rollback on failure
            if wasVisited {
                viewedTraveledCountries.insert(countryId)
            } else {
                viewedTraveledCountries.remove(countryId)
            }

            computeOrderedLists()

            print("❌ toggleTraveled rolled back due to error:", error)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mutual Bucket Logic
    
    private func computeMutualBucketList(
        currentUserCountries: [String],
        viewedUserCountries: [String]
    ) {
        let currentSet = Set(currentUserCountries)
        let viewedSet = Set(viewedUserCountries)
        mutualBucketCountries = Array(currentSet.intersection(viewedSet)).sorted()
    }

    // MARK: - Ordering

    func computeOrderedLists() {
        let mutualBucketSet = Set(mutualBucketCountries)
        orderedBucketListCountries = viewedBucketListCountries.sorted {
            let lhsIsMutual = mutualBucketSet.contains($0)
            let rhsIsMutual = mutualBucketSet.contains($1)

            if lhsIsMutual != rhsIsMutual {
                return lhsIsMutual
            }
            return $0 < $1
        }

        let mutualTraveledSet = Set(mutualTraveledCountries)
        orderedTraveledCountries = viewedTraveledCountries.sorted {
            let lhsIsMutual = mutualTraveledSet.contains($0)
            let rhsIsMutual = mutualTraveledSet.contains($1)

            if lhsIsMutual != rhsIsMutual {
                return lhsIsMutual
            }
            return $0 < $1
        }
    }
}
