import SwiftUI
import NukeUI
import Nuke

struct ProfileHeaderView: View {
    let profile: Profile?
    let username: String
    let homeCountryCodes: [String]
    let visitedCountryCodes: [String]
    let relationshipState: RelationshipState?
    let onToggleFriend: () -> Void
    let onOpenCountry: (String) -> Void
    @State private var showHomeFlagsSheet = false
    @State private var selectedBadge: ProfileBadge?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var effectiveState: RelationshipState {
        relationshipState ?? .none
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var headerSpacing: CGFloat {
        isCompactLayout ? 8 : 16
    }

    private var identityColumnWidth: CGFloat {
        isCompactLayout ? 112 : 140
    }

    private var badgeRailWidth: CGFloat {
        isCompactLayout ? 152 : 210
    }

    private var visibleHomeCountryCodes: [String] {
        Array(homeCountryCodes.prefix(3))
    }

    private var showsHomeFlagsOverflow: Bool {
        homeCountryCodes.count > visibleHomeCountryCodes.count
    }

    private var earnedBadges: [ProfileBadge] {
        ProfileBadgeCatalog.badges(for: visitedCountryCodes)
    }

    private var hasGoldBadgeState: Bool {
        visitedCountryCodes.count >= 100
    }

    private var goldBadgeTint: Color {
        Color(red: 0.84, green: 0.67, blue: 0.20)
    }

    var body: some View {
        HStack(alignment: .center, spacing: headerSpacing) {
            identitySection
                .frame(width: identityColumnWidth)

            ProfileBadgeShowcaseView(
                badges: earnedBadges,
                visitedCountryCount: visitedCountryCodes.count,
                onSelectBadge: presentBadgeToast
            )
            .frame(width: badgeRailWidth, alignment: .center)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(headerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .overlay(alignment: .bottomTrailing) {
            if let selectedBadge {
                badgeToast(selectedBadge)
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedBadge?.id)
        .sheet(isPresented: $showHomeFlagsSheet) {
            CountryCodesSheet(title: String(localized: "profile.header.home_flags"), countryCodes: homeCountryCodes, onOpenCountry: onOpenCountry)
        }
    }

    private var identitySection: some View {
        VStack(alignment: .center, spacing: 12) {
            avatarView
                .frame(width: 104, height: 104)

            VStack(alignment: .center, spacing: 6) {
                Text(profile?.formattedFullName ?? "")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)

                if effectiveState != .selfProfile, !username.isEmpty {
                    ctaButton
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if !username.isEmpty {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                }

                if !homeCountryCodes.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(visibleHomeCountryCodes, id: \.self) { code in
                            Button {
                                onOpenCountry(code)
                            } label: {
                                Text(flagEmoji(for: code))
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }

                        if showsHomeFlagsOverflow {
                            Button {
                                showHomeFlagsSheet = true
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.black.opacity(0.65))
                            }
                            .buttonStyle(.plain)

                            if homeCountryCodes.count - visibleHomeCountryCodes.count > 0 {
                                Text("+\(homeCountryCodes.count - visibleHomeCountryCodes.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var headerBackground: some View {
        GeometryReader { proxy in
            ZStack {
                if let urlString = profile?.avatarUrl,
                   let url = URL(string: urlString) {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color(red: 0.90, green: 0.87, blue: 0.82)
                        }
                    }
                    .processors([
                        ImageProcessors.Resize(size: CGSize(width: 1600, height: 1200))
                    ])
                    .priority(.high)
                    .frame(
                        width: proxy.size.width * 2.05,
                        height: proxy.size.height * 1.75
                    )
                    .offset(x: -proxy.size.width * 0.36, y: -proxy.size.height * 0.24)
                } else {
                    Image("profile_header")
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: proxy.size.width * 1.45,
                            height: proxy.size.height * 1.2
                        )
                        .offset(x: proxy.size.width * 0.3)
                }

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.34),
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private func presentBadgeToast(_ badge: ProfileBadge) {
        selectedBadge = badge

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            if selectedBadge?.id == badge.id {
                selectedBadge = nil
            }
        }
    }

    private func badgeToast(_ badge: ProfileBadge) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if let labelText = badge.labelText {
                    Text(labelText)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(badgeArtworkForegroundStyle)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                } else if badge.assetNames.isEmpty {
                    Text(badge.emoji ?? "✨")
                        .font(.system(size: 22))
                        .foregroundStyle(badgeArtworkForegroundStyle)
                } else if badge.assetNames.count == 1, let assetName = badge.assetNames.first {
                    Image(assetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(badgeArtworkForegroundStyle)
                        .padding(5)
                } else {
                    HStack(spacing: 2) {
                        ForEach(badge.assetNames, id: \.self) { assetName in
                            Image(assetName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(badgeArtworkForegroundStyle)
                        }
                    }
                }
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black)

                Text(badge.subtitle)
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(displayTint(for: badge).opacity(hasGoldBadgeState ? 0.62 : 0.34), lineWidth: hasGoldBadgeState ? 1.3 : 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }

    private func displayTint(for badge: ProfileBadge) -> Color {
        hasGoldBadgeState ? goldBadgeTint : badge.tint
    }

    private var badgeArtworkForegroundStyle: Color {
        hasGoldBadgeState ? Color(red: 0.38, green: 0.25, blue: 0.04) : Color.black.opacity(0.84)
    }

    private var ctaButton: some View {
        Button(action: {
            onToggleFriend()
        }) {
            HStack(spacing: 6) {
                switch effectiveState {
                case .friends:
                    Image(systemName: "checkmark")
                case .requestSent:
                    Image(systemName: "clock")
                case .requestReceived:
                    Image(systemName: "checkmark.circle.fill")
                case .none:
                    Image(systemName: "person.badge.plus")
                case .selfProfile:
                    EmptyView()
                }

                Text(buttonLabel(for: effectiveState))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(backgroundColor(for: effectiveState))
            )
            .foregroundStyle(foregroundColor(for: effectiveState))
        }
        .padding(.top, 2)
    }

    // MARK: - Avatar

    private var avatarView: some View {
        Group {
            if let urlString = profile?.avatarUrl,
               let url = URL(string: urlString) {

                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if state.error != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .foregroundColor(.black)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                            ProgressView()
                        }
                    }
                }
                .processors([
                    ImageProcessors.Resize(size: CGSize(width: 300, height: 300))
                ])
                .priority(.high)

            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundColor(.black)
            }
        }
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.white.opacity(0.8), lineWidth: 3)
        )
        .shadow(radius: 6)
    }

    private func buttonLabel(for state: RelationshipState) -> String {
        if !username.isEmpty {
            return "@\(username)"
        }

        switch state {
        case .none:
            return String(localized: "profile.header.add_friend")
        case .requestSent:
            return String(localized: "profile.header.request_sent")
        case .requestReceived:
            return String(localized: "profile.header.accept")
        case .friends:
            return String(localized: "friends.section.title")
        case .selfProfile:
            return ""
        }
    }

    private func backgroundColor(for state: RelationshipState) -> Color {
        switch state {
        case .none:
            return Color.blue.opacity(0.12)
        case .requestSent:
            return Color.gray.opacity(0.15)
        case .requestReceived:
            return Color.green.opacity(0.18)
        case .friends:
            return Color.blue.opacity(0.18)
        case .selfProfile:
            return .clear
        }
    }

    private func foregroundColor(for state: RelationshipState) -> Color {
        switch state {
        case .requestSent:
            return .gray
        case .requestReceived:
            return .green
        default:
            return .blue
        }
    }

    private func flagEmoji(for countryCode: String) -> String {
        countryCode
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }

    private func countryName(for code: String) -> String {
        let upper = code.uppercased()
        switch upper {
        case "US":
            return String(localized: "country.short.us")
        case "GB":
            return String(localized: "country.short.gb")
        case "PS":
            return String(localized: "country.short.ps")
        case "AE":
            return String(localized: "country.short.ae")
        case "CD":
            return String(localized: "country.short.cd")
        case "CF":
            return String(localized: "country.short.cf")
        default:
            break
        }
        let locale = Locale.autoupdatingCurrent
        return locale.localizedString(forRegionCode: upper) ?? upper
    }

}

private struct CountryCodesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let countryCodes: [String]
    let onOpenCountry: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.pageBackground("travel4")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Theme.titleBanner(title)

                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(countryCodes, id: \.self) { code in
                                Button {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        onOpenCountry(code)
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Text(flagEmoji(for: code))
                                            .font(.title2)

                                        Text(countryName(for: code))
                                            .font(.headline)
                                            .foregroundStyle(.black)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.black.opacity(0.45))
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(red: 0.97, green: 0.95, blue: 0.90).opacity(0.92))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(.white.opacity(0.35), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                    }
                    .background(
                        Image("country-list")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.top, 12)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func flagEmoji(for countryCode: String) -> String {
        countryCode
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }

    private func countryName(for countryCode: String) -> String {
        let upper = countryCode.uppercased()
        switch upper {
        case "US":
            return String(localized: "country.short.us")
        case "GB":
            return String(localized: "country.short.gb")
        case "PS":
            return String(localized: "country.short.ps")
        case "AE":
            return String(localized: "country.short.ae")
        case "CD":
            return String(localized: "country.short.cd")
        case "CF":
            return String(localized: "country.short.cf")
        default:
            return Locale.autoupdatingCurrent.localizedString(forRegionCode: upper) ?? upper
        }
    }
}
