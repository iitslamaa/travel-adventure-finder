//
//  LoadingOverlayView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/22/26.
//

import Foundation
import SwiftUI

struct LoadingOverlayView: View {
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.1)

                Text("discovery.world_map.preparing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
            )
            .shadow(radius: 20)
        }
    }
}
