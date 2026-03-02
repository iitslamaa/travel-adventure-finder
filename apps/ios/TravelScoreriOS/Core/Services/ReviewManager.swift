//
//  ReviewManager.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/1/26.
//

import StoreKit
import SwiftUI

final class ReviewManager {
    
    static let shared = ReviewManager()
    
    private init() {}
    
    func requestReviewIfAppropriate() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        
        SKStoreReviewController.requestReview(in: scene)
    }
}
