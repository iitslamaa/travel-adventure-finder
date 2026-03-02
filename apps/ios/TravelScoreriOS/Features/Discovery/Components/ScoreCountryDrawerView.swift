//
//  ScoreCountryDrawerView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/11/26.
//

import Foundation
import SwiftUI

struct ScoreCountryDrawerView: View {
    
    let country: Country
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationLink {
            CountryDetailView(country: country)
        } label: {
            VStack(spacing: 12) {
                
                // Header + Score (compact single row)
                HStack(spacing: 8) {
                    Text(country.flagEmoji ?? "🌍")
                        .font(.system(size: 30))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(country.name)
                            .font(.title3.weight(.semibold))

                        Text("Overall Score")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let score = country.score {
                        HStack(spacing: 8) {
                            Text("\(score)")
                                .font(.title2.weight(.bold))
                                .fixedSize()
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(ScoreColor.background(for: score))
                                )
                                .foregroundColor(.white)

                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.25), radius: 25, y: 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .buttonStyle(.plain)
    }
}
