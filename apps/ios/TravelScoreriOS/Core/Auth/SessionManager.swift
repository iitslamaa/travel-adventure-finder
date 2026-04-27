//
//  SessionManager.swift
//  TravelScoreriOS
//

import Foundation
import Combine
import Supabase

@MainActor
final class SessionManager: ObservableObject {

    private let instanceId = UUID()

    @Published private(set) var isAuthenticated: Bool = false {
        didSet {
            
        }
    }
    @Published var didContinueAsGuest: Bool = false
    @Published private(set) var userId: UUID? = nil {
        didSet {
            
        }
    }
    @Published private(set) var authScreenNonce: UUID = UUID()
    @Published private(set) var isAuthSuppressed: Bool = false
    @Published private(set) var hasResolvedInitialAuthState: Bool = false


    let supabase: SupabaseManager
    private var cancellables = Set<AnyCancellable>()

    private let bucketListStore: BucketListStore
    private let traveledStore: TraveledStore
    private let listSync: ListSyncService

    private var guestBucketSnapshot: Set<String> = []
    private var guestTraveledSnapshot: Set<String> = []

    private var hasMergedGuestData = false
    private var didEnsureProfile = false

    private var syncTask: Task<Void, Never>?
    private var ensureProfileTask: Task<Void, Never>?
    private var syncingUserId: UUID?

    // MARK: - Initializers

    init(
        supabase: SupabaseManager,
        bucketListStore: BucketListStore,
        traveledStore: TraveledStore
    ) {
        self.supabase = supabase
        self.bucketListStore = bucketListStore
        self.traveledStore = traveledStore
        self.listSync = ListSyncService(supabase: supabase)

        // Start Supabase auth listener (non-blocking)
        Task {
            await supabase.startAuthListener()
        }

        guestBucketSnapshot = bucketListStore.ids
        guestTraveledSnapshot = traveledStore.ids

        // Begin observing auth state
        startAuthObservation()
    }

    // MARK: - Public API

    func continueAsGuest() {
        if isAuthSuppressed != false { isAuthSuppressed = false }
        if didContinueAsGuest != true { didContinueAsGuest = true }
        if isAuthenticated != false { isAuthenticated = false }
    }

    func signOut() async {
        try? await supabase.signOut()
        if isAuthSuppressed != false { isAuthSuppressed = false }
        if didContinueAsGuest != false { didContinueAsGuest = false }
        if isAuthenticated != false { isAuthenticated = false }
        
        if userId != nil { userId = nil }
        bucketListStore.replace(with: guestBucketSnapshot)
        traveledStore.replace(with: guestTraveledSnapshot)
        hasMergedGuestData = false
        didEnsureProfile = false
        syncTask?.cancel()
        syncTask = nil
        syncingUserId = nil
        ensureProfileTask?.cancel()
        ensureProfileTask = nil
        
        bumpAuthScreen()
    }

    func bumpAuthScreen() {
        authScreenNonce = UUID()
    }

    /// Use this after a successful account deletion to force the UI back to auth,
    /// even if a stale local session token still exists briefly.
    func handleAccountDeleted() {
        if isAuthSuppressed != true { isAuthSuppressed = true }
        if didContinueAsGuest != false { didContinueAsGuest = false }
        if isAuthenticated != false { isAuthenticated = false }
        
        if userId != nil { userId = nil }
        hasMergedGuestData = false
        didEnsureProfile = false
        syncTask?.cancel()
        syncTask = nil
        syncingUserId = nil
        ensureProfileTask?.cancel()
        ensureProfileTask = nil
        bumpAuthScreen()
    }

    /// Call this after ANY auth attempt (Apple / Google / Email)
    /// to deterministically update UI state.
    func forceRefreshAuthState(source: String = "manual") async {
        // If we just deleted an account, stay logged out unless we observe a *real* (server-verified) fresh session.
        if isAuthSuppressed {
            let session = try? await supabase.fetchCurrentSession()
            if let session, !session.isExpired {
                
                isAuthSuppressed = false
            } else {
                
                if isAuthenticated != false { isAuthenticated = false }
                if userId != nil { userId = nil }
                if hasResolvedInitialAuthState != true { hasResolvedInitialAuthState = true }
                return
            }
        }
        do {
            let session = try await supabase.fetchCurrentSession()


            if let session {
                // Fresh valid session observed — allow auth again
                isAuthSuppressed = false
                if session.isExpired {
                    
                    if isAuthenticated != false { isAuthenticated = false }
                    if userId != nil { userId = nil }
                    hasMergedGuestData = false
                } else {
                    
                    if isAuthenticated != true { isAuthenticated = true }
                    if userId != session.user.id { userId = session.user.id }

                    ensureProfileEventually(for: session.user.id)
                    synchronizeListsIfNeeded(for: session.user.id)
                }
            } else {
                
                if isAuthenticated != false { isAuthenticated = false }
                if userId != nil { userId = nil }
                hasMergedGuestData = false
                didEnsureProfile = false
                syncingUserId = nil
            }
        } catch {
            print("⚠️ forceRefreshAuthState transient error:", error)
            // 🔥 DO NOT clear userId or isAuthenticated on transient error
        }

        if hasResolvedInitialAuthState != true {
            hasResolvedInitialAuthState = true
        }
    }

    // MARK: - Profile bring-up

    /// Ensures a `profiles` row exists for the authenticated user.
    /// On some devices, immediately after signup the `auth.users` row may not be visible yet,
    /// which causes `profiles_id_fkey` (23503). We retry with backoff.
    private func ensureProfileEventually(for userId: UUID) {
        guard !didEnsureProfile else { return }
        didEnsureProfile = true

        ensureProfileTask?.cancel()
        ensureProfileTask = Task {
            let delays: [UInt64] = [500_000_000, 1_000_000_000, 2_000_000_000, 4_000_000_000] // 0.5s, 1s, 2s, 4s

            for (idx, delay) in delays.enumerated() {
                try? await Task.sleep(nanoseconds: delay)

                // Re-hydrate session in case auth state is still propagating
                _ = try? await supabase.fetchCurrentSession()

                do {
                    let profileService = ProfileService(supabase: supabase)
                    try await profileService.ensureProfileExists(userId: userId)

                    ensureProfileTask = nil
                    return

                } catch {
                    // Keep retrying on FK race; otherwise bail.
                    if let pg = error as? PostgrestError, pg.code == "23503" {
                        print("⚠️ ensureProfileEventually FK (23503) — retry \(idx + 1)/\(delays.count) for:", userId)
                        continue
                    }

                    print("❌ ensureProfileEventually failed (non-FK):", error)
                    return
                }
            }

            // If we exhausted retries, allow a later auth refresh to try again.
            print("❌ ensureProfileEventually exhausted retries for:", userId)
            didEnsureProfile = false
            ensureProfileTask = nil
        }
    }

    // MARK: - Private

    private func mergeGuestDataIfNeeded(
        for userId: UUID,
        remoteBucketIds: Set<String>,
        remoteTraveledIds: Set<String>
    ) async {
        SocialFeedDebug.log(
            "session.guest_merge.enter user=\(userId.uuidString) already_merged=\(hasMergedGuestData) " +
            "guest_bucket_\(SocialFeedDebug.countrySetSummary(guestBucketSnapshot)) remote_bucket_\(SocialFeedDebug.countrySetSummary(remoteBucketIds))"
        )
        guard !hasMergedGuestData else {
            SocialFeedDebug.log("session.guest_merge.skip user=\(userId.uuidString) reason=already_merged")
            return
        }
        hasMergedGuestData = true

        let bucketIdsToMerge = guestBucketSnapshot.subtracting(remoteBucketIds)
        let traveledIdsToMerge = guestTraveledSnapshot.subtracting(remoteTraveledIds)
        SocialFeedDebug.log(
            "session.guest_merge.diff user=\(userId.uuidString) bucket_to_merge_\(SocialFeedDebug.countrySetSummary(bucketIdsToMerge)) traveled_to_merge_count=\(traveledIdsToMerge.count)"
        )

        for countryId in bucketIdsToMerge {
            SocialFeedDebug.log("session.guest_merge.bucket_add.begin user=\(userId.uuidString) country=\(countryId)")
            await listSync.setBucket(
                userId: userId,
                countryId: countryId,
                add: true
            )
            SocialFeedDebug.log("session.guest_merge.bucket_add.end user=\(userId.uuidString) country=\(countryId)")
        }

        for countryId in traveledIdsToMerge {
            await listSync.setTraveled(
                userId: userId,
                countryId: countryId,
                add: true
            )
        }

        if !bucketIdsToMerge.isEmpty {
            try? await SocialActivityService().recordCountryListActivity(
                actorUserId: userId,
                eventType: .bucketListAdded,
                countryIds: Array(bucketIdsToMerge)
            )
        }

        if !traveledIdsToMerge.isEmpty {
            try? await SocialActivityService().recordCountryListActivity(
                actorUserId: userId,
                eventType: .countryVisited,
                countryIds: Array(traveledIdsToMerge)
            )
        }

        // Clear guest snapshots after successful merge
        guestBucketSnapshot.removeAll()
        guestTraveledSnapshot.removeAll()
        SocialFeedDebug.log("session.guest_merge.end user=\(userId.uuidString) cleared_guest_snapshots=true")
    }

    private func synchronizeListsIfNeeded(for userId: UUID) {
        guard syncingUserId != userId else { return }

        syncTask?.cancel()
        syncingUserId = userId

        syncTask = Task { [weak self] in
            guard let self else { return }

            do {
                async let bucketTask = self.listSync.fetchBucketList(userId: userId)
                async let traveledTask = self.listSync.fetchTraveled(userId: userId)
                var (bucketIds, traveledIds) = try await (bucketTask, traveledTask)

                if !self.guestBucketSnapshot.isEmpty || !self.guestTraveledSnapshot.isEmpty {
                    await self.mergeGuestDataIfNeeded(
                        for: userId,
                        remoteBucketIds: bucketIds,
                        remoteTraveledIds: traveledIds
                    )

                    bucketIds.formUnion(self.guestBucketSnapshot)
                    traveledIds.formUnion(self.guestTraveledSnapshot)
                }

                if Task.isCancelled { return }

                self.bucketListStore.replace(with: bucketIds)
                self.traveledStore.replace(with: traveledIds)
            } catch {
                print("⚠️ synchronizeListsIfNeeded failed:", error)
            }

            if !Task.isCancelled, self.syncingUserId == userId {
                self.syncingUserId = nil
                self.syncTask = nil
            }
        }
    }

    private func startAuthObservation() {
        refreshFromCurrentSession(source: "initial")
        listenForAuthChanges()
    }

    // MARK: - Private

    private func refreshFromCurrentSession(source: String) {
        Task {
            if self.isAuthSuppressed {
                let session = try? await supabase.fetchCurrentSession()
                if let session, !session.isExpired {
                    
                    self.isAuthSuppressed = false
                } else {
                    
                    if self.isAuthenticated != false { self.isAuthenticated = false }
                    if self.userId != nil { self.userId = nil }
                    if self.hasResolvedInitialAuthState != true { self.hasResolvedInitialAuthState = true }
                    return
                }
            }
            do {
                let session = try await supabase.fetchCurrentSession()
                

                if let session, !session.isExpired {
                    
                    if isAuthenticated != true { isAuthenticated = true }
                    if userId != session.user.id { userId = session.user.id }

                    ensureProfileEventually(for: session.user.id)
                    synchronizeListsIfNeeded(for: session.user.id)
                } else {
                    
                    if isAuthenticated != false { isAuthenticated = false }
                    if userId != nil { userId = nil }
                    hasMergedGuestData = false
                    didEnsureProfile = false
                    syncingUserId = nil
                }
            } catch {
                print("⚠️ refreshFromCurrentSession transient error:", error)
                // 🔥 DO NOT clear userId or isAuthenticated on transient error
            }

            if self.hasResolvedInitialAuthState != true {
                self.hasResolvedInitialAuthState = true
            }
        }
    }

    private func listenForAuthChanges() {
        supabase.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromCurrentSession(source: "authEvent")
            }
            .store(in: &cancellables)
    }

    deinit {
    }
}
