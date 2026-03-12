//
//  EmailAuthView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/5/26.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - Reusable Button Wrapper

private let authPanelBackground = Color(red: 0.94, green: 0.92, blue: 0.88)
private let authFieldBackground = Color(red: 0.97, green: 0.95, blue: 0.91)
private let authPrimaryFill = Color(red: 0.16, green: 0.14, blue: 0.12)
private let authPrimaryText = Color.white
private let authSecondaryText = Color(red: 0.24, green: 0.21, blue: 0.18)
private let authMutedText = Color(red: 0.47, green: 0.41, blue: 0.34)

struct TranslucentAuthButton<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Email Auth Flow

struct EmailAuthView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var step: Step = .enterEmail
    @State private var showEmailFlow = false
    @FocusState private var focusedField: Field?

    @State private var isSending = false
    @State private var cooldownSeconds = 0

    // Apple
    @State private var appleNonce: String?
    @State private var appleError: String?

    enum Step {
        case enterEmail
        case enterCode
    }

    enum Field {
        case email
        case code
    }

    var body: some View {
        VStack {
            Spacer()

            ZStack {
                // MARK: - Initial Auth Menu

                if !showEmailFlow {
                    VStack(spacing: 20) {

                        // Apple Sign In
                        TranslucentAuthButton {
                            SignInWithAppleButton(.signIn) { request in
                                let nonce = randomNonceString()
                                appleNonce = nonce
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = sha256(nonce)
                            } onCompletion: { result in
                                Task {
                                    switch result {
                                    case .success(let authorization):
                                        guard
                                            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                            let tokenData = credential.identityToken,
                                            let idToken = String(data: tokenData, encoding: .utf8),
                                            let nonce = appleNonce
                                        else {
                                            return
                                        }

                                        await vm.signInWithApple(
                                            idToken: idToken,
                                            nonce: nonce
                                        )

                                        if vm.errorMessage == nil {
                                            await sessionManager.forceRefreshAuthState()
                                        }

                                    case .failure(let error):
                                        vm.errorMessage = error.localizedDescription
                                    }
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 52)
                        }

                        // Google Sign In
                        TranslucentAuthButton {
                            Button {
                                Task {
                                    await vm.signInWithGoogle()

                                    if vm.errorMessage == nil {
                                        await sessionManager.forceRefreshAuthState()
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image("google_logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)

                                    Text("Continue with Google")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.85))
                                }
                            }
                        }

                        // Email Entry
                        TranslucentAuthButton {
                            Button {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    showEmailFlow = true
                                    step = .enterEmail
                                }
                            } label: {
                                Text("✉️ Continue with Email")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black.opacity(0.85))
                            }
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // MARK: - Enter Email

                if showEmailFlow && step == .enterEmail {
                    AuthPanelCard {
                        VStack(spacing: 14) {

                            // Back button (EMAIL SCREEN ONLY)
                            HStack {
                                backButton
                                Spacer()
                            }

                            Text("Enter your email address")
                                .font(.headline)
                                .foregroundStyle(authPrimaryFill)

                            TextField("Email address", text: $vm.email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled(true)
                                .submitLabel(.continue)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(authFieldBackground)
                                )
                                .foregroundStyle(authPrimaryFill)
                                .focused($focusedField, equals: .email)
                                .onAppear {
                                    focusedField = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                        focusedField = .email
                                    }
                                }

                            Button {
                                guard !isSending && cooldownSeconds == 0 else { return }
                                isSending = true

                                Task {
                                    await vm.sendEmailOTP()

                                    isSending = false
                                    if vm.errorMessage == nil {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            step = .enterCode
                                        }
                                        focusedField = nil
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                            focusedField = .code
                                        }
                                        cooldownSeconds = 30
                                        startCooldown()
                                    }
                                }
                            } label: {
                                authActionLabel(
                                    title: cooldownSeconds > 0 ? "Resend in \(cooldownSeconds)s" : "Send code",
                                    isLoading: isSending,
                                    isEnabled: !vm.email.isEmpty && cooldownSeconds == 0
                                )
                            }
                            .disabled(vm.email.isEmpty || cooldownSeconds > 0)

                            Button {
                                guard !vm.email.isEmpty else { return }
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    step = .enterCode
                                }
                                focusedField = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                    focusedField = .code
                                }
                            } label: {
                                Text("Use Bypass Code")
                                    .font(.footnote)
                                    .foregroundColor(authMutedText)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // MARK: - Enter Code

                if step == .enterCode {
                    AuthPanelCard {
                        VStack(spacing: 14) {

                            // Back button (CODE SCREEN ONLY)
                            HStack {
                                backButton
                                Spacer()
                            }

                            Text("Enter the 6-digit code sent to your email, or enter your password")
                                .font(.subheadline)
                                .foregroundColor(authMutedText)

                            TextField("6-digit code or password", text: $vm.otp)
                                .keyboardType(.asciiCapable)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textContentType(.oneTimeCode)
                                .submitLabel(.go)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(authFieldBackground)
                                )
                                .foregroundStyle(authPrimaryFill)
                                .focused($focusedField, equals: .code)

                            Button {
                                Task {
                                    await vm.verifyEmailOTP()

                                    if vm.errorMessage == nil {
                                        focusedField = nil
                                        dismissKeyboard()
                                        await sessionManager.forceRefreshAuthState()
                                    }
                                }
                            } label: {
                                authActionLabel(
                                    title: "Verify",
                                    isLoading: vm.isLoading,
                                    isEnabled: !vm.otp.isEmpty
                                )
                            }
                            .disabled(vm.otp.isEmpty)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showEmailFlow)
            .animation(.easeInOut(duration: 0.4), value: step)

            if let msg = vm.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
        .onChange(of: sessionManager.isAuthenticated) { isAuthed in
            if isAuthed {
                dismissKeyboard()
            }
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showEmailFlow = false
                step = .enterEmail
            }
            dismissKeyboard()
            vm.otp = ""
            vm.errorMessage = nil
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.headline)
            .foregroundColor(authMutedText)
        }
    }

    @ViewBuilder
    private func authActionLabel(title: String, isLoading: Bool, isEnabled: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isEnabled ? Color(red: 0.42, green: 0.31, blue: 0.20) : Color(red: 0.82, green: 0.78, blue: 0.72))
                .frame(width: 210, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke((isEnabled ? Color(red: 0.30, green: 0.21, blue: 0.14) : Color.white.opacity(0.55)), lineWidth: 1)
                )

            if isLoading {
                ProgressView()
                    .tint(authPrimaryText)
            } else {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isEnabled ? authPrimaryText : authMutedText)
            }
        }
        .shadow(color: Color.black.opacity(isEnabled ? 0.14 : 0.08), radius: 10, x: 0, y: 6)
    }

    // MARK: - Helpers

    private func startCooldown() {
        Task {
            while cooldownSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                cooldownSeconds -= 1
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)

            for r in randoms where remaining > 0 {
                if r < charset.count {
                    result.append(charset[Int(r)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

private struct AuthPanelCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(authPanelBackground.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(red: 0.77, green: 0.71, blue: 0.60).opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
    }
}
