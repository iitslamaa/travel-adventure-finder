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

    func fetchRecentFriendActivity(for userId: UUID, limit: Int = 20, requestId: String = "unknown") async throws -> [SocialActivityEvent] {
        let startTime = Date()
        SocialFeedDebug.log("service.fetch.start id=\(requestId) user=\(userId) limit=\(limit)")

        let friendsStartTime = Date()
        SocialFeedDebug.log("service.friends.start id=\(requestId)")
        let friends = try await friendService.fetchFriends(for: userId)
        SocialFeedDebug.log("service.friends.success id=\(requestId) count=\(friends.count) duration=\(SocialFeedDebug.duration(since: friendsStartTime)) cancelled=\(Task.isCancelled)")

        let actorIds = Array(Set(friends.map(\.id) + [userId]))
        let actorPreview = actorIds.prefix(6).map(\.uuidString).joined(separator: ",")
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let cutoffValue = ISO8601DateFormatter().string(from: cutoffDate)

        SocialFeedDebug.log("service.query.prepare id=\(requestId) actors=\(actorIds.count) actor_preview=[\(actorPreview)] cutoff=\(cutoffValue)")

        do {
            let queryStartTime = Date()
            SocialFeedDebug.log("service.query.start id=\(requestId) table=activity_events")

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
                .gte("created_at", value: cutoffValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()

            let eventPreview = response.value.prefix(5)
                .map { "\($0.id.uuidString.prefix(8)):\($0.eventType.rawValue):\($0.actorUserId.uuidString.prefix(8))" }
                .joined(separator: ",")
            SocialFeedDebug.log("service.query.success id=\(requestId) rows=\(response.value.count) duration=\(SocialFeedDebug.duration(since: queryStartTime)) preview=[\(eventPreview)] total_duration=\(SocialFeedDebug.duration(since: startTime))")
            return response.value
        } catch let error as PostgrestError {
            SocialFeedDebug.log("service.query.postgrest_error id=\(requestId) message=\(error.message) code=\(error.code ?? "nil") detail=\(error.detail ?? "nil") hint=\(error.hint ?? "nil")")

            guard error.message.localizedCaseInsensitiveContains("activity_events") else {
                throw error
            }

            SocialFeedDebug.log("service.query.missing_activity_events id=\(requestId) returning_empty_feed=true")
            return []
        } catch is CancellationError {
            SocialFeedDebug.log("service.fetch.cancelled id=\(requestId) total_duration=\(SocialFeedDebug.duration(since: startTime))")
            throw CancellationError()
        } catch {
            SocialFeedDebug.log("service.fetch.error id=\(requestId) error=\(SocialFeedDebug.describe(error)) total_duration=\(SocialFeedDebug.duration(since: startTime))")
            throw error
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
