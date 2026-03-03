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
        print("🔄 refreshRelationshipState START")
        isRelationshipLoading = true
        defer {
            isRelationshipLoading = false
            print("🔄 refreshRelationshipState END — state:", relationshipState)
        }

        let userId = self.userId

        // Ensure session is hydrated (helps avoid nil currentUserId on cold start)
        _ = try? await supabase.client.auth.session

        guard let currentUserId = supabase.currentUserId else {
            errorMessage = "Not authenticated. Please log in again."
            print("❌ refreshRelationshipState abort — currentUserId nil")
            return
        }
        
        // Viewing own profile
        if currentUserId == userId {
            print("   👤 Viewing own profile — setting selfProfile")
            relationshipState = .selfProfile
            // logPublishedState("set selfProfile")
            isFriend = false
            return
        }

        // Friends?
        if try await friendService.isFriend(
            currentUserId: currentUserId,
            otherUserId: userId
        ) {
            print("   🤝 Users are friends — setting .friends")
            relationshipState = .friends
            isFriend = true
            return
        }
        
        // Incoming request?
        if try await friendService.hasIncomingRequest(
            from: userId,
            to: currentUserId
        ) {
            print("   📥 Incoming friend request — setting .requestReceived")
            relationshipState = .requestReceived
            isFriend = false
            return
        }
        
        // Request already sent?
        if try await friendService.hasSentRequest(from: currentUserId, to: userId) {
            print("   📤 Friend request already sent — setting .requestSent")
            relationshipState = .requestSent
            // logPublishedState("set requestSent")
            isFriend = false
            return
        }
        
        print("   🚫 No relationship found — setting .none")
        // No relationship
        relationshipState = .none
        // logPublishedState("set none")
        isFriend = false
    }
    
    // MARK: - Friend actions
    
    func toggleFriend() async {
        // print("🎬 [\(instanceId)] toggleFriend CALLED")
        print("   relationshipState:", relationshipState as Any)
        print("   profile?.id:", profile?.id as Any)

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
                print("   ➕ Attempting to send friend request...")
                do {
                    print("   📡 sendFriendRequest payload — from:", currentUserId, "to:", profileId)
                    try await friendService.sendFriendRequest(from: currentUserId, to: profileId)
                    print("📨 Friend request sent:", profileId)
                    
                    // Optimistic UI update
                    relationshipState = .requestSent
                    isFriend = false
                    // logPublishedState("after optimistic requestSent")
                } catch {
                    // Handle duplicate request (already sent)
                    if let pgError = error as? PostgrestError,
                       pgError.code == "23505" {
                        print("ℹ️ Friend request already exists — syncing state")
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
                print("   ✅ Accepting incoming friend request...")
                try await friendService.acceptRequest(
                    myUserId: currentUserId,
                    from: profileId
                )

                // Small delay to ensure DB trigger commit is visible
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2s

                // Reload full profile (includes updated friend_count)
                await reloadProfile()

                print("   ✅ Friend request accepted:", profileId)
                
            case .friends:
                print("   ➖ Attempting to remove friend...")
                try await friendService.removeFriend(myUserId: currentUserId, otherUserId: profileId)

                // Reload full profile (includes updated friend_count)
                await reloadProfile()

                print("➖ Removed friend:", profileId)
                
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
        print("   current profile?.id:", profile?.id as Any)
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
