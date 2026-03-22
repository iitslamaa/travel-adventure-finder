//
//  ProfileSettingsHeader.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 2/14/26.
//

import Foundation
import SwiftUI

struct ProfileSettingsHeader: View {
    var body: some View {
        VStack {
            HStack {
                Text("profile.settings.title")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 24)

                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
