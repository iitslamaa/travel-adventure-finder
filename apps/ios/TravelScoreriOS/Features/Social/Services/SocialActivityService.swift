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
        let duplicateActors = (friends.count + 1) - actorIds.count
        SocialFeedDebug.log("service.prequery.actors.end id=\(requestId) actors=\(actorIds.count) duplicate_actors=\(max(duplicateActors, 0)) duration=\(SocialFeedDebug.duration(since: actorsStartTime))")

        let lookupStartTime = Date()
        SocialFeedDebug.log("service.prequery.friend_lookup.start id=\(requestId) actors=\(actorIds.count)")
        let (profileLookup, profileSources) = try await buildActorProfiles(for: userId, friends: friends, requestId: requestId)
        SocialFeedDebug.log("service.prequery.friend_lookup.end id=\(requestId) profiles=\(profileLookup.count) missing_profiles=\(max(actorIds.count - profileLookup.count, 0)) duration=\(SocialFeedDebug.duration(since: lookupStartTime))")

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

            let mappingStartTime = Date()
            var omittedCurrentUserEvents = 0
            let events: [SocialActivityEvent] = response.value.compactMap { event -> SocialActivityEvent? in
                let actorProfile = profileLookup[event.actorUserId] ?? event.actorProfile
                let actorSource = profileSources[event.actorUserId] ?? (event.actorProfile != nil ? "decoded_event_profile" : "missing")
                if event.actorUserId == userId, actorProfile == nil {
                    omittedCurrentUserEvents += 1
                    SocialFeedDebug.log("service.query.map.omit_current_user id=\(requestId) event=\(event.id.uuidString.prefix(8)) actor=\(event.actorUserId.uuidString) source=\(actorSource)")
                    return nil
                }

                SocialFeedDebug.log(
                    "service.query.map.event id=\(requestId) event=\(event.id.uuidString.prefix(8)) actor=\(event.actorUserId.uuidString) " +
                    "source=\(actorSource) chosen_username=\(logField(actorProfile?.username)) chosen_avatar=\(logField(actorProfile?.avatarUrl)) " +
                    "event_username=\(logField(event.actorProfile?.username)) event_avatar=\(logField(event.actorProfile?.avatarUrl)) metadata_keys=\(event.metadata.keys.sorted())"
                )

                return SocialActivityEvent(
                    id: event.id,
                    actorUserId: event.actorUserId,
                    eventType: event.eventType,
                    metadata: event.metadata,
                    createdAt: event.createdAt,
                    actorProfile: actorProfile
                )
            }
            let unmatchedProfiles = events.filter { $0.actorProfile == nil }.count

            let eventPreview = events.prefix(5)
                .map { "\($0.id.uuidString.prefix(8)):\($0.eventType.rawValue):\($0.actorUserId.uuidString.prefix(8))" }
                .joined(separator: ",")
            SocialFeedDebug.log("service.query.map.end id=\(requestId) rows=\(events.count) unmatched_profiles=\(unmatchedProfiles) omitted_current_user_events=\(omittedCurrentUserEvents) duration=\(SocialFeedDebug.duration(since: mappingStartTime))")
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
        let startTime = Date()
        SocialFeedDebug.log("record.start actor=\(actorUserId) event=\(eventType.rawValue) metadata=\(metadata)")
        let payload = SocialActivityInsert(
            actorUserId: actorUserId,
            eventType: eventType.rawValue,
            metadata: metadata
        )

        do {
            try await supabase.client
                .from("activity_events")
                .insert(payload)
                .execute()
            SocialFeedDebug.log("record.success actor=\(actorUserId) event=\(eventType.rawValue) duration=\(SocialFeedDebug.duration(since: startTime))")
        } catch {
            SocialFeedDebug.log("record.error actor=\(actorUserId) event=\(eventType.rawValue) error=\(SocialFeedDebug.describe(error)) duration=\(SocialFeedDebug.duration(since: startTime))")
            throw error
        }
    }

    private func buildActorProfiles(for userId: UUID, friends: [Profile], requestId: String) async throws -> ([UUID: Profile], [UUID: String]) {
        let friendSeedStartTime = Date()
        var profilesById = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
        var profileSources = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, "friend_service") })
        SocialFeedDebug.log("service.profile_lookup.friend_seed.end id=\(requestId) seeded=\(profilesById.count) duration=\(SocialFeedDebug.duration(since: friendSeedStartTime))")
        let friendPreview = friends.prefix(6).map { profile in
            "\(profile.id.uuidString.prefix(8)):\(logField(profile.username)):\(logField(profile.avatarUrl))"
        }.joined(separator: ",")
        SocialFeedDebug.log("service.profile_lookup.friend_seed.preview id=\(requestId) values=[\(friendPreview)]")

        let currentUserStartTime = Date()
        if profilesById[userId] == nil {
            if let inMemoryProfile = profileService.inMemoryProfile(userId: userId) {
                profilesById[userId] = inMemoryProfile
                profileSources[userId] = "in_memory"
                SocialFeedDebug.log("service.profile_lookup.current_user.hit id=\(requestId) source=in_memory duration=\(SocialFeedDebug.duration(since: currentUserStartTime))")
            } else {
                let fallbackProfile = profileService.currentUserProfileFallback(userId: userId)
                if let fallbackProfile {
                    SocialFeedDebug.log(
                        "service.profile_lookup.current_user.fallback_candidate id=\(requestId) username=\(logField(fallbackProfile.username)) " +
                        "avatar=\(logField(fallbackProfile.avatarUrl)) synthetic_username=\(isSyntheticCurrentUserUsername(fallbackProfile.username))"
                    )
                } else {
                    SocialFeedDebug.log("service.profile_lookup.current_user.fallback_candidate id=\(requestId) username=nil avatar=nil synthetic_username=false")
                }

                if let fetchedProfile = await fetchCurrentUserProfileWithTimeout(userId: userId, requestId: requestId, startedAt: currentUserStartTime) {
                    profilesById[userId] = fetchedProfile
                    profileSources[userId] = "network_timeout_race"
                } else if let fallbackProfile {
                    let sanitizedFallback = sanitizedFallbackProfile(fallbackProfile)
                    profilesById[userId] = sanitizedFallback
                    profileSources[userId] = "session_fallback_sanitized"
                    SocialFeedDebug.log(
                        "service.profile_lookup.current_user.hit id=\(requestId) source=session_fallback_sanitized duration=\(SocialFeedDebug.duration(since: currentUserStartTime)) " +
                        "username=\(logField(sanitizedFallback.username)) avatar=\(logField(sanitizedFallback.avatarUrl))"
                    )
                } else if let cachedProfile = profileService.cachedProfile(userId: userId) {
                    profilesById[userId] = cachedProfile
                    profileSources[userId] = "persisted_cache"
                    SocialFeedDebug.log("service.profile_lookup.current_user.hit id=\(requestId) source=persisted_cache duration=\(SocialFeedDebug.duration(since: currentUserStartTime))")
                } else {
                    SocialFeedDebug.log("service.profile_lookup.current_user.miss id=\(requestId) source=none duration=\(SocialFeedDebug.duration(since: currentUserStartTime))")
                }
            }
        } else {
            SocialFeedDebug.log("service.profile_lookup.current_user.skipped id=\(requestId) reason=already_seeded")
        }

        SocialFeedDebug.log("service.profile_lookup.complete id=\(requestId) total_profiles=\(profilesById.count)")
        let sourcePreview = profileSources.prefix(8).map { key, value in
            "\(key.uuidString.prefix(8)):\(value)"
        }.joined(separator: ",")
        SocialFeedDebug.log("service.profile_lookup.sources id=\(requestId) values=[\(sourcePreview)]")
        return (profilesById, profileSources)
    }

    private func fetchCurrentUserProfileWithTimeout(userId: UUID, requestId: String, startedAt: Date) async -> Profile? {
        SocialFeedDebug.log("service.profile_lookup.current_user.network_race.start id=\(requestId) timeout_ms=450")
        return await withTaskGroup(of: Profile?.self) { group in
            group.addTask { [profileService] in
                do {
                    return try await profileService.fetchMyProfile(userId: userId)
                } catch {
                    return nil
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: 450_000_000)
                return nil
            }

            for await result in group {
                if let result {
                    group.cancelAll()
                    SocialFeedDebug.log(
                        "service.profile_lookup.current_user.network_race.hit id=\(requestId) duration=\(SocialFeedDebug.duration(since: startedAt)) " +
                        "username=\(logField(result.username)) avatar=\(logField(result.avatarUrl))"
                    )
                    return result
                }
            }

            SocialFeedDebug.log("service.profile_lookup.current_user.network_race.timeout id=\(requestId) duration=\(SocialFeedDebug.duration(since: startedAt))")
            return nil
        }
    }

    private func sanitizedFallbackProfile(_ profile: Profile) -> Profile {
        let syntheticUsername = isSyntheticCurrentUserUsername(profile.username)
        return Profile(
            id: profile.id,
            username: syntheticUsername ? "" : profile.username,
            fullName: profile.fullName,
            firstName: profile.firstName,
            lastName: profile.lastName,
            avatarUrl: syntheticUsername ? nil : profile.avatarUrl,
            languages: profile.languages,
            livedCountries: profile.livedCountries,
            travelStyle: profile.travelStyle,
            travelMode: profile.travelMode,
            nextDestination: profile.nextDestination,
            defaultCurrencyCode: profile.defaultCurrencyCode,
            currentCountry: profile.currentCountry,
            favoriteCountries: profile.favoriteCountries,
            onboardingCompleted: profile.onboardingCompleted,
            friendCount: profile.friendCount
        )
    }

    private func isSyntheticCurrentUserUsername(_ username: String) -> Bool {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("user_")
    }

    private func logField(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "nil" : trimmed
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
