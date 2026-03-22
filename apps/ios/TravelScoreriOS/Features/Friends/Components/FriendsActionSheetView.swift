//
//  FriendsActionSheetView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/13/26.
//

import Foundation
import SwiftUI

struct FriendsActionSheetView: View {
    
    let username: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            
            // Background Dim
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 20) {
                
                // Drag Indicator
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Icon
                Image(systemName: "person.crop.circle.badge.minus")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                    .padding(.top, 8)
                
                // Title
                Text(String(format: String(localized: "friends.action_sheet.unfriend_user_format"), locale: Locale.current, username))
                    .font(.title3.weight(.semibold))
                
                // Subtitle
                Text("friends.action_sheet.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(spacing: 12) {
                    
                    // Confirm Button
                    Button(action: {
                        onConfirm()
                    }) {
                        Text("friends.section.unfriend")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(14)
                    }
                    
                    // Cancel Button
                    Button(action: {
                        onCancel()
                    }) {
                        Text("common.cancel")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(14)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 24)
            .transition(.move(edge: .bottom))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: UUID())
        }
    }
}
