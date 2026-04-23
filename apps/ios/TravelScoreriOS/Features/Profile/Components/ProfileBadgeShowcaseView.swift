import SwiftUI

struct ProfileBadge: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
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
                    title: "Second Stamp",
                    subtitle: "Visited your second country",
                    systemImage: "sparkles",
                    tint: Color(red: 0.89, green: 0.55, blue: 0.26)
                )
            )
        }

        for threshold in milestoneThresholds where visitedCount >= threshold {
            badges.append(
                ProfileBadge(
                    id: "milestone-\(threshold)",
                    title: threshold == 100 ? "100 Club" : "\(threshold) Countries",
                    subtitle: "Visited \(threshold) countries",
                    systemImage: threshold >= 100 ? "globe.americas.fill" : "airplane.circle.fill",
                    tint: milestoneTint(for: threshold)
                )
            )
        }

        let visitedContinents = continentBadges(for: normalizedCodes)
        badges.append(contentsOf: visitedContinents)

        if let allCountriesCount = CountryAPI.loadCachedCountries()?.count,
           allCountriesCount > 0,
           visitedCount >= allCountriesCount {
            badges.append(
                ProfileBadge(
                    id: "milestone-all-countries",
                    title: "Every Country",
                    subtitle: "Visited every country in the app",
                    systemImage: "globe.europe.africa.fill",
                    tint: Color(red: 0.18, green: 0.52, blue: 0.39)
                )
            )
        }

        return badges
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
                    title: presentation.title,
                    subtitle: "Been to \(continent)",
                    systemImage: presentation.systemImage,
                    tint: presentation.tint
                )
            }
    }

    private static func canonicalContinent(region: String?, subregion: String?) -> String? {
        let raw = (region ?? subregion ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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
        case "americas", "north america", "south america", "latin america and the caribbean", "caribbean", "central america":
            return "Americas"
        default:
            return nil
        }
    }

    private static func continentPresentation(for continent: String) -> (title: String, systemImage: String, tint: Color)? {
        switch continent {
        case "Africa":
            return ("Africa Touched", "sun.max.fill", Color(red: 0.82, green: 0.47, blue: 0.16))
        case "Americas":
            return ("Americas Touched", "globe.americas.fill", Color(red: 0.21, green: 0.57, blue: 0.44))
        case "Antarctica":
            return ("Polar Passport", "snowflake", Color(red: 0.34, green: 0.59, blue: 0.86))
        case "Asia":
            return ("Asia Touched", "sparkles", Color(red: 0.77, green: 0.34, blue: 0.44))
        case "Europe":
            return ("Europe Touched", "building.columns.fill", Color(red: 0.27, green: 0.43, blue: 0.83))
        case "Oceania":
            return ("Oceania Touched", "water.waves", Color(red: 0.14, green: 0.60, blue: 0.78))
        default:
            return nil
        }
    }
}

struct ProfileBadgeShowcaseView: View {
    let badges: [ProfileBadge]
    let visitedCountryCount: Int

    private var featuredBadges: [ProfileBadge] {
        Array(badges.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Passport shelf")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.black)

                    if badges.isEmpty {
                        Text(visitedCountryCount == 1 ? "One more country unlocks your first badge." : "Start collecting badges as you travel.")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.72))
                    } else {
                        Text("\(badges.count) badge\(badges.count == 1 ? "" : "s") unlocked")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.72))
                    }
                }

                Spacer()

                Text("\(visitedCountryCount)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.64))
                    )
            }

            if featuredBadges.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(featuredBadges) { badge in
                        ProfileBadgeCard(badge: badge)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.36), lineWidth: 1)
                )
        )
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "seal")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.85, green: 0.50, blue: 0.21))

            VStack(alignment: .leading, spacing: 2) {
                Text("First badge is waiting")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)

                Text("Hit two visited countries to unlock your second-stamp badge.")
                    .font(.footnote)
                    .foregroundStyle(.black.opacity(0.68))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.48))
        )
    }
}

private struct ProfileBadgeCard: View {
    let badge: ProfileBadge

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: badge.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(badge.tint)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(badge.tint.opacity(0.16))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .lineLimit(2)

                Text(badge.subtitle)
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.56))
        )
    }
}
