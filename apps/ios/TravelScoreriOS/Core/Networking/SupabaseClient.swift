/// SupabaseClient.swift

import Foundation
import Combine
import Supabase

/// Low-level Supabase wrapper.
/// ❗️Not MainActor. Not UI. No SwiftUI state.
final class SupabaseManager {
    private let instanceId = UUID()
    static let shared = SupabaseManager()

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

        await client.auth.onAuthStateChange { [weak self] _, _ in
            Task { @MainActor in
                self?.authStateSubject.send(())
            }
        }
    }

    // MARK: - Auth verification

    /// Verifies the access token against Supabase Auth REST API.
    /// Returns true if the token maps to a real user on the server.
    private func verifyUserOnServer(accessToken: String) async -> Bool {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let baseURL = URL(string: urlString)
        else {
            return false
        }

        let url = baseURL.appendingPathComponent("auth/v1/user")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            return code == 200
        } catch {
            return false
        }
    }

    // MARK: - Session

    /// Supabase SDK exposes session asynchronously.
    /// IMPORTANT: We server-verify the session maps to a real auth user.
    /// On some devices/flows, the SDK can temporarily surface a local session before the user exists in `auth.users`.
    func fetchCurrentSession() async throws -> Session? {
        // Do not throw on missing session; treat as logged out.
        let session = try? await client.auth.session

        guard let session else { return nil }

        // Server-verify the access token maps to a real user.
        let isValidOnServer = await verifyUserOnServer(accessToken: session.accessToken)
        if !isValidOnServer {
            print("⚠️ [\(instanceId)] fetchCurrentSession server verify failed — treating as no session")
            return nil
        }

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
    func searchUsers(byUsername query: String) async throws -> [Profile] {
        let response: PostgrestResponse<[Profile]> = try await client
            .from("profiles")
            .select("*")
            .ilike("username", pattern: "%\(query)%")
            .limit(20)
            .execute()
        return response.value
    }
    deinit {
    }
}
