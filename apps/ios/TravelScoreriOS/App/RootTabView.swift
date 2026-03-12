//
//  RootTabView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/15/25.
//

import Combine
import SwiftUI

enum SocialRoute: Hashable {
    case profile(UUID)
    case friends(UUID)
    case friendRequests
}

@MainActor
final class SocialNavigationController: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: SocialRoute) {
        path.append(route)
    }
}

private struct FloatingTabBarInsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FloatingTabBarInsetEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var floatingTabBarInset: CGFloat {
        get { self[FloatingTabBarInsetEnvironmentKey.self] }
        set { self[FloatingTabBarInsetEnvironmentKey.self] = newValue }
    }
}

struct RootTabView: View {
    private enum Tab: Hashable {
        case discovery
        case planning
        case friends
        case profile
        case more
    }
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var weightsStore: ScoreWeightsStore

    @State private var countries: [Country] = []
    @State private var hasLoadedCountries = false
    @StateObject private var friendsSocialNav = SocialNavigationController()
    @StateObject private var profileSocialNav = SocialNavigationController()

    @State private var discoveryPath = NavigationPath()
    @State private var planningPath = NavigationPath()
    @State private var morePath = NavigationPath()

    @State private var selectedTab: Tab = .discovery
    @State private var floatingTabBarInset: CGFloat = 0

var body: some View {
    let _ = print("🧪 DEBUG: RootTabView body recomputed")

    TabView(selection: $selectedTab) {
        // Discovery
        NavigationStack(path: $discoveryPath) {
            DiscoveryView()
                .onAppear {
                    print("🧪 DEBUG: Discovery NavigationStack content appeared")
                }
        }
        .tag(Tab.discovery)

        // Planning
        NavigationStack(path: $planningPath) {
            PlanningView()
                .onAppear {
                    print("🧪 DEBUG: Planning NavigationStack content appeared")
                }
        }
        .tag(Tab.planning)

        // Friends (auth required)
        NavigationStack(path: $friendsSocialNav.path) {
            Group {
                if sessionManager.isAuthenticated,
                   let userId = sessionManager.userId {
                    FriendsView(userId: userId)
                        .environmentObject(friendsSocialNav)
                } else {
                    VStack(spacing: 20) {
                        Spacer()

                        Text("Create an account to add your friends!")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            sessionManager.didContinueAsGuest = false
                            sessionManager.bumpAuthScreen()
                        } label: {
                            Text("Create Account / Log In")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)

                        Spacer()
                    }
                }
            }
            .navigationDestination(for: SocialRoute.self) { route in
                socialDestination(route, navigator: friendsSocialNav)
            }
        }
        .tag(Tab.friends)

        // Profile (auth required)
        NavigationStack(path: $profileSocialNav.path) {
            Group {
                if sessionManager.isAuthenticated,
                   let userId = sessionManager.userId {
                    ProfileView(userId: userId)
                        .id(userId)
                        .environmentObject(profileSocialNav)
                } else {
                    VStack(spacing: 20) {
                        Spacer()

                        Text("Create an account to customize your profile!")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            sessionManager.didContinueAsGuest = false
                            sessionManager.bumpAuthScreen()
                        } label: {
                            Text("Create Account / Log In")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)

                        Spacer()
                    }
                }
            }
            .navigationDestination(for: SocialRoute.self) { route in
                socialDestination(route, navigator: profileSocialNav)
            }
        }
        .tag(Tab.profile)

        // More
        NavigationStack(path: $morePath) {
            MoreView()
        }
        .tag(Tab.more)
    }
    .ignoresSafeArea()
    .overlay(alignment: .bottom) {
        GeometryReader { geo in
            customTabBar
                .background {
                    GeometryReader { tabGeo in
                        Color.clear
                            .preference(
                                key: FloatingTabBarInsetPreferenceKey.self,
                                value: geo.safeAreaInsets.bottom + 12
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, geo.safeAreaInsets.bottom + 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }
    .onPreferenceChange(FloatingTabBarInsetPreferenceKey.self) { inset in
        floatingTabBarInset = inset
    }
    .environment(\.floatingTabBarInset, floatingTabBarInset)
    .onAppear {
        print("🧪 DEBUG: RootTabView fully appeared")
    }
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbarColorScheme(.light, for: .navigationBar)
    .task {
        guard !hasLoadedCountries else { return }
        hasLoadedCountries = true

        if let cached = CountryAPI.loadCachedCountries() {
            countries = cached
        }

        if let refreshed = await CountryAPI.refreshCountriesIfNeeded() {
            countries = refreshed
        } else if countries.isEmpty {
            do {
                countries = try await CountryAPI.fetchCountries()
            } catch {
                print("❌ Failed to fetch countries:", error)
            }
        }
    }
}

private var customTabBar: some View {
    HStack(spacing: 10) {
        tabButton(.discovery, title: "Discover", systemImage: "globe.americas.fill")
        tabButton(.planning, title: "Plan", systemImage: "list.bullet")
        tabButton(.friends, title: "Friends", systemImage: "person.2.fill")
        tabButton(.profile, title: "Profile", systemImage: "person.crop.circle")
        tabButton(.more, title: "More", systemImage: "ellipsis")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 10)
    .background {
        ZStack {
            Image("country")
                .resizable()
                .scaledToFill()

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.black.opacity(0.18))
        }
    }
    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(.white.opacity(0.18), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
}

@ViewBuilder
private func socialDestination(_ route: SocialRoute, navigator: SocialNavigationController) -> some View {
    switch route {
    case .profile(let userId):
        ProfileView(userId: userId, showsBackButton: true)
            .environmentObject(navigator)
    case .friends(let userId):
        FriendsView(userId: userId, showsBackButton: true)
            .environmentObject(navigator)
    case .friendRequests:
        FriendRequestsView()
            .environmentObject(navigator)
    }
}

@ViewBuilder
private func tabButton(_ tab: Tab, title: String, systemImage: String) -> some View {
    let isSelected = selectedTab == tab

    Button {
        selectedTab = tab
    } label: {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(TAFTypography.title(.bold))
            Text(title)
                .font(TAFTypography.caption(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.72))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.16))
            }
        }
    }
    .buttonStyle(.plain)
}
}

struct MoreView: View {
    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("More")

                ScrollView {
                    VStack(spacing: 24) {
                        NavigationLink {
                            FeedbackView()
                        } label: {
                            MoreCard(
                                title: "Send Feedback",
                                subtitle: "Tell us what feels off",
                                icon: "bubble.left.and.bubble.right"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            LegalView()
                        } label: {
                            MoreCard(
                                title: "Legal",
                                subtitle: "Privacy, terms, and app policies",
                                icon: "doc.text"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MoreCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        Theme.featureCard(
            icon: icon,
            title: title,
            subtitle: subtitle
        ) {
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
