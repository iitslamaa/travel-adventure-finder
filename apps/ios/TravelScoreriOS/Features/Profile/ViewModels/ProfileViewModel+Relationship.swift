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
        // print("🔄 [\(instanceId)] refreshRelationshipState CALLED")
        print("   bound userId:", userId as Any)
        print("   supabase.currentUserId:", supabase.currentUserId as Any)
        // logPublishedState("before relationship evaluation")
        isRelationshipLoading = true
        let userId = self.userId
        guard let currentUserId = supabase.currentUserId else {
            isRelationshipLoading = false
            return
        }
        
        // Viewing own profile
        if currentUserId == userId {
            print("   👤 Viewing own profile — setting selfProfile")
            relationshipState = .selfProfile
            // logPublishedState("set selfProfile")
            isFriend = false
            isRelationshipLoading = false
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
            isRelationshipLoading = false
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
            isRelationshipLoading = false
            return
        }
        
        // Request already sent?
        if try await friendService.hasSentRequest(from: currentUserId, to: userId) {
            print("   📤 Friend request already sent — setting .requestSent")
            relationshipState = .requestSent
            // logPublishedState("set requestSent")
            isFriend = false
            isRelationshipLoading = false
            return
        }
        
        print("   🚫 No relationship found — setting .none")
        // No relationship
        relationshipState = .none
        // logPublishedState("set none")
        isFriend = false
        isRelationshipLoading = false
    }
    
    // MARK: - Friend actions
    
    func toggleFriend() async {
        // print("🎬 [\(instanceId)] toggleFriend CALLED")
        print("   relationshipState:", relationshipState as Any)
        print("   profile?.id:", profile?.id as Any)
        // logPublishedState("before toggleFriend")
        guard let profileId = profile?.id else { return }
        
        isFriendLoading = true
        defer { isFriendLoading = false }
        
        do {
            let state = relationshipState
            switch state {
            case .none:
                print("   ➕ Attempting to send friend request...")
                do {
                    guard let currentUserId = supabase.currentUserId else { return }
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
                guard let currentUserId = supabase.currentUserId else { return }
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
                guard let currentUserId = supabase.currentUserId else { return }
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
            print("❌ Relationship action failed:", error)
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
