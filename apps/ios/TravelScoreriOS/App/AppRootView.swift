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
    
    // Controls whether intro overlay is visible
    @State private var hasFinishedIntroVideo = false
    
    init() {
        print("🧪 DEBUG: AppRootView.init() called")
    }
    
    var body: some View {
        let _ = print("🧪 DEBUG: AppRootView.body recomputed instance=\(instanceId)")

        ZStack {
            Color.clear
                .ignoresSafeArea()
            
            // MAIN APP CONTENT
            if sessionManager.isAuthSuppressed {
                AuthLandingView()
                    .onAppear {
                    }
                
            } else if sessionManager.isAuthenticated || sessionManager.didContinueAsGuest {

                if let userId = sessionManager.userId {

                    if let profileVM = profileVMHolder.profileVM {
                        RootTabView()
                            .environmentObject(profileVM)
                            .onAppear {
                                print("🧪 DEBUG: RootTabView mounted from AppRootView")
                            }
                    } else {
                        ProgressView()
                            .onAppear {
                                print("🧪 DEBUG: Waiting for ProfileViewModel creation for userId=\(userId)")
                            }
                    }
                }

            } else {
                AuthLandingView()
                    .onAppear {
                        profileVMHolder.clear()
                    }
            }
            
            // INTRO VIDEO OVERLAY (temporarily disabled while testing theme)
            if false {
                VideoBackgroundView(
                    videoName: "intro",
                    videoType: "mp4",
                    loop: false,
                    onFinished: {
                        hasFinishedIntroVideo = true
                    }
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            print("🧪 DEBUG: AppRootView appeared. authSuppressed=\(sessionManager.isAuthSuppressed) authenticated=\(sessionManager.isAuthenticated) guest=\(sessionManager.didContinueAsGuest)")
        }
        .task {
            print("🧪 DEBUG: AppRootView.task starting auth listener")
            await SupabaseManager.shared.startAuthListener()
        }
        .task(id: sessionManager.userId) {
            if let userId = sessionManager.userId {
                print("🧪 DEBUG: Configuring ProfileViewModel for userId=\(userId)")
                profileVMHolder.configureIfNeeded(userId: userId)
            } else {
                print("🧪 DEBUG: Clearing ProfileViewModel because userId is nil")
                profileVMHolder.clear()
            }
        }
        .font(TAFTypography.body())
        .foregroundStyle(.black)
        .tint(.black)
    }
}

final class ProfileVMHolder: ObservableObject {
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

    func clear() {
        profileVM = nil
    }
}
