import SwiftUI

private enum ProfileTravelSnapshotLocalized {
    static func string(_ key: String, fallback: String) -> String {
        let localized = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        guard localized != key else {
            return fallback
        }
        return localized
    }
}

struct ProfileTravelSnapshotCard: View {
    let currentCountry: String?
    let nextDestination: String?
    let favoriteCountries: [String]
    let onOpenCountry: (String) -> Void

    private let favoriteColumns = [
        GridItem(.adaptive(minimum: 40, maximum: 46), spacing: 4)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 6) {
                snapshotRow(
                    title: ProfileTravelSnapshotLocalized.string(
                        "profile.travel_snapshot.currently_in",
                        fallback: "Currently in"
                    ),
                    code: currentCountry,
                    emptyText: ProfileTravelSnapshotLocalized.string(
                        "profile.travel_snapshot.no_current_country",
                        fallback: "No current country yet"
                    )
                )

                snapshotRow(
                    title: ProfileTravelSnapshotLocalized.string(
                        "profile.travel_snapshot.next_stop",
                        fallback: "Next stop"
                    ),
                    code: nextDestination,
                    emptyText: ProfileTravelSnapshotLocalized.string(
                        "profile.travel_snapshot.no_next_destination",
                        fallback: "No next destination yet"
                    )
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(
                    verbatim: ProfileTravelSnapshotLocalized.string(
                        "profile.travel_snapshot.favorite_countries",
                        fallback: "Favorite trips"
                    ) + ":"
                )
                    .font(.headline.bold())
                    .foregroundStyle(.black)

                if favoriteCountries.isEmpty {
                    Text(
                        ProfileTravelSnapshotLocalized.string(
                            "profile.travel_snapshot.no_favorites",
                            fallback: "No favorites picked yet"
                        )
                        )
                        .font(.footnote)
                        .foregroundStyle(.black.opacity(0.72))
                } else {
                    LazyVGrid(columns: favoriteColumns, alignment: .leading, spacing: 4) {
                        ForEach(Array(Set(favoriteCountries.map { $0.uppercased() })).sorted(), id: \.self) { code in
                            Button {
                                onOpenCountry(code)
                            } label: {
                                Text(flagEmoji(for: code))
                                    .font(.system(size: 34))
                                    .frame(width: 42, height: 38)
                                    .contentShape(Rectangle())
                                    .accessibilityLabel(countryName(for: code))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func snapshotRow(title: String, code: String?, emptyText: String) -> some View {
        HStack(spacing: 2) {
            Text(verbatim: "\(title):")
                .font(.headline.bold())
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 122, alignment: .leading)

            if let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    onOpenCountry(code.uppercased())
                } label: {
                    HStack(spacing: 5) {
                        Text(flagEmoji(for: code))
                            .font(.system(size: 28))

                        Text(countryName(for: code))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.56))
                    )
                }
                .buttonStyle(.plain)
            } else {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundStyle(.black.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.34))
                    )
            }
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
            break
        }
        let locale = Locale.autoupdatingCurrent
        return locale.localizedString(forRegionCode: upper) ?? upper
    }
}
