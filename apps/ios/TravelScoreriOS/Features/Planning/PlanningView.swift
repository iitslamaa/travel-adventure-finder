//
//  PlanningView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/5/26.
//

import SwiftUI

enum PlanningListKind {
    case bucket
    case visited

    var title: String {
        switch self {
        case .bucket: return "Bucket List"
        case .visited: return "Visited Countries"
        }
    }

    var shortTitle: String {
        switch self {
        case .bucket: return "Bucket"
        case .visited: return "Visited"
        }
    }

    var subtitle: String {
        switch self {
        case .bucket: return "Places you want to visit"
        case .visited: return "Track places you've been"
        }
    }

    var icon: String {
        switch self {
        case .bucket: return "bookmark"
        case .visited: return "checkmark.circle"
        }
    }

    var filledIcon: String {
        switch self {
        case .bucket: return "bookmark.fill"
        case .visited: return "checkmark.circle.fill"
        }
    }

    var otherListLabel: String {
        switch self {
        case .bucket: return "Also visited"
        case .visited: return "Also in bucket"
        }
    }

    var otherListName: String {
        switch self {
        case .bucket: return "Visited"
        case .visited: return "Bucket"
        }
    }

    var pickerTitle: String {
        switch self {
        case .bucket: return "Add to Bucket List"
        case .visited: return "Add to Visited"
        }
    }

    var pickerSubtitle: String {
        switch self {
        case .bucket: return "Pick countries from the full list. Already saved entries stay checked."
        case .visited: return "Pick countries from the full list. Already tracked entries stay checked."
        }
    }

    var navigationTitle: String {
        switch self {
        case .bucket: return "🪣 Bucket List"
        case .visited: return "🎒 My Travels"
        }
    }

    var emptyTitle: String {
        switch self {
        case .bucket: return "No Bucket List Yet"
        case .visited: return "No trips yet"
        }
    }

    var emptySystemImage: String {
        switch self {
        case .bucket: return "bookmark"
        case .visited: return "backpack"
        }
    }

    var emptyDescription: String {
        switch self {
        case .bucket: return "Tap + to add countries here, or swipe left on a country and tap Bucket."
        case .visited: return "Tap + to add countries here, or swipe left on a country and tap Visited."
        }
    }

    var tint: Color {
        switch self {
        case .bucket: return .yellow
        case .visited: return .green
        }
    }
}

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
    @State private var scrollAnchor: String? = nil

    var body: some View {
        VStack(spacing: 0) {

            Theme.titleBanner("Planning")

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {

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
                    .id("planningListTop")
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .safeAreaPadding(.bottom)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Card

struct PlanningCard: View {

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        Theme.featureCard(
            icon: icon,
            title: title,
            subtitle: subtitle
        ) {
            Image(systemName: "chevron.right")
                .foregroundColor(.black)
        }
    }
}

struct PlanningListActionButton: View {
    let kind: PlanningListKind
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isActive
                        ? kind.tint.opacity(0.90)
                        : Color.white.opacity(0.82)
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                isActive
                                ? kind.tint.opacity(0.95)
                                : Color.white.opacity(0.65),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                if kind == .bucket {
                    Text("🪣")
                        .font(.system(size: 22))
                        .opacity(isActive ? 1.0 : 0.85)
                } else {
                    Image(systemName: isActive ? kind.filledIcon : kind.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }

                Circle()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 17, height: 17)
                    .overlay(
                        Image(systemName: isActive ? "checkmark" : "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isActive ? Color.green : Color.black.opacity(0.72))
                    )
                    .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
                    .offset(x: 13, y: 13)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isActive
            ? "Remove \(kind.shortTitle) for this country"
            : "Add \(kind.shortTitle) for this country"
        )
    }
}

struct PlanningCountryPickerView: View {
    let kind: PlanningListKind
    let countries: [Country]
    let selectedIds: Set<String>
    let otherSelectedIds: Set<String>
    let onSelect: (Country) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var sort: CountrySort = .name
    @State private var sortOrder: SortOrder = .ascending

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Theme.chromeIconButtonBackground(size: 44)
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)

                DiscoveryControlsView(
                    sort: $sort,
                    sortOrder: $sortOrder
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            VStack(spacing: 4) {
                Text(kind.pickerTitle)
                    .font(.headline)
                    .foregroundStyle(.black)

                Text(kind.pickerSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.black.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 4)

            CountryListView(
                showsSearchBar: true,
                searchText: $searchText,
                countries: countries,
                sort: $sort,
                sortOrder: $sortOrder,
                mode: .picker(
                    kind: kind,
                    selectedIds: selectedIds,
                    otherSelectedIds: otherSelectedIds,
                    onSelect: onSelect
                )
            )
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            Theme.pageBackground("travel1")
                .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}
