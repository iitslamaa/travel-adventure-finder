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
    let isLoading: Bool
    let passportLabel: String
    let recommendedPassportLabel: String?
    let equalBestPassportLabels: [String]
    let showPassportRecommendation: Bool
    let showsPassportSetupPrompt: Bool
    let onOpenPassportSettings: () -> Void

    private var equalBestPassportText: String? {
        guard recommendedPassportLabel == nil else { return nil }
        let labels = equalBestPassportLabels

        guard labels.count >= 2 else { return nil }

        if labels.count == 2 {
            return String(format: String(localized: "country_detail.visa.either_passport_format"), locale: AppDisplayLocale.current, labels[0], labels[1])
        }

        let allButLast = labels.dropLast().joined(separator: ", ")
        return String(format: String(localized: "country_detail.visa.any_passport_format"), locale: AppDisplayLocale.current, allButLast, labels.last ?? "")
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
        if isLoading {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("country_detail.visa.title")
                        .font(.headline)
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }

                Text("Matching visa guidance to your passport...")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("We are loading your saved passport details so this advice is accurate the first time it appears.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.countryDetailCardBackground(corner: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if showsPassportSetupPrompt {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("country_detail.visa.title")
                        .font(.headline)
                    Spacer()
                    Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.visa.passport_weight_format"), locale: AppDisplayLocale.current, "Passport needed", weightPercentage)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("Add a passport to personalize visa guidance")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Visa access depends on the passport you travel with. Add one in Profile Settings to see accurate visa rules and visa-based scoring.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onOpenPassportSettings) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.78))
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Open passport settings")
                                .font(.system(size: 14))
                                .foregroundStyle(.black)

                            Text("Add your passport to unlock personalized visa access for this destination.")
                                .font(.system(size: 13))
                                .foregroundStyle(.black.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black.opacity(0.5))
                            .padding(.top, 4)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.countryDetailCardBackground(corner: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if country.visaEaseScore != nil || country.visaType != nil {
            VStack(alignment: .leading, spacing: 12) {

                // Title row
                HStack {
                    Text("country_detail.visa.title")
                        .font(.headline)
                    Spacer()
                    Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.visa.passport_weight_format"), locale: AppDisplayLocale.current, passportLabel, weightPercentage)))
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
                           let recommendedPassport = recommendedPassportLabel,
                           !recommendedPassport.isEmpty {
                            Text(String(format: String(localized: "country_detail.visa.recommended_passport_format"), locale: AppDisplayLocale.current, recommendedPassport))
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
                        Text(String(format: String(localized: "country_detail.visa.type_format"), locale: AppDisplayLocale.current, formattedVisaType(type)))
                    }

                    if let days = country.visaAllowedDays {
                        Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.visa.allowed_stay_format"), locale: AppDisplayLocale.current, days)))
                    }

                    if let fee = country.visaFeeUsd {
                        Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.visa.approx_fee_format"), locale: AppDisplayLocale.current, fee)))
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
                        Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.visa.normalized_format"), locale: AppDisplayLocale.current, ease)))
                    }
                    Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.visa.weight_format"), locale: AppDisplayLocale.current, weightPercentage)))
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
