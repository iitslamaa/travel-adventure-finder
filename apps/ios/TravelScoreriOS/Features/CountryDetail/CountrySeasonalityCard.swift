//
//  CountrySeasonalityCard.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation
import SwiftUI

struct CountrySeasonalityCard: View {
    @EnvironmentObject private var weightsStore: ScoreWeightsStore
    let country: Country
    let weightPercentage: Int

    var body: some View {
        let displayedSeasonalityScore = country.resolvedSeasonalityScore(for: weightsStore.selectedMonth)
        let selectedMonthName = CountrySeasonalityHelpers.fullMonthName(for: weightsStore.selectedMonth)

        VStack(alignment: .leading, spacing: 12) {

            // Title row
            HStack {
                Text(String(format: String(localized: "country_detail.seasonality.title_format"), locale: Locale.current, selectedMonthName))
                    .font(.headline)
                Spacer()
                Text(String(format: String(localized: "country_detail.seasonality.month_weight_format"), locale: Locale.current, weightsStore.selectedMonthShortName, weightPercentage))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Score pill + description
            HStack(spacing: 12) {
                if let seasonalityScore = displayedSeasonalityScore {
                    Text(AppNumberFormatting.integerString(seasonalityScore))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(CountryScoreStyling.backgroundColor(for: seasonalityScore))
                        )
                        .overlay(
                            Capsule()
                                .stroke(CountryScoreStyling.borderColor(for: seasonalityScore), lineWidth: 1)
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
                    Text(CountrySeasonalityHelpers.headline(for: country, selectedMonth: weightsStore.selectedMonth))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(CountrySeasonalityHelpers.body(for: country, selectedMonth: weightsStore.selectedMonth))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Best months chips
            if let months = country.seasonalityBestMonths, !months.isEmpty {
                HStack(spacing: 6) {
                    Text("country_detail.seasonality.best_months")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(months, id: \.self) { month in
                        Text(CountrySeasonalityHelpers.shortMonthName(for: month))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                }
            }

            HStack(spacing: 12) {
                if let seasonalityScore = displayedSeasonalityScore {
                    Text(String(format: String(localized: "country_detail.seasonality.normalized_format"), locale: Locale.current, seasonalityScore))
                }
                Text(String(format: String(localized: "country_detail.seasonality.weight_format"), locale: Locale.current, weightPercentage))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("country_detail.seasonality.footer")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.countryDetailCardBackground(corner: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
