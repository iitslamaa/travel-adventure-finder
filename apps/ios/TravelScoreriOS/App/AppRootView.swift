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
    
    var body: some View {
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
                } else {
                    ProgressView()
                }
            } else {
                AuthLandingView()
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
