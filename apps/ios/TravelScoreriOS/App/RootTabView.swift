//
//  RootTabView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 11/15/25.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var weightsStore: ScoreWeightsStore

    @State private var countries: [Country] = []
    @State private var hasLoadedCountries = false

    @State private var discoveryPath = NavigationPath()
    @State private var planningPath = NavigationPath()
    @State private var friendsPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var morePath = NavigationPath()

var body: some View {
    let _ = print("🧪 DEBUG: RootTabView body recomputed")

    TabView {
            // Discovery
            NavigationStack(path: $discoveryPath) {
                DiscoveryView()
                    .onAppear {
                        print("🧪 DEBUG: Discovery NavigationStack content appeared")
                    }
            }
            .tabItem {
                Label("Discovery", systemImage: "globe.americas.fill")
            }

            // Planning
            NavigationStack(path: $planningPath) {
                PlanningView()
                    .onAppear {
                        print("🧪 DEBUG: Planning NavigationStack content appeared")
                    }
            }
            .tabItem {
                Label("Planning", systemImage: "list.bullet")
            }

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
            .tabItem {
                Label("Friends", systemImage: "person.2.fill")
            }

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
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }

            // More
            NavigationStack(path: $morePath) {
                MoreView()
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
    }
    .onAppear {
        print("🧪 DEBUG: RootTabView fully appeared")
    }
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
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
