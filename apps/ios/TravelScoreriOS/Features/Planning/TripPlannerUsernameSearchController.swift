import Combine
import SwiftUI

let tripPlannerUsernameSearchDebounceNanoseconds: UInt64 = 300_000_000

func tripPlannerNormalizedUsernameQuery(_ rawValue: String) -> String {
    rawValue
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "@", with: "")
}

@MainActor
final class TripPlannerUsernameSearchController: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [Profile] = []
    @Published private(set) var isSearching = false

    private let supabase: SupabaseManager
    private var searchTask: Task<Void, Never>?

    init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    convenience init() {
        self.init(supabase: .shared)
    }

    func scheduleSearch(enabled: Bool = true, excluding excludedUserID: UUID?) {
        searchTask?.cancel()

        let normalizedQuery = tripPlannerNormalizedUsernameQuery(query)
        guard enabled, !normalizedQuery.isEmpty else {
            results = []
            isSearching = false
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: tripPlannerUsernameSearchDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.runSearch(query: normalizedQuery, excluding: excludedUserID)
        }
    }

    func reset() {
        searchTask?.cancel()
        query = ""
        results = []
        isSearching = false
    }

    func cancel() {
        searchTask?.cancel()
        isSearching = false
    }

    private func runSearch(query: String, excluding excludedUserID: UUID?) async {
        guard !query.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let found = try await supabase.searchUsers(byUsername: query)
            guard tripPlannerNormalizedUsernameQuery(self.query) == query else { return }
            results = found.filter { $0.id != excludedUserID }
        } catch {
            guard tripPlannerNormalizedUsernameQuery(self.query) == query else { return }
            results = []
        }
    }
}
