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

    private struct ComparableLanguageEntry: Equatable {
        let code: String
        let proficiency: String
    }

    // MARK: - Save (single source of truth)

    func saveProfile(
        firstName: String,
        lastName: String,
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
        
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedName = [trimmedFirstName, trimmedLastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

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

        guard !trimmedFirstName.isEmpty, !trimmedUsername.isEmpty else {
            throw NSError(
                domain: "ProfileValidation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "profile.errors.name_username_required")]
            )
        }
        
        let payload = ProfileUpdate(
            username: trimmedUsername,
            fullName: combinedName,
            firstName: trimmedFirstName,
            lastName: trimmedLastName.isEmpty ? nil : trimmedLastName,
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

        if shouldUpdateProfile(payload: payload, combinedName: combinedName) {
            try await profileService.updateProfile(
                userId: userId,
                payload: payload
            )
        }

        try await profileService.replacePassportPreferences(
            userId: userId,
            nationalityCountryCodes: normalizedPassportNationalities,
            passportCountryCode: normalizedVisaPassportCountryCode
        )

        // 🔥 META GOLD STANDARD: deterministic local state merge (no immediate refetch)
        if var current = profile {
            current.username = trimmedUsername
            current.firstName = trimmedFirstName
            current.lastName = trimmedLastName.isEmpty ? nil : trimmedLastName
            current.fullName = combinedName
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

    private func shouldUpdateProfile(payload: ProfileUpdate, combinedName: String) -> Bool {
        guard let current = profile else { return true }

        let normalizedCurrentLastName = current.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPayloadLastName = payload.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrentAvatar = current.avatarUrl ?? ""
        let normalizedPayloadAvatar = payload.avatarUrl ?? current.avatarUrl ?? ""
        let normalizedCurrentLanguages = current.languages.map {
            ComparableLanguageEntry(
                code: LanguageRepository.shared.canonicalLanguageCode(for: $0.code) ?? $0.code,
                proficiency: LanguageProficiency(storageValue: $0.proficiency).storageValue
            )
        }
        let normalizedPayloadLanguages = (payload.languages ?? current.languages.map { [
            "code": $0.code,
            "proficiency": $0.proficiency
        ] }).compactMap { dict -> ComparableLanguageEntry? in
            guard let code = dict["code"], let proficiency = dict["proficiency"] else { return nil }
            return ComparableLanguageEntry(
                code: LanguageRepository.shared.canonicalLanguageCode(for: code) ?? code,
                proficiency: LanguageProficiency(storageValue: proficiency).storageValue
            )
        }

        return current.username != (payload.username ?? current.username)
            || current.fullName != combinedName
            || (current.firstName ?? "") != (payload.firstName ?? "")
            || normalizedCurrentLastName != normalizedPayloadLastName
            || normalizedCurrentAvatar != normalizedPayloadAvatar
            || current.livedCountries != (payload.livedCountries ?? current.livedCountries)
            || normalizedCurrentLanguages != normalizedPayloadLanguages
            || current.travelStyle != (payload.travelStyle ?? current.travelStyle)
            || current.travelMode != (payload.travelMode ?? current.travelMode)
            || current.nextDestination != payload.nextDestination
            || current.currentCountry != payload.currentCountry
            || current.favoriteCountries != (payload.favoriteCountries ?? current.favoriteCountries)
            || current.onboardingCompleted != true
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
