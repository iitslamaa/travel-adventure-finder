//
//  FriendsViewModel.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/10/26.
//

import Foundation
import Combine
import SwiftUI
import Supabase

private enum FriendsDebugLog {
    static func message(_ text: String) {}
}

@MainActor
final class FriendsViewModel: ObservableObject {
    private let instanceId = UUID()

    // MARK: - Published state
    @Published var searchText: String = ""
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
    @Published private(set) var hasAttemptedLoad: Bool = false

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
            FriendsDebugLog.message("Friends load skipped user=\(userId.uuidString) reason=already-loaded")
            return
        }

        if let cachedFriends = friendService.cachedFriends(for: userId),
           !cachedFriends.isEmpty,
           friends.isEmpty {
            friends = cachedFriends
            FriendsDebugLog.message("Friends seeded from cache user=\(userId.uuidString) count=\(cachedFriends.count)")
        }

        let loadStart = Date()
        isLoading = true
        hasAttemptedLoad = true
        defer { isLoading = false }

        if forceRefresh || friends.isEmpty {
            errorMessage = nil
        }

        do {
            let fetchedFriends = try await friendService.fetchFriends(for: userId)
            friends = fetchedFriends
            hasLoaded = true
            FriendsDebugLog.message(
                "Friends loaded user=\(userId.uuidString) count=\(fetchedFriends.count) duration=\(Int(Date().timeIntervalSince(loadStart) * 1000))ms forceRefresh=\(forceRefresh)"
            )
        } catch {
            if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                return
            }
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .timedOut:
                    errorMessage = "Couldn't load friends. Check your connection and pull to retry."
                default:
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Incoming Requests Count

    func loadIncomingRequestCount() async {
        guard let userId = supabase.currentUserId else { return }

        if let cachedCount = friendService.cachedIncomingRequestCount(for: userId) {
            incomingRequestCount = cachedCount
            FriendsDebugLog.message("Request count loaded from cache user=\(userId.uuidString) count=\(cachedCount)")
            return
        }

        let loadStart = Date()
        do {
            incomingRequestCount = try await friendService.incomingRequestCount(for: userId)
            FriendsDebugLog.message(
                "Request count loaded user=\(userId.uuidString) count=\(incomingRequestCount) duration=\(Int(Date().timeIntervalSince(loadStart) * 1000))ms"
            )
        } catch {
            if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                return
            }
            incomingRequestCount = 0
        }
    }

    // MARK: - Helpers

    func clearSearch() {
        searchText = ""
        errorMessage = nil
    }
}
