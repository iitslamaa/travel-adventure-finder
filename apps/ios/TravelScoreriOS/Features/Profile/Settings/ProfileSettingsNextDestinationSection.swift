//
//  ProfileSettingsNextDestinationSection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation
import SwiftUI

struct ProfileSettingsNextDestinationSection: View {

    let nextDestination: String?
    @Binding var showNextDestinationPicker: Bool

    var body: some View {
        SectionCard {

            Button {
                showNextDestinationPicker = true
            } label: {
                HStack(spacing: 12) {
                    Text("profile.settings.background.next_destination")
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(displayValue)
                        .foregroundStyle(nextDestination == nil ? .secondary : .primary)

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var displayValue: String {
        guard let nextDestination else { return String(localized: "profile.settings.not_set") }

        let upper = nextDestination.uppercased()
        let locale = Locale.autoupdatingCurrent
        let countryName = locale.localizedString(forRegionCode: upper) ?? upper

        return "\(countryName) \(flag(for: upper))"
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
