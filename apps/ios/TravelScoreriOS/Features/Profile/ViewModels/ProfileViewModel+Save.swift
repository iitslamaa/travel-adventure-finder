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
        passportNationalities: [String],
        visaPassportCountryCode: String?,
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
        let normalizedPassportNationalities = passportNationalities
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
            .sorted()
        let normalizedVisaPassportCountryCode: String? = {
            let normalized = visaPassportCountryCode?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            guard let normalized, !normalized.isEmpty else {
                return normalizedPassportNationalities.first
            }

            return normalizedPassportNationalities.contains(normalized)
                ? normalized
                : normalizedPassportNationalities.first
        }()

        guard !trimmedName.isEmpty, !trimmedUsername.isEmpty else {
            throw NSError(
                domain: "ProfileValidation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "profile.errors.name_username_required")]
            )
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

        try await profileService.upsertPassportPreferences(
            userId: userId,
            nationalityCountryCodes: normalizedPassportNationalities,
            passportCountryCode: normalizedVisaPassportCountryCode
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
                    return Profile.LanguageJSON(
                        code: LanguageRepository.shared.canonicalLanguageCode(for: code)
                            ?? code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                        proficiency: LanguageProficiency(storageValue: proficiency).storageValue
                    )
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

        passportPreferences = PassportPreferences(
            nationalityCountryCodes: normalizedPassportNationalities,
            passportCountryCode: normalizedVisaPassportCountryCode
        )

        
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
