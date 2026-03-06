//
//  Theme.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/4/26.
//

import SwiftUI

enum Theme {

    // MARK: - Active Theme
    // Change ONLY this line to swap the entire app theme
    static var current: ThemeStyle = .scrapbook

    // MARK: - Tokens

    static var primaryCardMaterial: Material {
        current.primaryCardMaterial
    }

    static var secondaryCardMaterial: Material {
        current.secondaryCardMaterial
    }

    static var cardShadow: Color {
        current.cardShadow
    }

    static var cardBorder: Color {
        current.cardBorder
    }

    static var paperRotation: Double {
        current.paperRotation
    }

    // MARK: - Layout Tokens

    static var cornerRadiusCard: CGFloat { current.cornerRadiusCard }
    static var cornerRadiusLarge: CGFloat { current.cornerRadiusLarge }

    static var spacingSmall: CGFloat { current.spacingSmall }
    static var spacingMedium: CGFloat { current.spacingMedium }
    static var spacingLarge: CGFloat { current.spacingLarge }

    // MARK: - Color Tokens

    static var backgroundPrimary: Color { current.backgroundPrimary }
    static var backgroundSecondary: Color { current.backgroundSecondary }

    // Global surfaces used across the app
    static var surface: Color { current.backgroundPrimary }
    static var surfaceSecondary: Color { current.backgroundSecondary }

    // Default background (Discovery uses travel1)
    static func pageBackground() -> some View {
        pageBackground("travel1", tint: 0.08)
    }

    // Flexible scrapbook background helper for any screen
    static func pageBackground(_ imageName: String, tint: Double = 0.08) -> some View {
        GeometryReader { geo in
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                if tint > 0 {
                    Color.black
                        .opacity(tint)
                        .ignoresSafeArea()
                }
            }
        }
        .allowsHitTesting(false)
    }

    static var accent: Color { current.accent }

    static var textPrimary: Color { current.textPrimary }
    static var textSecondary: Color { current.textSecondary }

    // MARK: - Card Background

    static func cardBackground(corner: CGFloat = 18) -> some View {
        ZStack {

            RoundedRectangle(cornerRadius: corner + 6, style: .continuous)
                .fill(backgroundSecondary.opacity(0.45))
                .rotationEffect(.degrees(paperRotation * 1.6))
                .offset(x: 6, y: -6)

            RoundedRectangle(cornerRadius: corner + 2, style: .continuous)
                .fill(backgroundSecondary.opacity(0.35))
                .rotationEffect(.degrees(paperRotation))
                .offset(x: -4, y: 4)

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(backgroundPrimary)
                .shadow(color: cardShadow.opacity(0.25), radius: 8, y: 6)

        }
    }

    // MARK: - Paper Stack Effect

    static func scrapbookBack(corner: CGFloat = 20) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(secondaryCardMaterial)
            .rotationEffect(.degrees(paperRotation * 0.4))
            .shadow(color: cardShadow.opacity(0.4), radius: 6, y: 4)
    }

    // MARK: - Decorative Tape

    static func tape(width: CGFloat = 60, height: CGFloat = 16) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(red: 0.93, green: 0.88, blue: 0.72))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(-6))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .opacity(0.9)
    }

    // MARK: - Torn Paper Background

    static func tornPaperBackground() -> some View {
        ZStack {
            pageBackground()

            RoundedRectangle(cornerRadius: 30)
                .fill(backgroundSecondary.opacity(0.35))
                .rotationEffect(.degrees(-4))
                .offset(x: -30, y: 40)

            RoundedRectangle(cornerRadius: 30)
                .fill(backgroundSecondary.opacity(0.25))
                .rotationEffect(.degrees(5))
                .offset(x: 40, y: -30)
        }
        .ignoresSafeArea()
    }

    // MARK: - Scrapbook Polaroid Photo

    static func polaroidPhoto<Content: View>(
        rotation: Double = -3,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {

            Image("travel3")
                .resizable()
                .scaledToFit()
                .opacity(0.25)
                .clipShape(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(spacing: 10) {
                content()
                    .clipShape(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 8)
            }
            .padding(12)

            tape()
                .offset(y: -10)
        }
        .rotationEffect(.degrees(rotation))
    }

    // MARK: - Scrapbook Section Container

    static func scrapbookSection<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            cardBackground(corner: 24)
                .shadow(color: cardShadow.opacity(0.35), radius: 10, y: 6)

            VStack(alignment: .leading, spacing: spacingMedium) {
                content()
            }
            .padding(20)
        }
        .padding(.horizontal)
    }

    // MARK: - Scrapbook Collage Layout

    static func collage<Content1: View, Content2: View, Content3: View>(
        @ViewBuilder first: () -> Content1,
        @ViewBuilder second: () -> Content2,
        @ViewBuilder third: () -> Content3
    ) -> some View {

        ZStack {

            polaroidPhoto(rotation: -6) {
                first()
            }
            .offset(x: -40, y: -20)

            polaroidPhoto(rotation: 5) {
                second()
            }
            .offset(x: 40, y: 0)

            polaroidPhoto(rotation: -2) {
                third()
            }
            .offset(x: 0, y: 40)
        }
        .frame(height: 260)
    }

    // MARK: - Scrapbook Feature Card (for navigation tiles)

    static func featureCard<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Content
    ) -> some View {

        scrapbookSection {

            HStack(spacing: 16) {

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }

                Spacer()

                trailing()

            }
        }
    }

    // MARK: - Title Banner (Page Headers)

    static func titleBanner(_ title: String) -> some View {
        ZStack {
            Image("title_background")
                .resizable()
                .scaledToFit()

            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, spacingSmall - 8)
        .padding(.bottom, spacingMedium + 6)
    }
}

// MARK: - Theme Style

struct ThemeStyle {

    let primaryCardMaterial: Material
    let secondaryCardMaterial: Material
    let cardShadow: Color
    let cardBorder: Color
    let paperRotation: Double

    // MARK: - Layout

    let cornerRadiusCard: CGFloat
    let cornerRadiusLarge: CGFloat
    let spacingSmall: CGFloat
    let spacingMedium: CGFloat
    let spacingLarge: CGFloat

    // MARK: - Colors

    let backgroundPrimary: Color
    let backgroundSecondary: Color
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color

    // MARK: - Presets

    static let beigePolaroid = ThemeStyle(
        primaryCardMaterial: .regularMaterial,
        secondaryCardMaterial: .thinMaterial,
        cardShadow: Color.black.opacity(0.18),
        cardBorder: Color(.separator),
        paperRotation: -3,

        cornerRadiusCard: 18,
        cornerRadiusLarge: 26,
        spacingSmall: 8,
        spacingMedium: 16,
        spacingLarge: 24,

        backgroundPrimary: Color(.systemGroupedBackground),
        backgroundSecondary: Color(.secondarySystemGroupedBackground),
        accent: Color.blue,
        textPrimary: .primary,
        textSecondary: .secondary
    )

    static let cleanModern = ThemeStyle(
        primaryCardMaterial: .regularMaterial,
        secondaryCardMaterial: .ultraThinMaterial,
        cardShadow: Color.black.opacity(0.12),
        cardBorder: Color(.separator),
        paperRotation: 0,

        cornerRadiusCard: 16,
        cornerRadiusLarge: 22,
        spacingSmall: 8,
        spacingMedium: 16,
        spacingLarge: 28,

        backgroundPrimary: Color(.systemBackground),
        backgroundSecondary: Color(.secondarySystemBackground),
        accent: Color.blue,
        textPrimary: .primary,
        textSecondary: .secondary
    )

    static let glass = ThemeStyle(
        primaryCardMaterial: .thinMaterial,
        secondaryCardMaterial: .ultraThinMaterial,
        cardShadow: Color.brown.opacity(0.35),
        cardBorder: Color.brown.opacity(0.15),
        paperRotation: -1.2,

        cornerRadiusCard: 22,
        cornerRadiusLarge: 30,
        spacingSmall: 10,
        spacingMedium: 18,
        spacingLarge: 28,

        backgroundPrimary: Color(red: 0.97, green: 0.95, blue: 0.90),
        backgroundSecondary: Color(red: 0.94, green: 0.91, blue: 0.85),
        accent: Color(red: 0.82, green: 0.38, blue: 0.32),
        textPrimary: Color.black.opacity(0.9),
        textSecondary: Color.black.opacity(0.55)
    )

    static let scrapbook = ThemeStyle(
        primaryCardMaterial: .ultraThinMaterial,
        secondaryCardMaterial: .thinMaterial,
        cardShadow: Color.black.opacity(0.25),
        cardBorder: Color(red: 0.82, green: 0.74, blue: 0.64).opacity(0.4),
        paperRotation: -2.5,

        cornerRadiusCard: 20,
        cornerRadiusLarge: 30,
        spacingSmall: 10,
        spacingMedium: 18,
        spacingLarge: 30,

        backgroundPrimary: Color(red: 0.96, green: 0.94, blue: 0.90),
        backgroundSecondary: Color(red: 0.92, green: 0.89, blue: 0.84),
        accent: Color(red: 0.78, green: 0.44, blue: 0.32),
        textPrimary: Color(red: 0.22, green: 0.20, blue: 0.18),
        textSecondary: Color(red: 0.36, green: 0.33, blue: 0.30)
    )
}
