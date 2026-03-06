//
//  TravelScoreriOSApp.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/10/25.
//


import SwiftUI
import Nuke
import UIKit

@main
struct TravelScoreriOSApp: App {
    private func forceTransparentRootBackgrounds() {
        // Run twice to ensure the UIHostingController + UITabBarController stack exists.
        func clearBackgrounds() {
            print("🧪 DEBUG: clearBackgrounds() invoked")
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap { $0.windows }

            for window in windows {
                print("🧪 DEBUG: Inspecting window: \(window)")
                window.isOpaque = false
                window.backgroundColor = .clear

                if let root = window.rootViewController {
                    print("🧪 DEBUG: Root VC: \(type(of: root))")
                    print("🧪 DEBUG: Root VC view frame: \(root.view.frame)")
                    root.view.isOpaque = false
                    root.view.backgroundColor = .clear

                    // Walk child controllers because TabView inserts UITabBarController
                    for child in root.children {
                        print("🧪 DEBUG: Child VC detected: \(type(of: child))")
                        child.view.isOpaque = false
                        child.view.backgroundColor = .clear
                    }
                }
            }

            print("🧪 DEBUG: Forced transparent UIWindow/root VC backgrounds. windowCount=\(windows.count)")
        }

        // First pass (next run loop)
        DispatchQueue.main.async {
            clearBackgrounds()

            // Second pass slightly later to catch TabView / NavigationStack containers
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                clearBackgrounds()
            }
        }
    }

    @StateObject private var bucketListStore: BucketListStore
    @StateObject private var traveledStore: TraveledStore
    @StateObject private var sessionManager: SessionManager
    @StateObject private var scoreWeightsStore: ScoreWeightsStore

    init() {
        print("🧪 DEBUG: TravelScoreriOSApp.init() called")
        print("🧪 DEBUG: UIApplication state: \(UIApplication.shared.applicationState.rawValue)")
        print("🧪 DEBUG: Connected scenes: \(UIApplication.shared.connectedScenes.count)")
        

        let bucket = BucketListStore()
        let traveled = TraveledStore()
        let weights = ScoreWeightsStore()

        let session = SessionManager(
            supabase: SupabaseManager.shared,
            bucketListStore: bucket,
            traveledStore: traveled
        )

        _bucketListStore = StateObject(wrappedValue: bucket)
        _traveledStore = StateObject(wrappedValue: traveled)
        _scoreWeightsStore = StateObject(wrappedValue: weights)
        _sessionManager = StateObject(wrappedValue: session)

        // Configure Nuke global image pipeline for avatar stability
        let dataCache = try? DataCache(name: "com.travelaf.avatarCache")
        dataCache?.sizeLimit = 200 * 1024 * 1024 // 200 MB disk cache

        var config = ImagePipeline.Configuration()
        config.dataCache = dataCache

        ImagePipeline.shared = ImagePipeline(configuration: config)
        print("🧪 DEBUG: Nuke pipeline configured")
        print("🧪 DEBUG: ImagePipeline.shared configured: \(ImagePipeline.shared)")
        // 🧪 DEBUG: Force UIKit chrome (TabBar / NavBar / List) to be transparent
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        }

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear

        print("🧪 DEBUG: UIKit appearances forced transparent")
    }

    var body: some Scene {
        let _ = print("🧪 DEBUG: TravelScoreriOSApp.body evaluated")
        let _ = print("🧪 DEBUG: Current scenes: \(UIApplication.shared.connectedScenes)")
        WindowGroup {
            let _ = print("🧪 DEBUG: WindowGroup rendering root UI")
            AppRootView()
                .environmentObject(sessionManager)
                .environmentObject(bucketListStore)
                .environmentObject(traveledStore)
                .environmentObject(scoreWeightsStore)
            .task {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    print("🧪 DEBUG: Active windows count: \(UIApplication.shared.windows.count)")
                    print("🧪 DEBUG: Connected scenes: \(UIApplication.shared.connectedScenes.count)")

                    if let window = UIApplication.shared.windows.first {
                        print("🧪 WINDOW GESTURES:", window.gestureRecognizers ?? [])
                    }
                }
            }
        }
    }
}
