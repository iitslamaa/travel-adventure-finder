//
//  TAFButtonStyle.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/4/26.
//

import SwiftUI

enum TAFButtonVariant {
    case primary
    case secondary
    case ghost
}

struct TAFButtonStyle: ButtonStyle {

    let variant: TAFButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TAFTypography.body(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background(configuration: configuration))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return TAFColor.textPrimary
        case .ghost: return TAFColor.ocean
        }
    }

    @ViewBuilder
    private func background(configuration: Configuration) -> some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [TAFColor.ocean, TAFColor.oceanSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .secondary:
            TAFColor.surfaceAlt

        case .ghost:
            Color.clear
        }
    }
}
