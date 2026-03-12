//
//  CountryVisaCard.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation
import SwiftUI

struct CountryVisaCard: View {
    let country: Country
    let weightPercentage: Int

    var body: some View {
        if country.visaEaseScore != nil || country.visaType != nil {
            VStack(alignment: .leading, spacing: 12) {

                // Title row
                HStack {
                    Text("Visa")
                        .font(.headline)
                    Spacer()
                    Text("US passport · \(weightPercentage)%")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Score pill + description
                HStack(spacing: 12) {
                    if let ease = country.visaEaseScore {
                        Text("\(ease)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(CountryScoreStyling.backgroundColor(for: country.visaEaseScore))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(CountryScoreStyling.borderColor(for: country.visaEaseScore), lineWidth: 1)
                            )
                    } else {
                        Text("—")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.gray.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(CountryVisaHelpers.headline(for: country))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(CountryVisaHelpers.body(for: country))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Details rows
                VStack(alignment: .leading, spacing: 4) {
                    if let type = country.visaType {
                        Text("Type: \(type.replacingOccurrences(of: "_", with: " ").capitalized)")
                    }

                    if let days = country.visaAllowedDays {
                        Text("Allowed stay: up to \(days) days")
                    }

                    if let fee = country.visaFeeUsd {
                        Text(String(format: "Approx. fee: $%.0f USD", fee))
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)


                if let url = country.visaSourceUrl {
                    Link("View official visa source", destination: url)
                        .font(.footnote)
                }

                HStack(spacing: 12) {
                    if let ease = country.visaEaseScore {
                        Text("Normalized: \(ease)")
                    }
                    Text("Weight: \(weightPercentage)%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.countryDetailCardBackground(corner: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
