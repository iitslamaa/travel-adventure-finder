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
        if isLoading, lastRequestedUserId == userId {
            SocialFeedDebug.log("load.skipped source=\(source) user=\(userId) reason=already_loading_same_user")
            return
        }

        let loadId = String(UUID().uuidString.prefix(8))
        let startTime = Date()

        SocialFeedDebug.log("load.start id=\(loadId) source=\(source) user=\(userId) existing_events=\(events.count)")
        if lastRequestedUserId != userId {
            SocialFeedDebug.log("load.user_change id=\(loadId) previous_user=\(lastRequestedUserId?.uuidString ?? "nil") new_user=\(userId.uuidString) clearing_existing_events=\(!events.isEmpty)")
            events = []
            lastRequestedUserId = userId
        }
        isLoading = true
        hasAttemptedLoad = true
        SocialFeedDebug.log("load.state id=\(loadId) source=\(source) isLoading=\(isLoading) hasAttemptedLoad=\(hasAttemptedLoad)")

        defer {
            isLoading = false
            SocialFeedDebug.log("load.finish id=\(loadId) source=\(source) duration=\(SocialFeedDebug.duration(since: startTime)) events=\(events.count) isLoading=\(isLoading) cancelled=\(Task.isCancelled)")
        }

        do {
            let fetchedEvents = try await activityService.fetchRecentFriendActivity(for: userId, requestId: loadId)
            let previousCount = events.count
            SocialFeedDebug.log("load.success id=\(loadId) source=\(source) fetched=\(fetchedEvents.count) previous_events=\(previousCount)")
            events = fetchedEvents
            SocialFeedDebug.log("load.state_updated id=\(loadId) source=\(source) new_events=\(events.count)")
        } catch where SocialFeedDebug.isCancellation(error) {
            SocialFeedDebug.log("load.cancelled id=\(loadId) source=\(source) keeping_existing_events=\(events.count)")
        } catch {
            SocialFeedDebug.log("load.error id=\(loadId) source=\(source) error=\(SocialFeedDebug.describe(error))")
            events = []
            SocialFeedDebug.log("load.state_updated id=\(loadId) source=\(source) new_events=0 reason=error")
        }
    }
}

enum SocialFeedDebug {
    static func log(_ message: String) {
        let timestamp = timestampFormatter.string(from: Date())
        print("[SocialActivity][\(timestamp)] \(message)")
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

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
