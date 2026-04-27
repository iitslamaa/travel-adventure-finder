//
//  BucketToggleButton.swift
//  TravelScoreriOS
//

import Foundation
import SwiftUI

struct BucketToggleButton: View {

    @EnvironmentObject private var sessionManager: SessionManager

    let countryId: String
    var size: CGFloat = 18

    @State private var isBucketed: Bool = false

    var body: some View {
        Button {
            Task {
                SocialFeedDebug.log(
                    "bucket.toggle_button.tap country=\(countryId) is_bucketed_before=\(isBucketed) user=\(sessionManager.userId?.uuidString ?? "nil")"
                )
                if let userId = sessionManager.userId {
                    let service = ProfileService(supabase: SupabaseManager.shared)
                    do {
                        if isBucketed {
                            try await service.removeFromBucketList(userId: userId, countryCode: countryId)
                            isBucketed = false
                            SocialFeedDebug.log("bucket.toggle_button.removed country=\(countryId) user=\(userId.uuidString) is_bucketed_after=\(isBucketed)")
                        } else {
                            try await service.addToBucketList(userId: userId, countryCode: countryId)
                            isBucketed = true
                            SocialFeedDebug.log("bucket.toggle_button.added country=\(countryId) user=\(userId.uuidString) is_bucketed_after=\(isBucketed)")
                            try? await SocialActivityService().recordCountryListActivity(
                                actorUserId: userId,
                                eventType: .bucketListAdded,
                                countryIds: [countryId]
                            )
                        }
                    } catch {
                        print("❌ BucketToggleButton failed:", error)
                        SocialFeedDebug.log("bucket.toggle_button.error country=\(countryId) error=\(SocialFeedDebug.describe(error))")
                    }
                } else {
                    SocialFeedDebug.log("bucket.toggle_button.no_user country=\(countryId)")
                }
            }
        } label: {
            Text("🪣")
                .font(.system(size: size))
                .opacity(isBucketed ? 1.0 : 0.35)
                .accessibilityLabel(
                    isBucketed
                    ? String(localized: "planning.bucket_list.remove_accessibility")
                    : String(localized: "planning.bucket_list.add_accessibility")
                )
        }
        .buttonStyle(.plain)
        .task {
            if let userId = sessionManager.userId {
                let service = ProfileService(supabase: SupabaseManager.shared)
                if let bucket = try? await service.fetchBucketListCountries(userId: userId) {
                    SocialFeedDebug.log(
                        "bucket.toggle_button.initial_fetch country=\(countryId) user=\(userId.uuidString) \(SocialFeedDebug.countrySetSummary(bucket))"
                    )
                    isBucketed = bucket.contains(countryId)
                } else {
                    SocialFeedDebug.log("bucket.toggle_button.initial_fetch.nil country=\(countryId) user=\(userId.uuidString)")
                }
            } else {
                SocialFeedDebug.log("bucket.toggle_button.initial_fetch.no_user country=\(countryId)")
            }
        }
    }
}
