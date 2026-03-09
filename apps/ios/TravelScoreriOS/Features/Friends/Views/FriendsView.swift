import SwiftUI
import NukeUI
import Nuke

struct FriendsView: View {
    private let userId: UUID
    @StateObject private var friendsVM = FriendsViewModel()
    @State private var displayName: String = ""
    @State private var showFriendRequests: Bool = false
    @FocusState private var isSearchFocused: Bool
    @State private var scrollAnchor: String? = nil

    init(userId: UUID) {
        self.userId = userId
    }

    var body: some View {
        VStack(spacing: 6) {

            Theme.titleBanner("Friends")

            contentView
                .padding(.bottom, 104)
        }
        .background(
            Theme.pageBackground("travel3")
                .ignoresSafeArea()
        )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if SupabaseManager.shared.currentUserId == userId {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showFriendRequests = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 36, height: 36)

                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                if friendsVM.incomingRequestCount > 0 {
                                    Text("\(min(friendsVM.incomingRequestCount, 9))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 16, height: 16)
                                        .background(Circle().fill(.red))
                                        .offset(x: 10, y: -10)
                                }
                            }
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
            // ✅ CRITICAL: destination attached at same level as the List/NavigationLink
            .navigationDestination(for: UUID.self) { destinationUserId in
                ProfileView(userId: destinationUserId)
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
        ZStack {
            ZStack {
                Image("friends-scroll")
                    .resizable()
                    .aspectRatio(contentMode: .fill)

                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.18), Color.clear]),
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.black)

                    TextField("Search by username", text: $friendsVM.searchText)
                        .textFieldStyle(.plain)
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
                .padding(.horizontal)
                .padding(.top, 14)
                .zIndex(1)

                ScrollViewReader { proxy in
                    ScrollView {
                        let data = friendsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? friendsVM.friends
                            : friendsVM.searchResults

                        LazyVStack(spacing: 16) {
                            ForEach(data, id: \.id) { profile in
                                NavigationLink(value: profile.id) {
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
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(Color(red: 0.97, green: 0.95, blue: 0.90))
                                                .offset(x: 2, y: 3)
                                                .rotationEffect(.degrees(-0.8))

                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(Color(red: 0.97, green: 0.95, blue: 0.90))
                                        }
                                    )
                                    .shadow(color: .black.opacity(0.10), radius: 6, y: 4)
                                    .rotationEffect(.degrees((Double(profile.id.uuidString.hashValue % 3) - 1) * 0.35))
                                }
                            }
                        }
                        .id("friendsListTop")
                        .padding(.top, 6)
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await friendsVM.loadFriends(for: userId, forceRefresh: true)
                        if SupabaseManager.shared.currentUserId == userId {
                            await friendsVM.loadIncomingRequestCount()
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
}
