//
//  FriendService.swift
//  TravelScoreriOS
//

import Foundation
import Supabase
import PostgREST

private enum FriendServiceDebugLog {
    static func message(_ text: String) {
#if DEBUG
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        print("🤝 [FriendService] \(timestamp) \(text)")
#endif
    }
}

private struct FriendRow: Decodable {
    let user_id: UUID
    let friend_id: UUID
}

private struct FriendProfileRow: Decodable {
    let id: UUID
    let username: String
    let full_name: String?
    let first_name: String?
    let last_name: String?
    let avatar_url: String?
    let friend_count: Int?

    var profile: Profile {
        Profile(
            id: id,
            username: username,
            fullName: full_name ?? "",
            firstName: first_name,
            lastName: last_name,
            avatarUrl: avatar_url,
            languages: [],
            livedCountries: [],
            travelStyle: [],
            travelMode: [],
            nextDestination: nil,
            defaultCurrencyCode: nil,
            currentCountry: nil,
            favoriteCountries: nil,
            onboardingCompleted: nil,
            friendCount: friend_count ?? 0
        )
    }
}

@MainActor
final class FriendService {
    private static let friendProfileSelect = """
        id,
        username,
        full_name,
        first_name,
        last_name,
        avatar_url,
        friend_count
    """

    private static var friendsCache: [UUID: [Profile]] = [:]
    private static var inFlightFriendFetches: [UUID: Task<[Profile], Error>] = [:]
    private static var incomingRequestsCache: [UUID: [Profile]] = [:]
    private static var inFlightIncomingRequestFetches: [UUID: Task<[Profile], Error>] = [:]
    private static var incomingRequestCountCache: [UUID: Int] = [:]
    private static var inFlightIncomingRequestCounts: [UUID: Task<Int, Error>] = [:]

    private let supabase: SupabaseManager

    init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    convenience init() {
        self.init(supabase: .shared)
    }

    // MARK: - Friends


    func fetchFriends(for userId: UUID) async throws -> [Profile] {
        if let cachedFriends = Self.friendsCache[userId] {
            FriendServiceDebugLog.message("Friends cache hit user=\(userId.uuidString) count=\(cachedFriends.count)")
            return cachedFriends
        }

        if let inFlightFetch = Self.inFlightFriendFetches[userId] {
            FriendServiceDebugLog.message("Friends joined in-flight fetch user=\(userId.uuidString)")
            return try await inFlightFetch.value
        }

        let startedAt = Date()
        let fetchTask = Task<[Profile], Error> {
            let friendshipStartedAt = Date()

            // These queries are independent, so fetch both directions in parallel.
            async let sentResponse: PostgrestResponse<[FriendRow]> = supabase.client
                .from("friends")
                .select("user_id, friend_id")
                .eq("user_id", value: userId)
                .limit(1000)
                .execute()

            async let receivedResponse: PostgrestResponse<[FriendRow]> = supabase.client
                .from("friends")
                .select("user_id, friend_id")
                .eq("friend_id", value: userId)
                .limit(1000)
                .execute()

            let rows = try await sentResponse.value + receivedResponse.value
            FriendServiceDebugLog.message(
                "Friend rows fetched user=\(userId.uuidString) rows=\(rows.count) duration=\(Int(Date().timeIntervalSince(friendshipStartedAt) * 1000))ms"
            )

            let friendIds: [UUID] = rows.map { row in
                row.user_id == userId ? row.friend_id : row.user_id
            }
            let uniqueFriendIds = Array(NSOrderedSet(array: friendIds)) as? [UUID] ?? []

            guard !uniqueFriendIds.isEmpty else {
                return []
            }

            let profilesStartedAt = Date()
            let profilesResponse: PostgrestResponse<[FriendProfileRow]> = try await supabase.client
                .from("profiles")
                .select(Self.friendProfileSelect)
                .in("id", values: uniqueFriendIds)
                .execute()
            let profiles = profilesResponse.value.map(\.profile)
            FriendServiceDebugLog.message(
                "Friend profiles fetched user=\(userId.uuidString) ids=\(uniqueFriendIds.count) profiles=\(profiles.count) duration=\(Int(Date().timeIntervalSince(profilesStartedAt) * 1000))ms"
            )

            let profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            return uniqueFriendIds.compactMap { profilesById[$0] }
        }

        Self.inFlightFriendFetches[userId] = fetchTask

        do {
            let orderedProfiles = try await fetchTask.value
            Self.friendsCache[userId] = orderedProfiles
            if Self.inFlightFriendFetches[userId] == fetchTask {
                Self.inFlightFriendFetches[userId] = nil
            }
            FriendServiceDebugLog.message(
                "Friends fetched user=\(userId.uuidString) count=\(orderedProfiles.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
            )
            return orderedProfiles
        } catch {
            if Self.inFlightFriendFetches[userId] == fetchTask {
                Self.inFlightFriendFetches[userId] = nil
            }
            throw error
        }
    }

    func cachedFriends(for userId: UUID) -> [Profile]? {
        Self.friendsCache[userId]
    }

    func cachedIncomingRequests(for userId: UUID) -> [Profile]? {
        Self.incomingRequestsCache[userId]
    }

    func cachedIncomingRequestCount(for userId: UUID) -> Int? {
        Self.incomingRequestCountCache[userId]
    }

    func isFriend(currentUserId: UUID, otherUserId: UUID) async throws -> Bool {
        let filter = "and(user_id.eq.\(currentUserId.uuidString),friend_id.eq.\(otherUserId.uuidString)),and(user_id.eq.\(otherUserId.uuidString),friend_id.eq.\(currentUserId.uuidString))"

        let response = try await supabase.client
            .from("friends")
            .select("id", count: .exact)
            .or(filter)
            .limit(1)
            .execute()
        return (response.count ?? 0) > 0
    }

    func removeFriend(myUserId: UUID, otherUserId: UUID) async throws {

        let filter = "and(user_id.eq.\(myUserId.uuidString),friend_id.eq.\(otherUserId.uuidString)),and(user_id.eq.\(otherUserId.uuidString),friend_id.eq.\(myUserId.uuidString))"

        try await supabase.client
            .from("friends")
            .delete()
            .or(filter)
            .execute()

        Self.invalidateFriendCaches(for: [myUserId, otherUserId])
    }

    func fetchMutualFriends(currentUserId: UUID, otherUserId: UUID) async throws -> [Profile] {
        async let currentFriends = fetchFriends(for: currentUserId)
        async let otherFriends = fetchFriends(for: otherUserId)

        let current = try await currentFriends
        let other = try await otherFriends

        let currentSet = Set(current.map { $0.id })
        let mutual = other.filter { currentSet.contains($0.id) }
        return mutual.sorted { $0.username < $1.username }
    }

    // MARK: - Requests

    func fetchIncomingRequests(for myUserId: UUID) async throws -> [Profile] {
        if let cachedRequests = Self.incomingRequestsCache[myUserId] {
            FriendServiceDebugLog.message("Incoming requests cache hit user=\(myUserId.uuidString) count=\(cachedRequests.count)")
            return cachedRequests
        }

        if let inFlightFetch = Self.inFlightIncomingRequestFetches[myUserId] {
            FriendServiceDebugLog.message("Incoming requests joined in-flight fetch user=\(myUserId.uuidString)")
            return try await inFlightFetch.value
        }

        let startedAt = Date()
        let fetchTask = Task<[Profile], Error> {
            let response: PostgrestResponse<[IncomingRequestJoinedRow]> = try await supabase.client
                .from("friend_requests")
                .select("""
                    id,
                    sender_id,
                    profiles!friend_requests_sender_id_fkey (
                        \(Self.friendProfileSelect)
                    )
                """)
                .eq("receiver_id", value: myUserId)
                .eq("status", value: "pending")
                .execute()

            return response.value.map { $0.profile }
        }

        Self.inFlightIncomingRequestFetches[myUserId] = fetchTask

        do {
            let profiles = try await fetchTask.value
            Self.incomingRequestsCache[myUserId] = profiles
            Self.incomingRequestCountCache[myUserId] = profiles.count
            if Self.inFlightIncomingRequestFetches[myUserId] == fetchTask {
                Self.inFlightIncomingRequestFetches[myUserId] = nil
            }
            FriendServiceDebugLog.message(
                "Incoming requests fetched user=\(myUserId.uuidString) count=\(profiles.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
            )
            return profiles
        } catch {
            if Self.inFlightIncomingRequestFetches[myUserId] == fetchTask {
                Self.inFlightIncomingRequestFetches[myUserId] = nil
            }
            throw error
        }
    }

    func incomingRequestCount(for myUserId: UUID) async throws -> Int {
        if let cachedCount = Self.incomingRequestCountCache[myUserId] {
            FriendServiceDebugLog.message("Incoming request count cache hit user=\(myUserId.uuidString) count=\(cachedCount)")
            return cachedCount
        }

        if let inFlightCount = Self.inFlightIncomingRequestCounts[myUserId] {
            FriendServiceDebugLog.message("Incoming request count joined in-flight fetch user=\(myUserId.uuidString)")
            return try await inFlightCount.value
        }

        struct RequestIDRow: Decodable { let id: UUID }

        let startedAt = Date()
        let fetchTask = Task<Int, Error> {
            let response: PostgrestResponse<[RequestIDRow]> = try await supabase.client
                .from("friend_requests")
                .select("id")
                .eq("receiver_id", value: myUserId)
                .eq("status", value: "pending")
                .limit(1000)
                .execute()
            return response.value.count
        }

        Self.inFlightIncomingRequestCounts[myUserId] = fetchTask

        do {
            let count = try await fetchTask.value
            Self.incomingRequestCountCache[myUserId] = count
            if Self.inFlightIncomingRequestCounts[myUserId] == fetchTask {
                Self.inFlightIncomingRequestCounts[myUserId] = nil
            }
            FriendServiceDebugLog.message(
                "Incoming request count fetched user=\(myUserId.uuidString) count=\(count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
            )
            return count
        } catch {
            if Self.inFlightIncomingRequestCounts[myUserId] == fetchTask {
                Self.inFlightIncomingRequestCounts[myUserId] = nil
            }
            throw error
        }
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

    func fetchRelationshipState(currentUserId: UUID, otherUserId: UUID) async throws -> RelationshipState {
        if currentUserId == otherUserId {
            return .selfProfile
        }

        async let isFriendValue = isFriend(currentUserId: currentUserId, otherUserId: otherUserId)
        async let hasIncomingValue = hasIncomingRequest(from: otherUserId, to: currentUserId)
        async let hasSentValue = hasSentRequest(from: currentUserId, to: otherUserId)

        if try await isFriendValue {
            return .friends
        }

        if try await hasIncomingValue {
            return .requestReceived
        }

        if try await hasSentValue {
            return .requestSent
        }

        return .none
    }

    func sendFriendRequest(from myUserId: UUID, to otherUserId: UUID) async throws {
        let requestId = UUID()
        

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

            Self.invalidateRequestCaches(for: [myUserId, otherUserId])

        } catch {
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
        

        do {
            try await supabase.client
                .from("friend_requests")
                .delete()
                .eq("sender_id", value: myUserId)
                .eq("receiver_id", value: otherUserId)
                .eq("status", value: "pending")
                .execute()

            Self.invalidateRequestCaches(for: [myUserId, otherUserId])

        } catch {
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

        Self.invalidateRequestCaches(for: [myUserId, otherUserId])
        Self.invalidateFriendCaches(for: [myUserId, otherUserId])
    }

    func rejectRequest(myUserId: UUID, from otherUserId: UUID) async throws {
        

        try await supabase.client
            .from("friend_requests")
            .delete()
            .eq("sender_id", value: otherUserId)
            .eq("receiver_id", value: myUserId)
            .execute()

        Self.invalidateRequestCaches(for: [myUserId, otherUserId])
    }

    private static func invalidateFriendCaches(for userIds: [UUID]) {
        for userId in userIds {
            friendsCache[userId] = nil
            inFlightFriendFetches[userId]?.cancel()
            inFlightFriendFetches[userId] = nil
        }
    }

    private static func invalidateRequestCaches(for userIds: [UUID]) {
        for userId in userIds {
            incomingRequestsCache[userId] = nil
            inFlightIncomingRequestFetches[userId]?.cancel()
            inFlightIncomingRequestFetches[userId] = nil
            incomingRequestCountCache[userId] = nil
            inFlightIncomingRequestCounts[userId]?.cancel()
            inFlightIncomingRequestCounts[userId] = nil
        }
    }
}

private struct IncomingRequestJoinedRow: Decodable {
    let profileRow: FriendProfileRow
    enum CodingKeys: String, CodingKey { case profile = "profiles" }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileRow = try container.decode(FriendProfileRow.self, forKey: .profile)
    }

    var profile: Profile {
        profileRow.profile
    }
}
