//
//  ProfileSettingsSaveCoordinator.swift
//  TravelScoreriOS
//

import UIKit

enum ProfileSaveResult {
    case success
    case usernameTaken
    case failure(String)
}

struct ProfileSettingsSaveCoordinator {

    static func handleSave(
        profileVM: ProfileViewModel,
        firstName: String,
        lastName: String,
        username: String,
        homeCountries: Set<String>,
        passportNationalities: Set<String>,
        visaPassportCountryCode: String?,
        languages: [LanguageEntry],
        travelMode: TravelMode?,
        travelStyle: TravelStyle?,
        nextDestination: String?,
        currentCountry: String?,
        favoriteCountries: [String],
        selectedUIImage: UIImage?,
        shouldRemoveAvatar: Bool,
        setSaving: @escaping (Bool) -> Void,
        setAvatarUploading: @escaping (Bool) -> Void,
        setAvatarCleared: @escaping () -> Void
    ) async -> ProfileSaveResult {

        setSaving(true)

        let avatarURL = await resolveAvatarChange(
            profileVM: profileVM,
            selectedUIImage: selectedUIImage,
            shouldRemoveAvatar: shouldRemoveAvatar,
            setAvatarUploading: setAvatarUploading
        )

        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            

            try await profileVM.saveProfile(
                firstName: trimmedName,
                lastName: trimmedLastName,
                username: trimmedUsername,
                homeCountries: Array(homeCountries).sorted(),
                passportNationalities: Array(passportNationalities).sorted(),
                visaPassportCountryCode: visaPassportCountryCode,
                languages: languages.map { [
                    "code": $0.canonicalCode,
                    "proficiency": $0.normalizedProficiency.storageValue
                ] },
                travelMode: travelMode?.rawValue,
                travelStyle: travelStyle?.rawValue,
                nextDestination: nextDestination,
                currentCountry: currentCountry,
                favoriteCountries: favoriteCountries,
                avatarUrl: avatarURL
            )

            

            setSaving(false)
            setAvatarCleared()
            return .success

        } catch {
            setSaving(false)

            let errorString = "\(error)"

            if errorString.contains("23505") ||
               errorString.localizedCaseInsensitiveContains("duplicate key") {
                return .usernameTaken
            }

            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .timedOut:
                    return .failure("Couldn't save changes. Check your connection and try again.")
                default:
                    break
                }
            }

            if errorString.localizedCaseInsensitiveContains("connection") ||
                errorString.localizedCaseInsensitiveContains("network") {
                return .failure("Couldn't save changes. Check your connection and try again.")
            }

            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Avatar Handling

    private static func resolveAvatarChange(
        profileVM: ProfileViewModel,
        selectedUIImage: UIImage?,
        shouldRemoveAvatar: Bool,
        setAvatarUploading: @escaping (Bool) -> Void
    ) async -> String? {

        if shouldRemoveAvatar {
            return ""
        }

        return await uploadAvatarIfNeeded(
            profileVM: profileVM,
            image: selectedUIImage,
            setAvatarUploading: setAvatarUploading
        )
    }

    private static func uploadAvatarIfNeeded(
        profileVM: ProfileViewModel,
        image: UIImage?,
        setAvatarUploading: @escaping (Bool) -> Void
    ) async -> String? {

        guard
            let image,
            let userId = profileVM.profile?.id,
            let data = image.jpegData(compressionQuality: 0.85)
        else {
            return nil
        }

        setAvatarUploading(true)
        defer { setAvatarUploading(false) }

        let fileName = "\(userId)_\(UUID().uuidString).jpg"

        do {
            let publicURL = try await profileVM.uploadAvatar(
                data: data,
                fileName: fileName
            )
            return publicURL
        } catch {
            return nil
        }
    }
}
