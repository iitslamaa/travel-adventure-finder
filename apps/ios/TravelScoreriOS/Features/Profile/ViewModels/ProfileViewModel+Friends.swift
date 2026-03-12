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

        do {
            pendingRequestCount = try await friendService.fetchPendingRequestCount(for: userId)
        } catch {
            print("❌ failed to load pending request count:", error)
            pendingRequestCount = 0
        }
    }

    // MARK: - Mutual Friends

    func loadMutualFriends() async {
        let viewedUserId = self.userId
        guard
            let currentUserId = supabase.currentUserId,
            currentUserId != viewedUserId
        else {
            mutualFriends = []
            return
        }

        do {
            mutualFriends = try await friendService.fetchMutualFriends(
                currentUserId: currentUserId,
                otherUserId: viewedUserId
            )
        } catch {
            print("❌ failed to load mutual friends:", error)
            mutualFriends = []
        }
    }
}
