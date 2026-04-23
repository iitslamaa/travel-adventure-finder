import Foundation
import Combine

@MainActor
final class SocialFeedViewModel: ObservableObject {
    @Published private(set) var events: [SocialActivityEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasAttemptedLoad = false

    private let activityService: SocialActivityService

    init(activityService: SocialActivityService? = nil) {
        self.activityService = activityService ?? SocialActivityService()
    }

    func loadFeed(for userId: UUID) async {
        isLoading = true
        hasAttemptedLoad = true

        do {
            events = try await activityService.fetchRecentFriendActivity(for: userId)
        } catch {
#if DEBUG
            print("Failed to load social activity feed:", error.localizedDescription)
#endif
            events = []
        }

        isLoading = false
    }
}
