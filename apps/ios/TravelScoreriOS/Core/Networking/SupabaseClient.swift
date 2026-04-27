/// SupabaseClient.swift

import Foundation
import Combine
import Supabase

private enum SupabaseSearchDebugLog {
    static func message(_ text: String) {}

    static func duration(since start: Date) -> String {
        "\(Int(Date().timeIntervalSince(start) * 1000))ms"
    }
}

private struct PublicProfileRow: Decodable {
    let id: UUID
    let username: String
    let full_name: String?
    let first_name: String?
    let last_name: String?
    let avatar_url: String?
    let friend_count: Int?

    var profile: Profile {
        Profile(
            id: id,
            username: username,
            fullName: full_name ?? "",
            firstName: first_name,
            lastName: last_name,
            avatarUrl: avatar_url,
            languages: [],
            livedCountries: [],
            travelStyle: [],
            travelMode: [],
            nextDestination: nil,
            defaultCurrencyCode: nil,
            currentCountry: nil,
            favoriteCountries: nil,
            onboardingCompleted: nil,
            friendCount: friend_count ?? 0
        )
    }
}

/// Low-level Supabase wrapper.
/// ❗️Not MainActor. Not UI. No SwiftUI state.
final class SupabaseManager {
    private let instanceId = UUID()
    private static let publicProfileSelect = """
        id,
        username,
        full_name,
        first_name,
        last_name,
        avatar_url,
        friend_count
    """

    static let shared = SupabaseManager()
    private static let authVerificationSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 4
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    let client: SupabaseClient

    // Emits whenever auth state changes (sign in / sign out)
    private let authStateSubject = PassthroughSubject<Void, Never>()
    private var hasStartedAuthListener = false
    var authStatePublisher: AnyPublisher<Void, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    private init() {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlString)
        else {
            fatalError("Missing Supabase credentials in Info.plist")
        }

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: URL(string: "travelaf://auth/callback"),
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    func startAuthListener() async {
        guard !hasStartedAuthListener else { return }
        hasStartedAuthListener = true
        let authStateSubject = self.authStateSubject

        await client.auth.onAuthStateChange { _, _ in
            Task { @MainActor in
                authStateSubject.send(())
            }
        }
    }

    // MARK: - Auth verification

    /// Verifies the access token against Supabase Auth REST API.
    /// Returns true if the token maps to a real user on the server.
    private func verifyUserOnServer(accessToken: String) async -> Bool {
        let startedAt = Date()
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let baseURL = URL(string: urlString)
        else {
            SocialFeedDebug.log("launch.supabase.verify.skip reason=missing_url duration=\(SocialFeedDebug.duration(since: startedAt))")
            return false
        }

        let url = baseURL.appendingPathComponent("auth/v1/user")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 4
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        do {
            SocialFeedDebug.log("launch.supabase.verify.start")
            let (_, response) = try await Self.authVerificationSession.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            SocialFeedDebug.log("launch.supabase.verify.end status=\(code) duration=\(SocialFeedDebug.duration(since: startedAt))")
            return code == 200
        } catch {
            SocialFeedDebug.log("launch.supabase.verify.error duration=\(SocialFeedDebug.duration(since: startedAt)) error=\(SocialFeedDebug.describe(error))")
            return false
        }
    }

    // MARK: - Session

    /// Supabase SDK exposes session asynchronously.
    /// IMPORTANT: We server-verify the session maps to a real auth user.
    /// On some devices/flows, the SDK can temporarily surface a local session before the user exists in `auth.users`.
    func fetchCurrentSession() async throws -> Session? {
        let startedAt = Date()
        SocialFeedDebug.log("launch.supabase.session.start")
        // Do not throw on missing session; treat as logged out.
        let session = try? await client.auth.session

        guard let session else {
            SocialFeedDebug.log("launch.supabase.session.none duration=\(SocialFeedDebug.duration(since: startedAt))")
            return nil
        }

        SocialFeedDebug.log("launch.supabase.session.local_hit expired=\(session.isExpired) duration=\(SocialFeedDebug.duration(since: startedAt))")

        // Server-verify the access token maps to a real user.
        let isValidOnServer = await verifyUserOnServer(accessToken: session.accessToken)
        if !isValidOnServer {
            SocialFeedDebug.log("launch.supabase.session.rejected duration=\(SocialFeedDebug.duration(since: startedAt))")
            return nil
        }

        SocialFeedDebug.log("launch.supabase.session.verified user=\(session.user.id.uuidString) duration=\(SocialFeedDebug.duration(since: startedAt))")
        return session
    }

    // MARK: - Auth helpers

    func signOut() async throws {
        
        try await client.auth.signOut()
    }

    /// Deletes the currently authenticated user account via Edge Function
    func deleteAccount() async throws {
        

        // Safely attempt to hydrate session (do not crash if missing)
        let session = try? await client.auth.session

        guard session != nil, client.auth.currentUser != nil else {
            throw NSError(
                domain: "DeleteAccount",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "profile.errors.no_active_session")]
            )
        }

        // Call the deployed edge function
        _ = try await client.functions.invoke("delete-account")

        // Sign out locally after backend deletion
        try await client.auth.signOut()
    }

    // MARK: - User Queries

    /// Returns the currently authenticated user's ID
    var currentUserId: UUID? {
        let id = client.auth.currentUser?.id
        return id
    }

    /// Search users by username (case-insensitive, partial match)
    func searchUsers(byUsername query: String, debugContext: String = "general") async throws -> [Profile] {
        let startedAt = Date()
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        SupabaseSearchDebugLog.message(
            "search.start context=\(debugContext) raw=\(query.debugDescription) normalized=\(normalizedQuery.debugDescription)"
        )

        let response: PostgrestResponse<[PublicProfileRow]> = try await client
            .from("profiles")
            .select(Self.publicProfileSelect)
            .ilike("username", pattern: "%\(normalizedQuery)%")
            .limit(20)
            .execute()

        let profiles = response.value.map(\.profile)
        let preview = profiles.prefix(5).map(\.username).joined(separator: ",")
        SupabaseSearchDebugLog.message(
            "search.success context=\(debugContext) normalized=\(normalizedQuery.debugDescription) rows=\(profiles.count) preview=[\(preview)] duration=\(SupabaseSearchDebugLog.duration(since: startedAt))"
        )
        return profiles
    }
    deinit {
    }
}
