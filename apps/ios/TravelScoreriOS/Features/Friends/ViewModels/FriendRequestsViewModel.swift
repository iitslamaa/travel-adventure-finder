//
//  FriendRequestsViewModel.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/10/26.
//

import Foundation
import Combine
import Supabase

private enum FriendRequestsDebugLog {
    static func message(_ text: String) {
#if DEBUG
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        print("🙋 [FriendRequests] \(timestamp) \(text)")
#endif
    }

    static func duration(since start: Date) -> String {
        "\(Int(Date().timeIntervalSince(start) * 1000))ms"
    }
}

@MainActor
final class FriendRequestsViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var searchResults: [Profile] = []
    @Published var incomingRequests: [Profile] = []
    @Published var outgoingRequests: [Profile] = []
    @Published var friends: [Profile] = []
    @Published var isLoading: Bool = false
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var hasAttemptedLoad: Bool = false

    private let supabase = SupabaseManager.shared
    private let friendService = FriendService()
    private var searchSequence = 0
    private var activeSearchTask: Task<[Profile], Error>?

    private let searchDebounceNanoseconds: UInt64 = 250_000_000

    private var currentUserId: UUID? {
        supabase.currentUserId
    }

    private var friendIds: Set<UUID> {
        Set(friends.map(\.id))
    }

    private var incomingRequestIds: Set<UUID> {
        Set(incomingRequests.map(\.id))
    }

    private var outgoingRequestIds: Set<UUID> {
        Set(outgoingRequests.map(\.id))
    }

    func loadData(forceRefresh: Bool = false) async {
        guard let myUserId = currentUserId else { return }

        hasAttemptedLoad = true

        if let cachedRequests = friendService.cachedIncomingRequests(for: myUserId),
           incomingRequests.isEmpty {
            incomingRequests = cachedRequests
            FriendRequestsDebugLog.message(
                "Incoming requests seeded from cache user=\(myUserId.uuidString) count=\(cachedRequests.count)"
            )
        }

        if let cachedFriends = friendService.cachedFriends(for: myUserId),
           friends.isEmpty {
            friends = cachedFriends
            FriendRequestsDebugLog.message(
                "Friends seeded from cache user=\(myUserId.uuidString) count=\(cachedFriends.count)"
            )
        }

        let loadStart = Date()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let incomingTask = friendService.fetchIncomingRequests(for: myUserId)
            async let outgoingTask = friendService.fetchOutgoingRequests(for: myUserId)
            async let friendsTask = friendService.fetchFriends(for: myUserId)

            incomingRequests = try await incomingTask
            outgoingRequests = try await outgoingTask
            friends = try await friendsTask

            FriendRequestsDebugLog.message(
                "Requests data loaded user=\(myUserId.uuidString) incoming=\(incomingRequests.count) outgoing=\(outgoingRequests.count) friends=\(friends.count) duration=\(Int(Date().timeIntervalSince(loadStart) * 1000))ms forceRefresh=\(forceRefresh)"
            )
        } catch {
            if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                return
            }

            errorMessage = error.localizedDescription
            if forceRefresh || incomingRequests.isEmpty {
                incomingRequests = []
                outgoingRequests = []
                friends = []
            }
        }
    }

    func searchUsers() async {
        guard let myUserId = currentUserId else { return }

        let rawQuery = searchText
        let query = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        let searchId = String(UUID().uuidString.prefix(8))

        searchSequence += 1
        let sequence = searchSequence

        activeSearchTask?.cancel()

        FriendRequestsDebugLog.message(
            "Search requested id=\(searchId) sequence=\(sequence) raw=\(rawQuery.debugDescription) normalized=\(query.debugDescription)"
        )

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            FriendRequestsDebugLog.message("Search cleared id=\(searchId) sequence=\(sequence) reason=empty_query")
            return
        }

        let startedAt = Date()
        isSearching = true
        errorMessage = nil
        defer {
            if sequence == searchSequence {
                isSearching = false
            }
        }

        do {
            let searchTask = Task<[Profile], Error> {
                try await Task.sleep(nanoseconds: searchDebounceNanoseconds)
                return try await supabase.searchUsers(byUsername: query, debugContext: "friend-requests:\(searchId)")
            }
            activeSearchTask = searchTask

            let users = try await searchTask.value
            let filteredUsers = users.filter { profile in
                profile.id != myUserId && !friendIds.contains(profile.id)
            }

            guard sequence == searchSequence else {
                FriendRequestsDebugLog.message(
                    "Search discarded id=\(searchId) sequence=\(sequence) reason=stale_response raw_results=\(users.count) filtered_results=\(filteredUsers.count) duration=\(FriendRequestsDebugLog.duration(since: startedAt))"
                )
                return
            }

            searchResults = filteredUsers
            FriendRequestsDebugLog.message(
                "Search completed id=\(searchId) sequence=\(sequence) query=\(query) raw_results=\(users.count) filtered_results=\(filteredUsers.count) incoming_matches=\(filteredUsers.filter { incomingRequestIds.contains($0.id) }.count) outgoing_matches=\(filteredUsers.filter { outgoingRequestIds.contains($0.id) }.count) duration=\(FriendRequestsDebugLog.duration(since: startedAt))"
            )
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled {
                FriendRequestsDebugLog.message(
                    "Search cancelled id=\(searchId) sequence=\(sequence) duration=\(FriendRequestsDebugLog.duration(since: startedAt))"
                )
                return
            }

            guard sequence == searchSequence else {
                FriendRequestsDebugLog.message(
                    "Search error ignored id=\(searchId) sequence=\(sequence) reason=stale_error error=\(error.localizedDescription)"
                )
                return
            }

            errorMessage = error.localizedDescription
            searchResults = []
            FriendRequestsDebugLog.message(
                "Search failed id=\(searchId) sequence=\(sequence) query=\(query) error=\(error.localizedDescription) duration=\(FriendRequestsDebugLog.duration(since: startedAt))"
            )
        }
    }

    func isIncomingRequest(_ userId: UUID) -> Bool {
        incomingRequestIds.contains(userId)
    }

    func isOutgoingRequest(_ userId: UUID) -> Bool {
        outgoingRequestIds.contains(userId)
    }

    func sendFriendRequest(to userId: UUID) async throws {
        guard let myUserId = currentUserId else { return }
        try await friendService.sendFriendRequest(from: myUserId, to: userId)
        await loadData(forceRefresh: true)
        await searchUsers()
    }

    func cancelRequest(to userId: UUID) async throws {
        guard let myUserId = currentUserId else { return }
        try await friendService.cancelRequest(from: myUserId, to: userId)
        await loadData(forceRefresh: true)
        await searchUsers()
    }

    func acceptRequest(from userId: UUID) async throws {
        guard let myUserId = currentUserId else { return }
        try await friendService.acceptRequest(myUserId: myUserId, from: userId)
        await loadData(forceRefresh: true)
        await searchUsers()
    }

    func rejectRequest(from userId: UUID) async throws {
        guard let myUserId = currentUserId else { return }
        try await friendService.rejectRequest(myUserId: myUserId, from: userId)
        await loadData(forceRefresh: true)
        await searchUsers()
    }

    func clearSearch() {
        activeSearchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
        FriendRequestsDebugLog.message("Search cleared manually")
    }
}
