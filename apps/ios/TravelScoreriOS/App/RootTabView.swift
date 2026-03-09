//
//  RootTabView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/15/25.
//

import SwiftUI

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

    @State private var discoveryPath = NavigationPath()
    @State private var planningPath = NavigationPath()
    @State private var friendsPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var morePath = NavigationPath()

    @State private var selectedTab: Tab = .discovery

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
        NavigationStack(path: $friendsPath) {
            if sessionManager.isAuthenticated,
               let userId = sessionManager.userId {
                FriendsView(userId: userId)
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
        .tag(Tab.friends)

        // Profile (auth required)
        NavigationStack(path: $profilePath) {
            if sessionManager.isAuthenticated,
               let userId = sessionManager.userId {
                ProfileView(userId: userId)
                    .id(userId)
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
        .tag(Tab.profile)

        // More
        NavigationStack(path: $morePath) {
            MoreView()
        }
        .tag(Tab.more)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .ignoresSafeArea()
    .overlay(alignment: .bottom) {
        GeometryReader { geo in
            customTabBar
                .padding(.horizontal, 16)
                .padding(.bottom, geo.safeAreaInsets.bottom + 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
    }
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
        tabButton(.discovery, title: "Discovery", systemImage: "globe.americas.fill")
        tabButton(.planning, title: "Planning", systemImage: "list.bullet")
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
private func tabButton(_ tab: Tab, title: String, systemImage: String) -> some View {
    let isSelected = selectedTab == tab

    Button {
        selectedTab = tab
    } label: {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
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
        List {
            NavigationLink("Lists") {
                PlanningView()
            }

            NavigationLink("Send Feedback") {
                FeedbackView()
            }

            NavigationLink("Legal") {
                LegalView()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .listRowBackground(Color.clear)
        .navigationTitle("More")
    }
}
