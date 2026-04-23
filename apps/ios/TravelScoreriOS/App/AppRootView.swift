//
//  AppRootView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/19/26.
//

import Foundation
import SwiftUI
import Combine

private enum AppRootDebugLog {
    static func message(_ text: String) {}
}

struct AppRootView: View {
    private let instanceId = UUID()
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore
    @StateObject private var profileVMHolder = ProfileVMHolder()
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            // MAIN APP CONTENT
            if !sessionManager.hasResolvedInitialAuthState {
                ProgressView()
            } else if sessionManager.isAuthSuppressed {
                AuthLandingView()
                    .environmentObject(authViewModel)
                    .onAppear {
                    }
                
            } else if sessionManager.isAuthenticated || sessionManager.didContinueAsGuest {
                if let profileVM = profileVMHolder.profileVM {
                    RootTabView()
                        .environmentObject(profileVM)
                } else {
                    ProgressView()
                }
            } else {
                AuthLandingView()
                    .environmentObject(authViewModel)
                    .onAppear {
                        profileVMHolder.clear()
                    }
            }
        }
        .task {
            await SupabaseManager.shared.startAuthListener()
        }
        .task(id: authConfigurationKey) {
            let startedAt = Date()
            if let userId = sessionManager.userId {
                profileVMHolder.configureIfNeeded(userId: userId)
                AppRootDebugLog.message(
                    "Configured auth session instance=\(instanceId.uuidString) mode=user user=\(userId.uuidString) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
                )
            } else if sessionManager.didContinueAsGuest {
                profileVMHolder.configureGuestIfNeeded()
                AppRootDebugLog.message(
                    "Configured auth session instance=\(instanceId.uuidString) mode=guest duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
                )
            } else {
                profileVMHolder.clear()
                AppRootDebugLog.message(
                    "Configured auth session instance=\(instanceId.uuidString) mode=logged-out duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
                )
            }
        }
        .task(id: profileVMHolder.profileVM?.profile?.defaultCurrencyCode) {
            currencyPreferenceStore.synchronizeProfileCurrency(
                profileVMHolder.profileVM?.profile?.defaultCurrencyCode
            )
        }
        .font(TAFTypography.body())
        .foregroundStyle(.black)
        .tint(.black)
        .onOpenURL { url in
            let scheme = url.scheme?.lowercased()
            guard scheme == "travelaf" || scheme == "travelscorer" else { return }

            Task {
                await authViewModel.handleOAuthCallback(url)
                await sessionManager.forceRefreshAuthState(source: "oauth-callback")
            }
        }
    }

    private var authConfigurationKey: String {
        if let userId = sessionManager.userId {
            return "user-\(userId.uuidString)"
        }
        if sessionManager.didContinueAsGuest {
            return "guest"
        }
        return "logged-out"
    }
}

final class ProfileVMHolder: ObservableObject {
    private static let guestUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @Published var profileVM: ProfileViewModel?

    func configureIfNeeded(userId: UUID) {
        if profileVM?.userId == userId {
            AppRootDebugLog.message("Profile VM reuse user=\(userId.uuidString) mode=authenticated")
            return
        }

        let startedAt = Date()

        let profileService = ProfileService(supabase: SupabaseManager.shared)
        let friendService = FriendService(supabase: SupabaseManager.shared)

        profileVM = ProfileViewModel(
            userId: userId,
            profileService: profileService,
            friendService: friendService
        )
        AppRootDebugLog.message(
            "Profile VM created user=\(userId.uuidString) mode=authenticated duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
        )
    }

    func configureGuestIfNeeded() {
        if profileVM?.isGuestMode == true {
            AppRootDebugLog.message("Profile VM reuse mode=guest")
            return
        }

        let startedAt = Date()

        let profileService = ProfileService(supabase: SupabaseManager.shared)
        let friendService = FriendService(supabase: SupabaseManager.shared)

        profileVM = ProfileViewModel(
            userId: Self.guestUserId,
            profileService: profileService,
            friendService: friendService,
            isGuestMode: true
        )
        AppRootDebugLog.message(
            "Profile VM created mode=guest duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
        )
    }

    func clear() {
        if let existingUserId = profileVM?.userId {
            AppRootDebugLog.message("Profile VM cleared user=\(existingUserId.uuidString)")
        } else if profileVM != nil {
            AppRootDebugLog.message("Profile VM cleared")
        }
        profileVM = nil
    }
}
