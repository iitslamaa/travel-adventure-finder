//
//  CountryHeaderCard.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation
import SwiftUI

struct CountryHeaderCard: View {
    let country: Country

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(country.flagEmoji)
                .font(.system(size: 60))

            VStack(alignment: .leading, spacing: 6) {
                Text(country.name)
                    .font(.title2)
                    .bold()

                if let regionLabel = country.regionLabel {
                    Text(regionLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let score = country.score {
                Text("\(score)")
                    .font(.title2.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(CountryScoreStyling.backgroundColor(for: score))
                    )
                    .overlay(
                        Capsule()
                            .stroke(CountryScoreStyling.borderColor(for: score), lineWidth: 1)
                    )
            } else {
                Text("—")
                    .font(.title2.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.countryDetailCardBackground(corner: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
