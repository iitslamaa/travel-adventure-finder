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
    static func message(_ text: String) {}
}

struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var socialNav: SocialNavigationController
    @StateObject private var vm = FriendRequestsViewModel()
    @FocusState private var isSearchFocused: Bool
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset

    private func socialHorizontalInset(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<390:
            return 16
        case ..<430:
            return 16
        case ..<520:
            return 18
        default:
            return max((width - 680) / 2, 32)
        }
    }

    private func socialContentWidth(for width: CGFloat) -> CGFloat {
        max(width - (socialHorizontalInset(for: width) * 2), 0)
    }

    private var searchResultsMaxHeight: CGFloat {
        280
    }

    private var isSearching: Bool {
        !vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GeometryReader { geo in
            let horizontalInset = socialHorizontalInset(for: geo.size.width)
            let contentWidth = socialContentWidth(for: geo.size.width)
            let tabOcclusionHeight = floatingTabBarInset + 20

            ZStack {
                VStack(spacing: 0) {
                    Theme.titleBanner(localizedString("social.requests.short", defaultValue: "Requests"))

                    contentView(contentWidth: contentWidth)
                        .padding(.top, -4)
                        .frame(maxHeight: .infinity)
                        .padding(.bottom, tabOcclusionHeight)
                        .clipped()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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
            .background(
                Theme.pageBackground("travel3")
                    .ignoresSafeArea()
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let startedAt = Date()
            await vm.loadData()
            FriendRequestsScreenDebugLog.message(
                "Initial task finished incoming=\(vm.incomingRequests.count) outgoing=\(vm.outgoingRequests.count) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
            )
        }
        .onChange(of: vm.searchText) { _, _ in
            Task { await vm.searchUsers() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendshipUpdated)) { _ in
            Task {
                await vm.loadData(forceRefresh: true)
                await vm.searchUsers()
            }
        }
        .alert(String(localized: "common.error"), isPresented: .constant(vm.errorMessage != nil)) {
            Button(String(localized: "common.ok")) {
                vm.errorMessage = nil
            }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func contentView(contentWidth: CGFloat) -> some View {
        VStack(spacing: 18) {
            requestsCard(width: contentWidth)

            ScrollView {
                LazyVStack(spacing: 18) {
                    if vm.isLoading && vm.incomingRequests.isEmpty && vm.outgoingRequests.isEmpty && !isSearching {
                        ProgressView(localizedString("friend_requests.loading", defaultValue: "Loading requests..."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }

                    if !vm.outgoingRequests.isEmpty {
                        sectionHeader(
                            title: localizedString("friend_requests.sent.title", defaultValue: "Sent Requests"),
                            width: contentWidth
                        )

                        ForEach(vm.outgoingRequests) { profile in
                            outgoingRequestRow(for: profile, width: contentWidth)
                        }
                    }

                    if vm.hasAttemptedLoad &&
                        !vm.isLoading &&
                        vm.incomingRequests.isEmpty &&
                        vm.outgoingRequests.isEmpty &&
                        !isSearching {
                        emptyStateCard(width: contentWidth)
                    }
                }
                .frame(width: contentWidth)
                .padding(.bottom, floatingTabBarInset + 76)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .refreshable {
                await vm.loadData(forceRefresh: true)
                await vm.searchUsers()
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func requestsCard(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.incomingRequests.isEmpty {
                cardSectionTitle(localizedString("friend_requests.incoming.title", defaultValue: "Incoming Requests"))

                ForEach(vm.incomingRequests) { profile in
                    incomingRequestRow(for: profile)
                }

                Divider()
                    .overlay(Color.black.opacity(0.08))
                    .padding(.vertical, 2)
            }

            Text(localizedString("friend_requests.search.title", defaultValue: "Add Friends"))
                .font(TAFTypography.title(.bold))
                .foregroundStyle(.black)

            searchBar

            if isSearching {
                searchResultsSection
            } else if vm.hasAttemptedLoad && vm.incomingRequests.isEmpty && vm.outgoingRequests.isEmpty && !vm.isLoading {
                Text(localizedString("friend_requests.empty.subtitle", defaultValue: "Search by username to add someone new, or manage requests here when they come in."))
                    .font(TAFTypography.section())
                    .foregroundStyle(.black.opacity(0.72))
                    .multilineTextAlignment(.leading)
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background(cardBackground(cornerRadius: 22))
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if isSearching {
            Group {
                if vm.isSearching {
                    ProgressView(localizedString("friend_requests.search.loading", defaultValue: "Searching..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if vm.searchResults.isEmpty {
                    VStack(spacing: 8) {
                        Text(localizedString("friend_requests.search.empty.title", defaultValue: "No people found"))
                            .font(TAFTypography.section(.bold))
                            .foregroundStyle(.black)

                        Text(localizedString("friend_requests.search.empty.subtitle", defaultValue: "Try another username."))
                            .font(TAFTypography.body())
                            .foregroundStyle(.black.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.searchResults) { profile in
                                searchResultRow(for: profile)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: searchResultsMaxHeight)
        }
    }

    private func incomingRequestRow(for profile: Profile) -> some View {
        VStack(spacing: 16) {
            profileHeader(for: profile)

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
                        }
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
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func outgoingRequestRow(for profile: Profile, width: CGFloat) -> some View {
        VStack(spacing: 16) {
            profileHeader(for: profile)

            HStack(spacing: 12) {
                statusPill(title: localizedString("friend_requests.requested", defaultValue: "Requested"))

                actionButton(
                    title: localizedString("friend_requests.cancel", defaultValue: "Cancel"),
                    foreground: .black.opacity(0.78),
                    background: Color(red: 0.95, green: 0.93, blue: 0.89).opacity(0.96),
                    border: .white.opacity(0.35)
                ) {
                    Task {
                        try? await vm.cancelRequest(to: profile.id)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background(cardBackground(cornerRadius: 22))
    }

    private func searchResultRow(for profile: Profile) -> some View {
        VStack(spacing: 16) {
            profileHeader(for: profile)

            if vm.isIncomingRequest(profile.id) {
                HStack(spacing: 12) {
                    statusPill(title: localizedString("friend_requests.incoming.badge", defaultValue: "Incoming"))

                    actionButton(
                        title: String(localized: "friend_requests.accept"),
                        foreground: .white,
                        background: Theme.accent.opacity(0.88),
                        border: .white.opacity(0.22)
                    ) {
                        Task {
                            try? await vm.acceptRequest(from: profile.id)
                            NotificationCenter.default.post(name: .friendshipUpdated, object: nil)
                        }
                    }
                }
            } else if vm.isOutgoingRequest(profile.id) {
                HStack(spacing: 12) {
                    statusPill(title: localizedString("friend_requests.requested", defaultValue: "Requested"))

                    actionButton(
                        title: localizedString("friend_requests.cancel", defaultValue: "Cancel"),
                        foreground: .black.opacity(0.78),
                        background: Color(red: 0.95, green: 0.93, blue: 0.89).opacity(0.96),
                        border: .white.opacity(0.35)
                    ) {
                        Task {
                            try? await vm.cancelRequest(to: profile.id)
                        }
                    }
                }
            } else {
                actionButton(
                    title: localizedString("friend_requests.add", defaultValue: "Add"),
                    foreground: .white,
                    background: Theme.accent.opacity(0.88),
                    border: .white.opacity(0.22)
                ) {
                    Task {
                        try? await vm.sendFriendRequest(to: profile.id)
                    }
                }
            }
        }
        .padding(.top, 10)
    }

    private func profileHeader(for profile: Profile) -> some View {
        NavigationLink(value: SocialRoute.profile(profile.id)) {
            HStack(spacing: 14) {
                avatarView(for: profile)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.fullName.isEmpty ? "@\(profile.username)" : profile.fullName)
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
    }

    private func sectionHeader(title: String, width: CGFloat) -> some View {
        HStack {
            Text(title)
                .font(TAFTypography.section(.bold))
                .foregroundStyle(.black)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
    }

    private func cardSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TAFTypography.section(.bold))
            .foregroundStyle(.black)
    }

    private func emptyStateCard(width: CGFloat) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.black.opacity(0.7))

            Text(localizedString("friend_requests.empty.title", defaultValue: "No requests yet"))
                .font(TAFTypography.title(.bold))
                .foregroundStyle(.black)

            Text(localizedString("friend_requests.empty.subtitle", defaultValue: "Search by username to add someone new, or manage requests here when they come in."))
                .font(TAFTypography.section())
                .foregroundStyle(.black.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: width)
        .background(cardBackground(cornerRadius: 20))
    }

    private func statusPill(title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.black.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            )
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.black)

            TextField(
                "",
                text: $vm.searchText,
                prompt: Text("friends.search.placeholder")
                    .foregroundStyle(.black.opacity(0.55))
            )
            .textFieldStyle(.plain)
            .foregroundStyle(.black)
            .tint(.black)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            .focused($isSearchFocused)
            .frame(maxWidth: .infinity)
            .frame(height: 34)

            if !vm.searchText.isEmpty {
                Button {
                    vm.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.black)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.94, green: 0.92, blue: 0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.94))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 6, y: 4)
    }

    private func localizedString(_ key: String, defaultValue: String) -> String {
        Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
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
