//
//  ProfileSettingsAccountSection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation
import SwiftUI

struct ProfileSettingsAccountSection: View {

    @Binding var firstName: String
    @Binding var username: String

    var body: some View {
        SectionCard {
            TextField(
                "",
                text: $firstName,
                prompt:
                    (Text("profile.settings.full_name")
                        .foregroundStyle(.secondary)
                     +
                     Text(" *")
                        .foregroundStyle(.red))
            )
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(.primary)
            .tint(.primary)

            HStack(spacing: 6) {
                Text("@")
                    .font(.body)
                    .foregroundStyle(.secondary)

                TextField(
                    "",
                    text: $username,
                    prompt:
                        (Text("profile.settings.username")
                            .foregroundStyle(.secondary)
                         +
                         Text(" *")
                            .foregroundStyle(.red))
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(.primary)
                .tint(.primary)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
