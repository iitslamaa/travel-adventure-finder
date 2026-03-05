import SwiftUI
import NukeUI
import Nuke

struct FriendsView: View {
    private let userId: UUID
    @StateObject private var friendsVM = FriendsViewModel()
    @State private var displayName: String = ""
    @State private var showFriendRequests: Bool = false

    init(userId: UUID) {
        self.userId = userId
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel3")
                .ignoresSafeArea()

            VStack(spacing: 16) {

                Theme.titleBanner("Friends")

                contentView
            }
        }
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
        VStack(spacing: 8) {

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.black)

                TextField(
                    "",
                    text: $friendsVM.searchText,
                    prompt: Text("Search by username")
                        .foregroundColor(.black.opacity(0.6))
                )
                    .foregroundColor(.black)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                if !friendsVM.searchText.isEmpty {
                    Button {
                        friendsVM.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
            )
            .padding(.horizontal)

            List {
            let data = friendsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? friendsVM.friends
                : friendsVM.searchResults

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
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white)
                    )
                    .rotationEffect(.degrees(0.5))
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            await friendsVM.loadFriends(for: userId, forceRefresh: true)
            if SupabaseManager.shared.currentUserId == userId {
                await friendsVM.loadIncomingRequestCount()
            }
        }
        .listStyle(.plain)
        .background(Color.clear)

        }
    }
}
