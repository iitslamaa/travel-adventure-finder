//
//  ProfileLoadingView.swift
//  TravelScoreriOS
//

import SwiftUI

struct ProfileLoadingView: View {
    var body: some View {
        ZStack {
            Theme.pageBackground("travel4")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "profile.title"))

                ProfileSkeletonView()
                    .padding(.top, 6)
            }

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.black)

                Text(String(localized: "profile.loading.title", defaultValue: "Loading profile"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.78))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
            )
        }
    }
}
