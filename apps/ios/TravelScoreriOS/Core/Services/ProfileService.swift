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

private struct CountryRow: Decodable {
    let countryId: String

    enum CodingKeys: String, CodingKey {
        case countryId = "country_id"
    }
}

@MainActor
final class ProfileService {

    private let supabase: SupabaseManager

    init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    // MARK: - Fetch

    func fetchMyProfile(userId: UUID) async throws -> Profile {
        print("📥 fetchMyProfile called for userId:", userId)
        print("   🧠 ProfileService instance:", ObjectIdentifier(self))
        let response: PostgrestResponse<[Profile]> = try await supabase.client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
        print("   📦 fetchMyProfile raw count:", response.value.count)
        print("   📦 fetchMyProfile ids:", response.value.map { $0.id })

        guard let profile = response.value.first else {
            throw NSError(
                domain: "ProfileService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Profile not found"]
            )
        }

        print("✅ fetchMyProfile returning profile id:", profile.id)
        print("   🔎 fetchMyProfile friend_count:", profile.friendCount)
        return profile
    }

    func ensureProfileExists(
        userId: UUID,
        defaultUsername: String? = nil,
        defaultAvatarUrl: String? = nil
    ) async throws {
        print("🛠 ensureProfileExists called for:", userId)
        print("   🧠 ProfileService instance:", ObjectIdentifier(self))

        // Try fetch first
        do {
            _ = try await fetchMyProfile(userId: userId)
            return
        } catch let error as NSError {
            // Only create profile if it's truly 404 (not found)
            if error.code == 404 {
                print("🟡 Profile truly missing, creating one for:", userId)
            } else {
                // Rethrow network / decoding / timeout errors
                throw error
            }
        }

        guard let user = supabase.client.auth.currentUser else {
            throw NSError(
                domain: "ProfileService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No auth user found"]
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

        try await supabase.client
            .from("profiles")
            .insert(createPayload)
            .execute()

        print("✅ Profile created with full_name:", fullName)
    }

    func fetchOrCreateProfile(
        userId: UUID,
        defaultUsername: String? = nil,
        defaultAvatarUrl: String? = nil
    ) async throws -> Profile {
        print("📥 fetchOrCreateProfile called for userId:", userId)
        print("   🧠 ProfileService instance:", ObjectIdentifier(self))
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
        print("🌍 fetchTraveledCountries for userId:", userId)
        print("   🧠 ProfileService instance:", ObjectIdentifier(self))
        let response: PostgrestResponse<[CountryRow]> = try await supabase.client
            .from("user_traveled")
            .select("country_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1000)
            .execute()
        print("   📦 traveled raw rows count:", response.value.count)
        print("   📦 traveled countryIds:", response.value.map { $0.countryId })

        return Set(response.value.map { $0.countryId })
    }

    /// Bucket list countries for any viewed user
    func fetchBucketListCountries(userId: UUID) async throws -> Set<String> {
        print("🪣 fetchBucketListCountries for userId:", userId)
        print("   🧠 ProfileService instance:", ObjectIdentifier(self))
        let response: PostgrestResponse<[CountryRow]> = try await supabase.client
            .from("user_bucket_list")
            .select("country_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1000)
            .execute()
        print("   📦 bucket raw rows count:", response.value.count)
        print("   📦 bucket countryIds:", response.value.map { $0.countryId })

        return Set(response.value.map { $0.countryId })
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

        print("📡 INSERT user:", userId.uuidString, "country:", countryCode)
        try await supabase.client
            .from("user_bucket_list")
            .insert(payload)
            .execute()
        print("✅ INSERT completed for:", countryCode)
    }

    func removeFromBucketList(
        userId: UUID,
        countryCode: String
    ) async throws {

        print("📡 DELETE user:", userId.uuidString, "country:", countryCode)
        try await supabase.client
            .from("user_bucket_list")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("country_id", value: countryCode)
            .execute()
        print("✅ DELETE completed for:", countryCode)
    }
}
