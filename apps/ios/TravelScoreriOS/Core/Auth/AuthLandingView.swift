import SwiftUI

struct AuthLandingView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var showAuthUI = false
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VideoBackgroundView(
                    videoName: "intro-video",
                    videoType: "mp4",
                    loop: false
                )
                .ignoresSafeArea()

                if !sessionManager.isAuthenticated && !sessionManager.didContinueAsGuest {
                    VStack(spacing: 12) {
                        EmailAuthView()
                            .frame(
                                maxWidth: 360,
                                maxHeight: min(max(proxy.size.height * 0.40, 320), 420),
                                alignment: .top
                            )

                        Button("Continue as Guest") {
                            sessionManager.continueAsGuest()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.27, green: 0.22, blue: 0.18))
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.83, green: 0.77, blue: 0.66).opacity(0.96))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
                        .padding(.top, -18)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 20))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, proxy.safeAreaInsets.top + max(proxy.size.height * 0.23, 168))
                    .padding(.horizontal, 20)
                    .opacity(showAuthUI ? 1 : 0)
                    .offset(y: showAuthUI ? 0 : 18)
                    .animation(.easeOut(duration: 0.45), value: showAuthUI)
                }
            }
        }
        .onAppear {
            showAuthUI = false
            revealTask?.cancel()
            revealTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    showAuthUI = true
                }
            }
        }
        .onChange(of: sessionManager.isAuthenticated) { isAuthed in
            if isAuthed {
                revealTask?.cancel()
                showAuthUI = false
            }
        }
        .onChange(of: sessionManager.didContinueAsGuest) { didGuest in
            if didGuest {
                revealTask?.cancel()
                showAuthUI = false
            }
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }
}
