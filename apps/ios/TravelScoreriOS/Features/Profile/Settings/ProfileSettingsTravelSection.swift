//
//  ProfileSettingsTravelSection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation
import SwiftUI

struct ProfileSettingsTravelSection: View {

    @Binding var travelMode: TravelMode?
    @Binding var travelStyle: TravelStyle?

    @Binding var showTravelModeDialog: Bool
    @Binding var showTravelStyleDialog: Bool

    var body: some View {
        SectionCard(title: String(localized: "profile.settings.travel.title")) {
            VStack(spacing: 0) {
                Button {
                    showTravelModeDialog = true
                } label: {
                    HStack(spacing: 12) {
                        Text("profile.settings.travel.mode")
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(travelMode?.label ?? String(localized: "profile.settings.not_set"))
                            .foregroundStyle(travelMode == nil ? .secondary : .primary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .opacity(0.18)

                Button {
                    showTravelStyleDialog = true
                } label: {
                    HStack(spacing: 12) {
                        Text("profile.settings.travel.style")
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(travelStyle?.label ?? String(localized: "profile.settings.not_set"))
                            .foregroundStyle(travelStyle == nil ? .secondary : .primary)

                        Image(systemName: "chevron.up.chevron.down")
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
}
