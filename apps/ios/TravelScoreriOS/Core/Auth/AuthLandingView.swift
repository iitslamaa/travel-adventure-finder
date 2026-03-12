import SwiftUI

struct AuthLandingView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var showAuthUI = false

    var body: some View {
        ZStack {
            // MARK: - Background video (loop only, no intro phase)
            Color.clear
                .ignoresSafeArea()

            // MARK: - Auth UI
            if !sessionManager.isAuthenticated && !sessionManager.didContinueAsGuest {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        EmailAuthView()

                        Button("Continue as Guest") {
                            sessionManager.continueAsGuest()
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: 360)
                    .opacity(showAuthUI ? 1 : 0)
                    .animation(.easeOut(duration: 0.35), value: showAuthUI)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            showAuthUI = true
        }
        .onChange(of: sessionManager.isAuthenticated) { isAuthed in
            if isAuthed {
                showAuthUI = false
            }
        }
        .onChange(of: sessionManager.didContinueAsGuest) { didGuest in
            if didGuest {
                showAuthUI = false
            }
        }
    }
}
