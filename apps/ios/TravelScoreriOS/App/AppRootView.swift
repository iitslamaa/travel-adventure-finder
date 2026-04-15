//
//  AppRootView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/19/26.
//

import Foundation
import SwiftUI
import Combine

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
            if let userId = sessionManager.userId {
                profileVMHolder.configureIfNeeded(userId: userId)
            } else if sessionManager.didContinueAsGuest {
                profileVMHolder.configureGuestIfNeeded()
            } else {
                profileVMHolder.clear()
            }
        }
        .task(id: profileVMHolder.profileVM?.profile?.defaultCurrencyCode) {
            currencyPreferenceStore.synchronizeProfileCurrency(
                profileVMHolder.profileVM?.profile?.defaultCurrencyCode
            )
        }
        .task(id: profileVMHolder.profileVM?.userId) {
            guard let profileVM = profileVMHolder.profileVM else { return }
            await profileVM.warmSessionCachesIfNeeded()
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
            return
        }

        let profileService = ProfileService(supabase: SupabaseManager.shared)
        let friendService = FriendService(supabase: SupabaseManager.shared)

        profileVM = ProfileViewModel(
            userId: userId,
            profileService: profileService,
            friendService: friendService
        )
    }

    func configureGuestIfNeeded() {
        if profileVM?.isGuestMode == true {
            return
        }

        let profileService = ProfileService(supabase: SupabaseManager.shared)
        let friendService = FriendService(supabase: SupabaseManager.shared)

        profileVM = ProfileViewModel(
            userId: Self.guestUserId,
            profileService: profileService,
            friendService: friendService,
            isGuestMode: true
        )
    }

    func clear() {
        profileVM = nil
    }
}
