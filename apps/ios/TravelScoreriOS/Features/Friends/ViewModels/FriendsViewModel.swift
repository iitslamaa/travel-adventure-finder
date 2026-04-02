//
//  FriendsViewModel.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/10/26.
//

import Foundation
import Combine
import SwiftUI
import PostgREST
import Supabase

@MainActor
final class FriendsViewModel: ObservableObject {
    private let instanceId = UUID()

    // MARK: - Published state
    @Published var searchText: String = ""
    @Published var searchResults: [Profile] = [] {
        didSet {
        }
    }
    @Published var isLoading: Bool = false {
        didSet {
        }
    }
    @Published var errorMessage: String?
    @Published var friends: [Profile] = [] {
        didSet {
        }
    }
    @Published var incomingRequestCount: Int = 0 {
        didSet {
        }
    }
    @Published var displayName: String = "" {
        didSet {
        }
    }
    @Published private(set) var hasLoaded: Bool = false

    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared
    private let friendService = FriendService()

    // MARK: - Init / Deinit

    init() {}

    deinit {
    }

    // MARK: - Load Friends

    func loadFriends(for userId: UUID, forceRefresh: Bool = false) async {
        if hasLoaded && !forceRefresh {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedFriends = try await friendService.fetchFriends(for: userId)
            friends = fetchedFriends
            hasLoaded = true
        } catch {
            if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                return
            }

            print("❌ [FriendsVM:", instanceId, "] loadFriends failed:", error)
            errorMessage = error.localizedDescription
            friends = []
        }

        isLoading = false
    }

    // MARK: - Load Display Name

    func loadDisplayName(for userId: UUID) async {
        do {
            let response: PostgrestResponse<Profile> = try await supabase.client
                .from("profiles")
                .select("*")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()

            displayName = response.value.displayName
        } catch {
            if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                return
            }

            print("❌ [FriendsVM:", instanceId, "] loadDisplayName failed:", error)
            displayName = ""
        }
    }

    // MARK: - Incoming Requests Count

    func loadIncomingRequestCount() async {
        guard let userId = supabase.currentUserId else { return }

        do {
            incomingRequestCount = try await friendService.incomingRequestCount(for: userId)
        } catch {
            if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                return
            }

            print("❌ [FriendsVM:", instanceId, "] loadIncomingRequestCount failed:", error)
            incomingRequestCount = 0
        }
    }

    // MARK: - Search

    func searchUsers() async {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            searchResults = try await supabase.searchUsers(byUsername: query)
        } catch {
            if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                return
            }

            print("❌ [FriendsVM:", instanceId, "] searchUsers failed:", error)
            errorMessage = error.localizedDescription
            searchResults = []
        }

        isLoading = false
    }

    // MARK: - Helpers

    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
    }
}
