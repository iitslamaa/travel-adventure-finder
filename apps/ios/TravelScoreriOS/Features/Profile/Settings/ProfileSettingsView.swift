import SwiftUI
import PhotosUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileVM: ProfileViewModel
    @EnvironmentObject private var sessionManager: SessionManager

    private let viewedUserId: UUID

    init(profileVM: ProfileViewModel, viewedUserId: UUID) {
        self.profileVM = profileVM
        self.viewedUserId = viewedUserId
    }

    // MARK: - Draft state (UI only)

    @State private var firstName: String = ""
    @State private var username: String = ""

    @State private var homeCountries: Set<String> = []
    @State private var nextDestination: String? = nil
    @State private var currentCountry: String? = nil
    @State private var favoriteCountries: [String] = []

    @State private var travelMode: TravelMode? = nil
    @State private var travelStyle: TravelStyle? = nil

    @State private var languages: [LanguageEntry] = []

    @State private var hasLoadedProfile = false

    // Avatar picker state
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedUIImage: UIImage? = nil
    @State private var isUploadingAvatar = false
    @State private var shouldRemoveAvatar = false

    // Sheets / dialogs

    private enum ActiveSheet: Identifiable {
        case home
        case currentCountry
        case favoriteCountries
        case nextDestination
        case addLanguage
        case travelMode
        case travelStyle

        var id: Int { hashValue }
    }

    @State private var activeSheet: ActiveSheet?

    // Delete account state
    @State private var showDeleteConfirm = false
    @State private var showDeleteSheet = false
    @State private var deleteText = ""
    @State private var isDeleting = false
    @State private var deleteError: String? = nil
    @State private var showSaveSuccess = false
    @State private var isSavingProfile = false
    @State private var usernameError: String? = nil
    @State private var isLoggingOut = false

    private var isFormValid: Bool {
        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !trimmedUsername.isEmpty
    }

    private var hasChanges: Bool {
        guard hasLoadedProfile else { return false }
        guard let profile = profileVM.profile else { return false }

        let originalFirstName = profile.fullName
        let originalUsername = profile.username
        let originalHomeCountries = Set(profile.livedCountries)
        let originalTravelMode = profile.travelMode.first.flatMap { TravelMode(rawValue: $0) }
        let originalTravelStyle = profile.travelStyle.first.flatMap { TravelStyle(rawValue: $0) }
        let originalNextDestination = profile.nextDestination
        let originalCurrentCountry = profile.currentCountry
        let originalFavoriteCountries = profile.favoriteCountries ?? []
        let originalLanguages = profile.languages.map { ($0.code, $0.proficiency) }
        let currentLanguages = languages.map { ($0.name, $0.proficiency) }

        let avatarChanged = shouldRemoveAvatar || selectedUIImage != nil

        return firstName != originalFirstName
            || username != originalUsername
            || homeCountries != originalHomeCountries
            || travelMode != originalTravelMode
            || travelStyle != originalTravelStyle
            || nextDestination != originalNextDestination
            || currentCountry != originalCurrentCountry
            || favoriteCountries.sorted() != originalFavoriteCountries.sorted()
            || !currentLanguages.elementsEqual(originalLanguages, by: { $0 == $1 })
            || avatarChanged
    }

    var body: some View {
        Group {

            // Wait for profile to exist before rendering settings UI
            if profileVM.profile == nil {
                VStack {
                    ProgressView()
                        .padding(.top, 40)
                    Text("Loading profile…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            else if SupabaseManager.shared.currentUserId != viewedUserId {
                Color.clear
                    .onAppear {
                        dismiss()
                    }
            }

            else {
                settingsContent()
                    .onAppear {
                        guard !hasLoadedProfile else { return }
                        hasLoadedProfile = true

                        if let profile = profileVM.profile {
                            firstName = profile.fullName ?? ""
                            username = profile.username ?? ""

                            homeCountries = Set(profile.livedCountries)
                            travelMode = profile.travelMode.first.flatMap { TravelMode(rawValue: $0) }
                            travelStyle = profile.travelStyle.first.flatMap { TravelStyle(rawValue: $0) }
                            nextDestination = profile.nextDestination

                            currentCountry = profile.currentCountry
                            favoriteCountries = profile.favoriteCountries ?? []

                            languages = profile.languages.map {
                                LanguageEntry(
                                    name: $0.code,
                                    proficiency: $0.proficiency
                                )
                            }
                        }
                    }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Theme.chromeIconButtonBackground(size: 40)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        let result = await ProfileSettingsSaveCoordinator.handleSave(
                            profileVM: profileVM,
                            firstName: firstName,
                            username: username,
                            homeCountries: homeCountries,
                            languages: languages,
                            travelMode: travelMode,
                            travelStyle: travelStyle,
                            nextDestination: nextDestination,
                            currentCountry: currentCountry,
                            favoriteCountries: favoriteCountries,
                            selectedUIImage: selectedUIImage,
                            shouldRemoveAvatar: shouldRemoveAvatar,
                            setSaving: { isSavingProfile = $0 },
                            setAvatarUploading: { isUploadingAvatar = $0 },
                            setAvatarCleared: {
                                selectedUIImage = nil
                                shouldRemoveAvatar = false
                            }
                        )

                        switch result {
                        case .success:
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                showSaveSuccess = true
                            }
                            usernameError = nil
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    showSaveSuccess = false
                                }
                            }

                        case .usernameTaken:
                            usernameError = "Username is already taken"

                        case .failure(let message):
                            usernameError = message
                        }
                    }
                } label: {
                    Group {
                        if isSavingProfile {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(hasChanges && isFormValid ? Theme.accent : Color.gray.opacity(0.55))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasChanges || !isFormValid || isSavingProfile)
                .opacity(hasChanges && isFormValid ? 1 : 0.5)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {

            case .home:
                CountryMultiSelectView(
                    title: "Home Countries",
                    subtitle: "Add any flag that represents you! (countries you've lived in, background, ethnicity, etc.)",
                    selection: $homeCountries
                )

            case .currentCountry:
                CountrySingleSelectView(
                    title: "Select current country",
                    selection: $currentCountry
                )

            case .favoriteCountries:
                CountryMultiSelectView(
                    title: "Favorite Countries",
                    subtitle: "Select your favorite destinations.",
                    selection: Binding(
                        get: { Set(favoriteCountries) },
                        set: { favoriteCountries = Array($0) }
                    )
                )

            case .nextDestination:
                CountrySingleSelectView(
                    title: "Select next destination",
                    selection: $nextDestination
                )

            case .addLanguage:
                AddLanguageView { entry in
                    if !languages.contains(where: { $0.name == entry.name }) {
                        languages.append(entry)
                    }
                }

            case .travelMode:
                NavigationStack {
                    List {
                        ForEach(TravelMode.allCases) { mode in
                            Button(mode.label) {
                                travelMode = mode
                                activeSheet = nil
                            }
                        }
                    }
                    .navigationTitle("Travel Mode")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)

            case .travelStyle:
                NavigationStack {
                    List {
                        ForEach(TravelStyle.allCases) { style in
                            Button(style.label) {
                                travelStyle = style
                                activeSheet = nil
                            }
                        }
                    }
                    .navigationTitle("Travel Style")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func settingsContent() -> some View {
        SettingsScrollContent(
            profileVM: profileVM,
            firstName: $firstName,
            username: $username,
            homeCountries: $homeCountries,
            currentCountry: $currentCountry,
            favoriteCountries: $favoriteCountries,
            travelMode: $travelMode,
            travelStyle: $travelStyle,
            languages: $languages,
            nextDestination: $nextDestination,
            showHomePicker: Binding(
                get: { false },
                set: { if $0 { activeSheet = .home } }
            ),
            showCurrentCountryPicker: Binding(
                get: { false },
                set: { if $0 { activeSheet = .currentCountry } }
            ),
            showFavoriteCountriesPicker: Binding(
                get: { false },
                set: { if $0 { activeSheet = .favoriteCountries } }
            ),
            showTravelModeDialog: Binding(
                get: { false },
                set: { if $0 { activeSheet = .travelMode } }
            ),
            showTravelStyleDialog: Binding(
                get: { false },
                set: { if $0 { activeSheet = .travelStyle } }
            ),
            showNextDestinationPicker: Binding(
                get: { false },
                set: { if $0 { activeSheet = .nextDestination } }
            ),
            showAddLanguage: Binding(
                get: { false },
                set: { if $0 { activeSheet = .addLanguage } }
            ),
            selectedUIImage: $selectedUIImage,
            selectedPhotoItem: $selectedPhotoItem,
            isUploadingAvatar: isUploadingAvatar,
            shouldRemoveAvatar: shouldRemoveAvatar,
            usernameError: usernameError,
            onRemoveAvatar: { markAvatarForRemoval() },
            onLogout: {
                guard !isLoggingOut else { return }
                isLoggingOut = true
                dismiss()
                Task {
                    await sessionManager.signOut()
                    await MainActor.run {
                        isLoggingOut = false
                    }
                }
            },
            isLoggingOut: isLoggingOut
        )
        .background(
            Theme.pageBackground("travel4")
                .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            if showSaveSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Profile updated")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.96))
                .clipShape(Capsule())
                .shadow(radius: 8)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    // MARK: - Display helpers

    private var homeCountriesDisplay: String {
        guard !homeCountries.isEmpty else { return "Not set" }
        return homeCountries.sorted().map(countryCodeToFlag).joined(separator: " ")
    }

    private var nextDestinationDisplay: String {
        guard let nextDestination else { return "Not set" }
        return countryCodeToFlag(nextDestination)
    }

    private func countryCodeToFlag(_ code: String) -> String {
        guard code.count == 2 else { return code }
        let base: UInt32 = 127397
        return code.unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }


    func markAvatarForRemoval() {
        selectedUIImage = nil
        selectedPhotoItem = nil
        shouldRemoveAvatar = true
    }

}


struct SettingsScrollContent: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @ObservedObject var profileVM: ProfileViewModel

    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false

    @Binding var firstName: String
    @Binding var username: String
    @Binding var homeCountries: Set<String>
    @Binding var currentCountry: String?
    @Binding var favoriteCountries: [String]
    @Binding var travelMode: TravelMode?
    @Binding var travelStyle: TravelStyle?
    @Binding var languages: [LanguageEntry]
    @Binding var nextDestination: String?

    @Binding var showHomePicker: Bool
    @Binding var showCurrentCountryPicker: Bool
    @Binding var showFavoriteCountriesPicker: Bool
    @Binding var showTravelModeDialog: Bool
    @Binding var showTravelStyleDialog: Bool
    @Binding var showNextDestinationPicker: Bool
    @Binding var showAddLanguage: Bool

    @Binding var selectedUIImage: UIImage?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isUploadingAvatar: Bool
    let shouldRemoveAvatar: Bool
    let usernameError: String?
    let onRemoveAvatar: () -> Void
    let onLogout: () -> Void
    let isLoggingOut: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Theme.titleBanner("Profile Settings")

                SectionCard {
                    HStack(alignment: .top, spacing: 20) {

                        ProfileSettingsAvatarSection(
                            selectedUIImage: $selectedUIImage,
                            profileVM: profileVM,
                            selectedPhotoItem: $selectedPhotoItem,
                            isUploadingAvatar: isUploadingAvatar,
                            shouldRemoveAvatar: shouldRemoveAvatar,
                            onRemoveAvatar: onRemoveAvatar
                        )
                        .frame(width: 96)
                        .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 12) {

                            TextField(
                                "",
                                text: $firstName,
                                prompt:
                                    (Text("Full name")
                                        .foregroundStyle(.secondary)
                                     +
                                     Text(" *")
                                        .foregroundStyle(.red))
                            )
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            HStack(spacing: 6) {
                                Text("@")
                                    .foregroundStyle(.secondary)

                                TextField(
                                    "",
                                    text: $username,
                                    prompt:
                                        (Text("username")
                                            .foregroundStyle(.secondary)
                                         +
                                         Text(" *")
                                            .foregroundStyle(.red))
                                )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            if let usernameError {
                                Text(usernameError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                ProfileSettingsBackgroundSection(
                    homeCountries: homeCountries,
                    currentCountry: currentCountry ?? "",
                    favoriteCountries: favoriteCountries,
                    nextDestination: nextDestination,
                    showHomePicker: $showHomePicker,
                    showCurrentCountryPicker: $showCurrentCountryPicker,
                    showNextDestinationPicker: $showNextDestinationPicker,
                    showFavoriteCountriesPicker: $showFavoriteCountriesPicker
                )

                ProfileSettingsLanguagesSection(
                    languages: $languages,
                    showAddLanguage: $showAddLanguage
                )

                ProfileSettingsTravelSection(
                    travelMode: $travelMode,
                    travelStyle: $travelStyle,
                    showTravelModeDialog: $showTravelModeDialog,
                    showTravelStyleDialog: $showTravelStyleDialog
                )

                // MARK: - Account Actions

                SectionCard {
                    VStack(spacing: 16) {

                        Button(role: .destructive) {
                            onLogout()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Log Out")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(isLoggingOut)

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Account")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(isDeletingAccount)
                        .confirmationDialog(
                            "Are you sure you want to permanently delete your account? This cannot be undone.",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Delete Account", role: .destructive) {
                                Task {
                                    isDeletingAccount = true
                                    do {
                                        try await SupabaseManager.shared.deleteAccount()
                                        sessionManager.handleAccountDeleted()
                                    } catch {
                                        print("❌ Delete account failed:", error)
                                    }
                                    isDeletingAccount = false
                                }
                            }

                            Button("Cancel", role: .cancel) {}
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Spacer(minLength: 40)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }
}
