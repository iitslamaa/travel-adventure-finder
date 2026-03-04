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
    }
    
    var body: some View {

        
        ZStack {
            
            // MAIN APP CONTENT
            if sessionManager.isAuthSuppressed {
                AuthLandingView()
                    .onAppear {
                    }
                
            } else if sessionManager.isAuthenticated || sessionManager.didContinueAsGuest {

                if let userId = sessionManager.userId {
                    let _ = profileVMHolder.configureIfNeeded(userId: userId)

                    if let profileVM = profileVMHolder.profileVM {
                        RootTabView()
                            .environmentObject(profileVM)
                            .onAppear {
                            }
                    }
                }

            } else {
                AuthLandingView()
                    .onAppear {
                        profileVMHolder.clear()
                    }
            }
            
            // INTRO VIDEO OVERLAY
            if !hasFinishedIntroVideo {
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
        .task {
            await SupabaseManager.shared.startAuthListener()
        }
    }
}

final class ProfileVMHolder: ObservableObject {
    @Published var profileVM: ProfileViewModel?

    func configureIfNeeded(userId: UUID) {
        if profileVM?.userId == userId { return }

        let profileService = ProfileService(supabase: SupabaseManager.shared)
        let friendService = FriendService(supabase: SupabaseManager.shared)

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
