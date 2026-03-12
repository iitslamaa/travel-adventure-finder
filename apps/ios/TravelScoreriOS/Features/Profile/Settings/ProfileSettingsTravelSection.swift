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
        SectionCard(title: "Travel preferences") {

            VStack(spacing: 0) {

                Button {
                    showTravelModeDialog = true
                } label: {
                    HStack(spacing: 12) {
                        Text("Travel mode")
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(travelMode?.label ?? "Not set")
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
                        Text("Travel style")
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(travelStyle?.label ?? "Not set")
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
