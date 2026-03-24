//
//  StatCard.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/6/26.
//

import Foundation
import SwiftUI

struct StatCard: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(AppNumberFormatting.integerString(value))
                .font(.title)
                .bold()

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
