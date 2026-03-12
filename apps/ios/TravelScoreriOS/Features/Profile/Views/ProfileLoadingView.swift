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
                Theme.titleBanner("Profile")

                ProfileSkeletonView()
                    .padding(.top, 6)
            }
        }
    }
}
