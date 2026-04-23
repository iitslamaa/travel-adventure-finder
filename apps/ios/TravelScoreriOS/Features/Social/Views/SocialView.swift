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

                VStack(spacing: 16) {
                    actionButtonRow(contentWidth: contentWidth)
                        .frame(width: contentWidth)
                        .padding(.top, max(geo.safeAreaInsets.top - 12, 12))

                    ScrollView {
                        activitySection
                            .frame(width: contentWidth)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, max(floatingTabBarInset + 24, 112))
                    }
                    .refreshable {
                        SocialFeedDebug.log("view.refresh.start user=\(userId)")
                        await feedVM.loadFeed(for: userId, source: "pull-to-refresh")
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: userId) {
            SocialFeedDebug.log("view.task.initial user=\(userId)")
            await feedVM.loadFeed(for: userId, source: "initial-task")
        }
        .onReceive(NotificationCenter.default.publisher(for: .socialActivityUpdated)) { _ in
            SocialFeedDebug.log("view.notification.received name=socialActivityUpdated user=\(userId)")
            Task {
                SocialFeedDebug.log("view.notification.task.start name=socialActivityUpdated user=\(userId)")
                await feedVM.loadFeed(for: userId, source: "social-activity-updated")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendshipUpdated)) { _ in
            SocialFeedDebug.log("view.notification.received name=friendshipUpdated user=\(userId)")
            Task {
                SocialFeedDebug.log("view.notification.task.start name=friendshipUpdated user=\(userId)")
                await feedVM.loadFeed(for: userId, source: "friendship-updated")
            }
        }
    }

    private func socialHorizontalInset(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<390:
            return 30
        case ..<430:
            return 28
        case ..<520:
            return 26
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
                Label(localizedString("social.activity.title", defaultValue: "Activity"), systemImage: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                if feedVM.isLoading, !feedVM.events.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if feedVM.isLoading && feedVM.events.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)

                    Text(localizedString("social.activity.empty.loading", defaultValue: "Loading friend activity"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.74))
                }
                .frame(maxWidth: .infinity, minHeight: 156)
                .background(Theme.listCardBackground(corner: 20))
            } else if feedVM.events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        feedVM.hasAttemptedLoad
                            ? localizedString("social.activity.empty.none", defaultValue: "No recent friend activity yet")
                            : localizedString("social.activity.empty.loading", defaultValue: "Loading friend activity")
                    )
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)

                    Text(
                        localizedString(
                            "social.activity.empty.description",
                            defaultValue: "When friends update travel lists, favorite countries, destinations, or profile details, those updates will appear here."
                        )
                    )
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.listCardBackground(corner: 20))
            } else {
                VStack(spacing: 2) {
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

    private func actionButtonRow(contentWidth: CGFloat) -> some View {
        let buttonSize = max(floor((contentWidth - 24) / 3), 1)

        return HStack(spacing: 12) {
            socialActionButton(
                icon: "person.2.fill",
                title: String(localized: "friends.title")
            ) {
                socialNav.push(.friends(userId))
            }

            socialActionButton(
                icon: "person.crop.circle.badge.plus",
                title: localizedString("social.requests.short", defaultValue: "Requests")
            ) {
                socialNav.push(.friendRequests)
            }

            socialActionButton(
                icon: "person.crop.circle",
                title: String(localized: "profile.title")
            ) {
                socialNav.push(.profile(userId))
            }
        }
        .frame(width: contentWidth, alignment: .center)
        .frame(height: buttonSize)
    }

    private func socialActionButton(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.92))
                    )

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(Theme.listCardBackground(corner: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func activityRow(for event: SocialActivityEvent) -> some View {
        Button {
            socialNav.push(.profile(event.actorUserId))
        } label: {
            HStack(spacing: 12) {
                avatarView(for: event.actorProfile)

                VStack(alignment: .leading, spacing: 4) {
                    Text(activityEyebrow(for: event))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.5))

                    Text(activityText(for: event))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(activityTimestamp(for: event.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.62))
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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

    private func activityText(for event: SocialActivityEvent) -> String {
        let country = countryDisplayName(for: event)
        let destination = destinationDisplayName(for: event)
        let fallbackCountry = localizedString("social.activity.fallback.country", defaultValue: "Somewhere new")
        let fallbackUpdated = localizedString("social.activity.fallback.updated", defaultValue: "Updated")

        switch event.eventType {
        case .bucketListAdded:
            return localizedFormat(
                "social.activity.bucket_list_format",
                defaultValue: "Added %@%@ to their bucket list",
                country ?? fallbackCountry,
                flagSuffix(for: event)
            )
        case .countryVisited:
            return localizedFormat(
                "social.activity.visited_format",
                defaultValue: "Visited %@%@",
                country ?? fallbackCountry,
                flagSuffix(for: event)
            )
        case .nextDestinationChanged:
            return localizedFormat(
                "social.activity.next_format",
                defaultValue: "Going Next: %@%@",
                destination ?? country ?? fallbackCountry,
                flagSuffix(for: event)
            )
        case .profilePhotoUpdated:
            return localizedString("social.activity.profile_photo_updated", defaultValue: "Updated their profile photo")
        case .currentCountryChanged:
            return localizedFormat(
                "social.activity.current_country_format",
                defaultValue: "Currently In: %@%@",
                country ?? fallbackCountry,
                flagSuffix(for: event)
            )
        case .homeCountryChanged:
            return localizedFormat(
                "social.activity.home_country_format",
                defaultValue: "Updated home country to %@%@",
                country ?? fallbackUpdated,
                flagSuffix(for: event)
            )
        case .favoriteCountryAdded:
            return localizedFormat(
                "social.activity.favorite_country_format",
                defaultValue: "Added %@%@ to favorite countries",
                country ?? fallbackCountry,
                flagSuffix(for: event)
            )
        }
    }

    private func activityEyebrow(for event: SocialActivityEvent) -> String {
        let username = usernameText(for: event.actorProfile)
        guard !username.isEmpty else {
            return localizedFormat(
                "social.activity.eyebrow.no_username_format",
                defaultValue: "%@ Update",
                activityEmoji(for: event)
            )
        }

        return localizedFormat(
            "social.activity.eyebrow.username_format",
            defaultValue: "%@ Update · %@",
            activityEmoji(for: event),
            username
        )
    }

    private func usernameText(for profile: Profile?) -> String {
        if let username = profile?.username.trimmingCharacters(in: .whitespacesAndNewlines),
           !username.isEmpty {
            return "@\(username)"
        }

        return ""
    }

    private func activityTimestamp(for date: Date) -> String {
        let elapsed = max(Date().timeIntervalSince(date), 0)

        if elapsed < 7 * 24 * 60 * 60 {
            return Self.relativeTimestampFormatter.localizedString(for: date, relativeTo: Date())
        }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func activityEmoji(for event: SocialActivityEvent) -> String {
        switch event.eventType {
        case .bucketListAdded:
            return "📝"
        case .countryVisited:
            return "✅"
        case .nextDestinationChanged:
            return "✈️"
        case .profilePhotoUpdated:
            return "📸"
        case .currentCountryChanged:
            return "📍"
        case .homeCountryChanged:
            return "📍"
        case .favoriteCountryAdded:
            return "⭐️"
        }
    }

    private func countryDisplayName(for event: SocialActivityEvent) -> String? {
        if let countryName = event.metadata["country_name"]?.stringValue,
           !countryName.isEmpty {
            return countryName
        }

        guard let countryCode = event.metadata["country_code"]?.stringValue
            ?? event.metadata["country"]?.stringValue
        else { return nil }

        let code = countryCode.uppercased()
        let name = Locale.current.localizedString(forRegionCode: code) ?? code
        return name
    }

    private func destinationDisplayName(for event: SocialActivityEvent) -> String? {
        if let destinationName = event.metadata["destination_name"]?.stringValue,
           !destinationName.isEmpty {
            return destinationName
        }

        guard let destination = event.metadata["destination"]?.stringValue else {
            return countryDisplayName(for: event)
        }

        let code = destination.uppercased()
        let name = Locale.current.localizedString(forRegionCode: code) ?? destination
        return name
    }

    private func flagSuffix(for event: SocialActivityEvent) -> String {
        guard let countryCode = event.metadata["country_code"]?.stringValue
            ?? event.metadata["country"]?.stringValue
            ?? event.metadata["destination"]?.stringValue
        else { return "" }

        let flag = flag(for: countryCode)
        guard !flag.isEmpty else { return "" }

        return "\u{00A0}\(flag)"
    }

    private func flag(for code: String) -> String {
        let upper = code.uppercased()
        guard upper.count == 2, upper.allSatisfy(\.isLetter) else { return "" }

        let base: UInt32 = 127397
        let flag = upper.unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()

        return flag
    }

    private func localizedString(_ key: String, defaultValue: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: defaultValue, comment: "")
    }

    private func localizedFormat(_ key: String, defaultValue: String, _ arguments: CVarArg...) -> String {
        String(
            format: localizedString(key, defaultValue: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }

    private static let relativeTimestampFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
