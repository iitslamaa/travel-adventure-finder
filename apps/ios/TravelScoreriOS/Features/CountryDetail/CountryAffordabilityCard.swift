//
//  CountryAffordabilityCard.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/23/26.
//

import Foundation
import SwiftUI

struct CountryAffordabilityCard: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let country: Country
    let weightPercentage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Title row
            HStack {
                Text("country_detail.affordability.title")
                    .font(.headline)
                Spacer()
                Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.affordability.estimated_daily_cost_format"), locale: AppDisplayLocale.current, weightPercentage)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Score pill + description
            HStack(spacing: 12) {
                if let affordabilityScore = country.affordabilityScore {
                    Text(AppNumberFormatting.integerString(affordabilityScore))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(CountryScoreStyling.backgroundColor(for: affordabilityScore))
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    CountryScoreStyling.borderColor(for: affordabilityScore),
                                    lineWidth: 1
                                )
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
                    if let headline = country.affordabilityHeadline {
                        Text(headline)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if let body = country.affordabilityBody {
                        Text(body)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Optional daily spend breakdown (if available)
            VStack(alignment: .leading, spacing: 4) {
                if let total = country.dailySpendTotalUsd {
                    Text("Typical daily total: \(currencyPreferenceStore.formatFromUSD(total, maximumFractionDigits: 0))")
                }

                if let hotel = country.dailySpendHotelUsd {
                    Text("Hotel (per night): \(currencyPreferenceStore.formatFromUSD(hotel, maximumFractionDigits: 0))")
                }

                if let food = country.dailySpendFoodUsd {
                    Text("Food (per day): \(currencyPreferenceStore.formatFromUSD(food, maximumFractionDigits: 0))")
                }

                if let activities = country.dailySpendActivitiesUsd {
                    Text("Activities (per day): \(currencyPreferenceStore.formatFromUSD(activities, maximumFractionDigits: 0))")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            // Footer
            HStack(spacing: 12) {
                if let affordabilityScore = country.affordabilityScore {
                    Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.affordability.normalized_format"), locale: AppDisplayLocale.current, affordabilityScore)))
                }
                Text(AppNumberFormatting.localizedDigits(in: String(format: String(localized: "country_detail.affordability.weight_format"), locale: AppDisplayLocale.current, weightPercentage)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("country_detail.affordability.footer")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
