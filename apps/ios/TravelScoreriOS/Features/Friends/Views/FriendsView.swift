import SwiftUI
import NukeUI
import Nuke

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var socialNav: SocialNavigationController
    private let userId: UUID
    private let showsBackButton: Bool
    @StateObject private var friendsVM = FriendsViewModel()
    @State private var displayName: String = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset

    private var isOwnFriendsPage: Bool {
        SupabaseManager.shared.currentUserId == userId
    }

    private var displayedProfiles: [Profile] {
        let query = friendsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else { return friendsVM.friends }

        if isOwnFriendsPage {
            return friendsVM.searchResults
        }

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
                VStack(spacing: 0) {
                    Theme.titleBanner("Friends")

                    contentView(contentWidth: contentWidth)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                }

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

                if isOwnFriendsPage {
                    VStack {
                        HStack {
                            Spacer()

                            NavigationLink(value: SocialRoute.friendRequests) {
                                ZStack {
                                    Theme.chromeIconButtonBackground(size: 40)

                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(TAFTypography.title(.bold))
                                        .foregroundStyle(.black)

                                    if friendsVM.incomingRequestCount > 0 {
                                        Text("\(min(friendsVM.incomingRequestCount, 9))")
                                            .font(TAFTypography.caption(.bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Circle().fill(.red))
                                            .offset(x: 12, y: -12)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, 12)

                        Spacer()
                    }
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
            .onChange(of: friendsVM.searchText) { _ in
                guard isOwnFriendsPage else { return }
                Task { await friendsVM.searchUsers() }
            }
            .alert("Error", isPresented: .constant(friendsVM.errorMessage != nil)) {
                Button("OK") { friendsVM.errorMessage = nil }
            } message: {
                Text(friendsVM.errorMessage ?? "")
            }
            .task(id: userId) {
                await friendsVM.loadFriends(for: userId, forceRefresh: false)

                if friendsVM.displayName.isEmpty {
                    await friendsVM.loadDisplayName(for: userId)
                    displayName = friendsVM.displayName
                }

                if isOwnFriendsPage {
                    await friendsVM.loadIncomingRequestCount()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .friendshipUpdated)) { _ in
                Task {
                    await friendsVM.loadFriends(for: userId, forceRefresh: true)

                    if isOwnFriendsPage {
                        await friendsVM.loadIncomingRequestCount()
                    }
                }
            }
    }

    private func contentView(contentWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ZStack {
                Theme.notebookListBackground(corner: 22)
                    .allowsHitTesting(false)

                VStack(spacing: 14) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    ScrollView {
                        LazyVStack(spacing: 18) {
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
                        .id("friendsListTop")
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, floatingTabBarInset + 20)
                    }
                }
                .refreshable {
                    await friendsVM.loadFriends(for: userId, forceRefresh: true)
                    if isOwnFriendsPage {
                        await friendsVM.loadIncomingRequestCount()
                    }
                }
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 18)
            .padding(.bottom, floatingTabBarInset + 18)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.black)

            TextField(
                "",
                text: $friendsVM.searchText,
                prompt: Text("Search by username")
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
}
