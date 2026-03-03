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

        print("💾 SAVE START — userId:", profileVM.userId)
        print("   firstName:", firstName)
        print("   username:", username)
        print("   homeCountries:", homeCountries)
        print("   travelMode:", travelMode as Any)
        print("   travelStyle:", travelStyle as Any)
        print("   nextDestination:", nextDestination as Any)
        print("   currentCountry:", currentCountry as Any)
        print("   favoriteCountries:", favoriteCountries)

        let avatarURL = await resolveAvatarChange(
            profileVM: profileVM,
            selectedUIImage: selectedUIImage,
            shouldRemoveAvatar: shouldRemoveAvatar,
            setAvatarUploading: setAvatarUploading
        )
        print("🖼 selectedUIImage is nil?:", selectedUIImage == nil)
        print("🖼 shouldRemoveAvatar:", shouldRemoveAvatar)
        print("🖼 resolved avatarURL:", avatarURL as Any)

        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            print("📡 Calling profileVM.saveProfile...")

            try await profileVM.saveProfile(
                firstName: trimmedName,
                username: trimmedUsername,
                homeCountries: Array(homeCountries).sorted(),
                languages: languages.map { [
                    "code": $0.name,
                    "proficiency": $0.proficiency
                ] },
                travelMode: travelMode?.rawValue,
                travelStyle: travelStyle?.rawValue,
                nextDestination: nextDestination,
                currentCountry: currentCountry,
                favoriteCountries: favoriteCountries,
                avatarUrl: avatarURL
            )

            print("✅ SAVE SUCCESS")

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
            print("🖼 uploadAvatarIfNeeded skipped — image nil?:", image == nil,
                  "profileId:", profileVM.profile?.id as Any)
            return nil
        }

        setAvatarUploading(true)
        defer { setAvatarUploading(false) }

        let fileName = "\(userId)_\(UUID().uuidString).jpg"
        print("🖼 uploading avatar file:", fileName, "bytes:", data.count)

        do {
            let publicURL = try await profileVM.uploadAvatar(
                data: data,
                fileName: fileName
            )
            return publicURL
        } catch {
            print("🔴 Avatar upload failed:", error)
            return nil
        }
    }
}
