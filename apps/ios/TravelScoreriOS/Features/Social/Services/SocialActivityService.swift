import Foundation
import PostgREST
import Supabase

@MainActor
final class SocialActivityService {
    private let supabase: SupabaseManager
    private let friendService: FriendService

    init(
        supabase: SupabaseManager,
        friendService: FriendService
    ) {
        self.supabase = supabase
        self.friendService = friendService
    }

    convenience init() {
        self.init(
            supabase: .shared,
            friendService: FriendService()
        )
    }

    func fetchRecentFriendActivity(for userId: UUID, limit: Int = 20) async throws -> [SocialActivityEvent] {
        let friends = try await friendService.fetchFriends(for: userId)
        let actorIds = Array(Set(friends.map(\.id) + [userId]))

        do {
            let response: PostgrestResponse<[SocialActivityEvent]> = try await supabase.client
                .from("activity_events")
                .select("""
                    id,
                    actor_user_id,
                    event_type,
                    metadata,
                    created_at,
                    profiles!activity_events_actor_user_id_fkey (
                        id,
                        username,
                        full_name,
                        first_name,
                        last_name,
                        avatar_url,
                        friend_count
                    )
                """)
                .in("actor_user_id", values: actorIds)
                .gte("created_at", value: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date())
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()

            return response.value
        } catch let error as PostgrestError {
            guard error.message.localizedCaseInsensitiveContains("activity_events") else {
                throw error
            }

            return []
        }
    }

    func recordActivity(
        actorUserId: UUID,
        eventType: SocialActivityEventType,
        metadata: [String: String]
    ) async throws {
        let payload = SocialActivityInsert(
            actorUserId: actorUserId,
            eventType: eventType.rawValue,
            metadata: metadata
        )

        try await supabase.client
            .from("activity_events")
            .insert(payload)
            .execute()
    }
}

private struct SocialActivityInsert: Encodable {
    let actorUserId: UUID
    let eventType: String
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case actorUserId = "actor_user_id"
        case eventType = "event_type"
        case metadata
    }
}
