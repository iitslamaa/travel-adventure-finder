//
//  FriendService.swift
//  TravelScoreriOS
//

import Foundation
import Supabase
import PostgREST

private struct FriendRow: Decodable {
    let user_id: UUID
    let friend_id: UUID
}

@MainActor
final class FriendService {

    private let instanceId = UUID()

    private let supabase: SupabaseManager

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }

    // MARK: - Friends


    func fetchFriends(for userId: UUID) async throws -> [Profile] {
        let requestId = UUID()
        let start = Date()
        

        // Query 1: user_id = me (use UUID directly, NOT uuidString)
        let sentResponse: PostgrestResponse<[FriendRow]> = try await supabase.client
            .from("friends")
            .select("user_id, friend_id")
            .eq("user_id", value: userId)
            .limit(1000)
            .execute()
        

        // Query 2: friend_id = me (use UUID directly)
        let receivedResponse: PostgrestResponse<[FriendRow]> = try await supabase.client
            .from("friends")
            .select("user_id, friend_id")
            .eq("friend_id", value: userId)
            .limit(1000)
            .execute()
        

        let rows = sentResponse.value + receivedResponse.value

        let friendIds: [UUID] = rows.map { row in
            row.user_id == userId ? row.friend_id : row.user_id
        }
        

        if friendIds.isEmpty {
            
            return []
        }

        let profilesResponse: PostgrestResponse<[Profile]> = try await supabase.client
            .from("profiles")
            .select("*")
            .in("id", values: friendIds)
            .execute()
        

        let elapsed = Date().timeIntervalSince(start)
        
        
        return profilesResponse.value
    }

    func isFriend(currentUserId: UUID, otherUserId: UUID) async throws -> Bool {
        let requestId = UUID()
        let start = Date()
        

        let filter = "and(user_id.eq.\(currentUserId.uuidString),friend_id.eq.\(otherUserId.uuidString)),and(user_id.eq.\(otherUserId.uuidString),friend_id.eq.\(currentUserId.uuidString))"

        let response = try await supabase.client
            .from("friends")
            .select("id", count: .exact)
            .or(filter)
            .limit(1)
            .execute()

        let elapsed = Date().timeIntervalSince(start)
        
        
        return (response.count ?? 0) > 0
    }

    func removeFriend(myUserId: UUID, otherUserId: UUID) async throws {

        let filter = "and(user_id.eq.\(myUserId.uuidString),friend_id.eq.\(otherUserId.uuidString)),and(user_id.eq.\(otherUserId.uuidString),friend_id.eq.\(myUserId.uuidString))"

        try await supabase.client
            .from("friends")
            .delete()
            .or(filter)
            .execute()
        
    }

    func fetchMutualFriends(currentUserId: UUID, otherUserId: UUID) async throws -> [Profile] {
        let requestId = UUID()
        let start = Date()
        

        async let currentFriends = fetchFriends(for: currentUserId)
        async let otherFriends = fetchFriends(for: otherUserId)

        let current = try await currentFriends
        let other = try await otherFriends

        let currentSet = Set(current.map { $0.id })
        let mutual = other.filter { currentSet.contains($0.id) }

        let elapsed = Date().timeIntervalSince(start)
        
        
        return mutual.sorted { $0.username < $1.username }
    }

    // MARK: - Requests

    func fetchIncomingRequests(for myUserId: UUID) async throws -> [Profile] {
        

        let response: PostgrestResponse<[IncomingRequestJoinedRow]> = try await supabase.client
            .from("friend_requests")
            .select("""
                id,
                sender_id,
                profiles!friend_requests_sender_id_fkey (*)
            """)
            .eq("receiver_id", value: myUserId)
            .eq("status", value: "pending")
            .execute()

        
        return response.value.map { $0.profile }
    }

    func incomingRequestCount(for myUserId: UUID) async throws -> Int {
        let requestId = UUID()
        let start = Date()
        

        struct RequestIDRow: Decodable { let id: UUID }

        let response: PostgrestResponse<[RequestIDRow]> = try await supabase.client
            .from("friend_requests")
            .select("id")
            .eq("receiver_id", value: myUserId)
            .eq("status", value: "pending")
            .limit(1000)
            .execute()

        let elapsed = Date().timeIntervalSince(start)
        
        
        return response.value.count
    }

    func fetchPendingRequestCount(for userId: UUID) async throws -> Int {
        try await incomingRequestCount(for: userId)
    }

    func hasIncomingRequest(from otherUserId: UUID, to myUserId: UUID) async throws -> Bool {
        

        struct RequestIDRow: Decodable { let id: UUID }

        let response: PostgrestResponse<[RequestIDRow]> = try await supabase.client
            .from("friend_requests")
            .select("id")
            .eq("sender_id", value: otherUserId)
            .eq("receiver_id", value: myUserId)
            .eq("status", value: "pending")
            .limit(1)
            .execute()

        
        return !response.value.isEmpty
    }

    func hasSentRequest(from myUserId: UUID, to otherUserId: UUID) async throws -> Bool {
        

        struct RequestIDRow: Decodable { let id: UUID }

        let response: PostgrestResponse<[RequestIDRow]> = try await supabase.client
            .from("friend_requests")
            .select("id")
            .eq("sender_id", value: myUserId)
            .eq("receiver_id", value: otherUserId)
            .eq("status", value: "pending")
            .limit(1)
            .execute()

        
        return !response.value.isEmpty
    }

    func sendFriendRequest(from myUserId: UUID, to otherUserId: UUID) async throws {
        let requestId = UUID()
        let start = Date()
        

        guard myUserId != otherUserId else {
            print("⚠️ [\(requestId)] abort — cannot friend self")
            return
        }

        do {
            if try await isFriend(currentUserId: myUserId, otherUserId: otherUserId) {
                
                return
            }

            if try await hasIncomingRequest(from: otherUserId, to: myUserId) {
                
                return
            }

            if try await hasSentRequest(from: myUserId, to: otherUserId) {
                
                return
            }

            struct FriendRequestInsert: Encodable {
                let sender_id: UUID
                let receiver_id: UUID
                let status: String
            }

            let payload = FriendRequestInsert(
                sender_id: myUserId,
                receiver_id: otherUserId,
                status: "pending"
            )

            

            try await supabase.client
                .from("friend_requests")
                .insert(payload)
                .execute()

            let elapsed = Date().timeIntervalSince(start)
            

        } catch {
            let elapsed = Date().timeIntervalSince(start)
            print("❌ [\(requestId)] sendFriendRequest FAILED — raw:", error)
            print("❌ [\(requestId)] sendFriendRequest FAILED — description:", error.localizedDescription)
            if let pg = error as? PostgrestError {
                print("❌ [\(requestId)] PostgrestError code:", pg.code as Any, "message:", pg.message, "detail:", pg.detail as Any, "hint:", pg.hint as Any)
            }
            
            throw error
        }
    }

    func cancelRequest(from myUserId: UUID, to otherUserId: UUID) async throws {
        let requestId = UUID()
        let start = Date()
        

        do {
            try await supabase.client
                .from("friend_requests")
                .delete()
                .eq("sender_id", value: myUserId)
                .eq("receiver_id", value: otherUserId)
                .eq("status", value: "pending")
                .execute()

            let elapsed = Date().timeIntervalSince(start)
            

        } catch {
            let elapsed = Date().timeIntervalSince(start)
            print("❌ [\(requestId)] cancelRequest FAILED — raw:", error)
            print("❌ [\(requestId)] cancelRequest FAILED — description:", error.localizedDescription)
            if let pg = error as? PostgrestError {
                print("❌ [\(requestId)] PostgrestError code:", pg.code as Any, "message:", pg.message, "detail:", pg.detail as Any, "hint:", pg.hint as Any)
            }
            
            throw error
        }
    }

    func acceptRequest(myUserId: UUID, from otherUserId: UUID) async throws {
        

        // Remove pending request
        try await supabase.client
            .from("friend_requests")
            .delete()
            .eq("sender_id", value: otherUserId)
            .eq("receiver_id", value: myUserId)
            .execute()

        // Insert ONE friendship row
        try await supabase.client
            .from("friends")
            .insert([
                "user_id": myUserId,
                "friend_id": otherUserId
            ])
            .execute()
        
        
    }

    func rejectRequest(myUserId: UUID, from otherUserId: UUID) async throws {
        

        try await supabase.client
            .from("friend_requests")
            .delete()
            .eq("sender_id", value: otherUserId)
            .eq("receiver_id", value: myUserId)
            .execute()
    }

    deinit {
        
    }
}

private struct IncomingRequestJoinedRow: Decodable {
    let profile: Profile
    enum CodingKeys: String, CodingKey { case profile = "profiles" }
}
