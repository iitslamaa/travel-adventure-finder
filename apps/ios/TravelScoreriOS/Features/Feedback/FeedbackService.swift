//
//  FeedbackService.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/28/26.
//

import Foundation
import UIKit
import Supabase

struct FeedbackService {
    
    struct FeedbackEmailPayload: Encodable {
        let message: String
        let user_id: String
        let device: String
        let app_version: String
        let created_at: String
    }

    static func submitFeedback(
        message: String,
        userId: UUID,
        supabase: SupabaseManager
    ) async throws {
        
        let device = UIDevice.current.model
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        try await supabase.client
            .from("app_feedback")
            .insert([
                "user_id": userId.uuidString,
                "message": message,
                "device": device,
                "app_version": version ?? "unknown"
            ])
            .execute()
        
        let payload = FeedbackEmailPayload(
            message: message,
            user_id: userId.uuidString,
            device: device,
            app_version: version ?? "unknown",
            created_at: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase.client.functions.invoke(
            "send-feedback-email",
            options: .init(body: payload)
        )
    }
}
