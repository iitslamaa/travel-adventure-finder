//
//  AddLanguageView.swift
//  TravelScoreriOS
//

import SwiftUI

struct AddLanguageView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    let onSelect: (LanguageEntry) -> Void

    private var languages: [AppLanguage] {
        let filtered = LanguageRepository.shared.allLanguages.filter {
            guard !searchText.isEmpty else { return true }
            return LanguageRepository.shared.matchesSearchQuery(searchText, language: $0)
        }

        var seenTravelCodes: Set<String> = []

        return filtered.compactMap { language in
            let canonicalCode = LanguageRepository.shared.canonicalLanguageCode(for: language.travelLanguageCode)
                ?? language.travelLanguageCode

            guard seenTravelCodes.insert(canonicalCode).inserted else {
                return nil
            }

            return language
        }
    }

    var body: some View {
        NavigationStack {
            List(languages) { language in
                Button {
                    onSelect(
                        LanguageEntry(
                            name: language.travelLanguageCode,
                            proficiency: LanguageProficiency.fluent.storageValue
                        )
                    )
                    dismiss()
                } label: {
                    Text(LanguageRepository.shared.preferredDisplayName(for: language))
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Language")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
