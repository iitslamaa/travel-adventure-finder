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
            errorMessage = "Not authenticated. Please log in again."
            print("❌ refreshRelationshipState abort — currentUserId nil")
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
            errorMessage = "Not authenticated. Please log in again."
            print("❌ toggleFriend abort — currentUserId nil")
            return
        }

        guard let profileId = profile?.id else {
            errorMessage = "Profile not loaded yet. Please try again."
            print("❌ toggleFriend abort — profileId nil")
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
                print("   ❌ Cancelling sent friend request...")
                await cancelFriendRequest()
                
            case .selfProfile:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Relationship action failed — raw:", error)
            print("❌ Relationship action failed — description:", error.localizedDescription)
            if let pg = error as? PostgrestError {
                print("❌ PostgrestError code:", pg.code as Any, "message:", pg.message, "detail:", pg.detail as Any, "hint:", pg.hint as Any)
            }
        }
    }

    func cancelFriendRequest() async {
        print("❌ cancelFriendRequest CALLED")
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

            print("❌ Friend request cancelled:", profileId)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Cancel request failed:", error)
        }
    }
}
