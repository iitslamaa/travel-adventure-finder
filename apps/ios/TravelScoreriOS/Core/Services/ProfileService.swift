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

@MainActor
final class ProfileService {

    private static var profileCache: [UUID: Profile] = [:]
    private static var traveledCache: [UUID: Set<String>] = [:]
    private static var bucketCache: [UUID: Set<String>] = [:]
    private static var passportPreferencesCache: [UUID: PassportPreferences] = [:]

    private let supabase: SupabaseManager

    init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    func cachedProfile(userId: UUID) -> Profile? {
        Self.profileCache[userId]
    }

    func cachedTraveledCountries(userId: UUID) -> Set<String>? {
        Self.traveledCache[userId]
    }

    func cachedBucketListCountries(userId: UUID) -> Set<String>? {
        Self.bucketCache[userId]
    }

    func cachedPassportPreferences(userId: UUID) -> PassportPreferences? {
        Self.passportPreferencesCache[userId]
    }

    // MARK: - Fetch

    func fetchMyProfile(userId: UUID) async throws -> Profile {
        let response: PostgrestResponse<[Profile]> = try await supabase.client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()

        guard let profile = response.value.first else {
            throw NSError(
                domain: "ProfileService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "profile.errors.not_found")]
            )
        }

        Self.profileCache[userId] = profile

        return profile
    }

    func ensureProfileExists(
        userId: UUID,
        defaultUsername: String? = nil,
        defaultAvatarUrl: String? = nil
    ) async throws {

        // Try fetch first
        do {
            _ = try await fetchMyProfile(userId: userId)
            return
        } catch let error as NSError {
            // Only create profile if it's truly 404 (not found)
            if error.code == 404 {
            } else {
                // Rethrow network / decoding / timeout errors
                throw error
            }
        }

        guard let user = supabase.client.auth.currentUser else {
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

                return

            } catch {
                lastError = error

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
        defaultAvatarUrl: String? = nil
    ) async throws -> Profile {
        do {
            let profile = try await fetchMyProfile(userId: userId)
            return try await hydrateProfileIdentityFromAuthMetadataIfNeeded(
                userId: userId,
                profile: profile
            )
        } catch let error as NSError where error.code == 404 {
            try await ensureProfileExists(
                userId: userId,
                defaultUsername: defaultUsername,
                defaultAvatarUrl: defaultAvatarUrl
            )
            let profile = try await fetchMyProfile(userId: userId)
            return try await hydrateProfileIdentityFromAuthMetadataIfNeeded(
                userId: userId,
                profile: profile
            )
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

    func fetchPassportPreferences(userId: UUID) async throws -> PassportPreferences {
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
        return preferences
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
        return hydratedProfile
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
                path: path,
                file: data,
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
        let response: PostgrestResponse<[CountryRow]> = try await supabase.client
            .from("user_traveled")
            .select("country_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1000)
            .execute()

        let traveled = Set(response.value.map { $0.countryId })
        Self.traveledCache[userId] = traveled
        return traveled
    }

    /// Bucket list countries for any viewed user
    func fetchBucketListCountries(userId: UUID) async throws -> Set<String> {
        let response: PostgrestResponse<[CountryRow]> = try await supabase.client
            .from("user_bucket_list")
            .select("country_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1000)
            .execute()

        let bucket = Set(response.value.map { $0.countryId })
        Self.bucketCache[userId] = bucket
        return bucket
    }

    // MARK: - Bucket List Mutations

    func addToBucketList(
        userId: UUID,
        countryCode: String
    ) async throws {

        struct InsertRow: Encodable {
            let user_id: String
            let country_id: String
        }

        let payload = InsertRow(
            user_id: userId.uuidString,
            country_id: countryCode
        )

        try await supabase.client
            .from("user_bucket_list")
            .insert(payload)
            .execute()
    }

    func removeFromBucketList(
        userId: UUID,
        countryCode: String
    ) async throws {

        try await supabase.client
            .from("user_bucket_list")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("country_id", value: countryCode)
            .execute()
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
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
