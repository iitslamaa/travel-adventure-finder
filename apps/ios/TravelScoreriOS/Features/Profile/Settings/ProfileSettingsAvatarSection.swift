//
//  ProfileSettingsAvatarSection.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation
import SwiftUI
import PhotosUI

struct ProfileSettingsAvatarSection: View {

    @Binding var selectedUIImage: UIImage?
    let profileVM: ProfileViewModel
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isUploadingAvatar: Bool
    let shouldRemoveAvatar: Bool
    let onRemoveAvatar: () -> Void

    @State private var showPhotoOptions = false
    @State private var showImagePicker = false
    @State private var previewImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 0) {

            Button {
                showPhotoOptions = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    avatarView

                    if isUploadingAvatar {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.94))
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                    }

                    cameraBadge
                }
                .frame(width: 96, height: 96)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "Profile Photo",
                isPresented: $showPhotoOptions,
                titleVisibility: .visible
            ) {
                Button(hasAvatar ? "Change Photo" : "Add Photo") {
                    showImagePicker = true
                }

                if hasAvatar {
                    Button("Remove Photo", role: .destructive) {
                        onRemoveAvatar()
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $showImagePicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }

                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            previewImage = uiImage
                            selectedUIImage = uiImage
                        }
                    }
                }
            }

        }
    }

    private var hasAvatar: Bool {
        if shouldRemoveAvatar { return false }
        if selectedUIImage != nil { return true }
        if let url = profileVM.profile?.avatarUrl, !url.isEmpty { return true }
        return false
    }

    @ViewBuilder
    private var avatarView: some View {
        Group {
            if shouldRemoveAvatar {
                placeholderAvatar
            } else if let image = selectedUIImage ?? previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = profileVM.profile?.avatarUrl,
                      !urlString.isEmpty,
                      let url = URL(string: urlString) {
                AsyncImage(
                    url: url,
                    transaction: Transaction(animation: .easeInOut(duration: 0.2))
                ) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure(_):
                        placeholderAvatar
                    case .empty:
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    @unknown default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 3)
        )
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.secondary)
            )
    }

    private var cameraBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            Image(systemName: "camera.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .offset(x: 4, y: 4)
    }
}
