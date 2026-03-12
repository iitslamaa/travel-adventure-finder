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

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

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
        guard !searchText.isEmpty else { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
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
