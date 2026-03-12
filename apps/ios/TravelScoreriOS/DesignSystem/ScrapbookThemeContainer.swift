//
//  ScrapbookThemeContainer.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/4/26.
//

import SwiftUI

struct ScrapbookThemeContainer: View {
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.92, blue: 0.85),
                Color(red: 0.94, green: 0.88, blue: 0.80),
                Color(red: 0.92, green: 0.85, blue: 0.76)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        let _ = print("🧪 DEBUG: ScrapbookThemeContainer.body recomputed.")
        backgroundGradient
            .ignoresSafeArea()
            .onAppear {
                print("🧪 DEBUG: ScrapbookThemeContainer gradient appeared")
            }
            .overlay {

                let _ = print("🧪 DEBUG: Scrapbook floating paper overlay recomputed")

                // floating scrapbook paper layers
                ZStack {

                    // torn paper background
                    RoundedRectangle(cornerRadius: 50, style: .continuous)
                        .fill(Color.white.opacity(0.6))
                        .rotationEffect(.degrees(-8))
                        .offset(x: -160, y: -280)

                    RoundedRectangle(cornerRadius: 50, style: .continuous)
                        .fill(Color(red: 1.0, green: 0.95, blue: 0.90).opacity(0.65))
                        .rotationEffect(.degrees(7))
                        .offset(x: 170, y: -320)

                    // soft photo paper pieces
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
                        .rotationEffect(.degrees(-5))
                        .offset(x: -170, y: 340)

                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color.white.opacity(0.65))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
                        .rotationEffect(.degrees(6))
                        .offset(x: 150, y: 420)

                    // subtle scrapbook accent circle
                    Circle()
                        .fill(Color.pink.opacity(0.08))
                        .frame(width: 320, height: 320)
                        .offset(x: -220, y: 180)

                    Circle()
                        .fill(Color.orange.opacity(0.07))
                        .frame(width: 260, height: 260)
                        .offset(x: 220, y: -160)
                }
                .allowsHitTesting(false)
            }
    }
}
