//
//  AddLanguageView.swift
//  TravelScoreriOS
//

import SwiftUI

struct AddLanguageView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    let selectedLanguages: [LanguageEntry]
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

    private var selectedLanguageEntries: [LanguageEntry] {
        selectedLanguages.sorted {
            LanguageRepository.shared.localizedDisplayName(for: $0.canonicalCode)
                < LanguageRepository.shared.localizedDisplayName(for: $1.canonicalCode)
        }
    }

    private var availableLanguages: [AppLanguage] {
        let selectedCodes = Set(selectedLanguages.map(\.canonicalCode))
        return languages.filter { language in
            let canonicalCode = LanguageRepository.shared.canonicalLanguageCode(for: language.travelLanguageCode)
                ?? language.travelLanguageCode
            return !selectedCodes.contains(canonicalCode)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !selectedLanguageEntries.isEmpty {
                    Section("Selected") {
                        ForEach(selectedLanguageEntries) { entry in
                            HStack {
                                Text(LanguageRepository.shared.localizedDisplayName(for: entry.canonicalCode))
                                Spacer()
                                Text(LanguageProficiency(storageValue: entry.proficiency).label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                ForEach(availableLanguages) { language in
                    Button {
                        onSelect(
                            LanguageEntry(
                                name: language.travelLanguageCode,
                                proficiency: LanguageProficiency.fluent.storageValue
                            )
                        )
                        dismiss()
                    } label: {
                        Text(LanguageRepository.shared.localizedDisplayName(for: language.travelLanguageCode))
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle(String(localized: "profile.settings.languages.select"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
            }
        }
    }
}
