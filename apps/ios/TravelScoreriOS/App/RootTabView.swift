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

    private let instanceId = UUID()

    var body: some View {
        let _ = print("🧱 RootTabView BODY — instance:", instanceId,
                      " userId:", sessionManager.userId as Any)
        TabView {

            // Discovery
            NavigationStack {
                DiscoveryView()
            }
            .tabItem {
                Label("Discovery", systemImage: "globe.americas.fill")
            }

            // Planning
            NavigationStack {
                ListsView()
            }
            .tabItem {
                Label("Planning", systemImage: "list.bullet")
            }

            // Friends (auth required)
            NavigationStack {
                let _ = print("📦 Friends NavigationStack BUILD — instance:", instanceId)
                if sessionManager.isAuthenticated,
                   let userId = sessionManager.userId {
                    let _ = print("🏠 RootTabView building FriendsView for:", userId)
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
            NavigationStack {
                let _ = print("📦 Profile NavigationStack BUILD — instance:", instanceId)
                if sessionManager.isAuthenticated,
                   let userId = sessionManager.userId {
                    let _ = print("🏠 RootTabView building ProfileView for:", userId)
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
            NavigationStack {
                MoreView()
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
        }
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
                ListsView()
            }

            NavigationLink("Send Feedback") {
                FeedbackView()
            }

            NavigationLink("Legal") {
                LegalView()
            }
        }
        .navigationTitle("More")
    }
}

struct ListsView: View {
    var body: some View {
        List {
            NavigationLink("Bucket List") {
                BucketListView()
            }

            NavigationLink("Visited Countries") {
                MyTravelsView()
            }
        }
        .navigationTitle("Lists")
    }
}
