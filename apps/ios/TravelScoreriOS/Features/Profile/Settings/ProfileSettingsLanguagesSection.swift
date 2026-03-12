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
        LanguageRepository.shared.allLanguages
            .first(where: { $0.code == entry.name })?
            .displayName
            ?? entry.name
    }

    var body: some View {
        SectionCard(title: "Languages spoken") {

            VStack(spacing: 0) {

                if languages.isEmpty {
                    Text("Add languages you speak or are learning")
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
                                "Proficiency",
                                selection: Binding(
                                    get: { languages[index].proficiency },
                                    set: { languages[index].proficiency = $0 }
                                )
                            ) {
                                Text("Beginner").tag("Beginner")
                                Text("Conversational").tag("Conversational")
                                Text("Fluent").tag("Fluent")
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
                    Label("Add language", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
