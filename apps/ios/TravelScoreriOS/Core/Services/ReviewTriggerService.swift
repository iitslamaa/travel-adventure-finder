//
//  ReviewTriggerService.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/1/26.
//

import Foundation
import UIKit
import Combine
import StoreKit

final class ReviewTriggerService: ObservableObject {
    
    static let shared = ReviewTriggerService()

    @Published var shouldShowPreReviewModal: Bool = false
    
    private init() {
        incrementLaunchCountIfNeeded()
    }
    
    // MARK: - Testing (trigger on country open)

    func triggerOnCountryOpenForTesting() {
        // Force re-present even if already shown
        shouldShowPreReviewModal = false
        DispatchQueue.main.async {
            self.shouldShowPreReviewModal = true
        }
    }
    
    // MARK: - Storage Keys
    
    private let launchCountKey = "review.launchCount"
    private let firstLaunchDateKey = "review.firstLaunchDate"
    private let lastPromptDateKey = "review.lastPromptDate"
    private let hasPromptedKey = "review.hasPrompted"
    private let lastDeclinedDateKey = "review.lastDeclinedDate"
    
    // MARK: - Public Entry Point
    
    func evaluateAndTriggerReviewIfEligible(visitedCount: Int) {
        
        guard shouldTriggerReview(visitedCount: visitedCount) else { return }
        
        // Trigger custom pre-review modal instead of calling Apple directly
        shouldShowPreReviewModal = true
    }
    
    // MARK: - Eligibility Logic
    
    private func shouldTriggerReview(visitedCount: Int) -> Bool {
        let defaults = UserDefaults.standard

        let hasPrompted = defaults.bool(forKey: hasPromptedKey)
        let hasDeclined = defaults.object(forKey: lastDeclinedDateKey) != nil
        let launchCount = defaults.integer(forKey: launchCountKey)

        // One-time only prompt:
        // - User has visited at least 3 countries
        // - App launched at least 5 times
        // - Has not completed review
        // - Has not declined before
        return visitedCount >= 3 &&
               launchCount >= 5 &&
               !hasPrompted &&
               !hasDeclined
    }
    
    // MARK: - Launch Tracking
    
    private func incrementLaunchCountIfNeeded() {
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: firstLaunchDateKey) == nil {
            defaults.set(Date(), forKey: firstLaunchDateKey)
        }
        
        let currentCount = defaults.integer(forKey: launchCountKey)
        defaults.set(currentCount + 1, forKey: launchCountKey)
    }
    func markPromptCompleted() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: hasPromptedKey)
        defaults.set(Date(), forKey: lastPromptDateKey)
    }
    func markPromptDeclined() {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: lastDeclinedDateKey)
    }
    func requestAppStoreReview() {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
