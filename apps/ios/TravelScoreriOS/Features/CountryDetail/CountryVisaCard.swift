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
            return String(format: String(localized: "country_detail.visa.either_passport_format"), locale: Locale.current, labels[0], labels[1])
        }

        let allButLast = labels.dropLast().joined(separator: ", ")
        return String(format: String(localized: "country_detail.visa.any_passport_format"), locale: Locale.current, allButLast, labels.last ?? "")
    }

    private func formattedVisaType(_ type: String) -> String {
        switch type {
        case "own_passport":
            return String(localized: "country_detail.visa.type.own_passport")
        case "freedom_of_movement":
            return String(localized: "country_detail.visa.type.freedom_of_movement")
        case "visa_free":
            return String(localized: "country_detail.visa.type.visa_free")
        case "visa_required":
            return String(localized: "country_detail.visa.type.visa_required")
        case "entry_permit":
            return String(localized: "country_detail.visa.type.entry_permit")
        default:
            return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var body: some View {
        if country.visaEaseScore != nil || country.visaType != nil {
            VStack(alignment: .leading, spacing: 12) {

                // Title row
                HStack {
                    Text("country_detail.visa.title")
                        .font(.headline)
                    Spacer()
                    Text(String(format: String(localized: "country_detail.visa.passport_weight_format"), locale: Locale.current, passportLabel, weightPercentage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Score pill + description
                HStack(spacing: 12) {
                    if let ease = country.visaEaseScore {
                        Text(AppNumberFormatting.integerString(ease))
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
                        Text("common.em_dash")
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
                            Text(String(format: String(localized: "country_detail.visa.recommended_passport_format"), locale: Locale.current, recommendedPassport))
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
                        Text(String(format: String(localized: "country_detail.visa.type_format"), locale: Locale.current, formattedVisaType(type)))
                    }

                    if let days = country.visaAllowedDays {
                        Text(String(format: String(localized: "country_detail.visa.allowed_stay_format"), locale: Locale.current, days))
                    }

                    if let fee = country.visaFeeUsd {
                        Text(String(format: String(localized: "country_detail.visa.approx_fee_format"), locale: Locale.current, fee))
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)


                if let url = country.visaSourceUrl {
                    Link(String(localized: "country_detail.visa.view_official_source"), destination: url)
                        .font(.footnote)
                }

                HStack(spacing: 12) {
                    if let ease = country.visaEaseScore {
                        Text(String(format: String(localized: "country_detail.visa.normalized_format"), locale: Locale.current, ease))
                    }
                    Text(String(format: String(localized: "country_detail.visa.weight_format"), locale: Locale.current, weightPercentage))
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
