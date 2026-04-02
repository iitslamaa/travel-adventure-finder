//
//  FeedbackView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/28/26.
//

import SwiftUI
import Auth

struct FeedbackView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager
    
    @State private var message: String = ""
    @State private var contactEmail: String = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContactEmail: String {
        contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasValidContactEmail: Bool {
        let parts = trimmedContactEmail.split(separator: "@")
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              parts[1].contains(".")
        else {
            return false
        }
        return true
    }
    
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
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your email")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)

                                TextField(String(localized: "auth.email_address_placeholder"), text: $contactEmail)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .background(Color(red: 0.95, green: 0.92, blue: 0.86))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            Text("Add an email you check so we can follow up if your note raises something useful or unclear.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)

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
                                .background(trimmedMessage.isEmpty || !hasValidContactEmail || isSubmitting ? Color.gray.opacity(0.3) : Theme.accent)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(trimmedMessage.isEmpty || !hasValidContactEmail || isSubmitting)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard contactEmail.isEmpty else { return }
            if let session = try? await sessionManager.supabase.fetchCurrentSession() {
                contactEmail = session.user.email ?? ""
            }
        }
    }
    
    private func submit() async {
        guard let userId = sessionManager.userId else { return }
        
        isSubmitting = true
        errorMessage = nil

        guard hasValidContactEmail else {
            errorMessage = "Please enter a valid email address."
            isSubmitting = false
            return
        }
        
        do {
            try await FeedbackService.submitFeedback(
                message: trimmedMessage,
                contactEmail: trimmedContactEmail,
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
