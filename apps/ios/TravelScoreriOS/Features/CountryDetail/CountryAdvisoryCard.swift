//
//  CountryAdvisoryCard.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/15/26.
//

import Foundation
import SwiftUI

struct CountryAdvisoryCard: View {
    let country: Country
    let weightPercentage: Int
    @State private var showFullAdvisory = false

    private var advisoryLevel: Int? {
        guard let advisoryScore = country.advisoryScore else { return nil }
        switch advisoryScore {
        case 88...: return 1
        case 63...: return 2
        case 38...: return 3
        default: return 4
        }
    }

    var body: some View {
        if let advisoryScore = country.advisoryScore {
            VStack(alignment: .leading, spacing: 12) {

                // Title row
                HStack {
                    Text("country_detail.advisory.title")
                        .font(.headline)
                    Spacer()
                    Text(String(format: String(localized: "country_detail.advisory.source_weight_format"), locale: AppDisplayLocale.current, weightPercentage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Score pill + description
                HStack(spacing: 12) {

                    Text(AppNumberFormatting.integerString(advisoryScore))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(CountryScoreStyling.backgroundColor(for: advisoryScore))
                        )
                        .overlay(
                            Capsule()
                                .stroke(CountryScoreStyling.borderColor(for: advisoryScore), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        let advisoryText = CountryTextHelpers.advisorySummary(level: advisoryLevel)

                        if !advisoryText.isEmpty {
                            Text(advisoryText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(showFullAdvisory ? nil : 3)
                                .fixedSize(horizontal: false, vertical: true)

                            if advisoryText.count > 200 {
                                Button {
                                    withAnimation {
                                        showFullAdvisory.toggle()
                                    }
                                } label: {
                                    Text(showFullAdvisory ? String(localized: "common.show_less") : String(localized: "common.show_more"))
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                if let updated = country.advisoryUpdatedAt,
                   !updated.isEmpty {
                    let localizedDate = AppDateFormatting.localizedDisplayDate(from: updated) ?? updated
                    Text(String(format: String(localized: "country_detail.advisory.last_updated_format"), locale: AppDisplayLocale.current, localizedDate))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let url = country.advisoryUrl {
                    Link(String(localized: "country_detail.advisory.view_official"), destination: url)
                        .font(.footnote)
                }

                HStack(spacing: 12) {
                    Text(String(format: String(localized: "country_detail.advisory.normalized_format"), locale: AppDisplayLocale.current, advisoryScore))
                    Text(String(format: String(localized: "country_detail.advisory.weight_format"), locale: AppDisplayLocale.current, weightPercentage))
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
