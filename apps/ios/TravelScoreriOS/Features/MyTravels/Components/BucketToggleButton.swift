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
                if let userId = sessionManager.userId {
                    let service = ProfileService(supabase: SupabaseManager.shared)
                    do {
                        if isBucketed {
                            try await service.removeFromBucketList(userId: userId, countryCode: countryId)
                            isBucketed = false
                        } else {
                            try await service.addToBucketList(userId: userId, countryCode: countryId)
                            isBucketed = true
                            try? await SocialActivityService().recordCountryListActivity(
                                actorUserId: userId,
                                eventType: .bucketListAdded,
                                countryIds: [countryId]
                            )
                        }
                    } catch {
                        print("❌ BucketToggleButton failed:", error)
                    }
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
                    isBucketed = bucket.contains(countryId)
                }
            }
        }
    }
}
