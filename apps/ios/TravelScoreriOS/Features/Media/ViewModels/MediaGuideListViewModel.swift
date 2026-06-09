import Combine
import Foundation

@MainActor
final class MediaGuideListViewModel: ObservableObject {
    @Published private(set) var guides: [MediaGuide] = []
    @Published private(set) var podcastEpisodes: [MediaPodcastEpisode] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasAttemptedLoad = false
    @Published private(set) var guideErrorMessage: String?
    @Published private(set) var podcastErrorMessage: String?

    private let guideService: MediaGuideService

    init(guideService: MediaGuideService? = nil) {
        self.guideService = guideService ?? MediaGuideService()
    }

    func loadGuides() async {
        guard !isLoading else { return }

        isLoading = true
        hasAttemptedLoad = true
        guideErrorMessage = nil
        podcastErrorMessage = nil

        defer {
            isLoading = false
        }

        do {
            guides = try await guideService.fetchPublishedGuides()
        } catch is CancellationError {
        } catch {
            guides = []
            guideErrorMessage = "Guides could not load right now."
        }

        do {
            podcastEpisodes = try await guideService.fetchPublishedPodcastEpisodes()
        } catch is CancellationError {
        } catch {
            podcastEpisodes = []
            podcastErrorMessage = "Podcasts could not load right now."
        }
    }
}
