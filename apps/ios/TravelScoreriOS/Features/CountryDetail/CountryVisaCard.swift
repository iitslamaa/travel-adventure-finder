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
    let passportLabel: String
    let showPassportRecommendation: Bool

    private var equalBestPassportText: String? {
        guard country.visaRecommendedPassportLabel == nil else { return nil }
        guard let passportLabel = country.visaPassportLabel, passportLabel.contains(" / ") else { return nil }

        let labels = passportLabel
            .components(separatedBy: " / ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard labels.count >= 2 else { return nil }

        if labels.count == 2 {
            return "Either \(labels[0]) or \(labels[1]) is fine here."
        }

        let allButLast = labels.dropLast().joined(separator: ", ")
        return "Any of \(allButLast), or \(labels.last ?? "") are fine here."
    }

    private func formattedVisaType(_ type: String) -> String {
        switch type {
        case "own_passport":
            return "Own passport"
        case "freedom_of_movement":
            return "Freedom of movement"
        case "visa_free":
            return "Visa free"
        case "visa_required":
            return "Visa required"
        case "entry_permit":
            return "Entry permit"
        default:
            return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var body: some View {
        if country.visaEaseScore != nil || country.visaType != nil {
            VStack(alignment: .leading, spacing: 12) {

                // Title row
                HStack {
                    Text("Visa")
                        .font(.headline)
                    Spacer()
                    Text("\(passportLabel) passport · \(weightPercentage)%")
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
                        Text(CountryVisaHelpers.headline(for: country, passportLabel: passportLabel))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if showPassportRecommendation,
                           let recommendedPassport = country.visaRecommendedPassportLabel,
                           !recommendedPassport.isEmpty {
                            Text("Recommended passport: \(recommendedPassport)")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        } else if showPassportRecommendation,
                                  let equalBestPassportText {
                            Text(equalBestPassportText)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }

                        Text(CountryVisaHelpers.body(for: country, passportLabel: passportLabel))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Details rows
                VStack(alignment: .leading, spacing: 4) {
                    if let type = country.visaType {
                        Text("Type: \(formattedVisaType(type))")
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
