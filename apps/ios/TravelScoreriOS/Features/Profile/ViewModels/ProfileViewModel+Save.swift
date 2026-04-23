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
        lastName: String,
        username: String,
        defaultCurrencyCode: String?,
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
        let previousProfile = profile
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
        let normalizedDefaultCurrencyCode = AppCurrencyCatalog.normalizedCode(defaultCurrencyCode)

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
            defaultCurrencyCode: normalizedDefaultCurrencyCode,
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
            current.defaultCurrencyCode = normalizedDefaultCurrencyCode
            current.currentCountry = normalizedCurrentCountry
            current.favoriteCountries = normalizedFavoriteCountries ?? current.favoriteCountries

            // Handle avatarUrl explicitly ("" means remove)
            if let avatarUrl {
                current.avatarUrl = avatarUrl.isEmpty ? nil : avatarUrl
            }

            profile = current
            profileService.cacheProfile(current)
        }

        passportPreferences = PassportPreferences(
            nationalityCountryCodes: normalizedPassportNationalities,
            passportCountryCode: normalizedVisaPassportCountryCode
        )

        await recordProfileActivityChanges(
            userId: userId,
            previousProfile: previousProfile,
            nextDestination: nextDestination,
            currentCountry: normalizedCurrentCountry,
            homeCountries: homeCountries,
            avatarUrl: avatarUrl
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

    private func recordProfileActivityChanges(
        userId: UUID,
        previousProfile: Profile?,
        nextDestination: String?,
        currentCountry: String?,
        homeCountries: [String]?,
        avatarUrl: String?
    ) async {
        let activityService = SocialActivityService()

        if let currentCountry,
           normalizedCountryCode(previousProfile?.currentCountry) != normalizedCountryCode(currentCountry) {
            await recordActivity(
                service: activityService,
                userId: userId,
                eventType: .currentCountryChanged,
                countryCode: currentCountry
            )
        }

        if let nextDestination,
           normalizedCountryCode(previousProfile?.nextDestination) != normalizedCountryCode(nextDestination) {
            await recordActivity(
                service: activityService,
                userId: userId,
                eventType: .nextDestinationChanged,
                countryCode: nextDestination
            )
        }

        if let homeCountries {
            let previousHomeCountries = Set(previousProfile?.livedCountries.map(normalizedCountryCode) ?? [])
            let updatedHomeCountries = Set(homeCountries.map(normalizedCountryCode))

            if previousHomeCountries != updatedHomeCountries,
               let changedCountry = updatedHomeCountries.subtracting(previousHomeCountries).first ?? updatedHomeCountries.first {
                await recordActivity(
                    service: activityService,
                    userId: userId,
                    eventType: .homeCountryChanged,
                    countryCode: changedCountry
                )
            }
        }

        if let avatarUrl {
            let previousAvatarUrl = previousProfile?.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let updatedAvatarUrl = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)

            if previousAvatarUrl != updatedAvatarUrl, !updatedAvatarUrl.isEmpty {
                do {
                    try await activityService.recordActivity(
                        actorUserId: userId,
                        eventType: .profilePhotoUpdated,
                        metadata: [:]
                    )
                } catch {
#if DEBUG
                    print("Failed to record profile photo activity:", error.localizedDescription)
#endif
                }
            }
        }
    }

    private func recordActivity(
        service: SocialActivityService,
        userId: UUID,
        eventType: SocialActivityEventType,
        countryCode: String
    ) async {
        let code = normalizedCountryCode(countryCode)

        do {
            try await service.recordActivity(
                actorUserId: userId,
                eventType: eventType,
                metadata: [
                    "country_code": code,
                    "country_name": countryDisplayName(for: code)
                ]
            )
        } catch {
#if DEBUG
            print("Failed to record profile activity:", error.localizedDescription)
#endif
        }
    }

    private func normalizedCountryCode(_ code: String?) -> String {
        code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
    }

    private func countryDisplayName(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
}
