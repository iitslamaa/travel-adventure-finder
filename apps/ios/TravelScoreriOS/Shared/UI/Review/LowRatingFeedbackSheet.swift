//
//  LowRatingFeedbackSheet.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/2/26.
//

import SwiftUI
import Supabase
import PostgREST

struct LowRatingFeedbackSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var feedbackText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var didSubmit: Bool = false
    
    let onFinished: () -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if didSubmit {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Thanks for your feedback!")
                            .font(.system(size: 18, weight: .semibold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        Text("What could we improve?")
                            .font(.system(size: 22, weight: .semibold))
                        
                        Text("Your feedback helps us make Travel Adventure Finder better.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $feedbackText)
                            .frame(minHeight: 140)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        
                        Spacer()
                        
                        Button(action: submitFeedback) {
                            if isSubmitting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Text("Send")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                        .disabled(isSubmitting)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onFinished()
                    }
                }
            }
        }
    }
    
    private func submitFeedback() {
        isSubmitting = true
        
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("app_feedback")
                    .insert([
                        "message": feedbackText,
                        "created_at": ISO8601DateFormatter().string(from: Date())
                    ])
                    .execute()
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        didSubmit = true
                    }
                }
                
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                await MainActor.run {
                    dismiss()
                    onFinished()
                }
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                }
            }
        }
    }
}
