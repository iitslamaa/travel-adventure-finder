//
//  AuthSheetView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/5/26.
//

import SwiftUI

struct AuthSheetView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Text("auth.sheet.subtitle")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                // Continue as Guest
                Button {
                    sessionManager.continueAsGuest()
                } label: {
                    Text("auth.continue_guest")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Divider()
                    .padding(.vertical, 8)

                // Auth flow (Apple / Google / Email)
                EmailAuthView()

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(String(localized: "auth.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
