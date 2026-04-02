//
//  ProfileView.swift
//  TravelScoreriOS
//

import SwiftUI
import NukeUI
import Nuke

extension Color {
    static let gold = Color(red: 0.85, green: 0.68, blue: 0.15)
}

struct LockedProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundColor(.white)

            Text("profile.locked.message")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Notification.Name {
    static let friendshipUpdated = Notification.Name("friendshipUpdated")
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.floatingTabBarInset) private var floatingTabBarInset
    @EnvironmentObject private var socialNav: SocialNavigationController
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var bucketList: BucketListStore
    @EnvironmentObject private var traveled: TraveledStore
    @StateObject private var profileVM: ProfileViewModel
    private let userId: UUID
    private let showsBackButton: Bool
    @State private var showFriendsDrawer = false
    @State private var scrollAnchor: String? = nil
    @State private var selectedCountry: Country? = nil

    init(userId: UUID, showsBackButton: Bool = false) {
        self.userId = userId
        self.showsBackButton = showsBackButton

        // ✅ VM is now single-identity (no rebinding / no stale reuse)
        _profileVM = StateObject(
            wrappedValue: ProfileViewModel(
                userId: userId,
                profileService: ProfileService(supabase: SupabaseManager.shared),
                friendService: FriendService(supabase: SupabaseManager.shared)
            )
        )
    }

    // MARK: - Derived State

    private var username: String { profileVM.profile?.username ?? "" }
    private var homeCountryCodes: [String] { profileVM.profile?.livedCountries ?? [] }
    private var languages: [String] {
        guard let entries = profileVM.profile?.languages else { return [] }

        return entries.map { entry in
            let displayName = LanguageRepository.shared.localizedDisplayName(for: entry.code)
            let proficiency = LanguageProficiency(storageValue: entry.proficiency).label
            return "\(displayName) — \(proficiency)"
        }
    }
    private var mutualLanguageLabels: [String] {
        profileVM.mutualLanguages.map { code in
            LanguageRepository.shared.localizedDisplayName(for: code)
        }
    }
    private var friendCount: Int {
        profileVM.profile?.friendCount ?? 0
    }

    private var isReadyToRenderProfile: Bool {
        profileVM.profile?.id == userId &&
        profileVM.isLoading == false
    }

    private var travelModeLabel: String? {
        guard let raw = profileVM.profile?.travelMode.first,
              let mode = TravelMode(rawValue: raw) else { return nil }
        return mode.label
    }

    private var travelStyleLabel: String? {
        guard let raw = profileVM.profile?.travelStyle.first,
              let style = TravelStyle(rawValue: raw) else { return nil }
        return style.label
    }

    private var nextDestination: String? {
        profileVM.profile?.nextDestination
    }

    private var firstName: String? {
        profileVM.profile?.firstName
    }

    private var navigationTitle: String {
        String(localized: "profile.title")
    }

    private func resolveCountry(for isoCode: String) -> Country {
        let normalizedISO = isoCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if let cached = CountryAPI.loadCachedCountries()?.first(where: { $0.iso2.uppercased() == normalizedISO }) {
            return cached
        }

        let locale = Locale.autoupdatingCurrent
        let countryName = locale.localizedString(forRegionCode: normalizedISO) ?? normalizedISO

        return Country(
            iso2: normalizedISO,
            name: countryName,
            score: nil
        )
    }


    var body: some View {
        GeometryReader { geometry in
            let isCompactWidth = geometry.size.width < 390
            let cardWrapperPadding: CGFloat = isCompactWidth ? 10 : 16
            let contentHorizontalPadding: CGFloat = isCompactWidth ? 14 : 20
            let bottomContentInset = max(floatingTabBarInset + 8, 28)

            ZStack {
                Color.clear

                // 🛡 Strict identity + relationship gate (production-safe)
                if !isReadyToRenderProfile {
                    ProfileLoadingView()
                } else {
                    let relationshipState = profileVM.relationshipState

                    ScrollViewReader { proxy in
                        VStack(spacing: 0) {
                            Theme.titleBanner(navigationTitle)

                            ScrollView {
                                VStack(spacing: 18) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                                            .fill(Color.clear)
                                            .rotationEffect(.degrees(-0.6))
                                            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

                                        ProfileHeaderView(
                                            profile: profileVM.profile,
                                            username: username,
                                            homeCountryCodes: homeCountryCodes,
                                            relationshipState: relationshipState,
                                            onToggleFriend: {
                                                switch relationshipState {
                                                case .friends:
                                                    showFriendsDrawer = true
                                                case .requestSent:
                                                    showFriendsDrawer = true
                                                case .requestReceived:
                                                    Task { await profileVM.toggleFriend() }
                                                case .none:
                                                    Task { await profileVM.toggleFriend() }
                                                case .selfProfile:
                                                    break
                                                }
                                            },
                                            onOpenCountry: { isoCode in
                                                selectedCountry = resolveCountry(for: isoCode)
                                            }
                                        )
                                        .padding(cardWrapperPadding)
                                        .background(
                                            Theme.profileCardBackground(corner: 22)
                                        )
                                    }

                                    if relationshipState == .friends ||
                                        relationshipState == .selfProfile {

                                        ZStack {
                                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                                .fill(Color.clear)
                                                .rotationEffect(.degrees(-0.4))
                                                .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

                                            ProfileInfoSection(
                                                relationshipState: relationshipState,
                                                viewedTraveledCountries: profileVM.viewedTraveledCountries,
                                                viewedBucketListCountries: profileVM.viewedBucketListCountries,
                                                orderedTraveledCountries: profileVM.orderedTraveledCountries,
                                                orderedBucketListCountries: profileVM.orderedBucketListCountries,
                                                mutualTraveledCountries: profileVM.mutualTraveledCountries,
                                                mutualBucketCountries: profileVM.mutualBucketCountries,
                                                mutualLanguages: mutualLanguageLabels,
                                                languages: languages,
                                                travelMode: travelModeLabel,
                                                travelStyle: travelStyleLabel,
                                                nextDestination: nextDestination,
                                                currentCountry: profileVM.profile?.currentCountry,
                                                favoriteCountries: profileVM.profile?.favoriteCountries ?? []
                                            )
                                            .padding(cardWrapperPadding)
                                            .background(
                                                Theme.profileCardBackground(corner: 22)
                                            )
                                        }

                                    } else {
                                        LockedProfileView()
                                            .padding(.top, 40)
                                    }
                                }
                                .id("profileTop")
                                .padding(.horizontal, contentHorizontalPadding)
                                .padding(.top, 6)
                                .padding(.bottom, bottomContentInset)
                            }
                            .refreshable {
                                await profileVM.reloadProfile()
                            }
                            .navigationDestination(item: $selectedCountry) { country in
                                CountryDetailView(country: country)
                            }
                            .background(Color.clear)
                            .sheet(isPresented: $showFriendsDrawer) {
                                FriendsSection(
                                    relationshipState: relationshipState,
                                    friendCount: friendCount,
                                    onToggleFriend: {
                                        Task {
                                            await profileVM.toggleFriend()
                                        }
                                    },
                                    onCancelRequest: {
                                        Task {
                                            await profileVM.toggleFriend()
                                        }
                                    },
                                    onViewFriends: {
                                        showFriendsDrawer = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            socialNav.push(.friends(userId))
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                VStack {
                    HStack {
                        if showsBackButton {
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

                        Spacer()

                        if SupabaseManager.shared.currentUserId == userId {
                            NavigationLink {
                                ProfileSettingsView(
                                    profileVM: profileVM,
                                    viewedUserId: userId
                                )
                            } label: {
                                ZStack {
                                    Theme.chromeIconButtonBackground(size: 40)
                                    Image(systemName: "gearshape")
                                        .font(TAFTypography.title(.bold))
                                        .foregroundStyle(.black)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()
                }
            }
        }
        .background(
            Theme.pageBackground("travel4")
                .ignoresSafeArea()
        )
        .id(userId)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // 🔒 Only load if no profile is currently bound
            guard profileVM.profile == nil else {
                
                return
            }

            Task {
                await profileVM.loadIfNeeded()
            }
        }
        .onDisappear {
        }
    }
}
