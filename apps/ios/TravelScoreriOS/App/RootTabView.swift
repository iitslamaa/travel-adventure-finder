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

    var hasActiveRoute: Bool {
        !path.isEmpty
    }

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
        case social
        case more
    }

    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var countries: [Country] = []
    @State private var hasLoadedCountries = false
    @StateObject private var socialNav = SocialNavigationController()
    @StateObject private var sharedTripInbox = SharedTripInboxStore()

    @State private var discoveryPath = NavigationPath()
    @State private var planningPath = NavigationPath()
    @State private var morePath = NavigationPath()
    @State private var discoveryRootID = UUID()
    @State private var planningRootID = UUID()
    @State private var socialRootID = UUID()
    @State private var moreRootID = UUID()

    @State private var selectedTab: Tab = .discovery
    @State private var floatingTabBarInset: CGFloat = 0
    @State private var isProcessingTabInteraction = false

    var body: some View {
        TabView(selection: $selectedTab) {
        // Discovery
        NavigationStack(path: $discoveryPath) {
            DiscoveryView()
        }
        .id(discoveryRootID)
        .tag(Tab.discovery)

        // Planning
        NavigationStack(path: $planningPath) {
            PlanningView()
                .environmentObject(sharedTripInbox)
        }
        .id(planningRootID)
        .tag(Tab.planning)

        // Social (auth required)
        NavigationStack(path: $socialNav.path) {
            Group {
                if sessionManager.isAuthenticated,
                   let userId = sessionManager.userId {
                    SocialView(userId: userId)
                        .environmentObject(socialNav)
                } else {
                    guestLockedState(
                        backgroundImage: "travel3"
                    )
                }
            }
            .navigationDestination(for: SocialRoute.self) { route in
                socialDestination(route, navigator: socialNav)
            }
        }
        .id(socialRootID)
        .tag(Tab.social)

        // More
        NavigationStack(path: $morePath) {
            MoreView()
        }
        .id(moreRootID)
        .tag(Tab.more)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
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
            Task {
                await sharedTripInbox.updateRealtimeConnection(isActive: phase == .active)

                guard phase == .active else { return }

                async let inboxRefresh: Void = sharedTripInbox.refresh()
                async let rateRefresh: Void = currencyPreferenceStore.refreshRatesIfNeeded()
                _ = await (inboxRefresh, rateRefresh)
            }
        }
        .task {
            await sharedTripInbox.updateRealtimeConnection(isActive: scenePhase == .active)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            guard !hasLoadedCountries else { return }
            hasLoadedCountries = true

            if let cached = CountryAPI.loadCachedCountries() {
                countries = cached
            }

            if countries.isEmpty {
                do {
                    countries = try await CountryAPI.fetchCountries()
                } catch {
                    print("❌ Failed to fetch countries:", error)
                }
            }
        }
        .task {
            await currencyPreferenceStore.refreshRatesIfNeeded()
        }
    }
    
    private func resetNavigationState() {
        selectedTab = .discovery
        discoveryPath = NavigationPath()
        planningPath = NavigationPath()
        morePath = NavigationPath()
        socialNav.reset()
    }

    private func selectTab(_ tab: Tab) {
        guard !isProcessingTabInteraction else {
            return
        }

        processTabInteraction(tab)
    }

    private func processTabInteraction(_ tab: Tab) {
        isProcessingTabInteraction = true

        if selectedTab == tab {
            resetPathIfNeeded(for: tab)
        } else {
            selectedTab = tab
        }

        Task { @MainActor in
            await Task.yield()
            isProcessingTabInteraction = false
        }
    }

    private func resetPathIfNeeded(for tab: Tab) {
        switch tab {
        case .discovery:
            guard !discoveryPath.isEmpty else { return }
            discoveryPath = NavigationPath()
        case .planning:
            guard !planningPath.isEmpty else { return }
            planningPath = NavigationPath()
        case .social:
            guard socialNav.hasActiveRoute else { return }
            socialNav.reset()
        case .more:
            guard !morePath.isEmpty else { return }
            morePath = NavigationPath()
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 10) {
            tabButton(.discovery, title: String(localized: "tab.discovery"), systemImage: "globe.americas.fill")
            tabButton(.planning, title: String(localized: "tab.planning"), systemImage: "list.bullet", badgeCount: sharedTripInbox.pendingCount)
            tabButton(.social, title: "Social", systemImage: "person.2.fill")
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

    private func guestLockedState(backgroundImage: String) -> some View {
        let bannerTitle = "Social"
        let cardTitle = String(localized: "guest.friends.card_title")
        let message = String(localized: "guest.friends.message")

        return ZStack {
            Theme.pageBackground(backgroundImage)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(bannerTitle)

                Spacer(minLength: 20)

                VStack(spacing: 24) {
                    Theme.featureCard(
                        icon: "person.2.fill",
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
            if sessionManager.userId == userId {
                ProfileView(userId: userId, showsBackButton: true, profileViewModel: profileVM)
                    .environmentObject(navigator)
            } else {
                ProfileView(userId: userId, showsBackButton: true)
                    .environmentObject(navigator)
            }
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
            selectTab(tab)
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
