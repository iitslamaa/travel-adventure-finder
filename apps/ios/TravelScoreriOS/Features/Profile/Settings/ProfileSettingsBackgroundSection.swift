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
        SectionCard(title: "Your background") {

            VStack(spacing: 0) {

                // My Flags
                Button {
                    showHomePicker = true
                } label: {
                    HStack(spacing: 12) {
                        Text("My flags")
                            .foregroundStyle(.primary)

                        Spacer()

                        if homeCountries.isEmpty {
                            Text("None")
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
                        Text("Current country")
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
                            Text("Not set")
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
                        Text("Next destination")
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
                            Text("Not set")
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
                        Text("Favorite countries")
                            .foregroundStyle(.primary)

                        Spacer()

                        if favoriteCountries.isEmpty {
                            Text("None")
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
        let locale = Locale(identifier: "en_US")
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
