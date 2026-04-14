//
//  CountrySingleSelectView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/26/26.
//

import SwiftUI

struct CountrySingleSelectView: View {
    let title: String
    @Binding var selection: String?
    let allowedCodes: Set<String>?
    let excludedCodes: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var draftSelection: String?
    @State private var hasChanges = false

    private let initialSelection: String?

    init(
        title: String,
        selection: Binding<String?>,
        allowedCodes: Set<String>? = nil,
        excludedCodes: Set<String> = []
    ) {
        self.title = title
        self._selection = selection
        self.initialSelection = selection.wrappedValue
        self._draftSelection = State(initialValue: selection.wrappedValue)
        self.allowedCodes = allowedCodes
        self.excludedCodes = Set(excludedCodes.map { $0.uppercased() })
    }

    private let countries: [(code: String, name: String)] =
        Locale.Region.isoRegions
            .compactMap { region -> (String, String)? in
                let code = region.identifier
                let name = Locale.current.localizedString(forRegionCode: code)
                return name.map { (code, $0) }
            }
            .sorted { $0.1 < $1.1 }

    private var selectedCountry: (code: String, name: String)? {
        guard let draftSelection else { return nil }
        return countries.first { $0.code == draftSelection }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("profile.settings.search_countries", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)

                List {
                    if let selectedCountry {
                        Section("Selected") {
                            Button {
                                toggleSelection(selectedCountry.code)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(countryCodeToFlag(selectedCountry.code))
                                        .font(.title3)

                                    Text(selectedCountry.name)

                                    Spacer()

                                    Image(systemName: "checkmark")
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    ForEach(filteredCountries, id: \.code) { country in
                        Button {
                            toggleSelection(country.code)
                        } label: {
                            HStack(spacing: 12) {
                                Text(countryCodeToFlag(country.code))
                                    .font(.title3)

                                Text(country.name)

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        selection = draftSelection
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(hasChanges ? .blue : .secondary)
                    .disabled(!hasChanges)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        draftSelection = initialSelection
                        selection = initialSelection
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredCountries: [(code: String, name: String)] {
        let baseCountries: [(code: String, name: String)] = {
            let visibleCountries = countries.filter { !excludedCodes.contains($0.code.uppercased()) }

            guard let allowedCodes, !allowedCodes.isEmpty else { return visibleCountries }
            return visibleCountries.filter { allowedCodes.contains($0.code.uppercased()) }
        }()
        let unselectedCountries = baseCountries.filter { $0.code != draftSelection }

        guard !searchText.isEmpty else { return unselectedCountries }
        let normalizedSearch = searchText.normalizedSearchKey
        return unselectedCountries.filter {
            $0.name.normalizedSearchKey.contains(normalizedSearch)
        }
    }

    private func toggleSelection(_ code: String) {
        if draftSelection == code {
            draftSelection = nil
        } else {
            draftSelection = code
        }

        hasChanges = draftSelection != initialSelection
    }

    private func countryCodeToFlag(_ code: String) -> String {
        guard code.count == 2 else { return code }
        let base: UInt32 = 127397
        return code.unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }
}
