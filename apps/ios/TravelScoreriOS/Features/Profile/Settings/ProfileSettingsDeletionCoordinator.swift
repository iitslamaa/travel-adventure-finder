//
//  ProfileSettingsDeletionCoordinator.swift
//  TravelScoreriOS
//

import Foundation
struct ProfileSettingsDeletionCoordinator {

    static func handleDelete(
        sessionManager: SessionManager,
        dismiss: @escaping () -> Void,
        setDeleting: @escaping (Bool) -> Void,
        setError: @escaping (String?) -> Void,
        closeSheet: @escaping () -> Void
    ) async {

        setDeleting(true)
        setError(nil)

        do {
            try await SupabaseManager.shared.deleteAccount()

            // Reset app auth state FIRST
            sessionManager.handleAccountDeleted()

            // Then close UI
            closeSheet()
            dismiss()

        } catch {
            setError(String(localized: "profile.settings.delete_failed"))
        }

        setDeleting(false)
    }
}
