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

        let prequeryStartTime = Date()
        SocialFeedDebug.log("service.prequery.start id=\(requestId) total_duration=\(SocialFeedDebug.duration(since: startTime)) cancelled=\(Task.isCancelled)")

        let lookupStartTime = Date()
        var profileLookup = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
        SocialFeedDebug.log("service.prequery.friend_lookup.end id=\(requestId) profiles=\(profileLookup.count) duration=\(SocialFeedDebug.duration(since: lookupStartTime))")

        let currentProfileStartTime = Date()
        SocialFeedDebug.log("service.prequery.current_profile_cache.start id=\(requestId)")
        if let currentUserProfile = ProfileService(supabase: supabase).cachedProfile(userId: userId) {
            profileLookup[userId] = currentUserProfile
        }
        SocialFeedDebug.log("service.prequery.current_profile_cache.end id=\(requestId) hit=\(profileLookup[userId] != nil) duration=\(SocialFeedDebug.duration(since: currentProfileStartTime)) total_duration=\(SocialFeedDebug.duration(since: startTime))")

        let actorsStartTime = Date()
        let actorIds = Array(Set(friends.map(\.id) + [userId]))
        let actorPreview = actorIds.prefix(6).map(\.uuidString).joined(separator: ",")
        SocialFeedDebug.log("service.prequery.actors.end id=\(requestId) actors=\(actorIds.count) duration=\(SocialFeedDebug.duration(since: actorsStartTime))")

        let cutoffStartTime = Date()
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let cutoffValue = ISO8601DateFormatter().string(from: cutoffDate)
        SocialFeedDebug.log("service.prequery.cutoff.end id=\(requestId) duration=\(SocialFeedDebug.duration(since: cutoffStartTime)) cutoff=\(cutoffValue)")

        SocialFeedDebug.log("service.query.prepare id=\(requestId) actors=\(actorIds.count) actor_preview=[\(actorPreview)] cutoff=\(cutoffValue) prequery_duration=\(SocialFeedDebug.duration(since: prequeryStartTime)) total_duration=\(SocialFeedDebug.duration(since: startTime))")

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
                    created_at
                """)
                .in("actor_user_id", values: actorIds)
                .gte("created_at", value: cutoffValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()

            let events = response.value.map { event in
                SocialActivityEvent(
                    id: event.id,
                    actorUserId: event.actorUserId,
                    eventType: event.eventType,
                    metadata: event.metadata,
                    createdAt: event.createdAt,
                    actorProfile: profileLookup[event.actorUserId] ?? event.actorProfile
                )
            }

            let eventPreview = events.prefix(5)
                .map { "\($0.id.uuidString.prefix(8)):\($0.eventType.rawValue):\($0.actorUserId.uuidString.prefix(8))" }
                .joined(separator: ",")
            SocialFeedDebug.log("service.query.success id=\(requestId) rows=\(events.count) duration=\(SocialFeedDebug.duration(since: queryStartTime)) preview=[\(eventPreview)] total_duration=\(SocialFeedDebug.duration(since: startTime))")
            return events
        } catch let error as PostgrestError {
            SocialFeedDebug.log("service.query.postgrest_error id=\(requestId) message=\(error.message) code=\(error.code ?? "nil") detail=\(error.detail ?? "nil") hint=\(error.hint ?? "nil")")

            guard error.message.localizedCaseInsensitiveContains("activity_events") else {
                throw error
            }

            SocialFeedDebug.log("service.query.missing_activity_events id=\(requestId) returning_empty_feed=true")
            return []
        } catch where SocialFeedDebug.isCancellation(error) {
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
