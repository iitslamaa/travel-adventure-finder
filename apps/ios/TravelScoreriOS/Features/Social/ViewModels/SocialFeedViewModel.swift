import Foundation
import Combine

@MainActor
final class SocialFeedViewModel: ObservableObject {
    @Published private(set) var events: [SocialActivityEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasAttemptedLoad = false

    private let activityService: SocialActivityService
    private var lastRequestedUserId: UUID?

    init(activityService: SocialActivityService? = nil) {
        self.activityService = activityService ?? SocialActivityService()
    }

    func loadFeed(for userId: UUID, source: String = "unspecified") async {
        let loadId = String(UUID().uuidString.prefix(8))
        let startTime = Date()

        SocialFeedDebug.log("load.start id=\(loadId) source=\(source) user=\(userId) existing_events=\(events.count)")
        if lastRequestedUserId != userId {
            events = []
            lastRequestedUserId = userId
        }
        isLoading = true
        hasAttemptedLoad = true

        defer {
            isLoading = false
            SocialFeedDebug.log("load.finish id=\(loadId) source=\(source) duration=\(SocialFeedDebug.duration(since: startTime)) events=\(events.count) cancelled=\(Task.isCancelled)")
        }

        do {
            let fetchedEvents = try await activityService.fetchRecentFriendActivity(for: userId, requestId: loadId)
            SocialFeedDebug.log("load.success id=\(loadId) source=\(source) fetched=\(fetchedEvents.count)")
            events = fetchedEvents
        } catch where SocialFeedDebug.isCancellation(error) {
            SocialFeedDebug.log("load.cancelled id=\(loadId) source=\(source) keeping_existing_events=\(events.count)")
        } catch {
            SocialFeedDebug.log("load.error id=\(loadId) source=\(source) error=\(SocialFeedDebug.describe(error))")
            events = []
        }
    }
}

enum SocialFeedDebug {
    static func log(_ message: String) {
#if DEBUG
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        print("📰 [SocialFeed] \(timestamp) \(message)")
#endif
    }

    static func duration(since startTime: Date) -> String {
        let milliseconds = Int(Date().timeIntervalSince(startTime) * 1_000)
        return "\(milliseconds)ms"
    }

    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(type(of: error))(domain=\(nsError.domain), code=\(nsError.code), description=\(error.localizedDescription))"
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError,
           urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
