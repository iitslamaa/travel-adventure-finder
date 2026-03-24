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
    let avatarUrl: String?
    let languages: [[String: String]]?
    let livedCountries: [String]?
    let travelStyle: [String]?
    let travelMode: [String]?
    let nextDestination: String?
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

        let metadata = user.userMetadata

        let fullName =
            metadata["full_name"]?.stringValue ??
            metadata["name"]?.stringValue ??
            "User"

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
            avatar_url: defaultAvatarUrl ?? "",
            full_name: fullName
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
                try await supabase.client
                    .from("profiles")
                    .insert(createPayload)
                    .execute()

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
            return try await fetchMyProfile(userId: userId)
        } catch let error as NSError where error.code == 404 {
            try await ensureProfileExists(
                userId: userId,
                defaultUsername: defaultUsername,
                defaultAvatarUrl: defaultAvatarUrl
            )
            return try await fetchMyProfile(userId: userId)
        }
    }

    // MARK: - Update

    func updateProfile(
        userId: UUID,
        payload: ProfileUpdate
    ) async throws {
        try await supabase.client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .execute()
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
}
