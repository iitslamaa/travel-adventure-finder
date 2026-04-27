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
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap { $0.windows }

            for window in windows {
                window.isOpaque = false
                window.backgroundColor = .clear

                if let root = window.rootViewController {
                    root.view.isOpaque = false
                    root.view.backgroundColor = .clear

                    // Walk child controllers because TabView inserts UITabBarController
                    for child in root.children {
                        child.view.isOpaque = false
                        child.view.backgroundColor = .clear
                    }
                }
            }
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
    @StateObject private var currencyPreferenceStore: CurrencyPreferenceStore

    init() {
        SocialFeedDebug.log("launch.build.marker country-startup-v2")

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
        _currencyPreferenceStore = StateObject(wrappedValue: CurrencyPreferenceStore())

        // Configure Nuke global image pipeline for avatar stability
        let dataCache = try? DataCache(name: "com.travelaf.avatarCache")
        dataCache?.sizeLimit = 200 * 1024 * 1024 // 200 MB disk cache

        var config = ImagePipeline.Configuration()
        config.dataCache = dataCache

        ImagePipeline.shared = ImagePipeline(configuration: config)
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
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(sessionManager)
                .environmentObject(bucketListStore)
                .environmentObject(traveledStore)
                .environmentObject(scoreWeightsStore)
                .environmentObject(currencyPreferenceStore)
                .preferredColorScheme(.light)
        }
    }
}
