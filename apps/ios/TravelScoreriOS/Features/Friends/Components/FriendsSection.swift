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
    let friendCount: Int
    let onToggleFriend: () -> Void
    let onCancelRequest: () -> Void
    let onViewFriends: () -> Void

    @State private var showUnfriendConfirmation = false

    var body: some View {
        drawerView
            .presentationDetents([.medium])
            .presentationBackground(.clear)
            .presentationCornerRadius(30)
    }

    private var drawerView: some View {
        VStack(spacing: 20) {

            Text("Friends")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            // View Friends Row
            Button {
                onViewFriends()
            } label: {
                HStack {
                    Label("View Friends", systemImage: "person.2.fill")
                        .font(.headline)
                    Spacer()
                    Text("\(friendCount)")
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
                        Text("Unfriend")
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
                        Text("Cancel Friend Request")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.black)
        .background(
            Theme.themedSheetBackground(corner: 30)
                .ignoresSafeArea()
        )
        .alert("Unfriend?", isPresented: $showUnfriendConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                onToggleFriend()
            }
        }
    }
}
