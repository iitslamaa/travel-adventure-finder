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

    @Environment(\.colorScheme) private var colorScheme

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
        .padding(.bottom, 48)
    }

    // MARK: - Languages

    private var languagesSection: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Languages")

                if languages.isEmpty {
                    secondaryText("Not set")
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
                sectionHeader("Shared Languages")

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
                        Text("Travel Mode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)

                        if let travelMode, !travelMode.isEmpty {
                            Text(travelMode)
                                .font(.subheadline)
                                .foregroundColor(.black)
                        } else {
                            Text("Not set")
                                .font(.subheadline)
                                .foregroundColor(.black)
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Travel Style")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)

                        if let travelStyle, !travelStyle.isEmpty {
                            Text(travelStyle)
                                .font(.subheadline)
                                .foregroundColor(.black)
                        } else {
                            Text("Not set")
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
                    title: "Countries Traveled",
                    countryCodes: orderedTraveledCountries,
                    highlightColor: .gold
                )

                CollapsibleCountrySection(
                    title: "Bucket List",
                    countryCodes: orderedBucketListCountries,
                    highlightColor: .blue
                )

            } else if relationshipState == .friends {

                CollapsibleCountrySection(
                    title: "Countries Traveled",
                    countryCodes: orderedTraveledCountries,
                    highlightColor: .gold,
                    mutualCountries: Set(mutualTraveledCountries)
                )

                CollapsibleCountrySection(
                    title: "Bucket List",
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
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.95, blue: 0.90))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05), lineWidth: 1)
            )
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
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forRegionCode: upper) ?? upper
    }

    private var lockedProfileMessage: some View {
        card {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundColor(.black)

                Text("Add this user as a friend to see more details.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
