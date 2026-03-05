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
    let _ = print("🧪 DEBUG: RootTabView body recomputed")
    ZStack {

        GeometryReader { geo in
            Image("travel1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: geo.size.width,
                    height: geo.size.height,
                    alignment: .center
                )
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }

        TabView {
            // Discovery
            NavigationStack {
                DiscoveryView()
                    .onAppear {
                        print("🧪 DEBUG: Discovery NavigationStack content appeared")
                    }
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .tabItem {
                Label("Discovery", systemImage: "globe.americas.fill")
            }

            // Planning
            NavigationStack {
                ListsView()
                    .onAppear {
                        print("🧪 DEBUG: ListsView NavigationStack content appeared")
                    }
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .background(.clear)
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
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .background(.clear)
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
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }

            // More
            NavigationStack {
                MoreView()
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
        }
        .background(Color.clear)
    }
    .onAppear {
        print("🧪 DEBUG: RootTabView fully appeared")
    }
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)

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
                ListsView()
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

struct ListsView: View {
    var body: some View {
        ZStack {

            ScrollView {
                VStack(spacing: 24) {

                    Text("Lists")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

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
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .background(Color.clear)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlanningCard: View {

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        ZStack {

            // scrapbook stacked paper
            Theme.scrapbookBack()
                .offset(x: -4, y: 4)

            HStack(spacing: 16) {

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(18)
            .frame(height: 110)
            .background(
                Theme.cardBackground()
            )
            .rotationEffect(.degrees(1))
        }
    }
}
