//
//  ThemePreviewView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/4/26.
//

import SwiftUI

struct ThemePreviewView: View {

    @State private var isDark = false
    @State private var score: Double = 86

    var body: some View {
        ZStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.94, blue: 0.88),
                        Color(red: 0.95, green: 0.90, blue: 0.80)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // subtle paper vignette
                RadialGradient(
                    colors: [Color.black.opacity(0.05), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 600
                )
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    header
                    
                    HStack(spacing: 8) {
                        Text("Explore")
                        Text("Adventure")
                        Text("Destinations")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.7))
                    )
                    .rotationEffect(.degrees(-1))

                    // Layered polaroid travel photos
                    ZStack {

                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .frame(height: 210)
                            .rotationEffect(.degrees(-4))
                            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)

                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .frame(height: 210)
                            .rotationEffect(.degrees(3))
                            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)

                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .frame(height: 210)
                            .shadow(color: .black.opacity(0.22), radius: 12, y: 8)

                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red:0.62,green:0.73,blue:0.88), Color(red:0.88,green:0.74,blue:0.60)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(16)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("🇯🇵 Tokyo")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Travel score: 92")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(24)
                    }
                    .rotationEffect(.degrees(-1))

                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        Text("✈︎")
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 6)

                    surfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Typography")
                                .font(TAFTypography.section())
                                .foregroundStyle(isDark ? .white : TAFColor.textPrimary)

                            Text("Large Title — Discover the world")
                                .font(TAFTypography.largeTitle())
                                .foregroundStyle(isDark ? .white : TAFColor.textPrimary)

                            Text("Title — Your next destination")
                                .font(TAFTypography.title())
                                .foregroundStyle(isDark ? .white : TAFColor.textPrimary)

                            Text("Body — Clean, modern, data-driven travel discovery.")
                                .font(TAFTypography.body())
                                .foregroundStyle(isDark ? Color.white.opacity(0.85) : TAFColor.textSecondary)

                            Text("Caption — Updated 2m ago")
                                .font(TAFTypography.caption())
                                .foregroundStyle(isDark ? Color.white.opacity(0.7) : TAFColor.textSecondary)
                        }
                    }

                    surfaceCard {
                        VStack(spacing: 12) {
                            Text("Buttons")
                                .font(TAFTypography.section())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(isDark ? .white : TAFColor.textPrimary)

                            Button("Explore Destinations ✈️") {}
                                .font(.system(size: 16, weight: .bold))
                                .buttonStyle(TAFButtonStyle(variant: .primary))

                            Button("See Score Breakdown") {}
                                .buttonStyle(TAFButtonStyle(variant: .secondary))

                            Button("Skip for now") {}
                                .buttonStyle(TAFButtonStyle(variant: .ghost))
                        }
                    }

                    // Passport-stamp scrapbook score collage
                    PassportStampScoreCard(score: $score, isDark: isDark)

                    Spacer(minLength: 24)
                }
                .padding(24)
            }
        }
        .preferredColorScheme(isDark ? .dark : .light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TravelAF Journal")
                    .font(TAFTypography.title())
                    .foregroundStyle(isDark ? .white : TAFColor.textPrimary)
                Spacer()
                Toggle("Dark", isOn: $isDark)
                    .labelsHidden()
            }

            Text("This screen is the visual contract for the app’s look.")
                .font(TAFTypography.body())
                .foregroundStyle(isDark ? Color.white.opacity(0.75) : TAFColor.textSecondary)
        }
    }

    private func surfaceCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)
                .rotationEffect(.degrees(-1))

            // scrapbook tape decoration
            Rectangle()
                .fill(Color(red: 0.95, green: 0.90, blue: 0.75).opacity(0.8))
                .frame(width: 60, height: 16)
                .rotationEffect(.degrees(20))
                .offset(x: 16, y: -8)
        }
    }
}


// Passport-stamp scrapbook score collage
private struct PassportStampScoreCard: View {
    @Binding var score: Double
    let isDark: Bool

    private var stampColor: Color {
        switch score {
        case 85...: return Color(red:0.32,green:0.55,blue:0.41)
        case 70..<85: return Color(red:0.37,green:0.49,blue:0.70)
        case 50..<70: return Color(red:0.72,green:0.59,blue:0.32)
        default: return Color(red:0.67,green:0.38,blue:0.36)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // Torn paper base
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 12)

            // Perforated ticket edge illusion
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .foregroundStyle(Color.black.opacity(0.10))
                .padding(10)

            // Big stamp + sticker collage
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("PASSPORT STAMP")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.black.opacity(0.55))

                    Spacer()

                    // Fake postage sticker
                    HStack(spacing: 6) {
                        Text("✉️")
                        Text("AIR MAIL")
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(red: 0.93, green: 0.90, blue: 0.78))
                    )
                    .overlay(
                        Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(8))
                }

                HStack(alignment: .center, spacing: 14) {
                    StampBadge(score: score, ink: stampColor)
                        .rotationEffect(.degrees(-8))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("🇯🇵 TOKYO")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(TAFColor.textPrimary)

                        HStack(spacing: 6) {
                            Chip(text: "Food")
                            Chip(text: "Walkable")
                            Chip(text: "Spring")
                        }

                        Text("Stamped in your journal — bold, messy, unforgettable.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }

                    Spacer()
                }

                // Ticket-style ruler slider
                VStack(alignment: .leading, spacing: 10) {
                    Text("Trip vibe")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.55))

                    TicketRulerSlider(value: $score, ink: stampColor)
                }
            }
            .padding(22)

            // Extra tape pieces
            TapePiece()
                .rotationEffect(.degrees(-18))
                .offset(x: -6, y: 18)

            TapePiece()
                .rotationEffect(.degrees(14))
                .offset(x: 250, y: -6)

            // Big ink splat accent
            Circle()
                .fill(stampColor.opacity(0.14))
                .frame(width: 140, height: 140)
                .blur(radius: 0.5)
                .offset(x: 230, y: 140)
        }
        .frame(maxWidth: .infinity)
        .rotationEffect(.degrees(1.2))
    }
}

private struct StampBadge: View {
    let score: Double
    let ink: Color

    var body: some View {
        ZStack {
            // outer stamp ring
            Circle()
                .stroke(ink.opacity(0.30), lineWidth: 10)

            // dashed "stamp" edge
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [4, 6]))
                .foregroundStyle(ink.opacity(0.75))
                .padding(6)

            // inner badge
            Circle()
                .fill(ink.opacity(0.10))
                .padding(14)

            VStack(spacing: 4) {
                Text("\(Int(score))")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                Text("SCORE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(ink.opacity(0.75))
            }

            // diagonal stamp text
            Text("APPROVED")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(ink.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(ink.opacity(0.35), lineWidth: 2)
                )
                .rotationEffect(.degrees(-22))
                .offset(x: 0, y: 34)
        }
        .frame(width: 120, height: 120)
    }
}

private struct Chip: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red:0.94,green:0.91,blue:0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
            .foregroundStyle(Color.black.opacity(0.7))
    }
}

private struct TicketRulerSlider: View {
    @Binding var value: Double
    let ink: Color

    var body: some View {
        VStack(spacing: 8) {
            // tick marks
            HStack(spacing: 4) {
                ForEach(0..<28) { i in
                    Rectangle()
                        .fill(Color.black.opacity(i % 7 == 0 ? 0.28 : 0.12))
                        .frame(width: 2, height: i % 7 == 0 ? 14 : 8)
                }
            }

            Slider(value: $value, in: 0...100, step: 1)
                .tint(ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.98, green: 0.96, blue: 0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
    }
}

private struct TapePiece: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(red: 0.95, green: 0.90, blue: 0.75).opacity(0.85))
            .frame(width: 72, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 4)
    }
}

#Preview("Theme Preview") {
    ThemePreviewView()
}
