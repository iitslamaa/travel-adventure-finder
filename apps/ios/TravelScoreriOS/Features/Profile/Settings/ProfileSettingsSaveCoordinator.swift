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
        username: String,
        homeCountries: Set<String>,
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
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            

            try await profileVM.saveProfile(
                firstName: trimmedName,
                username: trimmedUsername,
                homeCountries: Array(homeCountries).sorted(),
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

            print("❌ SAVE FAILED — raw error:", error)

            let errorString = "\(error)"
            print("❌ SAVE FAILED — errorString:", errorString)

            if errorString.contains("23505") ||
               errorString.localizedCaseInsensitiveContains("duplicate key") {
                print("⚠️ Username duplicate detected")
                return .usernameTaken
            }

            print("⚠️ SAVE FAILURE returning localizedDescription:", error.localizedDescription)
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
