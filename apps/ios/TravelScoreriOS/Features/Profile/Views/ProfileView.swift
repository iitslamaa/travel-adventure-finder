//
//  ProfileView.swift
//  TravelScoreriOS
//

import SwiftUI
import NukeUI
import Nuke

extension Color {
    static let gold = Color(red: 0.85, green: 0.68, blue: 0.15)
}

struct LockedProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("Learn more about this user by adding them as a friend!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Notification.Name {
    static let friendshipUpdated = Notification.Name("friendshipUpdated")
}

struct ProfileView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var bucketList: BucketListStore
    @EnvironmentObject private var traveled: TraveledStore
    @StateObject private var profileVM: ProfileViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let userId: UUID
    @State private var showFriendsDrawer = false
    @State private var navigateToFriends = false

    init(userId: UUID) {
        self.userId = userId

        // ✅ VM is now single-identity (no rebinding / no stale reuse)
        _profileVM = StateObject(
            wrappedValue: ProfileViewModel(
                userId: userId,
                profileService: ProfileService(supabase: SupabaseManager.shared),
                friendService: FriendService(supabase: SupabaseManager.shared)
            )
        )
    }

    // MARK: - Derived State

    private var username: String { profileVM.profile?.username ?? "" }
    private var homeCountryCodes: [String] { profileVM.profile?.livedCountries ?? [] }
    private var languages: [String] {
        guard let entries = profileVM.profile?.languages else { return [] }

        return entries.map { entry in
            let displayName = LanguageRepository.shared.allLanguages
                .first(where: { $0.code == entry.code })?
                .displayName ?? entry.code

            return "\(displayName) — \(entry.proficiency)"
        }
    }
    private var friendCount: Int {
        profileVM.profile?.friendCount ?? 0
    }

    private var isReadyToRenderProfile: Bool {
        profileVM.profile?.id == userId &&
        profileVM.isLoading == false
    }

    private var travelModeLabel: String? {
        guard let raw = profileVM.profile?.travelMode.first,
              let mode = TravelMode(rawValue: raw) else { return nil }
        return mode.label
    }

    private var travelStyleLabel: String? {
        guard let raw = profileVM.profile?.travelStyle.first,
              let style = TravelStyle(rawValue: raw) else { return nil }
        return style.label
    }

    private var nextDestination: String? {
        profileVM.profile?.nextDestination
    }

    private var firstName: String? {
        let raw = (profileVM.profile?.fullName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return raw.split(separator: " ").first.map(String.init)
    }

    private var navigationTitle: String {
        "Profile"
    }


    var body: some View {
        ZStack {
            Theme.pageBackground("travel4")
                .ignoresSafeArea()

            // 🛡 Strict identity + relationship gate (production-safe)
            if !isReadyToRenderProfile {
                ProfileLoadingView()
                    .transition(.opacity)
            } else {
                let relationshipState = profileVM.relationshipState

                ScrollView {
                    VStack(spacing: 40) {
                        ZStack {
                            // back card
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.clear)
                                .rotationEffect(.degrees(-0.6))
                                .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

                            ProfileHeaderView(
                                profile: profileVM.profile,
                                username: username,
                                homeCountryCodes: homeCountryCodes,
                                relationshipState: relationshipState,
                                friendCount: friendCount,
                                onToggleFriend: {
                                    switch relationshipState {
                                    case .friends:
                                        showFriendsDrawer = true
                                    case .requestSent:
                                        showFriendsDrawer = true
                                    case .requestReceived:
                                        Task { await profileVM.toggleFriend() }
                                    case .none:
                                        Task { await profileVM.toggleFriend() }
                                    case .selfProfile:
                                        break
                                    }
                                }
                            )
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.96))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                            )
                        }

                        // 🔒 GATE PROFILE CONTENT
                        if relationshipState == .friends ||
                            relationshipState == .selfProfile {

                            ZStack {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(Color.clear)
                                    .rotationEffect(.degrees(-0.4))
                                    .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

                                ProfileInfoSection(
                                    relationshipState: relationshipState,
                                    viewedTraveledCountries: profileVM.viewedTraveledCountries,
                                    viewedBucketListCountries: profileVM.viewedBucketListCountries,
                                    orderedTraveledCountries: profileVM.orderedTraveledCountries,
                                    orderedBucketListCountries: profileVM.orderedBucketListCountries,
                                    mutualTraveledCountries: profileVM.mutualTraveledCountries,
                                    mutualBucketCountries: profileVM.mutualBucketCountries,
                                    mutualLanguages: profileVM.mutualLanguages,
                                    languages: languages,
                                    travelMode: travelModeLabel,
                                    travelStyle: travelStyleLabel,
                                    nextDestination: nextDestination,
                                    currentCountry: profileVM.profile?.currentCountry,
                                    favoriteCountries: profileVM.profile?.favoriteCountries ?? []
                                )
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.96))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                                )
                            }

                        } else {
                            LockedProfileView()
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 60)
                }
                .refreshable {
                    await profileVM.reloadProfile()
                }
                .sheet(isPresented: $showFriendsDrawer) {
                    FriendsSection(
                        relationshipState: relationshipState,
                        friendCount: friendCount,
                        onToggleFriend: {
                            Task {
                                await profileVM.toggleFriend()
                            }
                        },
                        onCancelRequest: {
                            Task {
                                await profileVM.toggleFriend()
                            }
                        },
                        onViewFriends: {
                            showFriendsDrawer = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                navigateToFriends = true
                            }
                        }
                    )
                }
                .background(
                    NavigationLink(
                        destination: FriendsListView()
                            .environmentObject(profileVM),
                        isActive: $navigateToFriends
                    ) {
                        EmptyView()
                    }
                    .hidden()
                )
            }
        }
        .id(userId)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if SupabaseManager.shared.currentUserId == userId {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ProfileSettingsView(
                            profileVM: profileVM,
                            viewedUserId: userId
                        )
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isReadyToRenderProfile)
        
        .onAppear {
            // 🔒 Only load if no profile is currently bound
            guard profileVM.profile == nil else {
                
                return
            }

            Task {
                await profileVM.loadIfNeeded()
            }
        }
        .onDisappear {
        }
    }
}

struct FriendsListView: View {
    @EnvironmentObject var profileVM: ProfileViewModel

    var body: some View {
        Group {
            if profileVM.friends.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No friends yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(profileVM.friends, id: \.id) { friend in
                    HStack(spacing: 12) {
                        if let urlString = friend.avatarUrl,
                           let url = URL(string: urlString) {
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                }
                            }
                            .processors([
                                ImageProcessors.Resize(size: CGSize(width: 120, height: 120))
                            ])
                            .priority(.high)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                        }

                        VStack(alignment: .leading) {
                            Text(friend.fullName ?? "Unknown")
                                .font(.headline)

                            if !friend.username.isEmpty {
                                Text("@\(friend.username)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
    }
}
