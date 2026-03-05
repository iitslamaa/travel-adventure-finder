//
//  PlanningView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/5/26.
//

import SwiftUI

struct PlanningView: View {

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            ListsView()
                .background(.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Lists Root

struct ListsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                Theme.titleBanner("Lists")

                NavigationLink {
                    BucketListView()
                } label: {
                    PlanningCard(
                        title: "Bucket List",
                        subtitle: "Places you want to visit",
                        icon: "bookmark"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MyTravelsView()
                } label: {
                    PlanningCard(
                        title: "Visited Countries",
                        subtitle: "Track places you've been",
                        icon: "checkmark.circle"
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Card

struct PlanningCard: View {

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        ZStack {

            Theme.scrapbookBack()
                .offset(x: -4, y: 4)

            HStack(spacing: 16) {

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(18)
            .frame(height: 110)
            .background(
                Theme.cardBackground()
            )
            .rotationEffect(.degrees(1))
        }
    }
}
