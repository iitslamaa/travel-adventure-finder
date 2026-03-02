import SwiftUI
import NukeUI
import Nuke

struct ProfileHeaderView: View {
    private let instanceId = UUID()
    let profile: Profile?
    let username: String
    let homeCountryCodes: [String]
    let relationshipState: RelationshipState?
    let friendCount: Int
    let onToggleFriend: () -> Void

    private var effectiveState: RelationshipState {
        relationshipState ?? .none
    }

    var body: some View {
        let _ = print("🧾 ProfileHeaderView BODY — instance:", instanceId,
                      " profile.id:", profile?.id as Any,
                      " relationshipState:", relationshipState as Any,
                      " effectiveState:", effectiveState,
                      " friendCount:", friendCount)
        HStack(alignment: .top, spacing: 24) {

            // LEFT COLUMN — Identity
            VStack(alignment: .center, spacing: 12) {

                avatarView
                    .frame(width: 104, height: 104)

                VStack(alignment: .center, spacing: 6) {

                    Text(profile?.fullName ?? "")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    if !username.isEmpty {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if !homeCountryCodes.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(homeCountryCodes, id: \.self) { code in
                                Text(flagEmoji(for: code))
                                    .font(.title3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if effectiveState != .selfProfile {

                        Button(action: {
                            print("🔘 Friend button tapped — instance:", instanceId,
                                  " profile.id:", profile?.id as Any,
                                  " currentState:", effectiveState,
                                  " friendCount:", friendCount)
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
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(backgroundColor(for: effectiveState))
                            )
                            .foregroundStyle(foregroundColor(for: effectiveState))
                        }
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .frame(width: 140)

            // RIGHT COLUMN — Improved countries block (always show fields with fallback)
            VStack(alignment: .leading, spacing: 20) {

                // Current Country
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let country = profile?.currentCountry,
                       !country.isEmpty {
                        Text(formattedCountry(country))
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Next Destination
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let destination = profile?.nextDestination,
                       !destination.isEmpty {
                        Text(formattedCountry(destination))
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Favorites
                VStack(alignment: .leading, spacing: 4) {
                    Text("Favorite trips")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let favorites = profile?.favoriteCountries,
                       !favorites.isEmpty {

                        let visible = Array(favorites.prefix(10))
                        let remaining = favorites.count - visible.count

                        HStack(spacing: 6) {
                            ForEach(visible, id: \.self) { code in
                                Text(flagEmoji(for: code.uppercased()))
                                    .font(.title3)
                            }

                            if remaining > 0 {
                                Text("+\(remaining)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                    } else {
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .onChange(of: profile?.id) { oldValue, newValue in
            print("🔁 ProfileHeaderView profile.id changed — instance:", instanceId,
                  " old:", oldValue as Any,
                  " new:", newValue as Any)
        }
        .onChange(of: relationshipState) { oldValue, newValue in
            print("🔁 ProfileHeaderView relationshipState changed — instance:", instanceId,
                  " old:", oldValue as Any,
                  " new:", newValue as Any)
        }
        .onChange(of: friendCount) { oldValue, newValue in
            print("🔁 ProfileHeaderView friendCount changed — instance:", instanceId,
                  " old:", oldValue,
                  " new:", newValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
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
                            .foregroundStyle(.gray)
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
                    .foregroundStyle(.gray)
            }
        }
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 3)
        )
        .shadow(radius: 6)
    }

    private func buttonLabel(for state: RelationshipState) -> String {
        switch state {
        case .none:
            return "Add Friend"
        case .requestSent:
            return "Request Sent"
        case .requestReceived:
            return "Accept"
        case .friends:
            return friendCount == 1 ? "1 Friend" : "\(friendCount) Friends"
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

    private func formattedCountry(_ code: String) -> String {
        let upper = code.uppercased()
        let locale = Locale(identifier: "en_US")
        let name = locale.localizedString(forRegionCode: upper) ?? upper
        return "\(name) \(flagEmoji(for: upper))"
    }
}
