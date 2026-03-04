//
//  ScrapbookThemeContainer.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/4/26.
//

import SwiftUI

struct ScrapbookThemeContainer<Content: View>: View {

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {

            // scrapbook paper background
            ZStack {
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
            .ignoresSafeArea()

            // actual app UI
            content
        }
    }
}
