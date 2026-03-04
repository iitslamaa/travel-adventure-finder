//
//  TravelScoreriOSApp.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/10/25.
//


import SwiftUI
import Nuke

@main
struct TravelScoreriOSApp: App {
    @StateObject private var bucketListStore = BucketListStore()
    @StateObject private var traveledStore = TraveledStore()
    @StateObject private var sessionManager: SessionManager
    @StateObject private var scoreWeightsStore: ScoreWeightsStore

    init() {
        

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
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppRootView()
                    .environmentObject(sessionManager)
                    .environmentObject(bucketListStore)
                    .environmentObject(traveledStore)
                    .environmentObject(scoreWeightsStore)
            }
        }
    }
}
