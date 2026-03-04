//
//  ProfileViewModel+Save.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/19/26.
//

import Foundation
import Combine
import Supabase
import PostgREST

extension ProfileViewModel {

    // MARK: - Save (single source of truth)

    func saveProfile(
        firstName: String,
        username: String,
        homeCountries: [String]?,
        languages: [[String: String]]?,
        travelMode: String?,
        travelStyle: String?,
        nextDestination: String?,
        currentCountry: String?,
        favoriteCountries: [String]?,
        avatarUrl: String?
    ) async throws {
        let userId = self.userId
        errorMessage = nil
        
        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedCurrentCountry: String? = {
            guard let currentCountry,
                  !currentCountry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return currentCountry
        }()

        let normalizedFavoriteCountries = favoriteCountries?.sorted()

        guard !trimmedName.isEmpty, !trimmedUsername.isEmpty else {
            throw NSError(domain: "ProfileValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Name and username are required."])
        }
        
        let payload = ProfileUpdate(
            username: trimmedUsername,
            fullName: trimmedName,
            avatarUrl: avatarUrl,
            languages: languages,
            livedCountries: homeCountries,
            travelStyle: travelStyle.map { [$0] },
            travelMode: travelMode.map { [$0] },
            nextDestination: nextDestination,
            currentCountry: normalizedCurrentCountry,
            favoriteCountries: normalizedFavoriteCountries,
            onboardingCompleted: true
        )
        
        try await profileService.updateProfile(
            userId: userId,
            payload: payload
        )

        // 🔥 META GOLD STANDARD: deterministic local state merge (no immediate refetch)
        if var current = profile {
            current.username = trimmedUsername
            current.fullName = trimmedName
            current.livedCountries = homeCountries ?? current.livedCountries
            if let languages {
                current.languages = languages.compactMap { dict in
                    guard let code = dict["code"],
                          let proficiency = dict["proficiency"] else { return nil }
                    return Profile.LanguageJSON(code: code, proficiency: proficiency)
                }
            }
            current.travelStyle = travelStyle.map { [$0] } ?? current.travelStyle
            current.travelMode = travelMode.map { [$0] } ?? current.travelMode
            current.nextDestination = nextDestination
            current.currentCountry = normalizedCurrentCountry
            current.favoriteCountries = normalizedFavoriteCountries ?? current.favoriteCountries

            // Handle avatarUrl explicitly ("" means remove)
            if let avatarUrl {
                current.avatarUrl = avatarUrl.isEmpty ? nil : avatarUrl
            }

            profile = current
        }

        
    }
    
    func uploadAvatar(data: Data, fileName: String) async throws -> String {
        let path = "\(fileName)"
        
        try await profileService.uploadAvatar(
            data: data,
            path: path
        )
        
        return try profileService.publicAvatarURL(path: path)
    }
}
