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
    @StateObject private var reviewTriggerService = ReviewTriggerService.shared

    init() {
        print("🚀 TravelScoreriOSApp INIT")

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

        print("📦 bucketListStore instance:", ObjectIdentifier(bucket))
        print("🧳 traveledStore instance:", ObjectIdentifier(traveled))
        print("⚖️ scoreWeightsStore instance:", ObjectIdentifier(weights))
        print("🔐 sessionManager instance:", ObjectIdentifier(session))
        print("   🔎 SupabaseManager shared instance:", ObjectIdentifier(SupabaseManager.shared))

        // Configure Nuke global image pipeline for avatar stability
        let dataCache = try? DataCache(name: "com.travelaf.avatarCache")
        dataCache?.sizeLimit = 200 * 1024 * 1024 // 200 MB disk cache

        var config = ImagePipeline.Configuration()
        config.dataCache = dataCache

        ImagePipeline.shared = ImagePipeline(configuration: config)

        // Initialize review trigger service (tracks launches)
        _ = ReviewTriggerService.shared
    }

    var body: some Scene {
        WindowGroup {
            let _ = print("🧱 TravelScoreriOSApp BODY — app instance:", ObjectIdentifier(self as AnyObject),
                          " sessionManager instance:", ObjectIdentifier(sessionManager),
                          " bucketListStore instance:", ObjectIdentifier(bucketListStore),
                          " traveledStore instance:", ObjectIdentifier(traveledStore),
                          " scoreWeightsStore instance:", ObjectIdentifier(scoreWeightsStore),
                          " userId:", sessionManager.userId as Any)

            ZStack {
                AppRootView()
                    .environmentObject(sessionManager)
                    .environmentObject(bucketListStore)
                    .environmentObject(traveledStore)
                    .environmentObject(scoreWeightsStore)
                    .environmentObject(reviewTriggerService)

                if reviewTriggerService.shouldShowPreReviewModal {
                    PreReviewModalView(
                        onHighRating: {
                            reviewTriggerService.shouldShowPreReviewModal = false
                            reviewTriggerService.markPromptCompleted()
                            reviewTriggerService.requestAppStoreReview()
                        },
                        onLowRating: {
                            reviewTriggerService.shouldShowPreReviewModal = false
                            reviewTriggerService.markPromptDeclined()
                        },
                        onDismiss: {
                            reviewTriggerService.shouldShowPreReviewModal = false
                            reviewTriggerService.markPromptDeclined()
                        }
                    )
                    .frame(maxWidth: 360)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: reviewTriggerService.shouldShowPreReviewModal)
        }
    }
}
