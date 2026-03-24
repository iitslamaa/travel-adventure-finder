//
//  CountryPreviewCardMobile.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 12/2/25.
//

import SwiftUI
struct CountryPreviewCardMobile: View {
    let country: SeasonalityCountry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("discovery.preview.selected_destination")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(AppDisplayLocale.current.localizedString(forRegionCode: country.isoCode.uppercased()) ?? country.name ?? country.isoCode)
                        .font(.headline)
                    
                    if let region = country.region {
                        Text(region)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                if let score = country.score {
                    let bg = scoreBackground(score)
                    let fg = scoreTone(score)
                    Text(AppNumberFormatting.integerString(score))
                        .font(.subheadline.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(bg)
                        .foregroundColor(fg)
                        .clipShape(Capsule())
                }
            }
            
            // “Tags” row
            HStack(spacing: 8) {
                if let advisoryScore = country.scores?.advisory {
                    Text(String(format: String(localized: "discovery.preview.safety_score_format"), locale: AppDisplayLocale.current, Int(advisoryScore.rounded())))
                        .tagStyle()
                }
                if let region = country.region {
                    Text(String(format: String(localized: "discovery.preview.region_format"), locale: AppDisplayLocale.current, region))
                        .tagStyle()
                }
            }
            
            // Score snapshot
            if let scores = country.scores {
                VStack(alignment: .leading, spacing: 8) {
                    Text("discovery.preview.score_snapshot")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    scoreRow(label: String(localized: "discovery.preview.seasonality"), value: scores.seasonality)
                    scoreRow(label: String(localized: "discovery.preview.affordability"), value: scores.affordability)
                    scoreRow(label: String(localized: "discovery.preview.visa_ease"), value: scores.visaEase)
                }
            }
            
            Text("discovery.preview.best_time_summary")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // TODO: wire this into your existing CountryDetailView navigation
            NavigationLink {
                // Replace with your real detail view constructor
                Text(String(format: String(localized: "discovery.preview.todo_country_detail_format"), locale: AppDisplayLocale.current, AppDisplayLocale.current.localizedString(forRegionCode: country.isoCode.uppercased()) ?? country.name ?? country.isoCode))
            } label: {
                HStack(spacing: 4) {
                    Text("discovery.preview.open_full_country")
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(
            Theme.countryDetailCardBackground(corner: 18)
        )
    }
    
    private func scoreRow(label: String, value: Double?) -> some View {
        let bg = scoreBackground(value)
        let fg = scoreTone(value)
        
        return HStack {
            Text(label)
                .font(.caption)
            Spacer()
            if let value {
                Text(AppNumberFormatting.integerString(value))
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bg)
                    .foregroundColor(fg)
                    .clipShape(Capsule())
            } else {
                Text("common.em_dash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private extension View {
    func tagStyle() -> some View {
        self
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.55))
            .clipShape(Capsule())
    }
}
