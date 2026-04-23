import SwiftUI
import NukeUI
import Nuke

struct SocialView: View {
    @EnvironmentObject private var socialNav: SocialNavigationController
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset

    let userId: UUID

    @StateObject private var feedVM = SocialFeedViewModel()

    var body: some View {
        GeometryReader { geo in
            let contentWidth = socialContentWidth(for: geo.size.width)

            ZStack {
                Theme.pageBackground("travel3")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Theme.titleBanner("Social")

                    ScrollView {
                        VStack(spacing: 14) {
                            actionButtonRow
                            activitySection
                        }
                        .frame(width: contentWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, max(floatingTabBarInset + 24, 112))
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: userId) {
            await feedVM.loadFeed(for: userId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendshipUpdated)) { _ in
            Task {
                await feedVM.loadFeed(for: userId)
            }
        }
    }

    private func socialHorizontalInset(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<390:
            return 42
        case ..<430:
            return 38
        case ..<520:
            return 32
        default:
            return max((width - 680) / 2, 32)
        }
    }

    private func socialContentWidth(for width: CGFloat) -> CGFloat {
        max(width - (socialHorizontalInset(for: width) * 2), 0)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Activity", systemImage: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                if feedVM.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if feedVM.events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(feedVM.hasAttemptedLoad ? "No recent friend activity yet" : "Loading friend activity")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)

                    Text("When friends update travel lists, destinations, or profile details, those lightweight updates will appear here.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.listCardBackground(corner: 20))
            } else {
                VStack(spacing: 10) {
                    ForEach(feedVM.events) { event in
                        activityRow(for: event)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.10), radius: 10, y: 6)
    }

    private var actionButtonRow: some View {
        HStack(spacing: 10) {
            socialActionButton(
                icon: "person.2.fill",
                title: "Friends"
            ) {
                socialNav.push(.friends(userId))
            }

            socialActionButton(
                icon: "person.crop.circle.badge.plus",
                title: "Requests"
            ) {
                socialNav.push(.friendRequests)
            }

            socialActionButton(
                icon: "person.crop.circle",
                title: "Profile"
            ) {
                socialNav.push(.profile(userId))
            }
        }
    }

    private func socialActionButton(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.92))
                    )

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(10)
            .background(Theme.listCardBackground(corner: 22))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func activityRow(for event: SocialActivityEvent) -> some View {
        HStack(spacing: 12) {
            avatarView(for: event.actorProfile)

            VStack(alignment: .leading, spacing: 4) {
                Text(activityTitle(for: event))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)

                Text(event.createdAt, style: .relative)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.62))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.listCardBackground(corner: 20))
    }

    private func avatarView(for profile: Profile?) -> some View {
        Group {
            if let urlString = profile?.avatarUrl,
               let url = URL(string: urlString) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .foregroundStyle(.gray)
                    }
                }
                .processors([
                    ImageProcessors.Resize(size: CGSize(width: 88, height: 88))
                ])
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.black.opacity(0.35))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private func activityTitle(for event: SocialActivityEvent) -> String {
        let name = event.actorProfile?.firstName ?? event.actorProfile?.username ?? "A friend"
        let country = event.metadata["country_name"]?.stringValue
            ?? event.metadata["country"]?.stringValue
            ?? event.metadata["country_code"]?.stringValue
        let destination = event.metadata["destination_name"]?.stringValue
            ?? event.metadata["destination"]?.stringValue

        switch event.eventType {
        case .bucketListAdded:
            return "\(name) added \(country ?? "a country") to their bucket list"
        case .countryVisited:
            return "\(name) marked \(country ?? "a country") as visited"
        case .nextDestinationChanged:
            return "\(name) changed their next destination to \(destination ?? country ?? "somewhere new")"
        case .profilePhotoUpdated:
            return "\(name) updated their profile photo"
        case .currentCountryChanged:
            return "\(name) changed their current country to \(country ?? "somewhere new")"
        case .homeCountryChanged:
            return "\(name) updated their home country"
        }
    }
}
