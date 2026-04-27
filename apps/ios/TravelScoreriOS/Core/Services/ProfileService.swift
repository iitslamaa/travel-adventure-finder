//
//  ProfileService.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/6/26.
//

import Foundation
import Supabase
import PostgREST

struct ProfileInsert: Encodable {
    let id: UUID
    let username: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
    }
}

struct ProfileUpdate: Encodable {
    let username: String?
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
    let languages: [[String: String]]?
    let livedCountries: [String]?
    let travelStyle: [String]?
    let travelMode: [String]?
    let nextDestination: String?
    let defaultCurrencyCode: String?
    let currentCountry: String?
    let favoriteCountries: [String]?
    let onboardingCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case username
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case languages
        case livedCountries = "lived_countries"
        case travelStyle = "travel_style"
        case travelMode = "travel_mode"
        case nextDestination = "next_destination"
        case defaultCurrencyCode = "default_currency_code"
        case currentCountry = "current_country"
        case favoriteCountries = "favorite_countries"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct ProfileCreate: Encodable {
    let id: UUID
    let username: String
    let avatar_url: String
    let full_name: String
    let first_name: String?
    let last_name: String?
}

private struct LegacyProfileUpdate: Encodable {
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let languages: [[String: String]]?
    let livedCountries: [String]?
    let travelStyle: [String]?
    let travelMode: [String]?
    let nextDestination: String?
    let defaultCurrencyCode: String?
    let currentCountry: String?
    let favoriteCountries: [String]?
    let onboardingCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case languages
        case livedCountries = "lived_countries"
        case travelStyle = "travel_style"
        case travelMode = "travel_mode"
        case nextDestination = "next_destination"
        case defaultCurrencyCode = "default_currency_code"
        case currentCountry = "current_country"
        case favoriteCountries = "favorite_countries"
        case onboardingCompleted = "onboarding_completed"
    }
}

private struct LegacyProfileCreate: Encodable {
    let id: UUID
    let username: String
    let avatar_url: String
    let full_name: String
}

private struct ResolvedProfileIdentity {
    let firstName: String?
    let lastName: String?
    let fullName: String
    let avatarURL: String?
}

private struct PassportPreferencesRow: Codable {
    let userId: UUID
    let nationalityCountryCodes: [String]
    let passportCountryCode: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nationalityCountryCodes = "nationality_country_codes"
        case passportCountryCode = "passport_country_code"
    }
}

private struct CountryRow: Decodable {
    let countryId: String

    enum CodingKeys: String, CodingKey {
        case countryId = "country_id"
    }
}

private struct PersistedCountrySet: Codable {
    let countryCodes: [String]
}

final class ProfileService {

    private enum CacheKeys {
        static let version = "v1"
        static let profilePrefix = "travelaf.profile.cache.\(version).profile."
        static let traveledPrefix = "travelaf.profile.cache.\(version).traveled."
        static let bucketPrefix = "travelaf.profile.cache.\(version).bucket."
        static let passportPrefix = "travelaf.profile.cache.\(version).passport."
    }

    private static var profileCache: [UUID: Profile] = [:]
    private static var inFlightProfileFetches: [UUID: Task<Profile, Error>] = [:]
    private static var inFlightProfileWarmups: [UUID: Task<Profile, Error>] = [:]
    private static var traveledCache: [UUID: Set<String>] = [:]
    private static var bucketCache: [UUID: Set<String>] = [:]
    private static var passportPreferencesCache: [UUID: PassportPreferences] = [:]

    private let supabase: SupabaseManager

    init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    func inMemoryProfile(userId: UUID) -> Profile? {
        let cached = Self.profileCache[userId]
        SocialFeedDebug.log(
            "profile.service.memory_profile user=\(userId.uuidString) hit=\(cached != nil) username=\(logField(cached?.username))"
        )
        return cached
    }

    func currentUserProfileFallback(userId: UUID) -> Profile? {
        if let cachedProfile = Self.profileCache[userId] {
            SocialFeedDebug.log("profile.service.fallback.memory_hit user=\(userId.uuidString)")
            return cachedProfile
        }

        guard userId == supabase.currentUserId,
              let user = supabase.client.auth.currentUser else {
            SocialFeedDebug.log(
                "profile.service.fallback.unavailable user=\(userId.uuidString) current_user=\(supabase.currentUserId?.uuidString ?? "nil") auth_user_present=\(supabase.client.auth.currentUser != nil)"
            )
            return nil
        }

        let metadata = user.userMetadata
        let identity = resolvedIdentity(from: user)
        let fallbackUsername =
            metadata["username"]?.stringValue?.nilIfEmpty ??
            metadata["preferred_username"]?.stringValue?.nilIfEmpty ??
            metadata["user_name"]?.stringValue?.nilIfEmpty ??
            "user_\(userId.uuidString.replacingOccurrences(of: "-", with: "").prefix(6).lowercased())"

        let fallback = Profile(
            id: userId,
            username: fallbackUsername,
            fullName: identity.fullName,
            firstName: identity.firstName,
            lastName: identity.lastName,
            avatarUrl: identity.avatarURL,
            languages: [],
            livedCountries: [],
            travelStyle: [],
            travelMode: [],
            nextDestination: nil,
            defaultCurrencyCode: nil,
            currentCountry: nil,
            favoriteCountries: nil,
            onboardingCompleted: nil,
            friendCount: 0
        )
        SocialFeedDebug.log(
            "profile.service.fallback.created user=\(userId.uuidString) username=\(logField(fallback.username)) avatar=\(logField(fallback.avatarUrl))"
        )
        return fallback
    }

    func cachedProfile(userId: UUID) -> Profile? {
        if let cachedProfile = Self.profileCache[userId] {
            SocialFeedDebug.log(
                "profile.service.cache.profile.memory_hit user=\(userId.uuidString) username=\(logField(cachedProfile.username)) languages=\(cachedProfile.languages.count)"
            )
            return cachedProfile
        }

        guard let persistedProfile: Profile = Self.loadCachedValue(forKey: Self.profileCacheKey(for: userId)) else {
            SocialFeedDebug.log("profile.service.cache.profile.miss user=\(userId.uuidString)")
            return nil
        }

        Self.profileCache[userId] = persistedProfile
        SocialFeedDebug.log(
            "profile.service.cache.profile.disk_hit user=\(userId.uuidString) username=\(logField(persistedProfile.username)) languages=\(persistedProfile.languages.count)"
        )
        return persistedProfile
    }

    func warmProfileCacheIfNeeded(
        userId: UUID,
        defaultUsername: String? = nil,
        defaultAvatarUrl: String? = nil
    ) async throws -> Profile {
        if let cachedProfile = Self.profileCache[userId] {
            SocialFeedDebug.log("profile.service.warm.cache_hit user=\(userId.uuidString)")
            return cachedProfile
        }

        if let inFlightTask = Self.inFlightProfileWarmups[userId] {
            SocialFeedDebug.log("profile.service.warm.in_flight_hit user=\(userId.uuidString)")
            return try await inFlightTask.value
        }

        let startedAt = Date()
        SocialFeedDebug.log("profile.service.warm.start user=\(userId.uuidString)")
        let warmTask = Task<Profile, Error> { @MainActor [weak self] in
            guard let self else {
                throw CancellationError()
            }

            return try await self.fetchOrCreateProfile(
                userId: userId,
                defaultUsername: defaultUsername,
                defaultAvatarUrl: defaultAvatarUrl
            )
        }

        Self.inFlightProfileWarmups[userId] = warmTask
        defer {
            if Self.inFlightProfileWarmups[userId] == warmTask {
                Self.inFlightProfileWarmups[userId] = nil
            }
        }

        do {
            let profile = try await warmTask.value
            SocialFeedDebug.log(
                "profile.service.warm.success user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            return profile
        } catch {
            SocialFeedDebug.log(
                "profile.service.warm.error user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    func cachedTraveledCountries(userId: UUID) -> Set<String>? {
        if let cached = Self.traveledCache[userId] {
            SocialFeedDebug.log("profile.service.cache.traveled.memory_hit user=\(userId.uuidString) count=\(cached.count)")
            return cached
        }

        guard let persisted: PersistedCountrySet = Self.loadCachedValue(forKey: Self.traveledCacheKey(for: userId)) else {
            SocialFeedDebug.log("profile.service.cache.traveled.miss user=\(userId.uuidString)")
            return nil
        }

        let cached = Set(persisted.countryCodes)
        Self.traveledCache[userId] = cached
        SocialFeedDebug.log("profile.service.cache.traveled.disk_hit user=\(userId.uuidString) count=\(cached.count)")
        return cached
    }

    func cachedBucketListCountries(userId: UUID) -> Set<String>? {
        if let cached = Self.bucketCache[userId] {
            SocialFeedDebug.log(
                "profile.service.cache.bucket.memory_hit user=\(userId.uuidString) \(SocialFeedDebug.countrySetSummary(cached))"
            )
            return cached
        }

        guard let persisted: PersistedCountrySet = Self.loadCachedValue(forKey: Self.bucketCacheKey(for: userId)) else {
            SocialFeedDebug.log("profile.service.cache.bucket.miss user=\(userId.uuidString)")
            return nil
        }

        let cached = Set(persisted.countryCodes)
        Self.bucketCache[userId] = cached
        SocialFeedDebug.log(
            "profile.service.cache.bucket.disk_hit user=\(userId.uuidString) \(SocialFeedDebug.countrySetSummary(cached))"
        )
        return cached
    }

    func cachedPassportPreferences(userId: UUID) -> PassportPreferences? {
        if let cached = Self.passportPreferencesCache[userId] {
            SocialFeedDebug.log(
                "profile.service.cache.passport.memory_hit user=\(userId.uuidString) nationalities=\(cached.nationalityCountryCodes.count)"
            )
            return cached
        }

        guard let persisted: PassportPreferences = Self.loadCachedValue(forKey: Self.passportCacheKey(for: userId)) else {
            SocialFeedDebug.log("profile.service.cache.passport.miss user=\(userId.uuidString)")
            return nil
        }

        Self.passportPreferencesCache[userId] = persisted
        SocialFeedDebug.log(
            "profile.service.cache.passport.disk_hit user=\(userId.uuidString) nationalities=\(persisted.nationalityCountryCodes.count)"
        )
        return persisted
    }

    // MARK: - Fetch

    func fetchMyProfile(userId: UUID, useCache: Bool = true) async throws -> Profile {
        if useCache, let cachedProfile = Self.profileCache[userId] {
            SocialFeedDebug.log(
                "profile.service.fetch.cache_hit user=\(userId.uuidString) " +
                "username=\(logField(cachedProfile.username)) avatar=\(logField(cachedProfile.avatarUrl)) " +
                profileDetailDebugSummary(cachedProfile)
            )
            return cachedProfile
        }

        if useCache, let inFlightFetch = Self.inFlightProfileFetches[userId] {
            SocialFeedDebug.log("profile.service.fetch.in_flight_hit user=\(userId.uuidString)")
            return try await inFlightFetch.value
        }

        let startedAt = Date()
        let client = supabase.client
        SocialFeedDebug.log(
            "profile.service.fetch.network.start user=\(userId.uuidString) use_cache=\(useCache) current_user=\(supabase.currentUserId?.uuidString ?? "nil") table=profiles"
        )
        let fetchTask = Task.detached(priority: .userInitiated) {
            let response: PostgrestResponse<[Profile]> = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()

            guard let profile = response.value.first else {
                throw NSError(
                    domain: "ProfileService",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "profile.errors.not_found")]
                )
            }

            return profile
        }

        Self.inFlightProfileFetches[userId] = fetchTask

        do {
            let profile = try await fetchTask.value
            Self.profileCache[userId] = profile
            Self.persistCachedValue(profile, forKey: Self.profileCacheKey(for: userId))
            if Self.inFlightProfileFetches[userId] == fetchTask {
                Self.inFlightProfileFetches[userId] = nil
            }
            SocialFeedDebug.log(
                "profile.service.fetch.network.success user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) " +
                "username=\(logField(profile.username)) avatar=\(logField(profile.avatarUrl)) " +
                profileDetailDebugSummary(profile)
            )
            return profile
        } catch {
            if Self.inFlightProfileFetches[userId] == fetchTask {
                Self.inFlightProfileFetches[userId] = nil
            }
            SocialFeedDebug.log(
                "profile.service.fetch.network.error user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) " +
                "error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    func ensureProfileExists(
        userId: UUID,
        defaultUsername: String? = nil,
        defaultAvatarUrl: String? = nil
    ) async throws {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.service.ensure.start user=\(userId.uuidString) current_user=\(supabase.currentUserId?.uuidString ?? "nil")"
        )

        if let cachedProfile = cachedProfile(userId: userId) {
            SocialFeedDebug.log(
                "profile.service.ensure.cached_exists user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) " +
                "username=\(logField(cachedProfile.username))"
            )
            return
        }

        // Try fetch first
        do {
            _ = try await fetchMyProfile(userId: userId)
            SocialFeedDebug.log(
                "profile.service.ensure.exists user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            return
        } catch let error as NSError {
            // Only create profile if it's truly 404 (not found)
            if error.code == 404 {
                SocialFeedDebug.log("profile.service.ensure.not_found user=\(userId.uuidString)")
            } else {
                // Rethrow network / decoding / timeout errors
                SocialFeedDebug.log(
                    "profile.service.ensure.fetch_error user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
                )
                throw error
            }
        }

        guard let user = supabase.client.auth.currentUser else {
            SocialFeedDebug.log("profile.service.ensure.no_auth_user user=\(userId.uuidString)")
            throw NSError(
                domain: "ProfileService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "profile.errors.no_auth_user")]
            )
        }

        let identity = resolvedIdentity(from: user)

        // Generate a safe default username if none provided
        let generatedUsername: String = {
            if let provided = defaultUsername,
               !provided.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return provided
            }
            // e.g. user_925948
            let shortId = userId.uuidString
                .replacingOccurrences(of: "-", with: "")
                .prefix(6)
            return "user_\(shortId)".lowercased()
        }()

        let createPayload = ProfileCreate(
            id: userId,
            username: generatedUsername,
            avatar_url: defaultAvatarUrl ?? identity.avatarURL ?? "",
            full_name: identity.fullName,
            first_name: identity.firstName,
            last_name: identity.lastName
        )

        // Insert can transiently fail right after signup if auth.users row isn't visible yet.
        // Retry a few times on FK violation (23503) before giving up.
        let delays: [UInt64] = [0, 200_000_000, 500_000_000, 1_000_000_000] // 0s, 0.2s, 0.5s, 1.0s

        var lastError: Error?

        for (idx, delay) in delays.enumerated() {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            do {
                SocialFeedDebug.log(
                    "profile.service.ensure.insert.attempt user=\(userId.uuidString) attempt=\(idx + 1)/\(delays.count) delay_ns=\(delay)"
                )
                do {
                    try await supabase.client
                        .from("profiles")
                        .insert(createPayload)
                        .execute()
                } catch {
                    guard Self.isMissingSplitNameColumnsError(error) else {
                        throw error
                    }

                    try await supabase.client
                        .from("profiles")
                        .insert(Self.legacyProfileCreate(from: createPayload))
                        .execute()
                }

                SocialFeedDebug.log(
                    "profile.service.ensure.insert.success user=\(userId.uuidString) attempt=\(idx + 1) duration=\(SocialFeedDebug.duration(since: startedAt))"
                )
                return

            } catch {
                lastError = error
                SocialFeedDebug.log(
                    "profile.service.ensure.insert.error user=\(userId.uuidString) attempt=\(idx + 1) error=\(SocialFeedDebug.describe(error))"
                )

                if let pg = error as? PostgrestError, pg.code == "23503" {
                    print("⚠️ ensureProfileExists FK violation (23503) — retry \(idx + 1)/\(delays.count)")
                    continue
                }

                throw error
            }
        }

        throw lastError ?? NSError(
            domain: "ProfileService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: String(localized: "profile.errors.create_after_retries_failed")]
        )
    }

    func fetchOrCreateProfile(
        userId: UUID,
        defaultUsername: String? = nil,
        defaultAvatarUrl: String? = nil,
        useCache: Bool = true
    ) async throws -> Profile {
        let startedAt = Date()
        SocialFeedDebug.log("profile.service.fetch_or_create.start user=\(userId.uuidString) use_cache=\(useCache)")
        do {
            let profile = try await fetchMyProfile(userId: userId, useCache: useCache)
            hydrateProfileIdentityFromAuthMetadataIfNeededInBackground(
                userId: userId,
                profile: profile
            )
            SocialFeedDebug.log(
                "profile.service.fetch_or_create.success user=\(userId.uuidString) source=fetch duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            return profile
        } catch let error as NSError where error.code == 404 {
            SocialFeedDebug.log("profile.service.fetch_or_create.ensure user=\(userId.uuidString) reason=not_found")
            try await ensureProfileExists(
                userId: userId,
                defaultUsername: defaultUsername,
                defaultAvatarUrl: defaultAvatarUrl
            )
            let profile = try await fetchMyProfile(userId: userId, useCache: false)
            SocialFeedDebug.log(
                "profile.service.fetch_or_create.success user=\(userId.uuidString) source=create duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            hydrateProfileIdentityFromAuthMetadataIfNeededInBackground(
                userId: userId,
                profile: profile
            )
            return profile
        } catch {
            SocialFeedDebug.log(
                "profile.service.fetch_or_create.error user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    // MARK: - Update

    func updateProfile(
        userId: UUID,
        payload: ProfileUpdate
    ) async throws {
        do {
            try await supabase.client
                .from("profiles")
                .update(payload)
                .eq("id", value: userId)
                .execute()
        } catch {
            guard Self.isMissingSplitNameColumnsError(error) else {
                throw error
            }

            try await supabase.client
                .from("profiles")
                .update(Self.legacyProfileUpdate(from: payload))
                .eq("id", value: userId)
                .execute()
        }
    }

    func cacheProfile(_ profile: Profile) {
        SocialFeedDebug.log(
            "profile.service.cache.write user=\(profile.id.uuidString) " +
            "username=\(logField(profile.username)) avatar=\(logField(profile.avatarUrl)) " +
            profileDetailDebugSummary(profile)
        )
        Self.profileCache[profile.id] = profile
        Self.persistCachedValue(profile, forKey: Self.profileCacheKey(for: profile.id))
    }

    private func profileDetailDebugSummary(_ profile: Profile) -> String {
        [
            "languages=\(profile.languages.count)",
            "lived=\(profile.livedCountries.count)",
            "travel_style=\(profile.travelStyle.count)",
            "travel_mode=\(profile.travelMode.count)",
            "next=\(logField(profile.nextDestination))",
            "current=\(logField(profile.currentCountry))",
            "favorites=\(profile.favoriteCountries?.count ?? 0)",
            "onboarding=\(profile.onboardingCompleted.map(String.init) ?? "nil")",
            "friend_count=\(profile.friendCount)"
        ].joined(separator: " ")
    }

    private func logField(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "nil" : trimmed
    }

    func fetchPassportPreferences(userId: UUID) async throws -> PassportPreferences {
        let startedAt = Date()
        SocialFeedDebug.log("profile.service.passport.fetch.start user=\(userId.uuidString) table=user_passport_preferences")
        do {
            let response: PostgrestResponse<[PassportPreferencesRow]> = try await supabase.client
                .from("user_passport_preferences")
                .select("user_id,nationality_country_codes,passport_country_code")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()

            let preferences = PassportPreferences(
                nationalityCountryCodes: response.value.first?.nationalityCountryCodes ?? [],
                passportCountryCode: response.value.first?.passportCountryCode
            )

            Self.passportPreferencesCache[userId] = preferences
            Self.persistCachedValue(preferences, forKey: Self.passportCacheKey(for: userId))
            SocialFeedDebug.log(
                "profile.service.passport.fetch.success user=\(userId.uuidString) rows=\(response.value.count) nationalities=\(preferences.nationalityCountryCodes.count) duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            return preferences
        } catch {
            SocialFeedDebug.log(
                "profile.service.passport.fetch.error user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    func upsertPassportPreferences(
        userId: UUID,
        nationalityCountryCodes: [String],
        passportCountryCode: String?
    ) async throws {
        let normalizedNationalityCountryCodes = nationalityCountryCodes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
        let normalizedPassportCountryCode = passportCountryCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let payload = PassportPreferencesRow(
            userId: userId,
            nationalityCountryCodes: normalizedNationalityCountryCodes,
            passportCountryCode: normalizedPassportCountryCode
        )

        try await supabase.client
            .from("user_passport_preferences")
            .upsert(payload)
            .execute()

        Self.passportPreferencesCache[userId] = PassportPreferences(
            nationalityCountryCodes: normalizedNationalityCountryCodes,
            passportCountryCode: normalizedPassportCountryCode
        )
        Self.persistCachedValue(
            Self.passportPreferencesCache[userId],
            forKey: Self.passportCacheKey(for: userId)
        )
    }

    private func hydrateProfileIdentityFromAuthMetadataIfNeeded(
        userId: UUID,
        profile: Profile
    ) async throws -> Profile {
        guard userId == supabase.currentUserId,
              let user = supabase.client.auth.currentUser else {
            return profile
        }

        let identity = resolvedIdentity(from: user)
        let shouldFillFirstName = (profile.firstName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && identity.firstName != nil
        let shouldFillLastName = (profile.lastName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && identity.lastName != nil
        let shouldFillFullName = profile.formattedFullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !identity.fullName.isEmpty
        let shouldFillAvatar = (profile.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && identity.avatarURL != nil

        guard shouldFillFirstName || shouldFillLastName || shouldFillFullName || shouldFillAvatar else {
            return profile
        }

        let payload = ProfileUpdate(
            username: nil,
            fullName: shouldFillFullName ? identity.fullName : nil,
            firstName: shouldFillFirstName ? identity.firstName : nil,
            lastName: shouldFillLastName ? identity.lastName : nil,
            avatarUrl: shouldFillAvatar ? identity.avatarURL : nil,
            languages: nil,
            livedCountries: nil,
            travelStyle: nil,
            travelMode: nil,
            nextDestination: nil,
            defaultCurrencyCode: nil,
            currentCountry: nil,
            favoriteCountries: nil,
            onboardingCompleted: nil
        )

        try await updateProfile(userId: userId, payload: payload)

        var hydratedProfile = profile
        if shouldFillFirstName { hydratedProfile.firstName = identity.firstName }
        if shouldFillLastName { hydratedProfile.lastName = identity.lastName }
        if shouldFillFullName { hydratedProfile.fullName = identity.fullName }
        if shouldFillAvatar { hydratedProfile.avatarUrl = identity.avatarURL }
        Self.profileCache[userId] = hydratedProfile
        Self.persistCachedValue(hydratedProfile, forKey: Self.profileCacheKey(for: userId))
        return hydratedProfile
    }

    private func hydrateProfileIdentityFromAuthMetadataIfNeededInBackground(
        userId: UUID,
        profile: Profile
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await self.hydrateProfileIdentityFromAuthMetadataIfNeeded(
                    userId: userId,
                    profile: profile
                )
            } catch { }
        }
    }

    private func resolvedIdentity(from user: User) -> ResolvedProfileIdentity {
        let metadata = user.userMetadata
        let firstName =
            metadata["first_name"]?.stringValue?.nilIfEmpty ??
            metadata["given_name"]?.stringValue?.nilIfEmpty
        let lastName =
            metadata["last_name"]?.stringValue?.nilIfEmpty ??
            metadata["family_name"]?.stringValue?.nilIfEmpty
        let fullName =
            ([firstName, lastName].compactMap { $0 }.joined(separator: " ")).nilIfEmpty ??
            metadata["full_name"]?.stringValue?.nilIfEmpty ??
            metadata["name"]?.stringValue?.nilIfEmpty ??
            firstName ??
            "User"
        let avatarURL =
            metadata["avatar_url"]?.stringValue?.nilIfEmpty ??
            metadata["picture"]?.stringValue?.nilIfEmpty

        return ResolvedProfileIdentity(
            firstName: firstName,
            lastName: lastName,
            fullName: fullName,
            avatarURL: avatarURL
        )
    }

    // MARK: - Avatar Storage

    func uploadAvatar(
        data: Data,
        path: String
    ) async throws {

        try await supabase.client.storage
            .from("avatars")
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
    }

    func publicAvatarURL(path: String) throws -> String {
        try supabase.client.storage
            .from("avatars")
            .getPublicURL(path: path)
            .absoluteString
    }

    // MARK: - Viewed user stats

    /// Traveled countries for any viewed user
    func fetchTraveledCountries(userId: UUID) async throws -> Set<String> {
        let startedAt = Date()
        SocialFeedDebug.log("profile.service.traveled.fetch.start user=\(userId.uuidString) table=user_traveled")
        do {
            let response: PostgrestResponse<[CountryRow]> = try await supabase.client
                .from("user_traveled")
                .select("country_id")
                .eq("user_id", value: userId.uuidString)
                .limit(1000)
                .execute()

            let traveled = Set(response.value.map { $0.countryId })
            Self.traveledCache[userId] = traveled
            Self.persistCachedValue(
                PersistedCountrySet(countryCodes: traveled.sorted()),
                forKey: Self.traveledCacheKey(for: userId)
            )
            SocialFeedDebug.log(
                "profile.service.traveled.fetch.success user=\(userId.uuidString) rows=\(response.value.count) unique=\(traveled.count) duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            return traveled
        } catch {
            SocialFeedDebug.log(
                "profile.service.traveled.fetch.error user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    /// Bucket list countries for any viewed user
    func fetchBucketListCountries(userId: UUID) async throws -> Set<String> {
        let startedAt = Date()
        SocialFeedDebug.log("profile.service.bucket.fetch.start user=\(userId.uuidString) table=user_bucket_list")
        do {
            let response: PostgrestResponse<[CountryRow]> = try await supabase.client
                .from("user_bucket_list")
                .select("country_id")
                .eq("user_id", value: userId.uuidString)
                .limit(1000)
                .execute()

            let bucket = Set(response.value.map { $0.countryId })
            Self.bucketCache[userId] = bucket
            Self.persistCachedValue(
                PersistedCountrySet(countryCodes: bucket.sorted()),
                forKey: Self.bucketCacheKey(for: userId)
            )
            let duplicates = response.value.count - bucket.count
            SocialFeedDebug.log(
                "profile.service.bucket.fetch.success user=\(userId.uuidString) rows=\(response.value.count) duplicates=\(duplicates) " +
                "\(SocialFeedDebug.countrySetSummary(bucket)) duration=\(SocialFeedDebug.duration(since: startedAt))"
            )
            return bucket
        } catch {
            SocialFeedDebug.log(
                "profile.service.bucket.fetch.error user=\(userId.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }
    }

    // MARK: - Bucket List Mutations

    func addToBucketList(
        userId: UUID,
        countryCode: String
    ) async throws {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.service.bucket.add.start user=\(userId.uuidString) country=\(countryCode) current_user=\(supabase.currentUserId?.uuidString ?? "nil")"
        )

        struct InsertRow: Encodable {
            let user_id: String
            let country_id: String
        }

        let payload = InsertRow(
            user_id: userId.uuidString,
            country_id: countryCode
        )

        do {
            try await supabase.client
                .from("user_bucket_list")
                .insert(payload)
                .execute()
        } catch {
            SocialFeedDebug.log(
                "profile.service.bucket.add.error user=\(userId.uuidString) country=\(countryCode) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }

        Self.bucketCache[userId]?.insert(countryCode)
        if let cached = Self.bucketCache[userId] {
            Self.persistCachedValue(
                PersistedCountrySet(countryCodes: cached.sorted()),
                forKey: Self.bucketCacheKey(for: userId)
            )
            SocialFeedDebug.log(
                "profile.service.bucket.add.cache_after user=\(userId.uuidString) country=\(countryCode) \(SocialFeedDebug.countrySetSummary(cached))"
            )
        } else {
            SocialFeedDebug.log("profile.service.bucket.add.cache_after user=\(userId.uuidString) country=\(countryCode) cache=empty")
        }
        SocialFeedDebug.log(
            "profile.service.bucket.add.success user=\(userId.uuidString) country=\(countryCode) duration=\(SocialFeedDebug.duration(since: startedAt))"
        )
    }

    func removeFromBucketList(
        userId: UUID,
        countryCode: String
    ) async throws {
        let startedAt = Date()
        SocialFeedDebug.log(
            "profile.service.bucket.remove.start user=\(userId.uuidString) country=\(countryCode) current_user=\(supabase.currentUserId?.uuidString ?? "nil")"
        )

        do {
            try await supabase.client
                .from("user_bucket_list")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("country_id", value: countryCode)
                .execute()
        } catch {
            SocialFeedDebug.log(
                "profile.service.bucket.remove.error user=\(userId.uuidString) country=\(countryCode) duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))"
            )
            throw error
        }

        Self.bucketCache[userId]?.remove(countryCode)
        if let cached = Self.bucketCache[userId] {
            Self.persistCachedValue(
                PersistedCountrySet(countryCodes: cached.sorted()),
                forKey: Self.bucketCacheKey(for: userId)
            )
            SocialFeedDebug.log(
                "profile.service.bucket.remove.cache_after user=\(userId.uuidString) country=\(countryCode) \(SocialFeedDebug.countrySetSummary(cached))"
            )
        } else {
            SocialFeedDebug.log("profile.service.bucket.remove.cache_after user=\(userId.uuidString) country=\(countryCode) cache=empty")
        }
        SocialFeedDebug.log(
            "profile.service.bucket.remove.success user=\(userId.uuidString) country=\(countryCode) duration=\(SocialFeedDebug.duration(since: startedAt))"
        )
    }

    private static func isMissingSplitNameColumnsError(_ error: Error) -> Bool {
        guard let postgrestError = error as? PostgrestError,
              postgrestError.code == "PGRST204" else {
            return false
        }

        let message = postgrestError.message.lowercased()
        return message.contains("profiles")
            && (
                message.contains("first_name")
                || message.contains("last_name")
                || message.contains("default_currency_code")
            )
    }

    private static func legacyProfileUpdate(from payload: ProfileUpdate) -> LegacyProfileUpdate {
        LegacyProfileUpdate(
            username: payload.username,
            fullName: payload.fullName,
            avatarUrl: payload.avatarUrl,
            languages: payload.languages,
            livedCountries: payload.livedCountries,
            travelStyle: payload.travelStyle,
            travelMode: payload.travelMode,
            nextDestination: payload.nextDestination,
            defaultCurrencyCode: nil,
            currentCountry: payload.currentCountry,
            favoriteCountries: payload.favoriteCountries,
            onboardingCompleted: payload.onboardingCompleted
        )
    }

    private static func legacyProfileCreate(from payload: ProfileCreate) -> LegacyProfileCreate {
        LegacyProfileCreate(
            id: payload.id,
            username: payload.username,
            avatar_url: payload.avatar_url,
            full_name: payload.full_name
        )
    }

    private static func profileCacheKey(for userId: UUID) -> String {
        CacheKeys.profilePrefix + userId.uuidString.lowercased()
    }

    private static func traveledCacheKey(for userId: UUID) -> String {
        CacheKeys.traveledPrefix + userId.uuidString.lowercased()
    }

    private static func bucketCacheKey(for userId: UUID) -> String {
        CacheKeys.bucketPrefix + userId.uuidString.lowercased()
    }

    private static func passportCacheKey(for userId: UUID) -> String {
        CacheKeys.passportPrefix + userId.uuidString.lowercased()
    }

    private static func loadCachedValue<Value: Decodable>(forKey key: String) -> Value? {
        guard let data = loadCachedData(forKey: key) else { return nil }

        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            removeCachedValue(forKey: key)
            return nil
        }
    }

    private static func persistCachedValue<Value: Encodable>(_ value: Value?, forKey key: String) {
        guard let value else {
            removeCachedValue(forKey: key)
            return
        }

        do {
            let data = try JSONEncoder().encode(value)
            persistCachedData(data, forKey: key)
        } catch { }
    }

    private static func loadCachedData(forKey key: String) -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    private static func persistCachedData(_ data: Data, forKey key: String) {
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func removeCachedValue(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
