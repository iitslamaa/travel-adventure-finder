//
//  ProfileInfoSection.swift
//  TravelScoreriOS
//

import Foundation
import SwiftUI

struct ProfileInfoSection: View {

    let relationshipState: RelationshipState
    let viewedTraveledCountries: Set<String>
    let viewedBucketListCountries: Set<String>
    let orderedTraveledCountries: [String]
    let orderedBucketListCountries: [String]
    let mutualTraveledCountries: [String]
    let mutualBucketCountries: [String]
    let mutualLanguages: [String]
    let languages: [String]
    let travelMode: String?
    let travelStyle: String?
    let nextDestination: String?
    let currentCountry: String?
    let favoriteCountries: [String]
    let onOpenCountry: (String) -> Void
    @State private var expandedCountrySectionID: String? = nil

    var body: some View {
        LazyVStack(spacing: 32) {
            travelSnapshotSection
            languagesSection

            if relationshipState == .friends && !mutualLanguages.isEmpty {
                sharedLanguagesSection
            }

            combinedPreferencesSection

            countriesSection
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .background(sectionBackground)
    }

    private var travelSnapshotSection: some View {
        card(imageScale: 1.1, imageAnchor: .topLeading) {
            ProfileTravelSnapshotCard(
                currentCountry: currentCountry,
                nextDestination: nextDestination,
                favoriteCountries: favoriteCountries,
                onOpenCountry: onOpenCountry
            )
        }
    }

    // MARK: - Languages

    private var languagesSection: some View {
        card(imageScale: 1.18, imageAnchor: .trailing) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(String(localized: "profile.info.languages"))

                if languages.isEmpty {
                    secondaryText(String(localized: "profile.settings.not_set"))
                } else {
                    VStack(spacing: 14) {
                        ForEach(languages, id: \.self) { language in
                            languageRow(language)
                        }
                    }
                }
            }
        }
    }

    private var sharedLanguagesSection: some View {
        card(imageScale: 1.18, imageAnchor: .trailing) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(String(localized: "profile.info.shared_languages"))

                VStack(spacing: 14) {
                    ForEach(mutualLanguages, id: \.self) { language in
                        sharedLanguageRow(language)
                    }
                }
            }
        }
    }

    // MARK: - Preferences

    private var combinedPreferencesSection: some View {
        card(imageScale: 1.18, imageAnchor: .trailing) {
            VStack(spacing: 18) {

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("profile.settings.travel.mode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)

                        if let travelMode, !travelMode.isEmpty {
                            Text(travelMode)
                                .font(.subheadline)
                                .foregroundColor(.black)
                        } else {
                            Text("profile.settings.not_set")
                                .font(.subheadline)
                                .foregroundColor(.black)
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("profile.settings.travel.style")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)

                        if let travelStyle, !travelStyle.isEmpty {
                            Text(travelStyle)
                                .font(.subheadline)
                                .foregroundColor(.black)
                        } else {
                            Text("profile.settings.not_set")
                                .font(.subheadline)
                                .foregroundColor(.black)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Countries

    private var countriesSection: some View {
        VStack(spacing: 16) {

            if relationshipState == .selfProfile {

                CollapsibleCountrySection(
                    sectionID: "countries_traveled_self",
                    title: String(localized: "profile.info.countries_traveled"),
                    countryCodes: orderedTraveledCountries,
                    highlightColor: .gold,
                    isExpanded: expandedCountrySectionID == "countries_traveled_self",
                    onToggle: { toggleCountrySection("countries_traveled_self") }
                )

                CollapsibleCountrySection(
                    sectionID: "bucket_list_self",
                    title: String(localized: "profile.info.bucket_list"),
                    countryCodes: orderedBucketListCountries,
                    highlightColor: .blue,
                    isExpanded: expandedCountrySectionID == "bucket_list_self",
                    onToggle: { toggleCountrySection("bucket_list_self") }
                )

            } else if relationshipState == .friends {

                CollapsibleCountrySection(
                    sectionID: "countries_traveled_friends",
                    title: String(localized: "profile.info.countries_traveled"),
                    countryCodes: orderedTraveledCountries,
                    highlightColor: .gold,
                    mutualCountries: Set(mutualTraveledCountries),
                    isExpanded: expandedCountrySectionID == "countries_traveled_friends",
                    onToggle: { toggleCountrySection("countries_traveled_friends") }
                )

                CollapsibleCountrySection(
                    sectionID: "bucket_list_friends",
                    title: String(localized: "profile.info.bucket_list"),
                    countryCodes: orderedBucketListCountries,
                    highlightColor: .blue,
                    mutualCountries: Set(mutualBucketCountries),
                    isExpanded: expandedCountrySectionID == "bucket_list_friends",
                    onToggle: { toggleCountrySection("bucket_list_friends") }
                )

            } else {
                lockedProfileMessage
            }
        }
    }

    // MARK: - Reusable Components

    private func card<Content: View>(
        imageScale: CGFloat = 1,
        imageAnchor: UnitPoint = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.vertical, 22)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                innerCardBackground(
                    corner: 24,
                    imageScale: imageScale,
                    imageAnchor: imageAnchor
                )
            )
    }

    private func innerCardBackground(
        corner: CGFloat,
        imageScale: CGFloat = 1,
        imageAnchor: UnitPoint = .center
    ) -> some View {
        GeometryReader { proxy in
            ZStack {
                Image("profile_header")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(imageScale, anchor: imageAnchor)
                    .clipped()

                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.white.opacity(0.18))
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
            .allowsHitTesting(false)
        }
    }

    private var sectionBackground: some View {
        GeometryReader { proxy in
            ZStack {
                Image("profile_info")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .saturation(0.82)
                    .brightness(0.04)
                    .clipped()

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.92, blue: 0.82).opacity(0.34))
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
            .allowsHitTesting(false)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.black)
    }

    private func secondaryText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.black)
    }

    private func toggleCountrySection(_ sectionID: String) {
        if expandedCountrySectionID == sectionID {
            expandedCountrySectionID = nil
        } else {
            expandedCountrySectionID = sectionID
        }
    }

    private func languageRow(_ text: String) -> some View {
        let components = text.split(separator: "—").map { $0.trimmingCharacters(in: .whitespaces) }

        return HStack {
            Text(components.first ?? "")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black)

            Spacer()

            if components.count > 1 {
                Text(components[1])
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
        }
    }

    private func sharedLanguageRow(_ text: String) -> some View {
        let components = text.split(separator: "—").map { $0.trimmingCharacters(in: .whitespaces) }

        return HStack {
            Text(components.first ?? "")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black)

            Spacer()

            if components.count > 1 {
                Text(components[1])
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text(value)
                .font(.subheadline)
                .lineLimit(1)
        }
    }

    private var subtleDivider: some View {
        Divider()
            .opacity(0.08)
    }

    // MARK: - Helpers

    private func formattedCountry(_ code: String) -> String {
        let upper = code.uppercased()
        return "\(countryName(for: upper)) \(flagEmoji(for: upper))"
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

    private var lockedProfileMessage: some View {
        card {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundColor(.black)

                Text("profile.info.locked_message")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
