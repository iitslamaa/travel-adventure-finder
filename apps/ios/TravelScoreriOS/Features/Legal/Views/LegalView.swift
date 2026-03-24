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
                Theme.titleBanner(String(localized: "legal.title"))

                ScrollView {
                    VStack(spacing: 20) {
                        legalSection(
                            title: String(localized: "legal.general_information.title"),
                            body: String(localized: "legal.general_information.body")
                        )

                        legalSection(
                            title: String(localized: "legal.advisories.title"),
                            body: String(localized: "legal.advisories.body")
                        )

                        legalSection(
                            title: String(localized: "legal.no_professional_advice.title"),
                            body: String(localized: "legal.no_professional_advice.body")
                        )

                        legalSection(
                            title: String(localized: "legal.limitation_of_liability.title"),
                            body: String(localized: "legal.limitation_of_liability.body")
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
