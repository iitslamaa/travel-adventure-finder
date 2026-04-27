//
//  ProfileViewModel+Friends.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/19/26.
//

import Foundation
import Combine
import Supabase
import PostgREST

extension ProfileViewModel {

    // MARK: - Pending Friend Request Count

    func loadPendingRequestCount() async {
        let userId = self.userId
        let startedAt = Date()
        SocialFeedDebug.log("profile.vm.pending_requests.start user=\(userId.uuidString)")

        do {
            pendingRequestCount = try await friendService.fetchPendingRequestCount(for: userId)
            SocialFeedDebug.log(
                "profile.vm.pending_requests.success user=\(userId.uuidString) count=\(pendingRequestCount) duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
        } catch {
            SocialFeedDebug.log(
                "profile.vm.pending_requests.error user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            pendingRequestCount = 0
        }
    }

    // MARK: - Mutual Friends

    func loadMutualFriends() async {
        let viewedUserId = self.userId
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.vm.mutual_friends.start viewed_user=\(viewedUserId.uuidString) current_user=\(supabase.currentUserId?.uuidString ?? "nil")"
        )
        guard
            let currentUserId = supabase.currentUserId,
            currentUserId != viewedUserId
        else {
            mutualFriends = []
            SocialFeedDebug.log(
                "profile.vm.mutual_friends.skip viewed_user=\(viewedUserId.uuidString) reason=current_user_missing_or_self"
            )
            return
        }

        do {
            mutualFriends = try await friendService.fetchMutualFriends(
                currentUserId: currentUserId,
                otherUserId: viewedUserId
            )
            SocialFeedDebug.log(
                "profile.vm.mutual_friends.success viewed_user=\(viewedUserId.uuidString) count=\(mutualFriends.count) duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
        } catch {
            SocialFeedDebug.log(
                "profile.vm.mutual_friends.error viewed_user=\(viewedUserId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            mutualFriends = []
        }
    }
}
