//
//  ProfileSettingsLanguagesSection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation
import SwiftUI

struct ProfileSettingsLanguagesSection: View {

    @Binding var languages: [LanguageEntry]
    @Binding var showAddLanguage: Bool

    private func displayName(for entry: LanguageEntry) -> String {
        LanguageRepository.shared.localizedDisplayName(for: entry.canonicalCode)
    }

    var body: some View {
        SectionCard(title: String(localized: "profile.settings.languages.title")) {

            VStack(spacing: 0) {

                if languages.isEmpty {
                    Text("profile.settings.languages.empty")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(languages.enumerated()), id: \.offset) { index, entry in
                        VStack(spacing: 8) {

                            HStack {
                                Text(displayName(for: entry))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    languages.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }

                            Picker(
                                String(localized: "profile.settings.languages.proficiency"),
                                selection: Binding(
                                    get: { languages[index].proficiency },
                                    set: { languages[index].proficiency = $0 }
                                )
                            ) {
                                ForEach(LanguageProficiency.allCases) { proficiency in
                                    Text(proficiency.label).tag(proficiency.storageValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 14)

                        if index != languages.count - 1 {
                            Divider().opacity(0.18)
                        }
                    }
                }

                Spacer(minLength: 8)

                Button {
                    showAddLanguage = true
                } label: {
                    Label("profile.settings.languages.add", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
