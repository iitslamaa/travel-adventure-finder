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

    var body: some View {
        LazyVStack(spacing: 32) {
            languagesSection

            if relationshipState == .friends && !mutualLanguages.isEmpty {
                sharedLanguagesSection
            }

            combinedPreferencesSection

            countriesSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Languages

    private var languagesSection: some View {
        card {
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
        card {
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
        card {
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
        LazyVStack(spacing: 16) {

            if relationshipState == .selfProfile {

                CollapsibleCountrySection(
                    title: String(localized: "profile.info.countries_traveled"),
                    countryCodes: orderedTraveledCountries,
                    highlightColor: .gold
                )

                CollapsibleCountrySection(
                    title: String(localized: "profile.info.bucket_list"),
                    countryCodes: orderedBucketListCountries,
                    highlightColor: .blue
                )

            } else if relationshipState == .friends {

                CollapsibleCountrySection(
                    title: String(localized: "profile.info.countries_traveled"),
                    countryCodes: orderedTraveledCountries,
                    highlightColor: .gold,
                    mutualCountries: Set(mutualTraveledCountries)
                )

                CollapsibleCountrySection(
                    title: String(localized: "profile.info.bucket_list"),
                    countryCodes: orderedBucketListCountries,
                    highlightColor: .blue,
                    mutualCountries: Set(mutualBucketCountries)
                )

            } else {
                lockedProfileMessage
            }
        }
    }

    // MARK: - Reusable Components

    private func card<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.vertical, 22)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
    }

    private var cardBackground: some View {
        Image("profile_info")
            .resizable(
                capInsets: EdgeInsets(top: 140, leading: 120, bottom: 140, trailing: 120),
                resizingMode: .stretch
            )
            .scaledToFill()
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
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
