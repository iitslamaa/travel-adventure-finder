//
//  DiscoveryControlsView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/26/26.
//

import Foundation
import SwiftUI

struct DiscoveryControlsView: View {

    @Binding var sort: CountrySort
    @Binding var sortOrder: SortOrder

    var body: some View {
        HStack(spacing: 12) {

            // Primary segmented control
            Picker("discovery.controls.sort", selection: $sort) {
                ForEach(CountrySort.allCases, id: \.self) { s in
                    Text(s.localizedTitle).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 2)
    }
}
