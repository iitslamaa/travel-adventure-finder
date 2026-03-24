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

    init(
        title: String,
        selection: Binding<String?>,
        allowedCodes: Set<String>? = nil,
        excludedCodes: Set<String> = []
    ) {
        self.title = title
        self._selection = selection
        self.allowedCodes = allowedCodes
        self.excludedCodes = Set(excludedCodes.map { $0.uppercased() })
    }

    private let countries: [(code: String, name: String)] =
        Locale.isoRegionCodes
            .compactMap { code -> (String, String)? in
                let name = Locale.current.localizedString(forRegionCode: code)
                return name.map { (code, $0) }
            }
            .sorted { $0.1 < $1.1 }

    var body: some View {
        NavigationStack {
            List(filteredCountries, id: \.code) { country in
                Button {
                    selection = country.code
                    dismiss()
                } label: {
                    HStack {
                        Text(countryCodeToFlag(country.code))
                        Text(country.name)
                        Spacer()
                        if selection == country.code {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var filteredCountries: [(code: String, name: String)] {
        let baseCountries: [(code: String, name: String)] = {
            let visibleCountries = countries.filter { !excludedCodes.contains($0.code.uppercased()) }

            guard let allowedCodes, !allowedCodes.isEmpty else { return visibleCountries }
            return visibleCountries.filter { allowedCodes.contains($0.code.uppercased()) }
        }()

        guard !searchText.isEmpty else { return baseCountries }
        let normalizedSearch = searchText.normalizedSearchKey
        return baseCountries.filter {
            $0.name.normalizedSearchKey.contains(normalizedSearch)
        }
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
