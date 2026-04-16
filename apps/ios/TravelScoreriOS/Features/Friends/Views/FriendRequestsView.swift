//
//  FriendRequestsView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/10/26.
//

import SwiftUI
import NukeUI
import Nuke

private enum FriendRequestsScreenDebugLog {
    static func message(_ text: String) {
#if DEBUG
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        print("📨 [FriendRequestsView] \(timestamp) \(text)")
#endif
    }
}

struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var socialNav: SocialNavigationController
    @StateObject private var vm = FriendRequestsViewModel()

    private func socialHorizontalInset(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<390:
            return 42
        case ..<430:
            return 38
        case ..<520:
            return 32
        default:
            return max((width - 680) / 2, 32)
        }
    }

    private func socialContentWidth(for width: CGFloat) -> CGFloat {
        max(width - (socialHorizontalInset(for: width) * 2), 0)
    }

    var body: some View {
        GeometryReader { geo in
            let horizontalInset = socialHorizontalInset(for: geo.size.width)
            let contentWidth = socialContentWidth(for: geo.size.width)

            ZStack {
                Theme.pageBackground("travel3")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Theme.titleBanner(String(localized: "friend_requests.title"))

                    contentView(contentWidth: contentWidth)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                }

                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            ZStack {
                                Theme.chromeIconButtonBackground(size: 40)
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, 12)

                    Spacer()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let startedAt = Date()
            await vm.loadIncomingRequests()
            FriendRequestsScreenDebugLog.message(
                "Initial task finished requests=\(vm.incomingRequests.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
            )
        }
        .alert(String(localized: "common.error"), isPresented: .constant(vm.errorMessage != nil)) {
            Button(String(localized: "common.ok")) {
                vm.errorMessage = nil
            }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func contentView(contentWidth: CGFloat) -> some View {
        if vm.isLoading {
            ProgressView("friend_requests.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.incomingRequests.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.black.opacity(0.7))

                Text("friend_requests.empty.title")
                    .font(TAFTypography.title(.bold))
                    .foregroundStyle(.black)

                Text("friend_requests.empty.subtitle")
                    .font(TAFTypography.section())
                    .foregroundStyle(.black.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.92, blue: 0.85).opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack {
                Theme.notebookListBackground(corner: 24)
                    .allowsHitTesting(false)

                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(vm.incomingRequests) { profile in
                            requestRow(for: profile)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    private func requestRow(for profile: Profile) -> some View {
        VStack(spacing: 16) {
            NavigationLink(value: SocialRoute.profile(profile.id)) {
                HStack(spacing: 14) {
                    avatarView(for: profile)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.fullName)
                            .font(.headline)
                            .foregroundStyle(.black)
                            .lineLimit(1)

                        Text("@\(profile.username)")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.7))
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                actionButton(
                    title: String(localized: "friend_requests.accept"),
                    foreground: .white,
                    background: Theme.accent.opacity(0.88),
                    border: .white.opacity(0.22)
                ) {
                    Task {
                        do {
                            try await vm.acceptRequest(from: profile.id)
                        } catch {
                            print("❌ accept failed:", error)
                        }
                        await vm.loadIncomingRequests()
                        NotificationCenter.default.post(name: .friendshipUpdated, object: nil)
                    }
                }

                actionButton(
                    title: String(localized: "friend_requests.decline"),
                    foreground: .black.opacity(0.78),
                    background: Color(red: 0.95, green: 0.93, blue: 0.89).opacity(0.96),
                    border: .white.opacity(0.35)
                ) {
                    Task {
                        try? await vm.rejectRequest(from: profile.id)
                        await vm.loadIncomingRequests()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.36), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.10), radius: 6, y: 4)
    }

    private func actionButton(
        title: String,
        foreground: Color,
        background: Color,
        border: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(background)
                )
                .overlay(
                    Capsule()
                        .stroke(border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func avatarView(for profile: Profile) -> some View {
        Group {
            if let urlString = profile.avatarUrl,
               let url = URL(string: urlString) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if state.error != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .foregroundStyle(.gray)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                .processors([
                    ImageProcessors.Resize(size: CGSize(width: 120, height: 120))
                ])
                .priority(.high)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }
}
