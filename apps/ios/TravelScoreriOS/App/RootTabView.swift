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
            NavigationStack {
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
        ScrollView {
            VStack(spacing: 20) {

                Text("Lists")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    BucketListView()
                } label: {
                    PlanningCard(
                        title: "Bucket List",
                        subtitle: "Places you want to visit",
                        icon: "bookmark"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MyTravelsView()
                } label: {
                    PlanningCard(
                        title: "Visited Countries",
                        subtitle: "Track places you've been",
                        icon: "checkmark.circle"
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Planning")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlanningCard: View {

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
