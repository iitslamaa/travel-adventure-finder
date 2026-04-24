//
//  FriendsSection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/13/26.
//

import Foundation
import SwiftUI

struct FriendsSection: View {
    let relationshipState: RelationshipState
    let username: String
    let friendCount: Int
    let onToggleFriend: () -> Void
    let onCancelRequest: () -> Void
    let onViewFriends: () -> Void

    @State private var showUnfriendConfirmation = false

    var body: some View {
        drawerView
            .presentationDetents([.height(drawerHeight)])
            .presentationBackground(.clear)
            .presentationCornerRadius(30)
    }

    private var drawerView: some View {
        VStack(spacing: 20) {

            Text(drawerTitle)
                .font(.title2.bold())
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // View Friends Row
            Button {
                onViewFriends()
            } label: {
                HStack {
                    Label("friends.section.view_friends", systemImage: "person.2.fill")
                        .font(.headline)
                    Spacer()
                    Text(AppNumberFormatting.integerString(friendCount))
                        .foregroundStyle(.black.opacity(0.55))
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.black.opacity(0.55))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.52))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            // Unfriend Option
            if relationshipState == .friends {
                Button(role: .destructive) {
                    showUnfriendConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.minus")
                        Text("friends.section.unfriend")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            // Cancel Request Option
            if relationshipState == .requestSent {
                Button(role: .destructive) {
                    onCancelRequest()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("friends.section.cancel_request")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .top)
        .foregroundStyle(.black)
        .background(
            Theme.themedSheetBackground(corner: 30)
                .ignoresSafeArea()
        )
        .alert(String(localized: "friends.section.unfriend_confirm_title"), isPresented: $showUnfriendConfirmation) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.confirm"), role: .destructive) {
                onToggleFriend()
            }
        }
    }

    private var drawerTitle: String {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            return String(localized: "friends.section.title")
        }

        return trimmedUsername.hasPrefix("@") ? trimmedUsername : "@\(trimmedUsername)"
    }

    private var drawerHeight: CGFloat {
        switch relationshipState {
        case .friends, .requestSent:
            return 280
        default:
            return 190
        }
    }
}
