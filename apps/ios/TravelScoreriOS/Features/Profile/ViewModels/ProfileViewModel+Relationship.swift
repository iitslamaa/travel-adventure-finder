//
//  ProfileViewModel+Relationship.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/19/26.
//

import Foundation
import Supabase
import PostgREST

extension ProfileViewModel {

    // MARK: - Relationship refresh
    
    func refreshRelationshipState() async throws {
        isRelationshipLoading = true
        defer {
            isRelationshipLoading = false
        }

        let userId = self.userId

        // Ensure session is hydrated (helps avoid nil currentUserId on cold start)
        _ = try? await supabase.client.auth.session

        guard let currentUserId = supabase.currentUserId else {
            errorMessage = String(localized: "profile.errors.not_authenticated")
            return
        }

        let resolvedState = try await friendService.fetchRelationshipState(
            currentUserId: currentUserId,
            otherUserId: userId
        )

        relationshipState = resolvedState
        isFriend = resolvedState == .friends
    }
    
    // MARK: - Friend actions
    
    func toggleFriend() async {
        // 

        // Ensure session is hydrated so currentUserId is available
        _ = try? await supabase.client.auth.session

        guard let currentUserId = supabase.currentUserId else {
            errorMessage = String(localized: "profile.errors.not_authenticated")
            return
        }

        guard let profileId = profile?.id else {
            errorMessage = String(localized: "profile.errors.not_loaded")
            return
        }
        
        isFriendLoading = true
        defer { isFriendLoading = false }
        
        do {
            let state = relationshipState
            switch state {
            case .none:
                
                do {
                    try await friendService.sendFriendRequest(from: currentUserId, to: profileId)
                    
                    // Optimistic UI update
                    relationshipState = .requestSent
                    isFriend = false
                    // logPublishedState("after optimistic requestSent")
                } catch {
                    // Handle duplicate request (already sent)
                    if let pgError = error as? PostgrestError,
                       pgError.code == "23505" {
                        
                        relationshipState = .requestSent
                        isFriend = false
                    } else {
                        throw error
                    }
                }
                
                // Refresh in background without breaking UI
                Task {
                    try? await refreshRelationshipState()
                }
                
            case .requestReceived:
                
                try await friendService.acceptRequest(
                    myUserId: currentUserId,
                    from: profileId
                )

                // Small delay to ensure DB trigger commit is visible
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2s

                // Reload full profile (includes updated friend_count)
                await reloadProfile()

                
            case .friends:
                
                try await friendService.removeFriend(myUserId: currentUserId, otherUserId: profileId)

                // Reload full profile (includes updated friend_count)
                await reloadProfile()

                
            case .requestSent:
                await cancelFriendRequest()
                
            case .selfProfile:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelFriendRequest() async {
        guard let profileId = profile?.id,
              let currentUserId = supabase.currentUserId else { return }

        do {
            try await friendService.cancelRequest(
                from: currentUserId,
                to: profileId
            )

            relationshipState = .none
            isFriend = false
            // logPublishedState("after cancelFriendRequest")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
