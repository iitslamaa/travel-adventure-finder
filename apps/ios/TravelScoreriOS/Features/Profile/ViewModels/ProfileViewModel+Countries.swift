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

    func toggleBucket(_ countryId: String, recordActivity: Bool = true) async {
        SocialFeedDebug.log(
            "profile.bucket.toggle.start user=\(userId) country=\(countryId) guest=\(isGuestMode) before_\(SocialFeedDebug.countrySetSummary(viewedBucketListCountries))"
        )
        if isGuestMode {
            let wasInBucket = viewedBucketListCountries.contains(countryId)
            if wasInBucket {
                viewedBucketListCountries.remove(countryId)
            } else {
                viewedBucketListCountries.insert(countryId)
            }
            computeOrderedLists()
            SocialFeedDebug.log(
                "profile.bucket.toggle.guest.end user=\(userId) country=\(countryId) was_in_bucket=\(wasInBucket) after_\(SocialFeedDebug.countrySetSummary(viewedBucketListCountries))"
            )
            return
        }

        guard let currentUserId = supabase.currentUserId else {
            return
        }

        let wasInBucket = viewedBucketListCountries.contains(countryId)
        SocialFeedDebug.log(
            "profile.bucket.toggle.optimistic user=\(userId) country=\(countryId) was_in_bucket=\(wasInBucket) before_\(SocialFeedDebug.countrySetSummary(viewedBucketListCountries))"
        )

        // Optimistic UI update
        if wasInBucket {
            viewedBucketListCountries.remove(countryId)
        } else {
            viewedBucketListCountries.insert(countryId)
        }

        computeOrderedLists()
        SocialFeedDebug.log(
            "profile.bucket.toggle.optimistic_applied user=\(userId) country=\(countryId) after_\(SocialFeedDebug.countrySetSummary(viewedBucketListCountries))"
        )

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

                if recordActivity {
                    try? await SocialActivityService().recordCountryListActivity(
                        actorUserId: currentUserId,
                        eventType: .bucketListAdded,
                        countryIds: [countryId]
                    )
                }
            }

            SocialFeedDebug.log(
                "profile.bucket.toggle.remote_success user=\(userId) country=\(countryId) was_in_bucket=\(wasInBucket) after_\(SocialFeedDebug.countrySetSummary(viewedBucketListCountries))"
            )
            SocialFeedDebug.log("profile.bucket.toggle.notification user=\(userId) country=\(countryId) posting=socialActivityUpdated")
            NotificationCenter.default.post(name: .socialActivityUpdated, object: nil)
        } catch {
            // Rollback if server write fails
            if wasInBucket {
                viewedBucketListCountries.insert(countryId)
            } else {
                viewedBucketListCountries.remove(countryId)
            }

            computeOrderedLists()
            SocialFeedDebug.log(
                "profile.bucket.toggle.error user=\(userId) country=\(countryId) rolled_back_\(SocialFeedDebug.countrySetSummary(viewedBucketListCountries)) error=\(SocialFeedDebug.describe(error))"
            )
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Traveled Toggle

    func toggleTraveled(_ countryId: String, recordActivity: Bool = true) async {
        SocialFeedDebug.log("profile.traveled.toggle.start user=\(userId) country=\(countryId) guest=\(isGuestMode)")
        if isGuestMode {
            let wasVisited = viewedTraveledCountries.contains(countryId)
            if wasVisited {
                viewedTraveledCountries.remove(countryId)
            } else {
                viewedTraveledCountries.insert(countryId)
            }
            computeOrderedLists()
            SocialFeedDebug.log("profile.traveled.toggle.guest.end user=\(userId) country=\(countryId) was_visited=\(wasVisited) new_count=\(viewedTraveledCountries.count)")
            return
        }

        let currentUserId = self.userId

        let wasVisited = viewedTraveledCountries.contains(countryId)
        SocialFeedDebug.log("profile.traveled.toggle.optimistic user=\(userId) country=\(countryId) was_visited=\(wasVisited)")

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

                if recordActivity {
                    try? await SocialActivityService().recordCountryListActivity(
                        actorUserId: currentUserId,
                        eventType: .countryVisited,
                        countryIds: [countryId]
                    )
                }
            }

            SocialFeedDebug.log("profile.traveled.toggle.notification user=\(userId) country=\(countryId) posting=socialActivityUpdated")
            NotificationCenter.default.post(name: .socialActivityUpdated, object: nil)
        } catch {
            // Rollback on failure
            if wasVisited {
                viewedTraveledCountries.insert(countryId)
            } else {
                viewedTraveledCountries.remove(countryId)
            }

            computeOrderedLists()
            SocialFeedDebug.log("profile.traveled.toggle.error user=\(userId) country=\(countryId) error=\(SocialFeedDebug.describe(error))")
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
