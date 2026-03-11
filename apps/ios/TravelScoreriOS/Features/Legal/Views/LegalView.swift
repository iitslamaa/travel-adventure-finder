//
//  LegalView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/4/26.
//

import Foundation
import SwiftUI

struct LegalView: View {
    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("Legal")

                ScrollView {
                    VStack(spacing: 20) {
                        legalSection(
                            title: "General Information",
                            body: "Travel Adventure Finder provides informational travel insights only. All scores, advisories, and recommendations are intended for general guidance and educational purposes. Seasonality insights are based on historical climate averages and typical travel patterns."
                        )

                        legalSection(
                            title: "Advisories & Safety Scores",
                            body: "Safety advisories and scores are derived from publicly available sources and third-party data. Conditions may change rapidly, and Travel Adventure Finder does not guarantee accuracy, completeness, or timeliness."
                        )

                        legalSection(
                            title: "No Professional Advice",
                            body: "Travel Adventure Finder does not provide legal, medical, or governmental advice. Users should verify information with official sources before making travel decisions."
                        )

                        legalSection(
                            title: "Limitation of Liability",
                            body: "Travel Adventure Finder is not responsible for decisions made based on information presented in the app. Use of this app is at your own discretion."
                        )
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalSection(title: String, body: String) -> some View {
        Theme.scrapbookSection {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
