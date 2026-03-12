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
    @StateObject private var profileVMHolder = ProfileVMHolder()

    init() {
        print("🧪 DEBUG: AppRootView.init() called")
    }
    
    var body: some View {
        let _ = print("🧪 DEBUG: AppRootView.body recomputed instance=\(instanceId)")

        ZStack {
            Color.clear
                .ignoresSafeArea()

            // MAIN APP CONTENT
            if !sessionManager.hasResolvedInitialAuthState {
                ProgressView()
            } else if sessionManager.isAuthSuppressed {
                AuthLandingView()
                    .onAppear {
                    }
                
            } else if sessionManager.isAuthenticated || sessionManager.didContinueAsGuest {
                if let profileVM = profileVMHolder.profileVM {
                    RootTabView()
                        .environmentObject(profileVM)
                        .onAppear {
                            print("🧪 DEBUG: RootTabView mounted from AppRootView")
                        }
                } else {
                    ProgressView()
                        .onAppear {
                            print("🧪 DEBUG: Waiting for ProfileViewModel creation. userId=\(String(describing: sessionManager.userId)) guest=\(sessionManager.didContinueAsGuest)")
                        }
                }
            } else {
                AuthLandingView()
                    .onAppear {
                        profileVMHolder.clear()
                    }
            }
        }
        .onAppear {
            print("🧪 DEBUG: AppRootView appeared. authSuppressed=\(sessionManager.isAuthSuppressed) authenticated=\(sessionManager.isAuthenticated) guest=\(sessionManager.didContinueAsGuest)")
        }
        .task {
            print("🧪 DEBUG: AppRootView.task starting auth listener")
            await SupabaseManager.shared.startAuthListener()
        }
        .task(id: authConfigurationKey) {
            if let userId = sessionManager.userId {
                print("🧪 DEBUG: Configuring ProfileViewModel for userId=\(userId)")
                profileVMHolder.configureIfNeeded(userId: userId)
            } else if sessionManager.didContinueAsGuest {
                print("🧪 DEBUG: Configuring guest ProfileViewModel")
                profileVMHolder.configureGuestIfNeeded()
            } else {
                print("🧪 DEBUG: Clearing ProfileViewModel because userId is nil")
                profileVMHolder.clear()
            }
        }
        .font(TAFTypography.body())
        .foregroundStyle(.black)
        .tint(.black)
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
        print("🧪 DEBUG: configureIfNeeded called with userId=\(userId)")

        if profileVM?.userId == userId {
            print("🧪 DEBUG: ProfileViewModel already configured for this user")
            return
        }

        let profileService = ProfileService(supabase: SupabaseManager.shared)
        let friendService = FriendService(supabase: SupabaseManager.shared)

        print("🧪 DEBUG: Creating new ProfileViewModel")
        profileVM = ProfileViewModel(
            userId: userId,
            profileService: profileService,
            friendService: friendService
        )
    }

    func configureGuestIfNeeded() {
        if profileVM?.isGuestMode == true {
            print("🧪 DEBUG: Guest ProfileViewModel already configured")
            return
        }

        let profileService = ProfileService(supabase: SupabaseManager.shared)
        let friendService = FriendService(supabase: SupabaseManager.shared)

        print("🧪 DEBUG: Creating guest ProfileViewModel")
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
