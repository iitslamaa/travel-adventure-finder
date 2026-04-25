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
        errorMessage = nil
        let existingProfile = profile
        
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
            let changedFriendCacheEntries = friendService.refreshCachedProfile(current)
            SocialFeedDebug.log(
                "profile.save.cache_reconciled user=\(userId) friend_cache_changes=\(changedFriendCacheEntries) avatar=\(current.avatarUrl ?? "nil")"
            )
        }

        passportPreferences = PassportPreferences(
            nationalityCountryCodes: normalizedPassportNationalities,
            passportCountryCode: normalizedVisaPassportCountryCode
        )

        if didChangeSocialActivityFields(
            from: existingProfile,
            nextDestination: nextDestination,
            currentCountry: normalizedCurrentCountry,
            homeCountries: homeCountries ?? existingProfile?.livedCountries ?? [],
            favoriteCountries: normalizedFavoriteCountries,
            avatarUrl: avatarUrl
        ) {
            SocialFeedDebug.log(
                "profile.save.notification user=\(userId) posting=socialActivityUpdated next=\(nextDestination ?? "nil") current=\(normalizedCurrentCountry ?? "nil") homes=\((homeCountries ?? existingProfile?.livedCountries ?? []).count) favorites=\((normalizedFavoriteCountries ?? []).count) avatar_changed=\((existingProfile?.avatarUrl ?? "nil") != (avatarUrl == "" ? nil : avatarUrl ?? existingProfile?.avatarUrl))"
            )
            NotificationCenter.default.post(name: .socialActivityUpdated, object: nil)
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

    private func didChangeSocialActivityFields(
        from existingProfile: Profile?,
        nextDestination: String?,
        currentCountry: String?,
        homeCountries: [String],
        favoriteCountries: [String]?,
        avatarUrl: String?
    ) -> Bool {
        let normalizedExistingHomes = (existingProfile?.livedCountries ?? []).sorted()
        let normalizedExistingFavorites = (existingProfile?.favoriteCountries ?? []).sorted()
        let normalizedNext = nextDestination?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrent = currentCountry?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAvatar = avatarUrl == "" ? nil : avatarUrl
        let normalizedFavorites = favoriteCountries ?? normalizedExistingFavorites
        let homesChanged = normalizedExistingHomes != homeCountries.sorted()
        let favoritesChanged = normalizedExistingFavorites != normalizedFavorites
        let nextChanged = existingProfile?.nextDestination != normalizedNext
        let currentChanged = existingProfile?.currentCountry != normalizedCurrent
        let avatarChanged = existingProfile?.avatarUrl != normalizedAvatar
        let didChange = homesChanged || favoritesChanged || nextChanged || currentChanged || avatarChanged

        SocialFeedDebug.log(
            "profile.save.diff user=\(userId) homes_changed=\(homesChanged) favorites_changed=\(favoritesChanged) next_changed=\(nextChanged) current_changed=\(currentChanged) avatar_changed=\(avatarChanged) did_change=\(didChange)"
        )

        return didChange
    }
}
