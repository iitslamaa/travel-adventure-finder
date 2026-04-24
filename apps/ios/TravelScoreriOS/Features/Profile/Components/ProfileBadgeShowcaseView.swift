import SwiftUI

struct ProfileBadge: Identifiable, Hashable {
    let id: String
    let emoji: String?
    let assetNames: [String]
    let labelText: String?
    let title: String
    let subtitle: String
    let tint: Color
}

private struct ProfileTravelRank {
    let title: String
    let start: Int
    let nextThreshold: Int?
    let tint: Color
}

enum ProfileBadgeCatalog {
    private static let milestoneThresholds = [5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200]

    static func badges(for visitedCountryCodes: [String]) -> [ProfileBadge] {
        let normalizedCodes = Array(
            Set(
                visitedCountryCodes.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                }
            )
        )
        .filter { !$0.isEmpty }
        .sorted()

        let visitedCount = normalizedCodes.count
        var badges: [ProfileBadge] = []

        if visitedCount >= 2 {
            badges.append(
                ProfileBadge(
                    id: "milestone-2-first",
                    emoji: "👶",
                    assetNames: [],
                    labelText: nil,
                    title: "Travel Newbie",
                    subtitle: "Visited your second country",
                    tint: Color(red: 0.89, green: 0.55, blue: 0.26)
                )
            )
        }

        for threshold in milestoneThresholds where visitedCount >= threshold {
            badges.append(
                ProfileBadge(
                    id: "milestone-\(threshold)",
                    emoji: milestoneEmoji(for: threshold),
                    assetNames: [],
                    labelText: milestoneLabel(for: threshold),
                    title: threshold == 100 ? "100 Club" : "\(threshold) Countries",
                    subtitle: "Visited \(threshold) countries",
                    tint: milestoneTint(for: threshold)
                )
            )
        }

        badges.append(contentsOf: continentBadges(for: normalizedCodes))

        if let allCountriesCount = CountryAPI.loadCachedCountries()?.count,
           allCountriesCount > 0,
           visitedCount >= allCountriesCount {
            badges.append(
                ProfileBadge(
                    id: "milestone-all-countries",
                    emoji: "🌍",
                    assetNames: [],
                    labelText: nil,
                    title: "Every Country",
                    subtitle: "Visited every country in the app",
                    tint: Color(red: 0.18, green: 0.52, blue: 0.39)
                )
            )
        }

        return badges
    }

    private static func milestoneEmoji(for threshold: Int) -> String? {
        nil
    }

    private static func milestoneLabel(for threshold: Int) -> String? {
        switch threshold {
        case 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200:
            return "\(threshold)"
        default:
            return nil
        }
    }

    private static func milestoneTint(for threshold: Int) -> Color {
        switch threshold {
        case 2...9:
            return Color(red: 0.90, green: 0.57, blue: 0.25)
        case 10...49:
            return Color(red: 0.20, green: 0.53, blue: 0.87)
        case 50...99:
            return Color(red: 0.55, green: 0.36, blue: 0.84)
        default:
            return Color(red: 0.17, green: 0.59, blue: 0.43)
        }
    }

    private static func continentBadges(for countryCodes: [String]) -> [ProfileBadge] {
        guard let countries = CountryAPI.loadCachedCountries() else { return [] }

        let countriesByCode = Dictionary(uniqueKeysWithValues: countries.map { ($0.iso2.uppercased(), $0) })
        let visitedContinents = Set(countryCodes.compactMap { code -> String? in
            guard let country = countriesByCode[code] else { return nil }
            return canonicalContinent(region: country.region, subregion: country.subregion)
        })

        return visitedContinents
            .sorted()
            .compactMap { continent in
                guard let presentation = continentPresentation(for: continent) else { return nil }
                return ProfileBadge(
                    id: "continent-\(continent.lowercased())",
                    emoji: nil,
                    assetNames: presentation.assetNames,
                    labelText: nil,
                    title: presentation.title,
                    subtitle: "Been to \(continent)",
                    tint: presentation.tint
                )
            }
    }

    private static func canonicalContinent(region: String?, subregion: String?) -> String? {
        let rawRegion = (region ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSubregion = (subregion ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = (!rawRegion.isEmpty ? rawRegion : rawSubregion)
        guard !raw.isEmpty else { return nil }

        switch raw.lowercased() {
        case "africa":
            return "Africa"
        case "antarctic", "antarctica":
            return "Antarctica"
        case "asia":
            return "Asia"
        case "europe":
            return "Europe"
        case "oceania":
            return "Oceania"
        case "north america", "caribbean", "central america":
            return "North America"
        case "south america":
            return "South America"
        case "americas":
            switch rawSubregion.lowercased() {
            case "south america":
                return "South America"
            case "caribbean", "central america", "north america":
                return "North America"
            default:
                return "North America"
            }
        case "latin america and the caribbean":
            return "North America"
        default:
            return nil
        }
    }

    private static func continentPresentation(for continent: String) -> (title: String, assetNames: [String], tint: Color)? {
        switch continent {
        case "Africa":
            return ("Africa Explorer", ["badge-continent-africa"], Color(red: 0.82, green: 0.47, blue: 0.16))
        case "North America":
            return ("North America Explorer", ["badge-continent-north-america"], Color(red: 0.21, green: 0.57, blue: 0.44))
        case "South America":
            return ("South America Explorer", ["badge-continent-south-america"], Color(red: 0.18, green: 0.63, blue: 0.49))
        case "Antarctica":
            return ("Polar Passport", ["badge-continent-antarctica"], Color(red: 0.34, green: 0.59, blue: 0.86))
        case "Asia":
            return ("Asia Explorer", ["badge-continent-asia"], Color(red: 0.77, green: 0.34, blue: 0.44))
        case "Europe":
            return ("Europe Explorer", ["badge-continent-europe"], Color(red: 0.27, green: 0.43, blue: 0.83))
        case "Oceania":
            return ("Oceania Explorer", ["badge-continent-oceania"], Color(red: 0.14, green: 0.60, blue: 0.78))
        default:
            return nil
        }
    }
}

struct ProfileBadgeShowcaseView: View {
    let badges: [ProfileBadge]
    let visitedCountryCount: Int
    let onSelectBadge: (ProfileBadge) -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var featuredBadges: [ProfileBadge] {
        Array(badges.prefix(12))
    }

    private var totalCountryCount: Int {
        CountryAPI.loadCachedCountries()?.count ?? 220
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var badgeSize: CGFloat {
        isCompactLayout ? 36 : 44
    }

    private var badgeSpacing: CGFloat {
        isCompactLayout ? 8 : 10
    }

    private var countFontSize: CGFloat {
        isCompactLayout ? 18 : 22
    }

    private var badgeColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(badgeSize), spacing: badgeSpacing), count: isCompactLayout ? 4 : 6)
    }

    private var hasGoldBadgeState: Bool {
        visitedCountryCount >= 100
    }

    private var goldBadgeTint: Color {
        Color(red: 0.84, green: 0.67, blue: 0.20)
    }

    private var travelRank: ProfileTravelRank {
        switch visitedCountryCount {
        case ..<5:
            return ProfileTravelRank(
                title: "Travel Newbie",
                start: 0,
                nextThreshold: 5,
                tint: Color(red: 0.89, green: 0.55, blue: 0.26)
            )
        case 5..<20:
            return ProfileTravelRank(
                title: "Passport Starter",
                start: 5,
                nextThreshold: 20,
                tint: Color(red: 0.84, green: 0.63, blue: 0.26)
            )
        case 20..<40:
            return ProfileTravelRank(
                title: "Frequent Flyer",
                start: 20,
                nextThreshold: 40,
                tint: Color(red: 0.25, green: 0.55, blue: 0.87)
            )
        case 40..<60:
            return ProfileTravelRank(
                title: "World Hopper",
                start: 40,
                nextThreshold: 60,
                tint: Color(red: 0.21, green: 0.59, blue: 0.53)
            )
        case 60..<100:
            return ProfileTravelRank(
                title: "Global Explorer",
                start: 60,
                nextThreshold: 100,
                tint: Color(red: 0.48, green: 0.39, blue: 0.84)
            )
        default:
            return ProfileTravelRank(
                title: "100 Club",
                start: 100,
                nextThreshold: nil,
                tint: goldBadgeTint
            )
        }
    }

    private var rankProgress: Double {
        guard let nextThreshold = travelRank.nextThreshold else { return 1 }
        let span = max(nextThreshold - travelRank.start, 1)
        let progress = Double(visitedCountryCount - travelRank.start) / Double(span)
        return min(max(progress, 0), 1)
    }

    private var countriesUntilNextRank: Int? {
        guard let nextThreshold = travelRank.nextThreshold else { return nil }
        return max(nextThreshold - visitedCountryCount, 0)
    }

    var body: some View {
        VStack(alignment: .center, spacing: isCompactLayout ? 10 : 12) {
            VStack(alignment: .center, spacing: 6) {
                Text(travelRank.title)
                    .font(.system(size: isCompactLayout ? 13 : 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if travelRank.nextThreshold != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.black.opacity(0.14))

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                travelRank.tint.opacity(0.98),
                                                travelRank.tint.opacity(0.72)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(proxy.size.width * rankProgress, 8))
                            }
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.52), lineWidth: 0.8)
                            )
                        }
                        .frame(width: isCompactLayout ? 132 : 168, height: 8)

                        if let countriesUntilNextRank {
                            Text("\(countriesUntilNextRank) to next rank")
                                .font(.system(size: isCompactLayout ? 10 : 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black.opacity(0.66))
                        }
                    }
                }
            }

            Text("\(visitedCountryCount)/\(totalCountryCount)")
                .font(.system(size: countFontSize, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, isCompactLayout ? 10 : 12)
                .padding(.vertical, isCompactLayout ? 6 : 7)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.60))
                )

            if featuredBadges.isEmpty {
                Text("✨")
                    .font(.system(size: 24))
                    .frame(width: badgeSize, height: badgeSize)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.52))
                    )
            } else {
                LazyVGrid(columns: badgeColumns, alignment: .leading, spacing: badgeSpacing) {
                    ForEach(featuredBadges) { badge in
                        badgeButton(badge)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, isCompactLayout ? 4 : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func badgeButton(_ badge: ProfileBadge) -> some View {
        Button {
            onSelectBadge(badge)
        } label: {
            badgeArtwork(for: badge)
                .frame(width: badgeSize, height: badgeSize)
                .background(
                    Circle()
                        .fill(displayTint(for: badge).opacity(hasGoldBadgeState ? 0.32 : 0.18))
                )
                .overlay(
                    Circle()
                        .stroke(
                            hasGoldBadgeState ? displayTint(for: badge).opacity(0.72) : Color.white.opacity(0.72),
                            lineWidth: hasGoldBadgeState ? 1.4 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: hasGoldBadgeState ? displayTint(for: badge).opacity(0.24) : .clear, radius: 5, y: 2)
    }

    @ViewBuilder
    private func badgeArtwork(for badge: ProfileBadge) -> some View {
        if let labelText = badge.labelText {
            Text(labelText)
                .font(.system(size: isCompactLayout ? 13 : 15, weight: .black, design: .rounded))
                .foregroundStyle(artworkForegroundStyle)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        } else if badge.assetNames.isEmpty {
            Text(badge.emoji ?? "✨")
                .font(.system(size: isCompactLayout ? 18 : 22))
                .foregroundStyle(artworkForegroundStyle)
        } else if badge.assetNames.count == 1, let assetName = badge.assetNames.first {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(artworkForegroundStyle)
                .padding(isCompactLayout ? 7 : 8)
        } else {
            HStack(spacing: 1) {
                ForEach(badge.assetNames, id: \.self) { assetName in
                    Image(assetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: badgeSize * 0.32, height: badgeSize * 0.32)
                        .foregroundStyle(artworkForegroundStyle)
                }
            }
        }
    }

    private func displayTint(for badge: ProfileBadge) -> Color {
        hasGoldBadgeState ? goldBadgeTint : badge.tint
    }

    private var artworkForegroundStyle: Color {
        hasGoldBadgeState ? Color(red: 0.38, green: 0.25, blue: 0.04) : Color.black.opacity(0.84)
    }
}
