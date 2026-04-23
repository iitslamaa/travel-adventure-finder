import SwiftUI
import NukeUI
import Nuke

private enum FriendsScreenDebugLog {
    static func message(_ text: String) {
#if DEBUG
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        print("📇 [FriendsView] \(timestamp) \(text)")
#endif
    }
}

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var socialNav: SocialNavigationController
    private let userId: UUID
    private let showsBackButton: Bool
    @StateObject private var friendsVM = FriendsViewModel()
    @FocusState private var isSearchFocused: Bool
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset

    private var isOwnFriendsPage: Bool {
        SupabaseManager.shared.currentUserId == userId
    }

    private var displayedProfiles: [Profile] {
        let query = friendsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else { return friendsVM.friends }

        let lowered = query.lowercased()
        return friendsVM.friends.filter { profile in
            profile.username.lowercased().contains(lowered) ||
            profile.fullName.lowercased().contains(lowered)
        }
    }

    init(userId: UUID, showsBackButton: Bool = false) {
        self.userId = userId
        self.showsBackButton = showsBackButton
    }

    private func socialHorizontalInset(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<390:
            return 14
        case ..<430:
            return 14
        case ..<520:
            return 16
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
            let tabOcclusionHeight = floatingTabBarInset + 20

            ZStack {
                VStack(spacing: 0) {
                    Theme.titleBanner(String(localized: "friends.title"))

                    contentView(contentWidth: contentWidth)
                        .padding(.top, -4)
                        .frame(maxHeight: .infinity)
                        .padding(.bottom, tabOcclusionHeight)
                        .clipped()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack {
                    HStack {
                        if showsBackButton {
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
                        }

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
            .alert(String(localized: "common.error"), isPresented: .constant(friendsVM.errorMessage != nil)) {
                Button(String(localized: "common.ok")) { friendsVM.errorMessage = nil }
            } message: {
                Text(friendsVM.errorMessage ?? "")
            }
            .task(id: userId) {
                let shouldLoadRequestCount = isOwnFriendsPage
                let startedAt = Date()

                if shouldLoadRequestCount {
                    async let friendsLoad: Void = friendsVM.loadFriends(for: userId, forceRefresh: false)
                    async let requestCountLoad: Void = friendsVM.loadIncomingRequestCount()
                    _ = await (friendsLoad, requestCountLoad)
                } else {
                    await friendsVM.loadFriends(for: userId, forceRefresh: false)
                }

                FriendsScreenDebugLog.message(
                    "Initial task finished user=\(userId.uuidString) ownPage=\(isOwnFriendsPage) friends=\(friendsVM.friends.count) requestCount=\(friendsVM.incomingRequestCount) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .friendshipUpdated)) { _ in
                Task {
                    let startedAt = Date()
                    await friendsVM.loadFriends(for: userId, forceRefresh: true)

                    if isOwnFriendsPage {
                        await friendsVM.loadIncomingRequestCount()
                    }

                    FriendsScreenDebugLog.message(
                        "Friendship refresh finished user=\(userId.uuidString) ownPage=\(isOwnFriendsPage) friends=\(friendsVM.friends.count) requestCount=\(friendsVM.incomingRequestCount) duration=\(Int(Date().timeIntervalSince(startedAt) * 1000))ms"
                    )
                }
            }
    }

    private func contentView(contentWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ZStack {
                friendsNotebookBackground(corner: 22)
                    .allowsHitTesting(false)

                if friendsVM.isLoading && displayedProfiles.isEmpty {
                } else {
                    VStack(spacing: 14) {
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        ScrollView {
                            LazyVStack(spacing: 18) {
                                if friendsVM.hasAttemptedLoad && displayedProfiles.isEmpty {
                                    emptyStateCard
                                } else {
                                    ForEach(displayedProfiles, id: \.id) { profile in
                                        Button {
                                            socialNav.push(.profile(profile.id))
                                        } label: {
                                            HStack(spacing: 14) {
                                                if let urlString = profile.avatarUrl,
                                                   let url = URL(string: urlString) {
                                                    LazyImage(url: url) { state in
                                                        if let image = state.image {
                                                            image
                                                                .resizable()
                                                                .scaledToFill()
                                                        } else {
                                                            Image(systemName: "person.crop.circle.fill")
                                                                .resizable()
                                                                .scaledToFill()
                                                                .foregroundColor(.gray)
                                                        }
                                                    }
                                                    .processors([
                                                        ImageProcessors.Resize(size: CGSize(width: 120, height: 120))
                                                    ])
                                                    .priority(.high)
                                                    .frame(width: 44, height: 44)
                                                    .clipShape(Circle())
                                                } else {
                                                    Image(systemName: "person.crop.circle.fill")
                                                        .resizable()
                                                        .scaledToFill()
                                                        .foregroundColor(.gray)
                                                        .frame(width: 44, height: 44)
                                                }

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(profile.fullName)
                                                        .font(.headline)
                                                        .foregroundColor(.black)
                                                    Text("@\(profile.username)")
                                                        .font(.subheadline)
                                                        .foregroundColor(.black)
                                                }

                                                Spacer()

                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.black.opacity(0.35))
                                            }
                                            .padding(16)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .fill(Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.92))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                            .stroke(.white.opacity(0.35), lineWidth: 1)
                                                    )
                                            )
                                            .shadow(color: .black.opacity(0.10), radius: 6, y: 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .id("friendsListTop")
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                            .padding(.bottom, floatingTabBarInset + 76)
                        }
                        .refreshable {
                            await friendsVM.loadFriends(for: userId, forceRefresh: true)
                            if isOwnFriendsPage {
                                await friendsVM.loadIncomingRequestCount()
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 2)
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 44))
                .foregroundStyle(.black.opacity(0.7))

            Text(
                friendsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? localizedString("friends.empty.title", defaultValue: "No friends yet")
                    : localizedString("friends.search.empty", defaultValue: "No friends match that search")
            )
            .font(TAFTypography.title(.bold))
            .foregroundStyle(.black)

            Text(
                friendsVM.errorMessage
                    ?? (
                        friendsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? localizedString("friends.empty.subtitle", defaultValue: "When you add friends, they’ll show up here.")
                        : localizedString("friends.search.empty.subtitle", defaultValue: "Try a different name or username.")
                    )
            )
            .font(TAFTypography.section())
            .foregroundStyle(.black.opacity(0.72))
            .multilineTextAlignment(.center)

            if !friendsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(localizedString("common.clear", defaultValue: "Clear")) {
                    friendsVM.clearSearch()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
            } else {
                Button(localizedString("common.retry", defaultValue: "Retry")) {
                    Task {
                        await friendsVM.loadFriends(for: userId, forceRefresh: true)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func friendsNotebookBackground(corner: CGFloat = 22) -> some View {
        GeometryReader { geo in
            ZStack {
                Image("friends-scroll")
                    .resizable(
                        capInsets: EdgeInsets(top: 140, leading: 90, bottom: 180, trailing: 90),
                        resizingMode: .stretch
                    )
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.16), Color.clear]),
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.black)

            TextField(
                "",
                text: $friendsVM.searchText,
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

            if !friendsVM.searchText.isEmpty {
                Button {
                    friendsVM.searchText = ""
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

    private func localizedString(_ key: String, defaultValue: String) -> String {
        Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    }
}
