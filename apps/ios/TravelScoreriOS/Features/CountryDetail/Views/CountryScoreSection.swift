//
//  CountryScoreSection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/23/26.
//

import Foundation
import SwiftUI

/// Reusable score section layout used ONLY inside CountryDetailView.
/// Keeps CountryDetail consistent and future-proof.
struct CountryScoreSection: View {

    let title: String
    let weight: Int
    let score: Int
    let headline: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Title row
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text("\(AppNumberFormatting.integerString(weight))%")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Score + description row
            HStack(alignment: .top, spacing: 12) {

                // CountryDetail-specific pill styling (independent from ScorePill)
                Text(AppNumberFormatting.integerString(score))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(backgroundColor(for: score))
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                borderColor(for: score),
                                lineWidth: 1
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {

                    Text(headline)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func backgroundColor(for score: Int) -> Color {
        switch score {
        case 80...100: return Color.green.opacity(0.15)
        case 60..<80: return Color.yellow.opacity(0.15)
        case 40..<60: return Color.orange.opacity(0.15)
        default: return Color.red.opacity(0.15)
        }
    }

    private func borderColor(for score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}
