import SwiftUI
import NukeUI
import Nuke

struct ProfileHeaderView: View {
    let profile: Profile?
    let username: String
    let homeCountryCodes: [String]
    let relationshipState: RelationshipState?
    let onToggleFriend: () -> Void
    let onOpenCountry: (String) -> Void
    @State private var showFavoriteTripsSheet = false
    @State private var showHomeFlagsSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var effectiveState: RelationshipState {
        relationshipState ?? .none
    }

    private var favoriteCountries: [String] {
        profile?.favoriteCountries ?? []
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var headerSpacing: CGFloat {
        isCompactLayout ? 18 : 28
    }

    private var identityColumnWidth: CGFloat {
        isCompactLayout ? 128 : 140
    }

    private var visibleHomeCountryCodes: [String] {
        Array(homeCountryCodes.prefix(3))
    }

    private var showsHomeFlagsOverflow: Bool {
        homeCountryCodes.count > visibleHomeCountryCodes.count
    }

    private var visibleFavoriteCountries: [String] {
        Array(favoriteCountries.prefix(4))
    }

    private var showsFavoriteTripsOverflow: Bool {
        favoriteCountries.count > visibleFavoriteCountries.count
    }

    var body: some View {
        HStack(alignment: .center, spacing: headerSpacing) {

            // LEFT COLUMN — Identity
            VStack(alignment: .center, spacing: 12) {

                avatarView
                    .frame(width: 104, height: 104)

                VStack(alignment: .center, spacing: 6) {

                    Text(profile?.fullName ?? "")
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
            .frame(width: identityColumnWidth)
            .frame(maxHeight: .infinity, alignment: .center)

            // RIGHT COLUMN — Improved countries block (always show fields with fallback)
                VStack(alignment: .leading, spacing: 20) {

                // Current Country
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.black)

                    if let country = profile?.currentCountry,
                       !country.isEmpty {
                        countryLink(code: country)
                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundColor(.black)
                    }
                }

                // Next Destination
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.black)

                    if let destination = profile?.nextDestination,
                       !destination.isEmpty {
                        countryLink(code: destination)
                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundColor(.black)
                    }
                }

                // Favorites
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Favorite trips")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.black)

                        if showsFavoriteTripsOverflow {
                            Button {
                                showFavoriteTripsSheet = true
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.black.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !favoriteCountries.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(visibleFavoriteCountries, id: \.self) { code in
                                Button {
                                    onOpenCountry(code)
                                } label: {
                                    Text(flagEmoji(for: code.uppercased()))
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }

                            if showsFavoriteTripsOverflow {
                                Text("+\(favoriteCountries.count - visibleFavoriteCountries.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundColor(.black)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .center)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Image("profile_header")
                .resizable()
                .scaledToFill()
                .clipped()
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .sheet(isPresented: $showFavoriteTripsSheet) {
            CountryCodesSheet(title: "Favorite Trips", countryCodes: favoriteCountries, onOpenCountry: onOpenCountry)
        }
        .sheet(isPresented: $showHomeFlagsSheet) {
            CountryCodesSheet(title: "Home Flags", countryCodes: homeCountryCodes, onOpenCountry: onOpenCountry)
        }
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
            return "Add Friend"
        case .requestSent:
            return "Request Sent"
        case .requestReceived:
            return "Accept"
        case .friends:
            return "Friends"
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
            return "USA"
        case "GB":
            return "UK"
        case "PS":
            return "Palestine"
        case "AE":
            return "UAE"
        case "CD":
            return "DRC"
        case "CF":
            return "CAR"
        default:
            break
        }
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forRegionCode: upper) ?? upper
    }

    private func countryLink(code: String) -> some View {
        Button {
            onOpenCountry(code)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(countryName(for: code))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
                    .multilineTextAlignment(.leading)
                    .layoutPriority(1)

                Text(flagEmoji(for: code))
                    .font(.system(size: 18))
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            return "USA"
        case "GB":
            return "UK"
        case "PS":
            return "Palestine"
        case "AE":
            return "UAE"
        case "CD":
            return "DRC"
        case "CF":
            return "CAR"
        default:
            return Locale(identifier: "en_US").localizedString(forRegionCode: upper) ?? upper
        }
    }
}
