import SwiftUI

struct ProfileTravelSnapshotCard: View {
    let currentCountry: String?
    let nextDestination: String?
    let favoriteCountries: [String]
    let onOpenCountry: (String) -> Void

    private let favoriteColumns = [
        GridItem(.adaptive(minimum: 132), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 12) {
                snapshotRow(
                    title: "Currently In",
                    code: currentCountry,
                    emptyText: "No current country yet"
                )

                snapshotRow(
                    title: "Next Stop",
                    code: nextDestination,
                    emptyText: "No next destination yet"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Favorite Countries")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)

                if favoriteCountries.isEmpty {
                    Text("No favorites picked yet")
                        .font(.subheadline)
                        .foregroundStyle(.black.opacity(0.72))
                } else {
                    LazyVGrid(columns: favoriteColumns, alignment: .leading, spacing: 10) {
                        ForEach(Array(Set(favoriteCountries.map { $0.uppercased() })).sorted(), id: \.self) { code in
                            Button {
                                onOpenCountry(code)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(flagEmoji(for: code))
                                        .font(.title3)

                                    Text(countryName(for: code))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.black)
                                        .lineLimit(1)

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.56))
                                )
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
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 88, alignment: .leading)

            if let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    onOpenCountry(code.uppercased())
                } label: {
                    HStack(spacing: 8) {
                        Text(flagEmoji(for: code))
                            .font(.title3)

                        Text(countryName(for: code))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.56))
                    )
                }
                .buttonStyle(.plain)
            } else {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
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
