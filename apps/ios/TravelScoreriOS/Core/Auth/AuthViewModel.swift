//
//  AuthViewModel.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/3/26.
//

import Foundation
import Supabase
import Combine
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - UI State
    @Published var email: String = ""
    @Published var otp: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared
    private let oauthPresenter = OAuthPresenter()

    // MARK: - Email OTP

    func sendEmailOTP() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.client.auth.signInWithOTP(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func verifyEmailOTP() async {
        isLoading = true
        errorMessage = nil

        do {
            // If input is 6-digit numeric → treat as OTP
            if otp.count == 6 && otp.allSatisfy({ $0.isNumber }) {
                try await supabase.client.auth.verifyOTP(
                    email: email,
                    token: otp,
                    type: .email
                )
            } else {
                // Otherwise treat input as password
                try await supabase.client.auth.signIn(
                    email: email,
                    password: otp
                )
            }

            _ = try await supabase.client.auth.session
            try await ensureProfileExists()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Apple Sign In

    func signInWithApple(
        idToken: String,
        nonce: String
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let credentials = OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )

            try await supabase.client.auth.signInWithIdToken(
                credentials: credentials
            )

            _ = try await supabase.client.auth.session
            try await ensureProfileExists()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let redirectURL = URL(string: "travelscorer://login-callback") else {
                throw URLError(.badURL)
            }

            // Supabase iOS SDK handles opening the OAuth URL internally
            try await supabase.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: redirectURL
            )

            // After redirect completes, session will be available
            _ = try await supabase.client.auth.session
            try await ensureProfileExists()

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Profile Management

    private func ensureProfileExists() async throws {
        guard let user = supabase.client.auth.currentUser else { return }

        let result = try await supabase.client
            .from("profiles")
            .select("id")
            .eq("id", value: user.id.uuidString)
            .execute()

        if result.data.isEmpty {
            _ = try await supabase.client
                .from("profiles")
                .insert([
                    "id": user.id.uuidString,
                    "email": user.email ?? ""
                ])
                .execute()
        }
    }
    // MARK: - OAuth Callback Helper

    func handleOAuthCallback(_ url: URL) async {
        do {
            try await supabase.client.auth.session(from: url)
            _ = try await supabase.client.auth.session
            try await ensureProfileExists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
