import SwiftUI
import NukeUI
import Nuke

struct FriendsView: View {
    @EnvironmentObject private var socialNav: SocialNavigationController
    private let userId: UUID
    @StateObject private var friendsVM = FriendsViewModel()
    @State private var displayName: String = ""
    @State private var showFriendRequests: Bool = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset

    init(userId: UUID) {
        self.userId = userId
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Theme.titleBanner("Friends")

                contentView
                    .padding(.top, 12)
                    .padding(.bottom, 12)
            }

            VStack {
                HStack {
                    Spacer()

                    if SupabaseManager.shared.currentUserId == userId {
                        Button {
                            showFriendRequests = true
                        } label: {
                            ZStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(TAFTypography.title(.bold))
                                    .foregroundStyle(.black)

                                if friendsVM.incomingRequestCount > 0 {
                                    Text("\(min(friendsVM.incomingRequestCount, 9))")
                                        .font(TAFTypography.caption(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(.red))
                                        .offset(x: 10, y: -10)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }
        }
        .background(
            Theme.pageBackground("travel3")
                .ignoresSafeArea()
        )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showFriendRequests) {
                NavigationStack {
                    FriendRequestsView()
                }
            }
            .onChange(of: friendsVM.searchText) { _ in
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

                if SupabaseManager.shared.currentUserId == userId {
                    await friendsVM.loadIncomingRequestCount()
                }
            }
    }

    private var contentView: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.black)

                TextField("Search by username", text: $friendsVM.searchText)
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
            .padding(.horizontal, 16)

            ScrollViewReader { proxy in
                ZStack {
                    ZStack {
                        Image("friends-scroll")
                            .resizable()
                            .aspectRatio(contentMode: .fill)

                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.16), Color.clear]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    }
                    .allowsHitTesting(false)

                    ScrollView {
                        let data = friendsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? friendsVM.friends
                            : friendsVM.searchResults

                        LazyVStack(spacing: 18) {
                            ForEach(data, id: \.id) { profile in
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
                                            .fill(Color(red: 0.97, green: 0.95, blue: 0.90))
                                    )
                                    .shadow(color: .black.opacity(0.10), radius: 6, y: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .id("friendsListTop")
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, floatingTabBarInset + 20)
                    }
                    .refreshable {
                        await friendsVM.loadFriends(for: userId, forceRefresh: true)
                        if SupabaseManager.shared.currentUserId == userId {
                            await friendsVM.loadIncomingRequestCount()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, floatingTabBarInset)
    }
}
