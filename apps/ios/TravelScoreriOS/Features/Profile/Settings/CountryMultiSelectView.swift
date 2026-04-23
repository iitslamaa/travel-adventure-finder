//
//  CountryMultiSelectView.swift
//  TravelScoreriOS
//

import SwiftUI

struct CountryMultiSelectView: View {
    let title: String
    let subtitle: String?
    @Binding var selection: Set<String>
    let excludedCodes: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var hasChanges = false

    private let initialSelection: Set<String>

    init(
        title: String,
        subtitle: String? = nil,
        selection: Binding<Set<String>>,
        excludedCodes: Set<String> = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.initialSelection = selection.wrappedValue
        self.excludedCodes = Set(excludedCodes.map { $0.uppercased() })
    }

    private let countries: [(code: String, name: String)] =
        Locale.Region.isoRegions
            .compactMap { region -> (String, String)? in
                let code = region.identifier.uppercased()
                guard code.count == 2, code.allSatisfy(\.isLetter) else { return nil }
                let name = Locale.current.localizedString(forRegionCode: code)
                return name.map { (code, $0) }
            }
            .sorted { $0.1 < $1.1 }

    private var selectedCountries: [(code: String, name: String)] {
        countries
            .filter { selection.contains($0.code) && !excludedCodes.contains($0.code.uppercased()) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                }

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
                    if !selectedCountries.isEmpty {
                        Section("Selected") {
                            ForEach(selectedCountries, id: \.code) { country in
                                Button {
                                    toggleSelection(country.code)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(countryCodeToFlag(country.code))
                                            .font(.title3)

                                        Text(country.name)

                                        Spacer()

                                        Image(systemName: "checkmark")
                                    }
                                    .padding(.vertical, 8)
                                }
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

                                if selection.contains(country.code) {
                                    Image(systemName: "checkmark")
                                }
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
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(hasChanges ? .blue : .secondary)
                    .disabled(!hasChanges)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        selection = initialSelection
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredCountries: [(code: String, name: String)] {
        let visibleCountries = countries.filter { !excludedCodes.contains($0.code.uppercased()) }
        let unselectedCountries = visibleCountries.filter { !selection.contains($0.code) }

        guard !searchText.isEmpty else { return unselectedCountries }
        let normalizedSearch = searchText.normalizedSearchKey
        return unselectedCountries.filter {
            $0.name.normalizedSearchKey.contains(normalizedSearch)
        }
    }

    private func toggleSelection(_ code: String) {
        if selection.contains(code) {
            selection.remove(code)
        } else {
            selection.insert(code)
        }
        hasChanges = selection != initialSelection
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
