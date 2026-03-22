//
//  PreReviewModalView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/2/26.
//

import SwiftUI

import Supabase
import PostgREST

struct PreReviewModalView: View {
    
    let onHighRating: () -> Void
    let onLowRating: () -> Void
    let onDismiss: () -> Void
    
    @State private var selectedRating: Int = 0
    @State private var didSubmit: Bool = false
    @State private var isVisible: Bool = false
    @State private var showLowRatingForm: Bool = false
    @State private var feedbackText: String = ""
    
var body: some View {
    VStack(spacing: 22) {
        contentView
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 26)
    .background(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.regularMaterial)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 20)
    .padding(.horizontal, 32)
    .opacity(isVisible ? 1 : 0)
    .scaleEffect(isVisible ? 1 : 0.96)
    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isVisible)
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isVisible = true
        }
    }
}

@ViewBuilder
private var contentView: some View {
    if didSubmit {
        thankYouView
    } else if showLowRatingForm {
        lowRatingView
    } else {
        ratingView
    }
}

private var thankYouView: some View {
    VStack(spacing: 12) {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 44))
            .foregroundColor(.green)
        
        Text("review.thanks")
            .font(.system(size: 17, weight: .semibold))
            .multilineTextAlignment(.center)
    }
    .padding(.vertical, 10)
}

private var lowRatingView: some View {
    VStack(alignment: .leading, spacing: 14) {
        Text("review.improve_prompt")
            .font(.system(size: 18, weight: .semibold))
        
        ZStack(alignment: .topLeading) {
            if feedbackText.isEmpty {
                Text("review.feedback_placeholder")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
            }

            TextEditor(text: $feedbackText)
                .frame(height: 110)
                .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        
        HStack {
            Button("common.back") {
                withAnimation {
                    showLowRatingForm = false
                }
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            Button("common.send") {
                submitLowRating()
            }
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.accentColor))
            .foregroundColor(.white)
        }
    }
}

private var ratingView: some View {
    VStack(spacing: 16) {
        Text("review.enjoying_app")
            .font(.system(size: 20, weight: .semibold))
            .multilineTextAlignment(.center)
        
        HStack(spacing: 18) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= selectedRating ? "star.fill" : "star")
                    .font(.system(size: 30))
                    .foregroundColor(index <= selectedRating ? .yellow : .gray.opacity(0.35))
                    .onTapGesture {
                        withAnimation {
                            selectedRating = index
                        }
                    }
            }
        }
        
        HStack {
            if selectedRating == 0 { Spacer() }
            
            Button("common.not_now") {
                onDismiss()
            }
            .foregroundColor(.secondary)
            
            if selectedRating == 0 {
                Spacer()
            } else {
                Spacer()
                
                Button("common.submit") {
                    if selectedRating <= 3 {
                        showLowRatingForm = true
                    } else {
                        submitHighRating()
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.accentColor))
                .foregroundColor(.white)
            }
        }
    }
}

private struct FeedbackInsert: Encodable {
    let user_id: UUID
    let rating: Int
    let message: String
    let app_version: String
    let device: String
}

private func submitLowRating() {
    Task {
        do {
            // Ensure we have authenticated user
            if let userId = SupabaseManager.shared.client.auth.currentUser?.id {
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                let deviceName = UIDevice.current.model
                try await SupabaseManager.shared.client
                    .from("app_feedback")
                    .insert(
                        FeedbackInsert(
                            user_id: userId,
                            rating: selectedRating,
                            message: feedbackText,
                            app_version: version,
                            device: deviceName
                        )
                    )
                    .execute()
            }
        } catch {
        }
        
        await MainActor.run {
            didSubmit = true
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            onDismiss()
        }
    }
}

private func submitHighRating() {
    onHighRating()
    didSubmit = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        onDismiss()
    }
}
    
}
