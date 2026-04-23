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
        let friendIds = friends.map(\.id)

        guard !friendIds.isEmpty else {
            return []
        }

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
            .in("actor_user_id", values: friendIds)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        return response.value
    }
}
