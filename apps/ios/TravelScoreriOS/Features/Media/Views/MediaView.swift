import NukeUI
import SwiftUI

struct MediaView: View {
    @StateObject private var viewModel = MediaGuideListViewModel()

    var body: some View {
        ZStack {
            Theme.pageBackground("travel5")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "media.title"))

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        MediaGuideSection(
                            guides: viewModel.guides,
                            isLoading: viewModel.isLoading,
                            errorMessage: viewModel.guideErrorMessage
                        )

                        MediaPodcastSection(
                            episodes: viewModel.podcastEpisodes,
                            isLoading: viewModel.isLoading,
                            errorMessage: viewModel.podcastErrorMessage
                        )
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
                .refreshable {
                    await viewModel.loadGuides()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadGuides()
        }
    }
}

private struct MediaGuideSection: View {
    let guides: [MediaGuide]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        if isLoading && guides.isEmpty {
            MediaLoadingCard(title: MediaCopy.guidesLoadingTitle)
        } else if !guides.isEmpty {
            VStack(spacing: 14) {
                ForEach(guides) { guide in
                    MediaGuideCard(guide: guide)
                }
            }
        } else {
            MediaEmptyCard(
                icon: "doc.text.magnifyingglass",
                title: errorMessage == nil ? MediaCopy.guidesEmptyTitle : MediaCopy.guidesUnavailableTitle,
                errorMessage: errorMessage
            )
        }
    }
}

private struct MediaPodcastSection: View {
    let episodes: [MediaPodcastEpisode]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        if isLoading && episodes.isEmpty {
            MediaLoadingCard(title: MediaCopy.podcastsLoadingTitle)
        } else if !episodes.isEmpty {
            VStack(spacing: 14) {
                ForEach(episodes) { episode in
                    MediaPodcastCard(episode: episode)
                }
            }
        } else {
            MediaEmptyCard(
                icon: "mic.fill",
                title: errorMessage == nil ? MediaCopy.podcastsEmptyTitle : MediaCopy.podcastsUnavailableTitle,
                errorMessage: errorMessage
            )
        }
    }
}

private struct MediaGuideCard: View {
    @Environment(\.openURL) private var openURL

    let guide: MediaGuide

    var body: some View {
        Button {
            guard let destinationURL = guide.destinationURL else { return }
            openURL(destinationURL)
        } label: {
            HStack(spacing: 14) {
                MediaGuideCover(guide: guide)

                VStack(alignment: .leading, spacing: 6) {
                    Text(guide.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Text(guide.summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.78))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let publishedAt = guide.publishedAt {
                        Text(AppDateFormatting.dateString(from: publishedAt, dateStyle: .medium))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black.opacity(0.56))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if guide.destinationURL != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.88))
                        )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.listCardBackground())
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(guide.destinationURL == nil)
    }
}

private struct MediaGuideCover: View {
    let guide: MediaGuide

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.90))

            if let coverURL = guide.coverURL {
                LazyImage(url: coverURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        ProgressView()
                            .tint(.black.opacity(0.6))
                    }
                }
            } else {
                Image(systemName: "map.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        )
    }
}

private struct MediaPodcastCard: View {
    @Environment(\.openURL) private var openURL

    let episode: MediaPodcastEpisode

    var body: some View {
        Button {
            guard let playbackURL = episode.playbackURL else { return }
            openURL(playbackURL)
        } label: {
            HStack(spacing: 14) {
                MediaPodcastCover(episode: episode)

                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Text(episode.summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.78))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let durationText = episode.durationText {
                        Text(durationText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black.opacity(0.56))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if episode.playbackURL != nil {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.88))
                        )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.listCardBackground())
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(episode.playbackURL == nil)
    }
}

private struct MediaPodcastCover: View {
    let episode: MediaPodcastEpisode

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.90))

            if let coverURL = episode.coverURL {
                LazyImage(url: coverURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        ProgressView()
                            .tint(.black.opacity(0.6))
                    }
                }
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        )
    }
}

private struct MediaEmptyCard: View {
    let icon: String
    let title: String
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.90))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.listCardBackground())
    }
}

private struct MediaLoadingCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(.black.opacity(0.7))
                .frame(width: 44, height: 44)

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black.opacity(0.82))

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.listCardBackground())
    }
}

private enum MediaCopy {
    static let guidesEmptyTitle = "Travel guides coming soon!"
    static let guidesUnavailableTitle = "Guides are unavailable"
    static let guidesLoadingTitle = "Loading guides"
    static let podcastsEmptyTitle = "Podcasts coming soon!"
    static let podcastsUnavailableTitle = "Podcasts are unavailable"
    static let podcastsLoadingTitle = "Loading podcasts"
}
