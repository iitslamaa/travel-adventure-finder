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
                    Text("Selected destination")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(country.name ?? country.isoCode)
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
                    Text(String(Int(score.rounded())))
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
                    Text("Safety score: \(Int(advisoryScore.rounded()))")
                        .tagStyle()
                }
                if let region = country.region {
                    Text("Region: \(region)")
                        .tagStyle()
                }
            }
            
            // Score snapshot
            if let scores = country.scores {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Score snapshot")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    scoreRow(label: "Seasonality", value: scores.seasonality)
                    scoreRow(label: "Affordability", value: scores.affordability)
                    scoreRow(label: "Visa ease", value: scores.visaEase)
                }
            }
            
            Text("This month is one of the best times to visit based on weather, crowds, and overall conditions. Open the full country page to compare safety, affordability, and visa details.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // TODO: wire this into your existing CountryDetailView navigation
            NavigationLink {
                // Replace with your real detail view constructor
                Text("TODO: Country detail for \(country.name ?? country.isoCode)")
            } label: {
                HStack(spacing: 4) {
                    Text("Open full country page")
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
                Text(String(Int(value.rounded())))
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bg)
                    .foregroundColor(fg)
                    .clipShape(Capsule())
            } else {
                Text("—")
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
