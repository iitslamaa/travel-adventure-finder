//
//  FeedbackView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/28/26.
//

import SwiftUI

struct FeedbackView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager
    
    @State private var message: String = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "feedback.title"))

                ScrollView {
                    VStack(spacing: 20) {
                        Theme.scrapbookSection {
                            HStack(alignment: .center, spacing: 16) {
                                Image("lama_profile")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 92, height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(Color(.systemGray5), lineWidth: 1)
                                    )

                                Text("feedback.intro.headline")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("feedback.intro.body_1")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("feedback.intro.body_2")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("feedback.intro.body_3")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)

                                Text("feedback.intro.body_4")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Theme.scrapbookSection {
                            TextEditor(text: $message)
                                .frame(minHeight: 170)
                                .padding(12)
                                .background(Color(red: 0.95, green: 0.92, blue: 0.86))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            if let errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.footnote)
                            }

                            Button {
                                Task {
                                    await submit()
                                }
                            } label: {
                                Group {
                                    if isSubmitting {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Text(didSubmit ? String(localized: "feedback.sent") : String(localized: "feedback.send"))
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding()
                                .background(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting ? Color.gray.opacity(0.3) : Theme.accent)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func submit() async {
        guard let userId = sessionManager.userId else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            try await FeedbackService.submitFeedback(
                message: message,
                userId: userId,
                supabase: sessionManager.supabase
            )
            
            didSubmit = true
            isSubmitting = false
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
            
        } catch {
            errorMessage = String(localized: "feedback.error")
            isSubmitting = false
        }
    }
}
