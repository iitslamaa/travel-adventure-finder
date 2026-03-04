//
//  ScrapbookThemeContainer.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/4/26.
//

import SwiftUI

struct ScrapbookThemeContainer<Content: View>: View {

    @Environment(\.colorScheme) private var colorScheme

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {

            // scrapbook background (light / dark adaptive)
            ZStack {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.12, blue: 0.13),
                            Color(red: 0.08, green: 0.08, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [Color.white.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 700
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.94, blue: 0.88),
                            Color(red: 0.95, green: 0.90, blue: 0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [Color.black.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 700
                    )
                }
            }
            .ignoresSafeArea()

            // actual app UI
            content
        }
    }
}
