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

    func reset() {
        path = NavigationPath()
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

    private enum GuestLockedSection {
        case friends
        case profile
    }
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var countries: [Country] = []
    @State private var hasLoadedCountries = false
    @StateObject private var friendsSocialNav = SocialNavigationController()
    @StateObject private var profileSocialNav = SocialNavigationController()
    @StateObject private var sharedTripInbox = SharedTripInboxStore()

    @State private var discoveryPath = NavigationPath()
    @State private var planningPath = NavigationPath()
    @State private var morePath = NavigationPath()

    @State private var selectedTab: Tab = .discovery
    @State private var floatingTabBarInset: CGFloat = 0

    var body: some View {
        TabView(selection: $selectedTab) {
        // Discovery
        NavigationStack(path: $discoveryPath) {
            DiscoveryView()
        }
        .tag(Tab.discovery)

        // Planning
        NavigationStack(path: $planningPath) {
            PlanningView()
                .environmentObject(sharedTripInbox)
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
                    guestLockedState(
                        section: .friends,
                        backgroundImage: "travel3"
                    )
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
                    guestLockedState(
                        section: .profile,
                        backgroundImage: "travel4"
                    )
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
        .onChange(of: sessionManager.isAuthenticated) { _, isAuthenticated in
            guard !isAuthenticated else { return }
            resetNavigationState()
        }
        .onChange(of: sessionManager.userId) { _, userId in
            guard userId == nil else { return }
            resetNavigationState()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await sharedTripInbox.refresh()
            }
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
    
    private func resetNavigationState() {
        selectedTab = .discovery
        discoveryPath = NavigationPath()
        planningPath = NavigationPath()
        morePath = NavigationPath()
        friendsSocialNav.reset()
        profileSocialNav.reset()
    }

    private var customTabBar: some View {
        HStack(spacing: 10) {
            tabButton(.discovery, title: String(localized: "tab.discovery"), systemImage: "globe.americas.fill")
            tabButton(.planning, title: String(localized: "tab.planning"), systemImage: "list.bullet", badgeCount: sharedTripInbox.pendingCount)
            tabButton(.friends, title: String(localized: "tab.friends"), systemImage: "person.2.fill")
            tabButton(.profile, title: String(localized: "tab.profile"), systemImage: "person.crop.circle")
            tabButton(.more, title: String(localized: "tab.more"), systemImage: "ellipsis")
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

    private func guestLockedState(section: GuestLockedSection, backgroundImage: String) -> some View {
        let bannerTitle = String(localized: section == .friends ? "guest.friends.banner_title" : "guest.profile.banner_title")
        let cardTitle = String(localized: section == .friends ? "guest.friends.card_title" : "guest.profile.card_title")
        let message = String(localized: section == .friends ? "guest.friends.message" : "guest.profile.message")

        return ZStack {
            Theme.pageBackground(backgroundImage)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(bannerTitle)

                Spacer(minLength: 20)

                VStack(spacing: 24) {
                    Theme.featureCard(
                        icon: section == .friends ? "person.2.fill" : "person.crop.circle",
                        title: cardTitle,
                        subtitle: message,
                        minHeight: 138
                    ) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.black)
                    }

                    Button {
                        sessionManager.didContinueAsGuest = false
                        sessionManager.bumpAuthScreen()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("auth.create_account_log_in")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(Color(red: 0.19, green: 0.15, blue: 0.12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(red: 0.90, green: 0.84, blue: 0.72).opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.14), radius: 10, y: 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.pageHorizontalInset)

                Spacer()
            }
        }
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
    private func tabButton(_ tab: Tab, title: String, systemImage: String, badgeCount: Int = 0) -> some View {
        let isSelected = selectedTab == tab

        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(TAFTypography.title(.bold))

                    if badgeCount > 0 {
                        Text(AppNumberFormatting.integerString(min(badgeCount, 9)))
                            .font(TAFTypography.caption(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(.red))
                            .offset(x: 10, y: -10)
                    }
                }
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
                Theme.titleBanner(String(localized: "more.title"))

                ScrollView {
                    VStack(spacing: 24) {
                        NavigationLink {
                            FeedbackView()
                        } label: {
                            MoreCard(
                                title: String(localized: "more.feedback.title"),
                                subtitle: String(localized: "more.feedback.subtitle"),
                                icon: "bubble.left.and.bubble.right"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            LegalView()
                        } label: {
                            MoreCard(
                                title: String(localized: "more.legal.title"),
                                subtitle: String(localized: "more.legal.subtitle"),
                                icon: "doc.text"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
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
