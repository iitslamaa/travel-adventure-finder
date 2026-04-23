import Foundation
import PostgREST
import Supabase

@MainActor
final class SocialActivityService {
    private let supabase: SupabaseManager
    private let friendService: FriendService
    private let profileService: ProfileService

    init(
        supabase: SupabaseManager,
        friendService: FriendService,
        profileService: ProfileService
    ) {
        self.supabase = supabase
        self.friendService = friendService
        self.profileService = profileService
    }

    convenience init() {
        self.init(
            supabase: .shared,
            friendService: FriendService(),
            profileService: ProfileService(supabase: .shared)
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

        let actorsStartTime = Date()
        let actorIds = Array(Set(friends.map(\.id) + [userId]))
        let actorPreview = actorIds.prefix(6).map(\.uuidString).joined(separator: ",")
        SocialFeedDebug.log("service.prequery.actors.end id=\(requestId) actors=\(actorIds.count) duration=\(SocialFeedDebug.duration(since: actorsStartTime))")

        let lookupStartTime = Date()
        let profileLookup = try await fetchActorProfiles(for: actorIds)
        SocialFeedDebug.log("service.prequery.friend_lookup.end id=\(requestId) profiles=\(profileLookup.count) duration=\(SocialFeedDebug.duration(since: lookupStartTime))")

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

    private func fetchActorProfiles(for actorIds: [UUID]) async throws -> [UUID: Profile] {
        var profilesById: [UUID: Profile] = [:]

        for actorId in actorIds {
            if let cached = profileService.cachedProfile(userId: actorId) {
                profilesById[actorId] = cached
            }
        }

        let missingIds = actorIds.filter { profilesById[$0] == nil }
        guard !missingIds.isEmpty else {
            return profilesById
        }

        let response: PostgrestResponse<[SocialActorProfileRow]> = try await supabase.client
            .from("profiles")
            .select(SocialActorProfileRow.selectColumns)
            .in("id", values: missingIds)
            .execute()

        for row in response.value {
            profilesById[row.id] = row.profile
        }

        return profilesById
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

private struct SocialActorProfileRow: Decodable {
    static let selectColumns = """
        id,
        username,
        full_name,
        first_name,
        last_name,
        avatar_url,
        friend_count
    """

    let id: UUID
    let username: String?
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let friendCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case friendCount = "friend_count"
    }

    var profile: Profile {
        Profile(
            id: id,
            username: username ?? "",
            fullName: fullName ?? "",
            firstName: firstName,
            lastName: lastName,
            avatarUrl: avatarUrl,
            languages: [],
            livedCountries: [],
            travelStyle: [],
            travelMode: [],
            nextDestination: nil,
            defaultCurrencyCode: nil,
            currentCountry: nil,
            favoriteCountries: nil,
            onboardingCompleted: nil,
            friendCount: friendCount ?? 0
        )
    }
}
