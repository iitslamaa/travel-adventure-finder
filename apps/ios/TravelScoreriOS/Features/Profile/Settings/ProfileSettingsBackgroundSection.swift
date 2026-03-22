//
//  ProfileSettingsBackgroundSection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation
import SwiftUI

struct ProfileSettingsBackgroundSection: View {

    let homeCountries: Set<String>
    let currentCountry: String?
    let favoriteCountries: [String]
    let nextDestination: String?

    @Binding var showHomePicker: Bool
    @Binding var showCurrentCountryPicker: Bool
    @Binding var showNextDestinationPicker: Bool
    @Binding var showFavoriteCountriesPicker: Bool

    var body: some View {
        SectionCard(title: String(localized: "profile.settings.background.title")) {

            VStack(spacing: 0) {

                // My Flags
                Button {
                    showHomePicker = true
                } label: {
                    HStack(spacing: 12) {
                        Text("profile.settings.background.my_flags")
                            .foregroundStyle(.primary)

                        Spacer()

                        if homeCountries.isEmpty {
                            Text("profile.settings.none")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            HStack(spacing: 6) {
                                ForEach(homeCountries.sorted(), id: \.self) { code in
                                    Text(flag(for: code))
                                }
                            }
                            .font(.subheadline)
                        }

                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().opacity(0.18)

                // Current Country
                Button {
                    showCurrentCountryPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Text("profile.settings.background.current_country")
                            .foregroundStyle(.primary)

                        Spacer()

                        if let currentCountry {
                            let upper = currentCountry.uppercased()
                            HStack(spacing: 6) {
                                Text(flag(for: upper))
                                Text(localizedName(for: upper))
                            }
                            .foregroundStyle(.primary)
                            .font(.subheadline)
                        } else {
                            Text("profile.settings.not_set")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }

                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().opacity(0.18)

                // Next Destination
                Button {
                    showNextDestinationPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Text("profile.settings.background.next_destination")
                            .foregroundStyle(.primary)

                        Spacer()

                        if let nextDestination {
                            let upper = nextDestination.uppercased()
                            HStack(spacing: 6) {
                                Text(flag(for: upper))
                                Text(localizedName(for: upper))
                            }
                            .foregroundStyle(.primary)
                            .font(.subheadline)
                        } else {
                            Text("profile.settings.not_set")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }

                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().opacity(0.18)

                // Favorite Countries
                Button {
                    showFavoriteCountriesPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Text("profile.settings.background.favorite_countries")
                            .foregroundStyle(.primary)

                        Spacer()

                        if favoriteCountries.isEmpty {
                            Text("profile.settings.none")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            HStack(spacing: 6) {
                                ForEach(favoriteCountries.sorted(), id: \.self) { code in
                                    Text(flag(for: code))
                                }
                            }
                            .font(.subheadline)
                        }

                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func localizedName(for code: String) -> String {
        let upper = code.uppercased()
        let locale = Locale.autoupdatingCurrent
        return locale.localizedString(forRegionCode: upper) ?? upper
    }

    private func flag(for code: String) -> String {
        guard code.count == 2 else { return code }
        let base: UInt32 = 127397
        return code.unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}
