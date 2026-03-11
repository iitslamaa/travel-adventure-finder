//
//  FriendRequestsView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/10/26.
//

import SwiftUI
import NukeUI
import Nuke

struct FriendRequestsView: View {
    @StateObject private var vm = FriendRequestsViewModel()

var body: some View {
    VStack(spacing: 0) {
                Theme.titleBanner("Friend Requests")

                if vm.isLoading {
                    ProgressView("Loading requests…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.incomingRequests.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.black.opacity(0.7))

                        Text("No friend requests")
                            .font(TAFTypography.title(.bold))
                            .foregroundStyle(.black)

                        Text("When someone sends you a friend request, it’ll show up here.")
                            .font(TAFTypography.section())
                            .foregroundStyle(.black.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vm.incomingRequests) { profile in
                            HStack(spacing: 12) {

                                // Avatar
                                Group {
                                    if let urlString = profile.avatarUrl,
                                       let url = URL(string: urlString) {
                                        LazyImage(url: url) { state in
                                            if let image = state.image {
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } else if state.error != nil {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .resizable()
                                                    .scaledToFill()
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.15))
                                                    ProgressView()
                                                        .scaleEffect(0.7)
                                                }
                                            }
                                        }
                                        .processors([
                                            ImageProcessors.Resize(size: CGSize(width: 120, height: 120))
                                        ])
                                        .priority(.high)
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFill()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())

                                // Name + username
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.fullName)
                                        .fontWeight(.medium)

                                    Text("@\(profile.username)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // Accept / Decline
                                HStack(spacing: 8) {

                                    Button {
                                        Task {
                                            do {
                                                try await vm.acceptRequest(from: profile.id)
                                            } catch {
                                                print("❌ accept failed:", error)
                                            }
                                            await vm.loadIncomingRequests()
                                            NotificationCenter.default.post(name: .friendshipUpdated, object: nil)
                                        }
                                    } label: {
                                        Text("Accept")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .buttonBorderShape(.capsule)
                                    .fixedSize()

                                    Button {
                                        Task {
                                            try? await vm.rejectRequest(from: profile.id)
                                            await vm.loadIncomingRequests()
                                        }
                                    } label: {
                                        Text("Decline")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .buttonBorderShape(.capsule)
                                    .fixedSize()
                                }
                                .fixedSize()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await vm.loadIncomingRequests()
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") {
                    vm.errorMessage = nil
                }
            } message: {
                Text(vm.errorMessage ?? "")
            }
    }
}
