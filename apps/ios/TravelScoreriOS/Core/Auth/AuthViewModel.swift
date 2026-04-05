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
    @Published private(set) var isHandlingOAuthInBrowserSession = false

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
        isHandlingOAuthInBrowserSession = true

        do {
            guard let redirectURL = URL(string: "travelaf://auth/callback") else {
                throw URLError(.badURL)
            }

            _ = try await supabase.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: redirectURL,
                launchFlow: { @MainActor url in
                    try await self.oauthPresenter.start(
                        url: url,
                        callbackScheme: redirectURL.scheme ?? "travelaf"
                    )
                }
            )

            _ = try await supabase.client.auth.session
            try await ensureProfileExists()
            isHandlingOAuthInBrowserSession = false
            isLoading = false
        } catch {
            isHandlingOAuthInBrowserSession = false
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Profile Management

    private func ensureProfileExists() async throws {
        guard let user = supabase.client.auth.currentUser else { return }
        let profileService = ProfileService(supabase: supabase)
        try await profileService.ensureProfileExists(userId: user.id)
    }
    // MARK: - OAuth Callback Helper

    func handleOAuthCallback(_ url: URL) async {
        // Google sign-in already completes the PKCE exchange inside signInWithOAuth(...)
        // when using the explicit browser launch flow. Re-processing the callback here
        // causes a second code exchange attempt with a consumed verifier.
        if isHandlingOAuthInBrowserSession {
            return
        }

        do {
            try await supabase.client.auth.session(from: url)
            _ = try await supabase.client.auth.session
            try await ensureProfileExists()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
