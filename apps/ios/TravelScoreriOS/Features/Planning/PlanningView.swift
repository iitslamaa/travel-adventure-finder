//
//  PlanningView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/5/26.
//

import SwiftUI
import Combine
import CryptoKit
import EventKit
import EventKitUI
import UIKit
import NukeUI
import Supabase
import PostgREST

private enum TripPlannerDebugLog {
    nonisolated static func message(_ text: String) {
#if DEBUG
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        print("🧭 [TripPlanner] \(timestamp) \(text)")
#endif
    }

    nonisolated static func userLabel(_ userId: UUID?) -> String {
        userId?.uuidString ?? "nil-user"
    }

    nonisolated static func tripLabel(_ trip: TripPlannerTrip) -> String {
        "\(trip.title) [\(trip.id.uuidString)]"
    }

    nonisolated static func participantLabels(for ids: [UUID]) -> String {
        ids.map(\.uuidString).joined(separator: ", ")
    }

    nonisolated static func durationText(since startTime: TimeInterval) -> String {
        String(format: "%.0fms", (Date().timeIntervalSinceReferenceDate - startTime) * 1000)
    }

    nonisolated static func probe(_ name: String, _ detail: String = "") {
        let suffix = detail.isEmpty ? "" : " \(detail)"
        message("PROBE \(name)\(suffix)")
    }

    nonisolated static func tripCardState(
        trip: TripPlannerTrip,
        ownerSnapshot: TripPlannerFriendSnapshot?,
        travelerCount: Int
    ) -> String {
        let ownerState: String
        if let ownerSnapshot {
            ownerState = "owner=\(ownerSnapshot.displayName)"
        } else if trip.ownerId != nil {
            ownerState = "owner=missing"
        } else {
            ownerState = "owner=none"
        }

        return "\(tripLabel(trip)) \(ownerState) travelers=\(travelerCount) countries=\(trip.countryIds.count)"
    }
}

extension Notification.Name {
    static let sharedTripsUpdated = Notification.Name("sharedTripsUpdated")
}

struct SharedTripInboxEntry: Identifiable, Equatable {
    let trip: TripPlannerTrip

    var id: UUID { trip.id }
}

@MainActor
final class SharedTripInboxStore: ObservableObject {
    @Published private(set) var notifications: [SharedTripInboxEntry] = []

    private let supabase = SupabaseManager.shared
    private let syncService = TripPlannerSyncService(supabase: SupabaseManager.shared)
    private var cancellables = Set<AnyCancellable>()
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var subscribedUserId: UUID?
    private var isRealtimeActive = false

    init() {
        TripPlannerDebugLog.probe("SharedTripInbox.init.start")
        observeAuthState()
        observeTripUpdates()

        Task {
            TripPlannerDebugLog.probe("SharedTripInbox.init.refresh_task.start")
            await refresh()
            TripPlannerDebugLog.probe("SharedTripInbox.init.refresh_task.end", "pending=\(notifications.count)")
        }
        TripPlannerDebugLog.probe("SharedTripInbox.init.end")
    }

    var pendingCount: Int {
        notifications.count
    }

    func refresh() async {
        let start = Date().timeIntervalSinceReferenceDate
        guard let userId = supabase.currentUserId else {
            notifications = []
            TripPlannerDebugLog.probe(
                "SharedTripInbox.refresh.no_user",
                "duration=\(TripPlannerDebugLog.durationText(since: start))"
            )
            return
        }

        TripPlannerDebugLog.probe(
            "SharedTripInbox.refresh.start",
            "user=\(TripPlannerDebugLog.userLabel(userId))"
        )

        do {
            let trips = try await syncService.fetchTrips(userId: userId)
            applyPrefetchedTrips(trips, for: userId)
            TripPlannerDebugLog.probe(
                "SharedTripInbox.refresh.end",
                "duration=\(TripPlannerDebugLog.durationText(since: start)) fetched=\(trips.count) pending=\(notifications.count)"
            )
        } catch {
            print("❌ Shared trip inbox refresh failed:", error)
            notifications = []
            TripPlannerDebugLog.probe(
                "SharedTripInbox.refresh.failed",
                "duration=\(TripPlannerDebugLog.durationText(since: start)) error=\(String(describing: error))"
            )
        }
    }

    func refresh(using trips: [TripPlannerTrip], userId: UUID) {
        let start = Date().timeIntervalSinceReferenceDate
        applyPrefetchedTrips(trips, for: userId)
        TripPlannerDebugLog.probe(
            "SharedTripInbox.refresh.prefetched",
            "user=\(TripPlannerDebugLog.userLabel(userId)) trips=\(trips.count) pending=\(notifications.count) duration=\(TripPlannerDebugLog.durationText(since: start))"
        )
    }

    func markSeen(tripId: UUID) {
        guard let userId = supabase.currentUserId else { return }

        var ids = seenSharedTripIDs(for: userId)
        ids.insert(tripId.uuidString)
        UserDefaults.standard.set(Array(ids), forKey: seenKey(for: userId))
        notifications.removeAll { $0.trip.id == tripId }
    }

    private func observeAuthState() {
        supabase.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                Task {
                    await self.updateRealtimeConnection(isActive: self.isRealtimeActive)
                    await self.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func observeTripUpdates() {
        NotificationCenter.default.publisher(for: .sharedTripsUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func seenSharedTripIDs(for userId: UUID) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: seenKey(for: userId)) ?? [])
    }

    private func applyPrefetchedTrips(_ trips: [TripPlannerTrip], for userId: UUID) {
        let seenTripIDs = seenSharedTripIDs(for: userId)

        notifications = trips
            .filter { trip in
                trip.ownerId != nil
                    && trip.ownerId != userId
                    && !seenTripIDs.contains(trip.id.uuidString)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map(SharedTripInboxEntry.init)

        TripPlannerDebugLog.message(
            "Inbox refresh for \(TripPlannerDebugLog.userLabel(userId)) fetched \(trips.count) trips, pending notifications=\(notifications.count)"
        )
    }

    private func seenKey(for userId: UUID) -> String {
        "trip_planner_seen_shared_trip_ids_\(userId.uuidString)"
    }

    func updateRealtimeConnection(isActive: Bool) async {
        isRealtimeActive = isActive

        guard isActive else {
            await tearDownRealtimeSubscription()
            return
        }

        await configureRealtimeSubscription()
    }

    private func configureRealtimeSubscription() async {
        guard let userId = supabase.currentUserId else { return }
        guard realtimeChannel == nil || subscribedUserId != userId else { return }

        await tearDownRealtimeSubscription()

        TripPlannerDebugLog.message("Configuring realtime subscription for \(TripPlannerDebugLog.userLabel(userId))")

        let channel = supabase.client.channel("shared-trip-inbox-\(userId.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_trip_plans",
            filter: .eq("user_id", value: userId)
        )

        do {
            try await channel.subscribeWithError()
            realtimeChannel = channel
            subscribedUserId = userId
            TripPlannerDebugLog.message("Realtime subscribed for \(TripPlannerDebugLog.userLabel(userId))")
            realtimeTask = Task {
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    TripPlannerDebugLog.message("Realtime change received for \(TripPlannerDebugLog.userLabel(userId))")
                    await TripPlannerSyncService.invalidateCache(for: [userId])
                    await MainActor.run {
                        NotificationCenter.default.post(name: .sharedTripsUpdated, object: nil)
                    }
                }
            }
        } catch {
            print("❌ Shared trip realtime subscribe failed:", error)
            await supabase.client.removeChannel(channel)
        }
    }

    private func tearDownRealtimeSubscription() async {
        realtimeTask?.cancel()
        realtimeTask = nil

        if let realtimeChannel {
            await supabase.client.removeChannel(realtimeChannel)
            self.realtimeChannel = nil
        }

        subscribedUserId = nil
    }

    deinit {
        let channel = realtimeChannel
        let client = supabase.client
        realtimeTask?.cancel()
        if let channel {
            Task {
                await client.removeChannel(channel)
            }
        }
    }
}

enum PlanningListKind {
    case bucket
    case visited

    var title: String {
        switch self {
        case .bucket: return String(localized: "planning.bucket_list.title")
        case .visited: return String(localized: "planning.visited.title")
        }
    }

    var shortTitle: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.short")
        case .visited: return String(localized: "planning.list_kind.visited.short")
        }
    }

    var subtitle: String {
        switch self {
        case .bucket: return String(localized: "planning.bucket_list.subtitle")
        case .visited: return String(localized: "planning.visited.subtitle")
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
        case .bucket: return String(localized: "planning.list_kind.bucket.other_label")
        case .visited: return String(localized: "planning.list_kind.visited.other_label")
        }
    }

    var otherListName: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.visited.short")
        case .visited: return String(localized: "planning.list_kind.bucket.short")
        }
    }

    var pickerTitle: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.picker_title")
        case .visited: return String(localized: "planning.list_kind.visited.picker_title")
        }
    }

    var pickerSubtitle: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.picker_subtitle")
        case .visited: return String(localized: "planning.list_kind.visited.picker_subtitle")
        }
    }

    var navigationTitle: String {
        switch self {
        case .bucket: return "🪣 \(String(localized: "planning.bucket_list.title"))"
        case .visited: return "🎒 \(String(localized: "planning.visited.title"))"
        }
    }

    var emptyTitle: String {
        switch self {
        case .bucket: return String(localized: "planning.list_kind.bucket.empty_title")
        case .visited: return String(localized: "planning.list_kind.visited.empty_title")
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
        case .bucket: return String(localized: "planning.list_kind.bucket.empty_description")
        case .visited: return String(localized: "planning.list_kind.visited.empty_description")
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
    @EnvironmentObject private var sharedTripInbox: SharedTripInboxStore
    @State private var scrollAnchor: String? = nil

    var body: some View {
        VStack(spacing: 0) {

            Theme.titleBanner(String(localized: "planning.title"))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {

                        NavigationLink {
                            BucketListView()
                        } label: {
                            PlanningCard(
                                title: String(localized: "planning.bucket_list.title"),
                                subtitle: String(localized: "planning.bucket_list.subtitle"),
                                icon: "bookmark"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MyTravelsView()
                        } label: {
                            PlanningCard(
                                title: String(localized: "planning.visited.title"),
                                subtitle: String(localized: "planning.visited.subtitle"),
                                icon: "checkmark.circle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TripPlannerDebugProbeView("plan.destination_builder")
                            TripPlannerLazyDestination {
                                TripPlannerDebugProbeView("plan.lazy_destination_body")
                                TripPlannerView()
                                    .environmentObject(sharedTripInbox)
                            }
                        } label: {
                            PlanningCard(
                                title: String(localized: "planning.trip_planner.title"),
                                subtitle: String(localized: "planning.trip_planner.subtitle"),
                                icon: "airplane.departure"
                            )
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            TripPlannerDebugLog.probe(
                                "plan.tap",
                                "pendingInbox=\(sharedTripInbox.notifications.count)"
                            )
                        })

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

private struct TripPlannerNavigationChrome<Trailing: View>: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let showsBackButton: Bool
    let trailing: Trailing

    init(
        showsBackButton: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.showsBackButton = showsBackButton
        self.trailing = trailing()
    }

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
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

                    trailing
                }
                .padding(.horizontal, Theme.pageHorizontalInset)
                .padding(.top, 12)
            }
    }
}

private extension View {
    func tripPlannerNavigationChrome<Trailing: View>(
        showsBackButton: Bool = true,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        modifier(
            TripPlannerNavigationChrome(
                showsBackButton: showsBackButton,
                trailing: trailing
            )
        )
    }
}

private struct TripPlannerLazyDestination<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        let _ = TripPlannerDebugLog.probe("TripPlannerLazyDestination.body")
        content()
    }
}

private struct TripPlannerDebugProbeView: View {
    init(_ name: String, _ detail: String = "") {
        TripPlannerDebugLog.probe(name, detail)
    }

    var body: some View {
        EmptyView()
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
            ? String(format: String(localized: "planning.country_toggle.remove_format"), locale: AppDisplayLocale.current, kind.shortTitle)
            : String(format: String(localized: "planning.country_toggle.add_format"), locale: AppDisplayLocale.current, kind.shortTitle)
        )
    }
}

struct PlanningCountryPickerView: View {
    let kind: PlanningListKind
    let countries: [Country]
    let selectedIds: Set<String>
    let otherSelectedIds: Set<String>
    let onSave: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var sort: CountrySort = .name
    @State private var sortOrder: SortOrder = .ascending
    @State private var draftSelectedIds: Set<String>
    @State private var isSaving = false

    init(
        kind: PlanningListKind,
        countries: [Country],
        selectedIds: Set<String>,
        otherSelectedIds: Set<String>,
        onSave: @escaping (Set<String>) -> Void
    ) {
        self.kind = kind
        self.countries = countries
        self.selectedIds = selectedIds
        self.otherSelectedIds = otherSelectedIds
        self.onSave = onSave
        _draftSelectedIds = State(initialValue: selectedIds)
    }

    private var hasChanges: Bool {
        draftSelectedIds != selectedIds
    }

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

                Button {
                    isSaving = true
                    onSave(draftSelectedIds)
                    dismiss()
                } label: {
                    Text(isSaving ? String(localized: "common.saving") : String(localized: "common.save"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(hasChanges ? Theme.accent : Color.gray.opacity(0.55))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasChanges || isSaving)
                .opacity(hasChanges ? 1 : 0.5)
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
                    selectedIds: draftSelectedIds,
                    otherSelectedIds: otherSelectedIds,
                    onSelect: { country in
                        if draftSelectedIds.contains(country.id) {
                            draftSelectedIds.remove(country.id)
                        } else {
                            draftSelectedIds.insert(country.id)
                        }
                    }
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

struct TripPlannerFriendSnapshot: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarURL: String?

    init(
        id: UUID,
        displayName: String,
        username: String,
        avatarURL: String?
    ) {
        self.id = id
        self.displayName = Self.normalizedTripDisplayName(displayName, username: username)
        self.username = username
        self.avatarURL = avatarURL
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case username
        case avatarURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let rawDisplayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        username = try container.decode(String.self, forKey: .username)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        displayName = Self.normalizedTripDisplayName(rawDisplayName, username: username)
    }

    private static func normalizedTripDisplayName(_ rawDisplayName: String, username: String) -> String {
        let trimmed = rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains(",") {
            let commaSeparatedParts = trimmed
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if commaSeparatedParts.count >= 2 {
                let preferred = commaSeparatedParts[1]
                if let firstWord = preferred.split(whereSeparator: \.isWhitespace).first {
                    return String(firstWord)
                }
            }
        }

        if let firstWord = trimmed.split(whereSeparator: \.isWhitespace).first, !firstWord.isEmpty {
            return String(firstWord)
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUsername.isEmpty ? "Traveler" : trimmedUsername
    }

    static func currentUserFallback(userId: UUID) -> TripPlannerFriendSnapshot {
        return TripPlannerFriendSnapshot(
            id: userId,
            displayName: String(localized: "trip_planner.you"),
            username: "traveler",
            avatarURL: nil
        )
    }
}

enum TripPlannerAvailabilityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case exactDates
    case flexibleMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exactDates:
            return String(localized: "trip_planner.availability.kind.exact_dates")
        case .flexibleMonth:
            return String(localized: "trip_planner.availability.kind.flexible_month")
        }
    }

    var subtitle: String {
        switch self {
        case .exactDates:
            return String(localized: "trip_planner.availability.kind.exact_dates_subtitle")
        case .flexibleMonth:
            return String(localized: "trip_planner.availability.kind.flexible_month_subtitle")
        }
    }
}

struct TripPlannerAvailabilityProposal: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let participantId: String
    let participantName: String
    let participantUsername: String?
    let participantAvatarURL: String?
    let kind: TripPlannerAvailabilityKind
    let startDate: Date
    let endDate: Date

    init(
        id: UUID = UUID(),
        participantId: String,
        participantName: String,
        participantUsername: String?,
        participantAvatarURL: String?,
        kind: TripPlannerAvailabilityKind,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.participantId = participantId
        self.participantName = participantName
        self.participantUsername = participantUsername
        self.participantAvatarURL = participantAvatarURL
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case participantId
        case participantName
        case participantUsername
        case participantAvatarURL
        case kind
        case startDate
        case endDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        participantId = try container.decode(String.self, forKey: .participantId)
        participantName = try container.decode(String.self, forKey: .participantName)
        participantUsername = try container.decodeIfPresent(String.self, forKey: .participantUsername)
        participantAvatarURL = try container.decodeIfPresent(String.self, forKey: .participantAvatarURL)
        kind = try container.decode(TripPlannerAvailabilityKind.self, forKey: .kind)
        startDate = try container.decodeFlexibleDate(forKey: .startDate)
        endDate = try container.decodeFlexibleDate(forKey: .endDate)
    }
}

enum TripPlannerDayPlanKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case country
    case travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .country: return String(localized: "trip_planner.itinerary.country")
        case .travel: return String(localized: "trip_planner.itinerary.travel")
        }
    }
}

enum TripPlannerChecklistCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case accommodation
    case attractionTickets
    case transportBooking
    case reservation
    case visa
    case insurance
    case packing
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accommodation: return "Accommodation"
        case .attractionTickets: return "Attraction tickets"
        case .transportBooking: return "Transport booking"
        case .reservation: return "Reservation"
        case .visa: return "Visa"
        case .insurance: return "Insurance"
        case .packing: return "Packing list"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .accommodation: return "bed.double.fill"
        case .attractionTickets: return "ticket.fill"
        case .transportBooking: return "tram.fill"
        case .reservation: return "fork.knife"
        case .visa: return "globe"
        case .insurance: return "cross.case.fill"
        case .packing: return "suitcase.rolling.fill"
        case .custom: return "checklist"
        }
    }
}

struct TripPlannerChecklistItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let category: TripPlannerChecklistCategory
    let title: String
    let notes: String
    let expenseSourceItemId: UUID?
    let linkedExpenseId: UUID?
    let linkedExpenseAmount: Double?
    let linkedExpenseCurrencyCode: String?
    let linkedExpenseDate: Date?
    let isCompleted: Bool
    let completedById: String?
    let completedByName: String?
    let completedAt: Date?

    init(
        id: UUID = UUID(),
        category: TripPlannerChecklistCategory,
        title: String,
        notes: String = "",
        expenseSourceItemId: UUID? = nil,
        linkedExpenseId: UUID? = nil,
        linkedExpenseAmount: Double? = nil,
        linkedExpenseCurrencyCode: String? = nil,
        linkedExpenseDate: Date? = nil,
        isCompleted: Bool = false,
        completedById: String? = nil,
        completedByName: String? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.notes = notes
        self.expenseSourceItemId = expenseSourceItemId
        self.linkedExpenseId = linkedExpenseId
        self.linkedExpenseAmount = linkedExpenseAmount
        self.linkedExpenseCurrencyCode = AppCurrencyCatalog.normalizedCode(linkedExpenseCurrencyCode)
        self.linkedExpenseDate = linkedExpenseDate
        self.isCompleted = isCompleted
        self.completedById = completedById
        self.completedByName = completedByName
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case title
        case notes
        case expenseSourceItemId
        case linkedExpenseId
        case linkedExpenseAmount
        case linkedExpenseCurrencyCode
        case linkedExpenseDate
        case isCompleted
        case completedById
        case completedByName
        case completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decodeIfPresent(TripPlannerChecklistCategory.self, forKey: .category) ?? .custom
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        expenseSourceItemId = try container.decodeIfPresent(UUID.self, forKey: .expenseSourceItemId)
        linkedExpenseId = try container.decodeIfPresent(UUID.self, forKey: .linkedExpenseId)
        linkedExpenseAmount = try container.decodeIfPresent(Double.self, forKey: .linkedExpenseAmount)
        linkedExpenseCurrencyCode = AppCurrencyCatalog.normalizedCode(
            try container.decodeIfPresent(String.self, forKey: .linkedExpenseCurrencyCode)
        )
        linkedExpenseDate = try container.decodeFlexibleDateIfPresent(forKey: .linkedExpenseDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedById = try container.decodeIfPresent(String.self, forKey: .completedById)
        completedByName = try container.decodeIfPresent(String.self, forKey: .completedByName)
        completedAt = try container.decodeFlexibleDateIfPresent(forKey: .completedAt)
    }

    func updatedCompletion(
        isCompleted: Bool,
        actorId: UUID?,
        actorName: String
    ) -> TripPlannerChecklistItem {
        TripPlannerChecklistItem(
            id: id,
            category: category,
            title: title,
            notes: notes,
            expenseSourceItemId: expenseSourceItemId,
            linkedExpenseId: linkedExpenseId,
            linkedExpenseAmount: linkedExpenseAmount,
            linkedExpenseCurrencyCode: linkedExpenseCurrencyCode,
            linkedExpenseDate: linkedExpenseDate,
            isCompleted: isCompleted,
            completedById: isCompleted ? actorId?.uuidString : nil,
            completedByName: isCompleted ? actorName : nil,
            completedAt: isCompleted ? Date() : nil
        )
    }

    func updatedNotes(_ notes: String) -> TripPlannerChecklistItem {
        TripPlannerChecklistItem(
            id: id,
            category: category,
            title: title,
            notes: notes,
            expenseSourceItemId: expenseSourceItemId,
            linkedExpenseId: linkedExpenseId,
            linkedExpenseAmount: linkedExpenseAmount,
            linkedExpenseCurrencyCode: linkedExpenseCurrencyCode,
            linkedExpenseDate: linkedExpenseDate,
            isCompleted: isCompleted,
            completedById: completedById,
            completedByName: completedByName,
            completedAt: completedAt
        )
    }

    func updatedTitle(_ title: String) -> TripPlannerChecklistItem {
        TripPlannerChecklistItem(
            id: id,
            category: category,
            title: title,
            notes: notes,
            expenseSourceItemId: expenseSourceItemId,
            linkedExpenseId: linkedExpenseId,
            linkedExpenseAmount: linkedExpenseAmount,
            linkedExpenseCurrencyCode: linkedExpenseCurrencyCode,
            linkedExpenseDate: linkedExpenseDate,
            isCompleted: isCompleted,
            completedById: completedById,
            completedByName: completedByName,
            completedAt: completedAt
        )
    }

    func updatedExpenseLink(
        expenseId: UUID?,
        amount: Double?,
        currencyCode: String?,
        date: Date?
    ) -> TripPlannerChecklistItem {
        updatedExpenseSync(
            sourceItemId: expenseSourceItemId,
            expenseId: expenseId,
            amount: amount,
            currencyCode: currencyCode,
            date: date
        )
    }

    func updatedExpenseSync(
        sourceItemId: UUID?,
        expenseId: UUID?,
        amount: Double?,
        currencyCode: String?,
        date: Date?
    ) -> TripPlannerChecklistItem {
        TripPlannerChecklistItem(
            id: id,
            category: category,
            title: title,
            notes: notes,
            expenseSourceItemId: sourceItemId,
            linkedExpenseId: expenseId,
            linkedExpenseAmount: amount,
            linkedExpenseCurrencyCode: currencyCode,
            linkedExpenseDate: date,
            isCompleted: isCompleted,
            completedById: completedById,
            completedByName: completedByName,
            completedAt: completedAt
        )
    }

    var supportsExpenseTracking: Bool {
        switch category {
        case .visa, .packing:
            return false
        case .accommodation, .attractionTickets, .transportBooking, .reservation, .insurance, .custom:
            return true
        }
    }

    var expenseSyncKey: UUID {
        expenseSourceItemId ?? id
    }

    var hasLinkedExpenseDetails: Bool {
        linkedExpenseAmount != nil || linkedExpenseId != nil
    }

    func duplicatedForNewChecklistEntry() -> TripPlannerChecklistItem {
        TripPlannerChecklistItem(
            category: category,
            title: title,
            notes: notes,
            linkedExpenseCurrencyCode: linkedExpenseCurrencyCode,
            isCompleted: false,
            completedById: nil,
            completedByName: nil,
            completedAt: nil
        )
    }
}

struct TripPlannerPackingEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var note: String

    init(id: UUID = UUID(), title: String, note: String = "") {
        self.id = id
        self.title = title
        self.note = note
    }
}

struct TripPlannerPackingProgress: Codable, Identifiable, Hashable, Sendable {
    let userKey: String
    let userName: String
    let checkedEntryIDs: [UUID]

    var id: String { userKey }

    init(userKey: String, userName: String, checkedEntryIDs: [UUID] = []) {
        self.userKey = userKey
        self.userName = userName
        self.checkedEntryIDs = checkedEntryIDs
    }

    func updatedCheckedEntryIDs(_ ids: Set<UUID>) -> TripPlannerPackingProgress {
        TripPlannerPackingProgress(
            userKey: userKey,
            userName: userName,
            checkedEntryIDs: ids.sorted { $0.uuidString < $1.uuidString }
        )
    }
}

private enum TripPlannerPackingCodec {
    private static let fieldSeparator = "||"

    static func decodeEntries(from notes: String) -> [TripPlannerPackingEntry] {
        notes
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine in
                let raw = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else { return nil }

                let parts = raw.components(separatedBy: fieldSeparator)

                if parts.count >= 3, let id = UUID(uuidString: parts[0]) {
                    let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { return nil }
                    let note = parts.dropFirst(2).joined(separator: fieldSeparator)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return TripPlannerPackingEntry(id: id, title: title, note: note)
                }

                let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !title.isEmpty else { return nil }
                let note = parts.count > 1
                    ? parts.dropFirst().joined(separator: fieldSeparator).trimmingCharacters(in: .whitespacesAndNewlines)
                    : ""
                return TripPlannerPackingEntry(
                    id: stableLegacyID(for: raw),
                    title: title,
                    note: note
                )
            }
    }

    static func encodeEntries(_ entries: [TripPlannerPackingEntry]) -> String {
        entries
            .map { entry in
                [
                    entry.id.uuidString,
                    entry.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
                ].joined(separator: fieldSeparator)
            }
            .joined(separator: "\n")
    }

    static func sanitizedProgressEntries(
        _ progressEntries: [TripPlannerPackingProgress],
        sharedEntries: [TripPlannerPackingEntry]
    ) -> [TripPlannerPackingProgress] {
        let validIDs = Set(sharedEntries.map(\.id))
        return progressEntries.map { progress in
            let keptIDs = Set(progress.checkedEntryIDs).intersection(validIDs)
            return progress.updatedCheckedEntryIDs(keptIDs)
        }
    }

    private static func stableLegacyID(for raw: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(raw.utf8))
        let bytes = Array(digest)
        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidBytes)
    }
}

private enum TripPlannerChecklistTemplates {
    static let accommodationTitle = "Accommodation"
    static let transportationTitle = "Transportation"
    static let visaTitle = "Apply for visas"
    static let packingTitle = "What to pack"
    static let packingSuggestions = [
        "Passport",
        "Camera",
        "Phone charger",
        "Travel adapter",
        "Medication",
        "Comfortable shoes",
        "Rain layer",
        "Toiletries",
        "Earplugs",
        "Headphones",
        "Sunscreen",
        "Eye mask",
        "Slippers"
    ]

    static let daySuggestions: [TripPlannerChecklistItem] = [
        TripPlannerChecklistItem(category: .attractionTickets, title: "Book attraction tickets"),
        TripPlannerChecklistItem(category: .transportBooking, title: "Book transport in advance"),
        TripPlannerChecklistItem(category: .reservation, title: "Reserve a restaurant or experience")
    ]

    static func defaultAccommodationItem() -> TripPlannerChecklistItem {
        TripPlannerChecklistItem(category: .accommodation, title: accommodationTitle)
    }

    static func defaultTransportationItem() -> TripPlannerChecklistItem {
        TripPlannerChecklistItem(category: .transportBooking, title: transportationTitle)
    }

    static func defaultPackingItem(existing: TripPlannerChecklistItem? = nil) -> TripPlannerChecklistItem {
        TripPlannerChecklistItem(
            id: existing?.id ?? UUID(),
            category: .packing,
            title: packingTitle,
            notes: existing?.notes ?? "",
            isCompleted: false,
            completedById: nil,
            completedByName: nil,
            completedAt: nil
        )
    }
}

struct TripPlannerDayPlan: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let kind: TripPlannerDayPlanKind
    let countryId: String?
    let countryName: String?
    let checklistItems: [TripPlannerChecklistItem]

    init(
        id: UUID = UUID(),
        date: Date,
        kind: TripPlannerDayPlanKind,
        countryId: String? = nil,
        countryName: String? = nil,
        checklistItems: [TripPlannerChecklistItem] = []
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.kind = kind
        self.countryId = countryId
        self.countryName = countryName
        self.checklistItems = checklistItems
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case kind
        case countryId
        case countryName
        case checklistItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = Calendar.current.startOfDay(for: try container.decodeFlexibleDate(forKey: .date))
        kind = try container.decode(TripPlannerDayPlanKind.self, forKey: .kind)
        countryId = try container.decodeIfPresent(String.self, forKey: .countryId)
        countryName = try container.decodeIfPresent(String.self, forKey: .countryName)
        checklistItems = try container.decodeIfPresent([TripPlannerChecklistItem].self, forKey: .checklistItems) ?? []
    }
}

enum TripPlannerExpenseCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case accommodation
    case food
    case transportation
    case activities
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accommodation: return "Accommodation"
        case .food: return "Food"
        case .transportation: return "Transportation"
        case .activities: return "Activities"
        case .other: return "Other"
        }
    }

    var tintColor: Color {
        switch self {
        case .accommodation:
            return Color(red: 0.71, green: 0.45, blue: 0.22)
        case .food:
            return Color(red: 0.78, green: 0.36, blue: 0.24)
        case .transportation:
            return Color(red: 0.20, green: 0.47, blue: 0.62)
        case .activities:
            return Color(red: 0.22, green: 0.54, blue: 0.38)
        case .other:
            return Color(red: 0.39, green: 0.39, blue: 0.42)
        }
    }

    var backgroundTint: Color {
        tintColor.opacity(0.14)
    }

    var suggestedSplitMode: TripPlannerExpenseSplitMode {
        switch self {
        case .accommodation:
            return .everyone
        case .food, .transportation, .activities, .other:
            return .selectedPeople
        }
    }

    var splitGuidance: String {
        switch self {
        case .accommodation:
            return "Good for hotels or stays that usually get split across the people sharing them."
        case .food:
            return "Food is usually per person, so pick exactly who this meal covered."
        case .transportation:
            return "Transport is often only for the riders on that segment."
        case .activities:
            return "Use this for tours, events, or anything booked for specific travelers."
        case .other:
            return "Choose who should share this cost."
        }
    }
}

enum TripPlannerExpenseSplitMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case everyone
    case selectedPeople

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyone: return String(localized: "trip_planner.expenses.split_mode.everyone")
        case .selectedPeople: return String(localized: "trip_planner.expenses.split_mode.selected")
        }
    }
}

enum TripPlannerExpensePaymentMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case venmo
    case applePay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return String(localized: "trip_planner.expenses.manual")
        case .venmo: return String(localized: "trip_planner.expenses.venmo")
        case .applePay: return String(localized: "trip_planner.expenses.apple_pay")
        }
    }
}

struct TripPlannerExpenseShare: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let participantId: String
    let participantName: String
    let participantUsername: String?
    let amountOwed: Double
    let isPaid: Bool
    let paymentMethod: TripPlannerExpensePaymentMethod?

    init(
        id: UUID = UUID(),
        participantId: String,
        participantName: String,
        participantUsername: String?,
        amountOwed: Double,
        isPaid: Bool = false,
        paymentMethod: TripPlannerExpensePaymentMethod? = nil
    ) {
        self.id = id
        self.participantId = participantId
        self.participantName = participantName
        self.participantUsername = participantUsername
        self.amountOwed = amountOwed
        self.isPaid = isPaid
        self.paymentMethod = paymentMethod
    }
}

struct TripPlannerExpense: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let linkedChecklistItemId: UUID?
    let category: TripPlannerExpenseCategory
    let customCategoryName: String?
    let entryCurrencyCode: String?
    let title: String
    let totalAmount: Double
    let paidById: String
    let paidByName: String
    let paidByUsername: String?
    let splitMode: TripPlannerExpenseSplitMode
    let date: Date
    let participantIds: [String]
    let participantNames: [String]
    let shares: [TripPlannerExpenseShare]

    init(
        id: UUID = UUID(),
        linkedChecklistItemId: UUID? = nil,
        category: TripPlannerExpenseCategory = .other,
        customCategoryName: String? = nil,
        entryCurrencyCode: String? = nil,
        title: String,
        totalAmount: Double,
        paidById: String,
        paidByName: String,
        paidByUsername: String?,
        splitMode: TripPlannerExpenseSplitMode,
        date: Date = Date(),
        participantIds: [String],
        participantNames: [String],
        shares: [TripPlannerExpenseShare]
    ) {
        self.id = id
        self.linkedChecklistItemId = linkedChecklistItemId
        self.category = category
        let trimmedCustomCategory = customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.customCategoryName = trimmedCustomCategory.isEmpty ? nil : trimmedCustomCategory
        self.entryCurrencyCode = AppCurrencyCatalog.normalizedCode(entryCurrencyCode)
        self.title = title
        self.totalAmount = totalAmount
        self.paidById = paidById
        self.paidByName = paidByName
        self.paidByUsername = paidByUsername
        self.splitMode = splitMode
        self.date = date
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.shares = shares
    }

    enum CodingKeys: String, CodingKey {
        case id
        case linkedChecklistItemId
        case category
        case customCategoryName
        case entryCurrencyCode
        case title
        case totalAmount
        case paidById
        case paidByName
        case paidByUsername
        case splitMode
        case date
        case participantIds
        case participantNames
        case shares
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        linkedChecklistItemId = try container.decodeIfPresent(UUID.self, forKey: .linkedChecklistItemId)
        category = try container.decodeIfPresent(TripPlannerExpenseCategory.self, forKey: .category) ?? .other
        let rawCustomCategoryName = try container.decodeIfPresent(String.self, forKey: .customCategoryName) ?? ""
        customCategoryName = rawCustomCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : rawCustomCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        entryCurrencyCode = AppCurrencyCatalog.normalizedCode(
            try container.decodeIfPresent(String.self, forKey: .entryCurrencyCode)
        )
        title = try container.decode(String.self, forKey: .title)
        totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        paidById = try container.decode(String.self, forKey: .paidById)
        paidByName = try container.decode(String.self, forKey: .paidByName)
        paidByUsername = try container.decodeIfPresent(String.self, forKey: .paidByUsername)
        splitMode = try container.decode(TripPlannerExpenseSplitMode.self, forKey: .splitMode)
        date = try container.decodeFlexibleDate(forKey: .date)
        participantIds = try container.decode([String].self, forKey: .participantIds)
        participantNames = try container.decode([String].self, forKey: .participantNames)
        shares = try container.decode([TripPlannerExpenseShare].self, forKey: .shares)
    }
}

struct TripPlannerTrip: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let title: String
    let notes: String
    let startDate: Date?
    let endDate: Date?
    let countryIds: [String]
    let countryNames: [String]
    let friendIds: [UUID]
    let friendNames: [String]
    let friends: [TripPlannerFriendSnapshot]
    let ownerId: UUID?
    let ownerSnapshot: TripPlannerFriendSnapshot?
    let plannerCurrencyCode: String?
    let availability: [TripPlannerAvailabilityProposal]
    let dayPlans: [TripPlannerDayPlan]
    let overallChecklistItems: [TripPlannerChecklistItem]
    let packingProgressEntries: [TripPlannerPackingProgress]
    let expenses: [TripPlannerExpense]

    var isGroupTrip: Bool {
        !friendIds.isEmpty
    }

    var travelerDisplayNames: [String] {
        let snapshots = friends.compactMap { friend -> String? in
            let trimmed = friend.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }

            let username = friend.username.trimmingCharacters(in: .whitespacesAndNewlines)
            return username.isEmpty ? nil : "@\(username)"
        }

        let source = snapshots.isEmpty ? friendNames : snapshots
        var seen = Set<String>()
        var ordered: [String] = []

        for rawName in source {
            let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let normalized = trimmed
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: AppDisplayLocale.current)
            guard seen.insert(normalized).inserted else { continue }
            ordered.append(trimmed)
        }

        return ordered
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case updatedAt
        case title
        case notes
        case startDate
        case endDate
        case countryIds
        case countryNames
        case friendIds
        case friendNames
        case friends
        case ownerId
        case ownerSnapshot
        case plannerCurrencyCode
        case availability
        case dayPlans
        case overallChecklistItems
        case packingProgressEntries
        case expenses
    }

    init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date? = nil,
        title: String,
        notes: String,
        startDate: Date?,
        endDate: Date?,
        countryIds: [String],
        countryNames: [String],
        friendIds: [UUID],
        friendNames: [String],
        friends: [TripPlannerFriendSnapshot],
        ownerId: UUID? = nil,
        ownerSnapshot: TripPlannerFriendSnapshot? = nil,
        plannerCurrencyCode: String? = nil,
        availability: [TripPlannerAvailabilityProposal],
        dayPlans: [TripPlannerDayPlan] = [],
        overallChecklistItems: [TripPlannerChecklistItem] = [],
        packingProgressEntries: [TripPlannerPackingProgress] = [],
        expenses: [TripPlannerExpense] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.countryIds = countryIds
        self.countryNames = countryNames
        self.friendIds = friendIds
        self.friendNames = friendNames
        self.friends = friends
        self.ownerId = ownerId
        if let ownerId {
            if let ownerSnapshot, ownerSnapshot.id == ownerId {
                self.ownerSnapshot = ownerSnapshot
            } else {
                self.ownerSnapshot = friends.first(where: { $0.id == ownerId })
            }
        } else {
            self.ownerSnapshot = nil
        }
        self.plannerCurrencyCode = AppCurrencyCatalog.normalizedCode(plannerCurrencyCode)
        self.availability = availability
        self.dayPlans = dayPlans
        self.overallChecklistItems = overallChecklistItems
        self.packingProgressEntries = packingProgressEntries
        self.expenses = expenses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decodeFlexibleDate(forKey: .createdAt)
        updatedAt = try container.decodeFlexibleDateIfPresent(forKey: .updatedAt) ?? createdAt
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decode(String.self, forKey: .notes)
        startDate = try container.decodeFlexibleDateIfPresent(forKey: .startDate)
        endDate = try container.decodeFlexibleDateIfPresent(forKey: .endDate)
        countryIds = try container.decode([String].self, forKey: .countryIds)
        countryNames = try container.decode([String].self, forKey: .countryNames)
        friendIds = try container.decodeIfPresent([UUID].self, forKey: .friendIds) ?? []
        friendNames = try container.decodeIfPresent([String].self, forKey: .friendNames) ?? []
        friends = try container.decodeIfPresent([TripPlannerFriendSnapshot].self, forKey: .friends)
            ?? zip(friendIds, friendNames).map { id, name in
                TripPlannerFriendSnapshot(
                    id: id,
                    displayName: name,
                    username: name.replacingOccurrences(of: " ", with: "").lowercased(),
                    avatarURL: nil
                )
            }
        ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
        let decodedOwnerSnapshot = try container.decodeIfPresent(TripPlannerFriendSnapshot.self, forKey: .ownerSnapshot)
        if let ownerId {
            ownerSnapshot = decodedOwnerSnapshot?.id == ownerId
                ? decodedOwnerSnapshot
                : friends.first(where: { $0.id == ownerId })
        } else {
            ownerSnapshot = nil
        }
        plannerCurrencyCode = AppCurrencyCatalog.normalizedCode(
            try container.decodeIfPresent(String.self, forKey: .plannerCurrencyCode)
        )
        availability = try container.decodeIfPresent([TripPlannerAvailabilityProposal].self, forKey: .availability) ?? []
        dayPlans = try container.decodeIfPresent([TripPlannerDayPlan].self, forKey: .dayPlans) ?? []
        overallChecklistItems = try container.decodeIfPresent([TripPlannerChecklistItem].self, forKey: .overallChecklistItems) ?? []
        packingProgressEntries = try container.decodeIfPresent([TripPlannerPackingProgress].self, forKey: .packingProgressEntries) ?? []
        expenses = try container.decodeIfPresent([TripPlannerExpense].self, forKey: .expenses) ?? []
    }

    func preparedForSync(currentUserId: UUID?) -> TripPlannerTrip {
        TripPlannerTrip(
            id: id,
            createdAt: createdAt,
            updatedAt: Date(),
            title: title,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            countryIds: countryIds,
            countryNames: countryNames,
            friendIds: friendIds,
            friendNames: friendNames,
            friends: friends,
            ownerId: ownerId ?? currentUserId,
            ownerSnapshot: effectiveOwnerSnapshot,
            plannerCurrencyCode: plannerCurrencyCode,
            availability: availability,
            dayPlans: dayPlans,
            overallChecklistItems: overallChecklistItems,
            packingProgressEntries: packingProgressEntries,
            expenses: expenses
        )
    }

    var effectiveOwnerSnapshot: TripPlannerFriendSnapshot? {
        guard let ownerId else { return nil }

        if let ownerSnapshot, ownerSnapshot.id == ownerId {
            return ownerSnapshot
        }

        return friends.first(where: { $0.id == ownerId })
    }

    func participantIDs(including currentUserId: UUID?) -> [UUID] {
        var ids: [UUID] = []
        var seen = Set<UUID>()

        func append(_ id: UUID?) {
            guard let id, seen.insert(id).inserted else { return }
            ids.append(id)
        }

        append(ownerId)
        friendIds.forEach { append($0) }
        append(currentUserId)
        return ids
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDate(forKey key: Key) throws -> Date {
        if let numeric = try? decode(Double.self, forKey: key) {
            return Date(timeIntervalSinceReferenceDate: numeric)
        }

        if let seconds = try? decode(Int.self, forKey: key) {
            return Date(timeIntervalSinceReferenceDate: Double(seconds))
        }

        if let string = try? decode(String.self, forKey: key) {
            if let isoDate = ISO8601DateFormatter().date(from: string) {
                return isoDate
            }

            if let timestamp = Double(string) {
                return Date(timeIntervalSinceReferenceDate: timestamp)
            }
        }

        return try decode(Date.self, forKey: key)
    }

    func decodeFlexibleDateIfPresent(forKey key: Key) throws -> Date? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeFlexibleDate(forKey: key)
    }
}

private enum TripPlannerDayPlanBuilder {
    static func syncedDayPlans(
        existingPlans: [TripPlannerDayPlan],
        startDate: Date?,
        endDate: Date?,
        countries: [(id: String, name: String)]
    ) -> [TripPlannerDayPlan] {
        guard let startDate, let endDate else { return [] }

        let calendar = Calendar.current
        let validCountryIDs = Set(countries.map(\.id))
        let namesByID = Dictionary(uniqueKeysWithValues: countries)
        let existingByDate = Dictionary(
            uniqueKeysWithValues: existingPlans.map { (calendar.startOfDay(for: $0.date), $0) }
        )
        var mostRecentCountry: (id: String, name: String)?

        return dateRange(from: startDate, to: endDate).map { date in
            if let existing = existingByDate[date] {
                if existing.kind == .travel {
                    return TripPlannerDayPlan(
                        id: existing.id,
                        date: date,
                        kind: .travel,
                        checklistItems: syncedChecklistItems(existing.checklistItems, dayKind: .travel)
                    )
                }

                if let countryId = existing.countryId, validCountryIDs.contains(countryId) {
                    let resolvedPlan = TripPlannerDayPlan(
                        id: existing.id,
                        date: date,
                        kind: .country,
                        countryId: countryId,
                        countryName: namesByID[countryId],
                        checklistItems: syncedChecklistItems(existing.checklistItems, dayKind: .country)
                    )
                    if let countryName = resolvedPlan.countryName {
                        mostRecentCountry = (countryId, countryName)
                    }
                    return resolvedPlan
                }
            }

            if let inheritedCountry = mostRecentCountry ?? countries.first {
                return TripPlannerDayPlan(
                    date: date,
                    kind: .country,
                    countryId: inheritedCountry.id,
                    countryName: inheritedCountry.name,
                    checklistItems: syncedChecklistItems([], dayKind: .country)
                )
            }

            return TripPlannerDayPlan(
                date: date,
                kind: .travel,
                checklistItems: syncedChecklistItems([], dayKind: .travel)
            )
        }
    }

    static func syncedChecklistItems(
        _ items: [TripPlannerChecklistItem],
        dayKind: TripPlannerDayPlanKind? = nil
    ) -> [TripPlannerChecklistItem] {
        var result = items
        let hasTransportation = result.contains {
            $0.category == .transportBooking || $0.title.localizedCaseInsensitiveContains(TripPlannerChecklistTemplates.transportationTitle)
        }
        let hasAccommodation = result.contains {
            $0.category == .accommodation || $0.title.localizedCaseInsensitiveContains(TripPlannerChecklistTemplates.accommodationTitle)
        }

        if dayKind == .travel, !hasTransportation {
            result.insert(TripPlannerChecklistTemplates.defaultTransportationItem(), at: 0)
        }

        if !hasAccommodation {
            let accommodationInsertIndex = dayKind == .travel ? min(1, result.count) : 0
            result.insert(TripPlannerChecklistTemplates.defaultAccommodationItem(), at: accommodationInsertIndex)
        }

        return result
    }

    static func dateRange(from startDate: Date, to endDate: Date) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return [] }

        var dates: [Date] = []
        var current = start

        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }
}

private enum TripPlannerChecklistBuilder {
    static func syncedOverallChecklistItems(
        existingItems: [TripPlannerChecklistItem],
        countries: [Country],
        groupVisaNeeds: [TripPlannerTravelerVisaNeed] = []
    ) -> [TripPlannerChecklistItem] {
        let packingItem = TripPlannerChecklistTemplates.defaultPackingItem(
            existing: existingItems.first(where: { $0.category == .packing })
        )
        let existingVisaItemsByTitle = Dictionary(
            uniqueKeysWithValues: existingItems
                .filter { $0.category == .visa }
                .map { ($0.title, $0) }
        )

        let requiredVisaItems: [TripPlannerChecklistItem]
        if !groupVisaNeeds.isEmpty {
            requiredVisaItems = groupVisaNeeds
                .sorted { lhs, rhs in
                    if lhs.travelerName != rhs.travelerName {
                        return lhs.travelerName.localizedCaseInsensitiveCompare(rhs.travelerName) == .orderedAscending
                    }
                    return lhs.countryName.localizedCaseInsensitiveCompare(rhs.countryName) == .orderedAscending
                }
                .map { need in
                    let title = "\(need.travelerName) • \(need.countryFlag) \(need.countryName)"
                    if let existing = existingVisaItemsByTitle[title] {
                        return existing
                    }
                    return TripPlannerChecklistItem(category: .visa, title: title)
                }
        } else {
            let visaPrepCountries = countries
                .filter { ["evisa", "visa_required", "entry_permit", "ban"].contains($0.visaType ?? "") }
                .sorted { $0.localizedDisplayName.localizedCaseInsensitiveCompare($1.localizedDisplayName) == .orderedAscending }

            requiredVisaItems = visaPrepCountries.map { country in
                let title = "\(country.flagEmoji) \(country.localizedDisplayName)"
                if let existing = existingVisaItemsByTitle[title] {
                    return existing
                }
                return TripPlannerChecklistItem(category: .visa, title: title)
            }
        }

        let otherItems = existingItems.filter { item in
            item.category != .visa && item.category != .packing
        }

        return requiredVisaItems + [packingItem] + otherItems
    }
}

@MainActor
final class TripPlannerStore: ObservableObject {
    @Published private(set) var trips: [TripPlannerTrip] = []
    @Published private(set) var isLoadingLocalTrips = true

    private let legacySaveKey = "trip_planner_trips_v1"
    private let guestSaveKey = "trip_planner_trips_guest_v1"
    private let supabase = SupabaseManager.shared
    private let syncService = TripPlannerSyncService(supabase: SupabaseManager.shared)
    private var cancellables = Set<AnyCancellable>()
    private var hasRequestedInitialRefresh = false
    private var hasLoadedLocalTrips = false

    init() {
        let initStart = Date().timeIntervalSinceReferenceDate
        TripPlannerDebugLog.probe("TripPlannerStore.init.start")
        observeAuthState()
        observeTripUpdates()
        TripPlannerDebugLog.probe(
            "TripPlannerStore.init.end",
            "duration=\(TripPlannerDebugLog.durationText(since: initStart))"
        )
    }

    func add(_ trip: TripPlannerTrip) {
        let syncedTrip = trip.preparedForSync(currentUserId: supabase.currentUserId)
        trips.insert(syncedTrip, at: 0)
        persistLocal()

        Task {
            await syncUpsert(syncedTrip, previousTrip: nil)
        }
    }

    func upsert(_ trip: TripPlannerTrip) {
        let syncedTrip = trip.preparedForSync(currentUserId: supabase.currentUserId)
        let previousTrip = trips.first(where: { $0.id == syncedTrip.id })

        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = syncedTrip
            trips.sort { $0.updatedAt > $1.updatedAt }
        } else {
            trips.insert(syncedTrip, at: 0)
        }
        persistLocal()

        Task {
            await syncUpsert(syncedTrip, previousTrip: previousTrip)
        }
    }

    func cacheOwnerSnapshot(_ snapshot: TripPlannerFriendSnapshot, forTripID tripId: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripId }) else { return }

        let existingTrip = trips[index]
        guard existingTrip.ownerId == snapshot.id else { return }
        guard existingTrip.effectiveOwnerSnapshot != snapshot else { return }

        trips[index] = existingTrip.withOwnerSnapshot(snapshot)
        persistLocal()
    }

    enum DeleteScope {
        case justMe
        case everyone
    }

    func delete(id: UUID, scope: DeleteScope) {
        let removedTrip = trips.first(where: { $0.id == id })
        trips.removeAll { $0.id == id }
        persistLocal()

        Task {
            await syncDelete(id: id, previousTrip: removedTrip, scope: scope)
        }
    }

    private func observeAuthState() {
        TripPlannerDebugLog.probe("TripPlannerStore.observeAuthState.attach")
        supabase.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                TripPlannerDebugLog.probe("TripPlannerStore.observeAuthState.event")
                Task {
                    await self.handleAuthStateChange()
                }
            }
            .store(in: &cancellables)
    }

    private func observeTripUpdates() {
        TripPlannerDebugLog.probe("TripPlannerStore.observeTripUpdates.attach")
        NotificationCenter.default.publisher(for: .sharedTripsUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                TripPlannerDebugLog.probe("TripPlannerStore.observeTripUpdates.event")
                Task {
                    await self.refreshFromRemoteIfNeeded(migrateLocalTrips: false)
                }
            }
            .store(in: &cancellables)
    }

    private func handleAuthStateChange() async {
        let start = Date().timeIntervalSinceReferenceDate
        TripPlannerDebugLog.probe("TripPlannerStore.auth_change.start")
        loadLocalIfNeeded(force: true)
        hasRequestedInitialRefresh = false
        await refreshFromRemoteIfNeeded(migrateLocalTrips: true)
        hasRequestedInitialRefresh = true
        TripPlannerDebugLog.probe(
            "TripPlannerStore.auth_change.end",
            "duration=\(TripPlannerDebugLog.durationText(since: start)) trips=\(trips.count)"
        )
    }

    private var localSaveKey: String {
        guard let userId = supabase.currentUserId else {
            return guestSaveKey
        }

        return "trip_planner_trips_user_\(userId.uuidString)"
    }

    private func loadLocalIfNeeded(force: Bool = false) {
        guard force || !hasLoadedLocalTrips else {
            TripPlannerDebugLog.probe(
                "TripPlannerStore.loadLocalIfNeeded.skipped",
                "force=\(force) trips=\(trips.count)"
            )
            return
        }

        let start = Date().timeIntervalSinceReferenceDate
        TripPlannerDebugLog.probe("TripPlannerStore.loadLocalIfNeeded.start", "force=\(force)")
        loadLocal()
        hasLoadedLocalTrips = true
        isLoadingLocalTrips = false
        TripPlannerDebugLog.probe(
            "TripPlannerStore.loadLocalIfNeeded.end",
            "duration=\(TripPlannerDebugLog.durationText(since: start)) trips=\(trips.count)"
        )
    }

    private func loadLocal() {
        let start = Date().timeIntervalSinceReferenceDate
        let defaults = UserDefaults.standard
        let candidateKeys = [localSaveKey, legacySaveKey]
        TripPlannerDebugLog.probe(
            "TripPlannerStore.loadLocal.start",
            "keys=\(candidateKeys.joined(separator: ","))"
        )

        for key in candidateKeys {
            guard let data = defaults.data(forKey: key) else {
                TripPlannerDebugLog.probe("TripPlannerStore.loadLocal.miss", "key=\(key)")
                continue
            }

            TripPlannerDebugLog.probe(
                "TripPlannerStore.loadLocal.decode.start",
                "key=\(key) bytes=\(data.count)"
            )

            guard let decoded = try? TripPlannerJSONCoding.decoder.decode([TripPlannerTrip].self, from: data) else {
                TripPlannerDebugLog.probe(
                    "TripPlannerStore.loadLocal.decode.failed",
                    "key=\(key) duration=\(TripPlannerDebugLog.durationText(since: start))"
                )
                continue
            }

            trips = decoded.sorted { $0.updatedAt > $1.updatedAt }
            TripPlannerDebugLog.probe(
                "TripPlannerStore.loadLocal.decode.end",
                "key=\(key) trips=\(decoded.count) duration=\(TripPlannerDebugLog.durationText(since: start))"
            )
            return
        }

        trips = []
        TripPlannerDebugLog.probe(
            "TripPlannerStore.loadLocal.empty",
            "duration=\(TripPlannerDebugLog.durationText(since: start))"
        )
    }

    private func persistLocal() {
        let start = Date().timeIntervalSinceReferenceDate
        guard let data = try? TripPlannerJSONCoding.encoder.encode(trips) else {
            TripPlannerDebugLog.probe(
                "TripPlannerStore.persistLocal.encode_failed",
                "trips=\(trips.count) duration=\(TripPlannerDebugLog.durationText(since: start))"
            )
            return
        }
        UserDefaults.standard.set(data, forKey: localSaveKey)
        TripPlannerDebugLog.probe(
            "TripPlannerStore.persistLocal.end",
            "trips=\(trips.count) bytes=\(data.count) duration=\(TripPlannerDebugLog.durationText(since: start))"
        )
    }

    private func refreshFromRemoteIfNeeded(migrateLocalTrips: Bool) async {
        let refreshStart = Date().timeIntervalSinceReferenceDate
        guard let userId = supabase.currentUserId else {
            TripPlannerDebugLog.probe(
                "TripPlannerStore.refreshRemote.no_user",
                "duration=\(TripPlannerDebugLog.durationText(since: refreshStart))"
            )
            return
        }

        let localTrips = trips
        TripPlannerDebugLog.message(
            "Refreshing remote trips for \(TripPlannerDebugLog.userLabel(userId)); local count=\(localTrips.count), migrateLocal=\(migrateLocalTrips)"
        )

        do {
            let remoteTrips = try await syncService.fetchTrips(userId: userId)
            try await applyRemoteTrips(
                remoteTrips,
                for: userId,
                localTrips: localTrips,
                migrateLocalTrips: migrateLocalTrips
            )
        } catch {
            print("❌ Trip planner sync failed:", error)
            TripPlannerDebugLog.probe(
                "TripPlannerStore.refreshRemote.failed",
                "duration=\(TripPlannerDebugLog.durationText(since: refreshStart)) error=\(String(describing: error))"
            )
        }
        TripPlannerDebugLog.probe(
            "TripPlannerStore.refreshRemote.end",
            "duration=\(TripPlannerDebugLog.durationText(since: refreshStart)) trips=\(trips.count) migrateLocal=\(migrateLocalTrips)"
        )
    }

    private func applyRemoteTrips(
        _ remoteTrips: [TripPlannerTrip],
        for userId: UUID,
        localTrips: [TripPlannerTrip],
        migrateLocalTrips: Bool
    ) async throws {
        let applyStart = Date().timeIntervalSinceReferenceDate
        TripPlannerDebugLog.probe(
            "TripPlannerStore.applyRemoteTrips.start",
            "local=\(localTrips.count) remote=\(remoteTrips.count) migrateLocal=\(migrateLocalTrips)"
        )
        let mergedTrips = mergedTrips(local: localTrips, remote: remoteTrips)
        TripPlannerDebugLog.probe(
            "TripPlannerStore.applyRemoteTrips.merged",
            "merged=\(mergedTrips.count) duration=\(TripPlannerDebugLog.durationText(since: applyStart))"
        )

        if migrateLocalTrips {
            let localOnlyTrips = mergedTrips.filter { mergedTrip in
                !remoteTrips.contains(where: { $0.id == mergedTrip.id })
            }
            TripPlannerDebugLog.probe(
                "TripPlannerStore.applyRemoteTrips.local_only",
                "count=\(localOnlyTrips.count)"
            )

            for trip in localOnlyTrips {
                if trip.isGroupTrip {
                    TripPlannerDebugLog.message(
                        "Skipping automatic migration for local group trip \(TripPlannerDebugLog.tripLabel(trip)); it will sync on explicit save"
                    )
                } else {
                    try await syncService.upsertTrip(userId: userId, trip: trip)
                }
            }
        }

        trips = mergedTrips
        TripPlannerDebugLog.probe("TripPlannerStore.applyRemoteTrips.assign", "trips=\(trips.count)")
        persistLocal()
        TripPlannerDebugLog.message(
            "Remote refresh complete for \(TripPlannerDebugLog.userLabel(userId)); remote count=\(remoteTrips.count), merged count=\(mergedTrips.count)"
        )

        if !mergedTrips.isEmpty {
            UserDefaults.standard.removeObject(forKey: legacySaveKey)
        }
        TripPlannerDebugLog.probe(
            "TripPlannerStore.applyRemoteTrips.end",
            "duration=\(TripPlannerDebugLog.durationText(since: applyStart))"
        )
    }

    private func syncUpsert(_ trip: TripPlannerTrip, previousTrip: TripPlannerTrip?) async {
        guard let userId = supabase.currentUserId else { return }

        do {
            let oldParticipantIDs = Set(previousTrip?.participantIDs(including: userId) ?? [userId])
            let newParticipantIDs = Set(trip.participantIDs(including: userId))
            let removedParticipantIDs = oldParticipantIDs.subtracting(newParticipantIDs)

            TripPlannerDebugLog.message(
                """
                Saving shared trip \(TripPlannerDebugLog.tripLabel(trip))
                actor=\(TripPlannerDebugLog.userLabel(userId))
                owner=\(TripPlannerDebugLog.userLabel(trip.ownerId))
                participants=[\(TripPlannerDebugLog.participantLabels(for: Array(newParticipantIDs)))]
                removedParticipants=[\(TripPlannerDebugLog.participantLabels(for: Array(removedParticipantIDs)))]
                """
            )

            try await syncService.shareTrip(
                trip: trip,
                participantIDs: Array(newParticipantIDs)
            )

            let remoteTrips = try await syncService.fetchTrips(userId: userId)
            trips = mergedTrips(local: trips, remote: remoteTrips)
            persistLocal()
            NotificationCenter.default.post(name: .sharedTripsUpdated, object: nil)
            TripPlannerDebugLog.message(
                "Save completed for \(TripPlannerDebugLog.tripLabel(trip)); actor now sees \(remoteTrips.count) remote trips"
            )
        } catch {
            print("❌ Trip planner upsert failed:", error)
        }
    }

    private func syncDelete(id: UUID, previousTrip: TripPlannerTrip?, scope: DeleteScope) async {
        guard let userId = supabase.currentUserId else { return }

        do {
            let participantIDs = Set(previousTrip?.participantIDs(including: userId) ?? [userId])
            TripPlannerDebugLog.message(
                "Deleting trip \(id.uuidString) scope=\(scope) actor=\(TripPlannerDebugLog.userLabel(userId)) participants=[\(TripPlannerDebugLog.participantLabels(for: Array(participantIDs)))]"
            )

            switch scope {
            case .justMe:
                try await syncService.deleteTrip(userId: userId, tripId: id)
            case .everyone:
                if let previousTrip {
                    try await syncService.deleteSharedTrip(
                        trip: previousTrip,
                        participantIDs: Array(participantIDs)
                    )
                } else {
                    for participantId in participantIDs {
                        try await syncService.deleteTrip(userId: participantId, tripId: id)
                    }
                }
            }

            if scope == .justMe, let previousTrip {
                TripPlannerDebugLog.message(
                    "Removed trip \(TripPlannerDebugLog.tripLabel(previousTrip)) for current user only"
                )
            }
            NotificationCenter.default.post(name: .sharedTripsUpdated, object: nil)
        } catch {
            print("❌ Trip planner delete failed:", error)
        }
    }
}

private enum TripPlannerDeleteChoice: String, Identifiable {
    case justMe
    case everyone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .justMe:
            return "Delete for me only"
        case .everyone:
            return "Delete for everyone"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .justMe:
            return "Remove This Trip For You?"
        case .everyone:
            return "Delete This Trip For Everyone?"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .justMe:
            return "This removes the trip from your planner only. Everyone else keeps it."
        case .everyone:
            return "This deletes the trip for every participant in the group."
        }
    }

    var buttonRole: ButtonRole? { .destructive }

    var storeScope: TripPlannerStore.DeleteScope {
        switch self {
        case .justMe:
            return .justMe
        case .everyone:
            return .everyone
        }
    }
}
 
private extension TripPlannerStore {
    func mergedTrips(local: [TripPlannerTrip], remote: [TripPlannerTrip]) -> [TripPlannerTrip] {
        // Prefer the newest copy, but preserve richer participant metadata from
        // the other version so older local caches do not hide shared travelers.
        var mergedByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for trip in remote {
            if let existing = mergedByID[trip.id] {
                mergedByID[trip.id] = existing.mergedForDisplay(with: trip)
            } else {
                mergedByID[trip.id] = trip
            }
        }

        return mergedByID.values.sorted { $0.updatedAt > $1.updatedAt }
    }
}

private extension TripPlannerTrip {
    func mergedForDisplay(with other: TripPlannerTrip) -> TripPlannerTrip {
        let preferred = updatedAt >= other.updatedAt ? self : other
        let fallback = updatedAt >= other.updatedAt ? other : self

        let mergedFriendIDs = preferred.friendIds.isEmpty ? fallback.friendIds : preferred.friendIds
        let mergedFriendNames = preferred.friendNames.isEmpty ? fallback.friendNames : preferred.friendNames

        let mergedFriends: [TripPlannerFriendSnapshot]
        if preferred.friends.isEmpty {
            mergedFriends = !fallback.friends.isEmpty
                ? fallback.friends
                : zip(mergedFriendIDs, mergedFriendNames).map { id, name in
                    TripPlannerFriendSnapshot(
                        id: id,
                        displayName: name,
                        username: name.replacingOccurrences(of: " ", with: "").lowercased(),
                        avatarURL: nil
                    )
                }
        } else {
            mergedFriends = preferred.friends
        }

        return TripPlannerTrip(
            id: preferred.id,
            createdAt: preferred.createdAt,
            updatedAt: preferred.updatedAt,
            title: preferred.title,
            notes: preferred.notes,
            startDate: preferred.startDate,
            endDate: preferred.endDate,
            countryIds: preferred.countryIds,
            countryNames: preferred.countryNames,
            friendIds: mergedFriendIDs,
            friendNames: mergedFriendNames,
            friends: mergedFriends,
            ownerId: preferred.ownerId ?? fallback.ownerId,
            ownerSnapshot: preferred.effectiveOwnerSnapshot ?? fallback.effectiveOwnerSnapshot,
            plannerCurrencyCode: preferred.plannerCurrencyCode ?? fallback.plannerCurrencyCode,
            availability: preferred.availability,
            dayPlans: preferred.dayPlans,
            overallChecklistItems: preferred.overallChecklistItems,
            packingProgressEntries: preferred.packingProgressEntries.isEmpty ? fallback.packingProgressEntries : preferred.packingProgressEntries,
            expenses: preferred.expenses
        )
    }
}

private extension TripPlannerChecklistCategory {
    var defaultExpenseCategory: TripPlannerExpenseCategory {
        switch self {
        case .accommodation:
            return .accommodation
        case .transportBooking:
            return .transportation
        case .attractionTickets:
            return .activities
        case .reservation:
            return .food
        case .visa, .insurance, .packing, .custom:
            return .other
        }
    }
}

private extension TripPlannerTrip {
    func preservingMissingState(from existing: TripPlannerTrip) -> TripPlannerTrip {
        TripPlannerTrip(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            countryIds: countryIds,
            countryNames: countryNames,
            friendIds: friendIds,
            friendNames: friendNames,
            friends: friends,
            ownerId: ownerId ?? existing.ownerId,
            ownerSnapshot: effectiveOwnerSnapshot ?? existing.effectiveOwnerSnapshot,
            plannerCurrencyCode: plannerCurrencyCode ?? existing.plannerCurrencyCode,
            availability: availability,
            dayPlans: dayPlans,
            overallChecklistItems: overallChecklistItems,
            packingProgressEntries: packingProgressEntries.isEmpty ? existing.packingProgressEntries : packingProgressEntries,
            expenses: expenses
        )
    }

    func withOwnerSnapshot(_ snapshot: TripPlannerFriendSnapshot?) -> TripPlannerTrip {
        TripPlannerTrip(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            countryIds: countryIds,
            countryNames: countryNames,
            friendIds: friendIds,
            friendNames: friendNames,
            friends: friends,
            ownerId: ownerId,
            ownerSnapshot: snapshot,
            plannerCurrencyCode: plannerCurrencyCode,
            availability: availability,
            dayPlans: dayPlans,
            overallChecklistItems: overallChecklistItems,
            packingProgressEntries: packingProgressEntries,
            expenses: expenses
        )
    }

    func applyingExpenseEditsToLinkedChecklistItems(_ updatedExpenses: [TripPlannerExpense]) -> TripPlannerTrip {
        let expensesByChecklistID = Dictionary<UUID, TripPlannerExpense>(
            uniqueKeysWithValues: updatedExpenses.compactMap { expense -> (UUID, TripPlannerExpense)? in
                guard let linkedChecklistItemId = expense.linkedChecklistItemId else { return nil }
                return (linkedChecklistItemId, expense)
            }
        )

        let updatedDayPlans = dayPlans.map { plan in
            let updatedItems = plan.checklistItems.map { item in
                guard item.supportsExpenseTracking else { return item }

                if let expense = expensesByChecklistID[item.expenseSyncKey] {
                    return item
                        .updatedTitle(expense.title)
                        .updatedExpenseSync(
                            sourceItemId: item.expenseSourceItemId,
                            expenseId: expense.id,
                            amount: expense.totalAmount,
                            currencyCode: expense.entryCurrencyCode ?? item.linkedExpenseCurrencyCode,
                            date: expense.date
                        )
                }

                if item.hasLinkedExpenseDetails {
                    return item.updatedExpenseSync(
                        sourceItemId: item.expenseSourceItemId,
                        expenseId: nil,
                        amount: nil,
                        currencyCode: item.linkedExpenseCurrencyCode,
                        date: nil
                    )
                }

                return item
            }

            return TripPlannerDayPlan(
                id: plan.id,
                date: plan.date,
                kind: plan.kind,
                countryId: plan.countryId,
                countryName: plan.countryName,
                checklistItems: updatedItems
            )
        }

        return TripPlannerTrip(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            countryIds: countryIds,
            countryNames: countryNames,
            friendIds: friendIds,
            friendNames: friendNames,
            friends: friends,
            ownerId: ownerId,
            ownerSnapshot: effectiveOwnerSnapshot,
            plannerCurrencyCode: plannerCurrencyCode,
            availability: availability,
            dayPlans: updatedDayPlans,
            overallChecklistItems: overallChecklistItems,
            packingProgressEntries: packingProgressEntries,
            expenses: updatedExpenses
        )
    }

    func normalizedForPersistence(currentUser: TripPlannerFriendSnapshot?) -> TripPlannerTrip {
        let participantSnapshots = plannerExpenseParticipants(preferredCurrentUser: currentUser)
        let manualExpenses = expenses.filter { $0.linkedChecklistItemId == nil }
        let existingLinkedExpenses = Dictionary<UUID, TripPlannerExpense>(
            uniqueKeysWithValues: expenses.compactMap { expense -> (UUID, TripPlannerExpense)? in
                guard let linkedChecklistItemId = expense.linkedChecklistItemId else { return nil }
                return (linkedChecklistItemId, expense)
            }
        )
        let sortedPlans = dayPlans.sorted { $0.date < $1.date }

        struct SharedExpenseDraft {
            let item: TripPlannerChecklistItem
            let amount: Double
            let date: Date
        }

        var sharedExpenseDrafts: [UUID: SharedExpenseDraft] = [:]

        for plan in sortedPlans {
            for item in plan.checklistItems where item.supportsExpenseTracking {
                let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let amount = item.linkedExpenseAmount, amount > 0.009, !trimmedTitle.isEmpty else {
                    continue
                }

                sharedExpenseDrafts[item.expenseSyncKey] = SharedExpenseDraft(
                    item: item,
                    amount: amount,
                    date: item.linkedExpenseDate ?? plan.date
                )
            }
        }

        var linkedExpenses: [TripPlannerExpense] = []
        var emittedExpenseKeys = Set<UUID>()

        let updatedDayPlans = dayPlans.map { plan in
            let updatedItems = plan.checklistItems.map { item -> TripPlannerChecklistItem in
                guard item.supportsExpenseTracking else { return item }

                let expenseKey = item.expenseSyncKey
                guard let draft = sharedExpenseDrafts[expenseKey] else {
                    if item.hasLinkedExpenseDetails {
                        return item.updatedExpenseSync(
                            sourceItemId: item.expenseSourceItemId,
                            expenseId: nil,
                            amount: nil,
                            currencyCode: item.linkedExpenseCurrencyCode,
                            date: nil
                        )
                    }
                    return item
                }

                let existingExpense = existingLinkedExpenses[expenseKey]
                let resolvedExpense = syncedLinkedExpense(
                    for: draft.item,
                    syncKey: expenseKey,
                    existing: existingExpense,
                    amount: draft.amount,
                    date: draft.date,
                    participantSnapshots: participantSnapshots,
                    currentUser: currentUser
                )

                if emittedExpenseKeys.insert(expenseKey).inserted {
                    linkedExpenses.append(resolvedExpense)
                }

                return item
                    .updatedTitle(resolvedExpense.title)
                    .updatedExpenseSync(
                        sourceItemId: item.expenseSourceItemId,
                        expenseId: resolvedExpense.id,
                        amount: resolvedExpense.totalAmount,
                        currencyCode: resolvedExpense.entryCurrencyCode ?? item.linkedExpenseCurrencyCode,
                        date: item.linkedExpenseDate ?? resolvedExpense.date
                    )
            }

            return TripPlannerDayPlan(
                id: plan.id,
                date: plan.date,
                kind: plan.kind,
                countryId: plan.countryId,
                countryName: plan.countryName,
                checklistItems: updatedItems
            )
        }

        return TripPlannerTrip(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            countryIds: countryIds,
            countryNames: countryNames,
            friendIds: friendIds,
            friendNames: friendNames,
            friends: friends,
            ownerId: ownerId,
            ownerSnapshot: effectiveOwnerSnapshot,
            plannerCurrencyCode: plannerCurrencyCode,
            availability: availability,
            dayPlans: updatedDayPlans,
            overallChecklistItems: overallChecklistItems,
            packingProgressEntries: packingProgressEntries,
            expenses: TripPlannerExpensesEditorView.sortedExpenses(manualExpenses + linkedExpenses)
        )
    }

    private func plannerExpenseParticipants(preferredCurrentUser: TripPlannerFriendSnapshot?) -> [TripPlannerFriendSnapshot] {
        var ordered: [TripPlannerFriendSnapshot] = []
        var seen = Set<UUID>()

        if let preferredCurrentUser, seen.insert(preferredCurrentUser.id).inserted {
            ordered.append(preferredCurrentUser)
        } else if let currentUserId = SupabaseManager.shared.currentUserId, seen.insert(currentUserId).inserted {
            ordered.append(.currentUserFallback(userId: currentUserId))
        }

        for friend in friends where seen.insert(friend.id).inserted {
            ordered.append(friend)
        }

        if let ownerId = ownerId,
           ownerId != SupabaseManager.shared.currentUserId,
           !friends.contains(where: { $0.id == ownerId }),
           seen.insert(ownerId).inserted {
            if let effectiveOwnerSnapshot {
                ordered.append(effectiveOwnerSnapshot)
            } else {
                let profileService = ProfileService(supabase: SupabaseManager.shared)

                if let cachedOwner = profileService.cachedProfile(userId: ownerId) {
                    ordered.append(
                        TripPlannerFriendSnapshot(
                            id: cachedOwner.id,
                            displayName: cachedOwner.tripDisplayName,
                            username: cachedOwner.username,
                            avatarURL: cachedOwner.avatarUrl
                        )
                    )
                } else {
                    ordered.append(.currentUserFallback(userId: ownerId))
                }
            }
        }

        return ordered
    }

    private func syncedLinkedExpense(
        for item: TripPlannerChecklistItem,
        syncKey: UUID,
        existing: TripPlannerExpense?,
        amount: Double,
        date: Date,
        participantSnapshots: [TripPlannerFriendSnapshot],
        currentUser: TripPlannerFriendSnapshot?
    ) -> TripPlannerExpense {
        let category = existing?.category ?? item.category.defaultExpenseCategory
        let payer = preferredPayer(
            existing: existing,
            participantSnapshots: participantSnapshots,
            currentUser: currentUser
        )

        let participantIDs: [String]
        if let existing {
            participantIDs = existing.participantIds
        } else {
            let defaultIDs = defaultParticipantIDs(for: category, payerId: payer.id.uuidString, participantSnapshots: participantSnapshots)
            participantIDs = defaultIDs.isEmpty ? [payer.id.uuidString] : defaultIDs
        }

        let participantNamesByID = Dictionary(
            uniqueKeysWithValues: participantSnapshots.map {
                ($0.id.uuidString, $0.displayName)
            }
        )
        let selectedNames = participantIDs.compactMap { participantNamesByID[$0] }
        let existingShareStates = Dictionary(
            uniqueKeysWithValues: (existing?.shares ?? []).map {
                ($0.participantId, $0)
            }
        )
        let shares = syncedShares(
            amount: amount,
            payerId: payer.id.uuidString,
            participantIDs: participantIDs,
            participantSnapshots: participantSnapshots,
            existingShareStates: existingShareStates
        )

        return TripPlannerExpense(
            id: existing?.id ?? item.linkedExpenseId ?? UUID(),
            linkedChecklistItemId: syncKey,
            category: category,
            customCategoryName: existing?.customCategoryName,
            entryCurrencyCode: item.linkedExpenseCurrencyCode ?? existing?.entryCurrencyCode,
            title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
            totalAmount: amount,
            paidById: existing?.paidById ?? payer.id.uuidString,
            paidByName: existing?.paidByName ?? payer.displayName,
            paidByUsername: existing?.paidByUsername ?? payer.username,
            splitMode: existing?.splitMode ?? category.suggestedSplitMode,
            date: date,
            participantIds: participantIDs,
            participantNames: selectedNames,
            shares: shares
        )
    }

    private func preferredPayer(
        existing: TripPlannerExpense?,
        participantSnapshots: [TripPlannerFriendSnapshot],
        currentUser: TripPlannerFriendSnapshot?
    ) -> TripPlannerFriendSnapshot {
        if
            let existing,
            let match = participantSnapshots.first(where: { $0.id.uuidString == existing.paidById })
        {
            return match
        }

        if let currentUser {
            return currentUser
        }

        if let first = participantSnapshots.first {
            return first
        }

        let fallbackId = ownerId ?? SupabaseManager.shared.currentUserId ?? UUID()
        return .currentUserFallback(userId: fallbackId)
    }

    private func defaultParticipantIDs(
        for category: TripPlannerExpenseCategory,
        payerId: String,
        participantSnapshots: [TripPlannerFriendSnapshot]
    ) -> [String] {
        switch category.suggestedSplitMode {
        case .everyone:
            return participantSnapshots.map { $0.id.uuidString }
        case .selectedPeople:
            return [payerId]
        }
    }

    private func syncedShares(
        amount: Double,
        payerId: String,
        participantIDs: [String],
        participantSnapshots: [TripPlannerFriendSnapshot],
        existingShareStates: [String: TripPlannerExpenseShare]
    ) -> [TripPlannerExpenseShare] {
        let beneficiaryIDs = participantIDs.filter { $0 != payerId }
        let shareAmount = beneficiaryIDs.isEmpty ? 0 : amount / Double(beneficiaryIDs.count)
        let snapshotsByID = Dictionary(
            uniqueKeysWithValues: participantSnapshots.map { ($0.id.uuidString, $0) }
        )

        return beneficiaryIDs.map { participantId in
            let snapshot = snapshotsByID[participantId]
            let existingShare = existingShareStates[participantId]
            return TripPlannerExpenseShare(
                id: existingShare?.id ?? UUID(),
                participantId: participantId,
                participantName: snapshot?.displayName ?? existingShare?.participantName ?? "Traveler",
                participantUsername: snapshot?.username ?? existingShare?.participantUsername,
                amountOwed: shareAmount,
                isPaid: existingShare?.isPaid ?? false,
                paymentMethod: existingShare?.paymentMethod
            )
        }
    }
}

private extension String {
    var detectedURLs: [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(startIndex..., in: self)
        var urls: [URL] = []
        var seen = Set<String>()

        detector.enumerateMatches(in: self, options: [], range: range) { match, _, _ in
            guard let url = match?.url else { return }
            let absolute = url.absoluteString
            guard seen.insert(absolute).inserted else { return }
            urls.append(url)
        }

        return urls
    }
}

private struct TripPlannerDetectedLinkList: View {
    let text: String

    private var urls: [URL] {
        text.detectedURLs
    }

    var body: some View {
        if !urls.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(urls, id: \.absoluteString) { url in
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .bold))
                            Text(linkLabel(for: url))
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color(red: 0.13, green: 0.34, blue: 0.60))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func linkLabel(for url: URL) -> String {
        if let host = url.host, !host.isEmpty {
            return "\(host)\(url.path.isEmpty ? "" : url.path)"
        }
        return url.absoluteString
    }
}

extension TripPlannerStore {
    @MainActor
    func loadInitialTripsIfNeeded() async {
        let start = Date().timeIntervalSinceReferenceDate
        guard !hasRequestedInitialRefresh else {
            TripPlannerDebugLog.probe(
                "TripPlannerStore.loadInitialTripsIfNeeded.skipped",
                "duration=\(TripPlannerDebugLog.durationText(since: start))"
            )
            return
        }

        TripPlannerDebugLog.probe("TripPlannerStore.loadInitialTripsIfNeeded.start")
        hasRequestedInitialRefresh = true
        loadLocalIfNeeded()
        await refreshFromRemoteIfNeeded(migrateLocalTrips: true)
        TripPlannerDebugLog.probe(
            "TripPlannerStore.loadInitialTripsIfNeeded.end",
            "duration=\(TripPlannerDebugLog.durationText(since: start)) trips=\(trips.count)"
        )
    }

    func refresh() async {
        TripPlannerDebugLog.probe("TripPlannerStore.refresh.manual.start")
        await refreshFromRemoteIfNeeded(migrateLocalTrips: false)
        TripPlannerDebugLog.probe("TripPlannerStore.refresh.manual.end", "trips=\(trips.count)")
    }

    func refresh(using remoteTrips: [TripPlannerTrip], userId: UUID) async {
        let start = Date().timeIntervalSinceReferenceDate
        let localTrips = trips
        TripPlannerDebugLog.message(
            "Refreshing remote trips for \(TripPlannerDebugLog.userLabel(userId)); local count=\(localTrips.count), migrateLocal=false"
        )

        do {
            try await applyRemoteTrips(
                remoteTrips,
                for: userId,
                localTrips: localTrips,
                migrateLocalTrips: false
            )
        } catch {
            print("❌ Trip planner sync failed:", error)
            TripPlannerDebugLog.probe(
                "TripPlannerStore.refresh.prefetched.failed",
                "duration=\(TripPlannerDebugLog.durationText(since: start)) error=\(String(describing: error))"
            )
        }
        TripPlannerDebugLog.probe(
            "TripPlannerStore.refresh.prefetched.end",
            "duration=\(TripPlannerDebugLog.durationText(since: start)) trips=\(trips.count) remote=\(remoteTrips.count)"
        )
    }
}

private struct TripPlannerRemoteTripRow: Codable {
    let userId: UUID
    let tripId: UUID
    let tripData: TripPlannerTrip

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tripId = "trip_id"
        case tripData = "trip_data"
    }
}

private struct TripPlannerRemoteTripMutationRow: Codable {
    let userId: UUID
    let tripId: UUID
    let tripData: TripPlannerTrip

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tripId = "trip_id"
        case tripData = "trip_data"
    }
}

private enum TripPlannerFetchPolicy {
    case standard
    case networkOnly
}

private enum TripPlannerAvatarLogDeduper {
    private static let lock = NSLock()
    private static var lastLoggedAtByKey: [String: TimeInterval] = [:]

    static func shouldLog(key: String, cooldown: TimeInterval = 30) -> Bool {
        let now = Date().timeIntervalSinceReferenceDate
        lock.lock()
        defer { lock.unlock() }

        if let lastLoggedAt = lastLoggedAtByKey[key], now - lastLoggedAt < cooldown {
            return false
        }

        lastLoggedAtByKey[key] = now
        return true
    }
}

private actor TripPlannerFetchCache {
    struct Entry {
        let trips: [TripPlannerTrip]
        let fetchedAt: Date
    }

    private var entries: [UUID: Entry] = [:]
    private var inFlightTasks: [UUID: Task<[TripPlannerTrip], Error>] = [:]

    func cachedTrips(for userId: UUID, maxAge: TimeInterval) -> [TripPlannerTrip]? {
        guard let entry = entries[userId] else { return nil }
        guard Date().timeIntervalSince(entry.fetchedAt) <= maxAge else {
            entries[userId] = nil
            return nil
        }
        return entry.trips
    }

    func inFlightTask(for userId: UUID) -> Task<[TripPlannerTrip], Error>? {
        inFlightTasks[userId]
    }

    func storeInFlightTask(_ task: Task<[TripPlannerTrip], Error>, for userId: UUID) {
        inFlightTasks[userId] = task
    }

    func clearInFlightTask(for userId: UUID) {
        inFlightTasks[userId] = nil
    }

    func storeTrips(_ trips: [TripPlannerTrip], for userId: UUID) {
        entries[userId] = Entry(trips: trips, fetchedAt: Date())
    }

    func invalidate(userIds: [UUID]) {
        for userId in userIds {
            entries[userId] = nil
            inFlightTasks[userId]?.cancel()
            inFlightTasks[userId] = nil
        }
    }
}

private struct TripPlannerSyncService {
    let supabase: SupabaseManager

    private static let fetchCache = TripPlannerFetchCache()
    private static let cacheMaxAge: TimeInterval = 30

    static func invalidateCache(for userIds: [UUID]) async {
        await fetchCache.invalidate(userIds: userIds)
    }

    func fetchTrips(userId: UUID, policy: TripPlannerFetchPolicy = .standard) async throws -> [TripPlannerTrip] {
        let start = Date().timeIntervalSinceReferenceDate
        TripPlannerDebugLog.probe(
            "TripPlannerSyncService.fetchTrips.start",
            "user=\(TripPlannerDebugLog.userLabel(userId)) policy=\(policy)"
        )

        if policy == .standard,
           let cachedTrips = await Self.fetchCache.cachedTrips(for: userId, maxAge: Self.cacheMaxAge) {
            TripPlannerDebugLog.message(
                "Using cached trip rows for user \(TripPlannerDebugLog.userLabel(userId)) count=\(cachedTrips.count)"
            )
            TripPlannerDebugLog.probe(
                "TripPlannerSyncService.fetchTrips.cache_hit",
                "count=\(cachedTrips.count) duration=\(TripPlannerDebugLog.durationText(since: start))"
            )
            return cachedTrips
        }

        if let inFlightTask = await Self.fetchCache.inFlightTask(for: userId) {
            TripPlannerDebugLog.message(
                "Awaiting in-flight trip fetch for user \(TripPlannerDebugLog.userLabel(userId))"
            )
            let waitStart = Date().timeIntervalSinceReferenceDate
            let trips = try await inFlightTask.value
            TripPlannerDebugLog.probe(
                "TripPlannerSyncService.fetchTrips.in_flight_resolved",
                "count=\(trips.count) wait=\(TripPlannerDebugLog.durationText(since: waitStart)) total=\(TripPlannerDebugLog.durationText(since: start))"
            )
            return trips
        }

        let fetchTask = Task<[TripPlannerTrip], Error> {
            let networkStart = Date().timeIntervalSinceReferenceDate
            TripPlannerDebugLog.probe(
                "TripPlannerSyncService.fetchTrips.network.start",
                "user=\(TripPlannerDebugLog.userLabel(userId))"
            )
            let rows: [TripPlannerRemoteTripRow] = try await supabase.client
                .from("user_trip_plans")
                .select("user_id,trip_id,trip_data")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            TripPlannerDebugLog.probe(
                "TripPlannerSyncService.fetchTrips.network.rows",
                "rows=\(rows.count) duration=\(TripPlannerDebugLog.durationText(since: networkStart))"
            )

            TripPlannerDebugLog.message(
                "Fetched \(rows.count) raw trip rows for user \(TripPlannerDebugLog.userLabel(userId)): [\(rows.map { $0.tripId.uuidString }.joined(separator: ", "))]"
            )

            let mapStart = Date().timeIntervalSinceReferenceDate
            let trips = rows
                .map(\.tripData)
                .sorted { $0.createdAt > $1.createdAt }
            TripPlannerDebugLog.probe(
                "TripPlannerSyncService.fetchTrips.decode_sort.end",
                "trips=\(trips.count) duration=\(TripPlannerDebugLog.durationText(since: mapStart))"
            )
            return trips
        }

        TripPlannerDebugLog.probe("TripPlannerSyncService.fetchTrips.in_flight_store")
        await Self.fetchCache.storeInFlightTask(fetchTask, for: userId)

        do {
            let trips = try await fetchTask.value
            await Self.fetchCache.storeTrips(trips, for: userId)
            await Self.fetchCache.clearInFlightTask(for: userId)
            TripPlannerDebugLog.probe(
                "TripPlannerSyncService.fetchTrips.end",
                "count=\(trips.count) duration=\(TripPlannerDebugLog.durationText(since: start))"
            )
            return trips
        } catch {
            await Self.fetchCache.clearInFlightTask(for: userId)
            TripPlannerDebugLog.probe(
                "TripPlannerSyncService.fetchTrips.failed",
                "duration=\(TripPlannerDebugLog.durationText(since: start)) error=\(String(describing: error))"
            )
            throw error
        }
    }

    func upsertTrip(userId: UUID, trip: TripPlannerTrip) async throws {
        await Self.invalidateCache(for: [userId])
        TripPlannerDebugLog.message("Attempting row upsert for user \(userId.uuidString) trip \(TripPlannerDebugLog.tripLabel(trip))")
        try await deleteTrip(userId: userId, tripId: trip.id)

        try await supabase.client
            .from("user_trip_plans")
            .insert(
                TripPlannerRemoteTripMutationRow(
                    userId: userId,
                    tripId: trip.id,
                    tripData: trip
                )
            )
            .execute()
        TripPlannerDebugLog.message("Row upsert succeeded for user \(userId.uuidString) trip \(trip.id.uuidString)")
    }

    func shareTrip(trip: TripPlannerTrip, participantIDs: [UUID]) async throws {
        await Self.invalidateCache(for: participantIDs)
        let payload = try encodedTripPayload(trip)
        TripPlannerDebugLog.message(
            """
            Calling share_trip_plan for \(TripPlannerDebugLog.tripLabel(trip))
            participants=[\(TripPlannerDebugLog.participantLabels(for: participantIDs))]
            """
        )

        try await supabase.client.rpc(
            "share_trip_plan",
            params: rpcParams(
                participantIDs: participantIDs,
                tripID: trip.id,
                tripPayload: payload
            )
        )
        .execute()

        TripPlannerDebugLog.message("share_trip_plan succeeded for \(trip.id.uuidString)")
    }

    func deleteSharedTrip(trip: TripPlannerTrip, participantIDs: [UUID]) async throws {
        await Self.invalidateCache(for: participantIDs)
        let payload = try encodedTripPayload(trip)
        TripPlannerDebugLog.message(
            """
            Calling delete_shared_trip_plan for \(TripPlannerDebugLog.tripLabel(trip))
            participants=[\(TripPlannerDebugLog.participantLabels(for: participantIDs))]
            """
        )

        try await supabase.client.rpc(
            "delete_shared_trip_plan",
            params: rpcParams(
                participantIDs: participantIDs,
                tripID: trip.id,
                tripPayload: payload
            )
        )
        .execute()

        TripPlannerDebugLog.message("delete_shared_trip_plan succeeded for \(trip.id.uuidString)")
    }

    func deleteTrip(userId: UUID, tripId: UUID) async throws {
        await Self.invalidateCache(for: [userId])
        TripPlannerDebugLog.message("Attempting row delete for user \(userId.uuidString) trip \(tripId.uuidString)")
        try await supabase.client
            .from("user_trip_plans")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("trip_id", value: tripId.uuidString)
            .execute()
        TripPlannerDebugLog.message("Row delete succeeded for user \(userId.uuidString) trip \(tripId.uuidString)")
    }

    private func encodedTripPayload(_ trip: TripPlannerTrip) throws -> String {
        let data = try TripPlannerJSONCoding.encoder.encode(trip)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "TripPlannerSyncService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode trip payload as UTF-8"]
            )
        }
        return payload
    }

    private func rpcParams(
        participantIDs: [UUID],
        tripID: UUID,
        tripPayload: String
    ) -> JSONObject {
        [
            "p_target_user_ids": .array(participantIDs.map { .string($0.uuidString) }),
            "p_trip_id": .string(tripID.uuidString),
            "p_trip_payload": .string(tripPayload)
        ]
    }
}

private enum TripPlannerJSONCoding {
    static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let string = try? container.decode(String.self) {
                if let date = formatter.date(from: string) ?? fallbackFormatter.date(from: string) {
                    return date
                }
                if let timestamp = Double(string) {
                    return Date(timeIntervalSinceReferenceDate: timestamp)
                }
            }

            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: timestamp)
            }

            if let timestamp = try? container.decode(Int.self) {
                return Date(timeIntervalSinceReferenceDate: Double(timestamp))
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported Trip Planner date value"
            )
        }
        return decoder
    }()
}

private struct TripPlannerCalendarDraft: Identifiable {
    let id = UUID()
    let store: EKEventStore
    let event: EKEvent
}

struct TripPlannerView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var sharedTripInbox: SharedTripInboxStore
    @StateObject private var store: TripPlannerStore
    @State private var calendarDraft: TripPlannerCalendarDraft?
    @State private var calendarError: String?
    @State private var pendingDeleteTrip: TripPlannerTrip?
    @State private var pendingDeleteChoice: TripPlannerDeleteChoice?
    @State private var currentUserSnapshot: TripPlannerFriendSnapshot?
    @State private var ownerSnapshotsByTripID: [UUID: TripPlannerFriendSnapshot] = [:]
    @State private var preparedUserId: UUID?
    @State private var selectedTripForDetail: TripPlannerTrip?
    @State private var selectedCountryForDetail: Country?

    private let profileService: ProfileService
    private let syncService: TripPlannerSyncService

    init() {
        TripPlannerDebugLog.probe("TripPlannerView.init.start")
        let profileService = ProfileService(supabase: SupabaseManager.shared)
        self.profileService = profileService
        self.syncService = TripPlannerSyncService(supabase: SupabaseManager.shared)
        _store = StateObject(wrappedValue: TripPlannerStore())
        _currentUserSnapshot = State(initialValue: nil)
        TripPlannerDebugLog.probe("TripPlannerView.init.end")
    }

    private var pendingSharedTripIDs: Set<UUID> {
        Set(sharedTripInbox.notifications.map { $0.trip.id })
    }

    private var ownerPreloadKey: String {
        let userKey = sessionManager.userId?.uuidString ?? "nil-user"
        let tripKey = store.trips.map { $0.id.uuidString }.joined(separator: ",")
        return "\(userKey)|\(tripKey)"
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel5")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.title"))

                ScrollView {
                    VStack(spacing: 20) {
                        if !sharedTripInbox.notifications.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(sharedTripInbox.notifications) { entry in
                                    if let trip = store.trips.first(where: { $0.id == entry.trip.id }) {
                                        TripPlannerSharedTripNotificationCard(
                                            trip: trip,
                                            onDismiss: {
                                                sharedTripInbox.markSeen(tripId: trip.id)
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        if store.isLoadingLocalTrips {
                            TripPlannerLoadingStateCard()
                        } else if store.trips.isEmpty {
                            NavigationLink {
                                TripPlannerComposerView { trip in
                                    store.add(trip)
                                }
                            } label: {
                                TripPlannerEmptyStateCard()
                            }
                            .buttonStyle(.plain)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(store.trips) { trip in
                                    TripPlannerSavedTripCard(
                                        trip: trip,
                                        isNewSharedTrip: pendingSharedTripIDs.contains(trip.id),
                                        currentUserSnapshot: currentUserSnapshot,
                                        ownerSnapshot: ownerSnapshotsByTripID[trip.id],
                                        onOpen: {
                                            TripPlannerDebugLog.probe(
                                                "TripPlannerView.trip_card.open",
                                                TripPlannerDebugLog.tripLabel(trip)
                                            )
                                            selectedTripForDetail = trip
                                        },
                                        onOpenCountry: { country in
                                            TripPlannerDebugLog.probe(
                                                "TripPlannerView.country.open",
                                                "\(country.iso2.uppercased()) \(country.localizedDisplayName)"
                                            )
                                            selectedCountryForDetail = country
                                        },
                                        onDelete: {
                                            pendingDeleteTrip = trip
                                        },
                                        onAddToCalendar: {
                                            Task {
                                                await openCalendar(for: trip)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    let refreshStart = Date().timeIntervalSinceReferenceDate
                    TripPlannerDebugLog.probe(
                        "TripPlannerView.refreshable.start",
                        "trips=\(store.trips.count) pendingInbox=\(sharedTripInbox.notifications.count)"
                    )
                    async let snapshotRefresh: Void = loadCurrentUserSnapshot()

                    if let userId = sessionManager.userId {
                        do {
                            let remoteTrips = try await syncService.fetchTrips(userId: userId, policy: .networkOnly)
                            await store.refresh(using: remoteTrips, userId: userId)
                            sharedTripInbox.refresh(using: remoteTrips, userId: userId)
                        } catch {
                            print("❌ Trip planner shared refresh failed:", error)
                            async let tripRefresh: Void = store.refresh()
                            async let inboxRefresh: Void = sharedTripInbox.refresh()
                            _ = await (tripRefresh, inboxRefresh)
                        }
                    } else {
                        await store.refresh()
                    }

                    _ = await snapshotRefresh
                    await preloadTripOwnerProfiles()
                    TripPlannerDebugLog.probe(
                        "TripPlannerView.refreshable.end",
                        "duration=\(TripPlannerDebugLog.durationText(since: refreshStart)) trips=\(store.trips.count) pendingInbox=\(sharedTripInbox.notifications.count)"
                    )
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            NavigationLink {
                TripPlannerComposerView { trip in
                    store.add(trip)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.94))
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "trip_planner.new_trip"))
        }
        .sheet(item: $calendarDraft) { draft in
            TripPlannerCalendarSheet(draft: draft)
        }
        .alert(String(localized: "trip_planner.calendar_access"), isPresented: Binding(
            get: { calendarError != nil },
            set: { newValue in
                if !newValue {
                    calendarError = nil
                }
            }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(calendarError ?? "")
        }
        .confirmationDialog(
            "Delete Trip",
            isPresented: Binding(
                get: { pendingDeleteTrip != nil && pendingDeleteChoice == nil },
                set: { newValue in
                    if !newValue, pendingDeleteChoice == nil {
                        pendingDeleteTrip = nil
                    }
                }
            )
        ) {
            Button("Delete for me only", role: .destructive) {
                pendingDeleteChoice = .justMe
            }

            Button("Delete for everyone", role: .destructive) {
                pendingDeleteChoice = .everyone
            }

            Button("Cancel", role: .cancel) {
                pendingDeleteTrip = nil
            }
        } message: {
            Text("Choose whether to remove this trip only from your planner or from the whole group.")
        }
        .alert(
            pendingDeleteChoice?.confirmationTitle ?? "Delete Trip",
            isPresented: Binding(
                get: { pendingDeleteChoice != nil },
                set: { newValue in
                    if !newValue {
                        pendingDeleteChoice = nil
                    }
                }
            ),
            presenting: pendingDeleteChoice
        ) { choice in
            Button(choice.title, role: .destructive) {
                if let trip = pendingDeleteTrip {
                    store.delete(id: trip.id, scope: choice.storeScope)
                }
                pendingDeleteTrip = nil
                pendingDeleteChoice = nil
            }

            Button("Cancel", role: .cancel) {
                pendingDeleteChoice = nil
            }
        } message: { choice in
            Text(choice.confirmationMessage)
        }
        .task(id: sessionManager.userId) {
            guard preparedUserId != sessionManager.userId else { return }
            let loadStart = Date().timeIntervalSinceReferenceDate
            preparedUserId = sessionManager.userId
            TripPlannerDebugLog.probe(
                "TripPlannerView.task.enter",
                "user=\(TripPlannerDebugLog.userLabel(sessionManager.userId))"
            )
            TripPlannerDebugLog.message(
                "Planner screen task started trips=\(store.trips.count) pendingInbox=\(sharedTripInbox.notifications.count)"
            )
            let hasCachedCurrentUserProfile = sessionManager.userId.flatMap { profileService.cachedProfile(userId: $0) } != nil
            TripPlannerDebugLog.probe(
                "TripPlannerView.task.before_initial_load",
                "duration=\(TripPlannerDebugLog.durationText(since: loadStart)) cachedProfile=\(hasCachedCurrentUserProfile) trips=\(store.trips.count)"
            )
            async let tripRefresh: Void = store.loadInitialTripsIfNeeded()

            if hasCachedCurrentUserProfile {
                Task {
                    await loadCurrentUserSnapshot()
                }
                await tripRefresh
            } else {
                async let snapshotRefresh: Void = loadCurrentUserSnapshot()
                _ = await (snapshotRefresh, tripRefresh)
            }

            TripPlannerDebugLog.message(
                "Planner screen task finished duration=\(TripPlannerDebugLog.durationText(since: loadStart)) trips=\(store.trips.count)"
            )
        }
        .task(id: ownerPreloadKey) {
            guard preparedUserId == sessionManager.userId else { return }
            TripPlannerDebugLog.probe("TripPlannerView.owner_preload_task.enter", ownerPreloadKey)
            await preloadTripOwnerProfiles()
        }
        .onAppear {
            TripPlannerDebugLog.probe(
                "TripPlannerView.onAppear",
                "trips=\(store.trips.count) pendingInbox=\(sharedTripInbox.notifications.count)"
            )
        }
        .navigationDestination(item: $selectedTripForDetail) { selectedTrip in
            TripPlannerLazyDestination {
                TripPlannerDebugProbeView(
                    "TripPlannerView.trip_detail.lazy_destination_body",
                    TripPlannerDebugLog.tripLabel(selectedTrip)
                )
                tripDetailDestination(for: selectedTrip)
            }
        }
        .navigationDestination(item: $selectedCountryForDetail) { country in
            CountryDetailView(country: country)
        }
    }

    @MainActor
    private func loadCurrentUserSnapshot() async {
        let loadStart = Date().timeIntervalSinceReferenceDate
        guard let userId = sessionManager.userId else {
            currentUserSnapshot = nil
            return
        }

        if let cachedProfile = profileService.cachedProfile(userId: userId) {
            currentUserSnapshot = TripPlannerFriendSnapshot(
                id: cachedProfile.id,
                displayName: cachedProfile.tripDisplayName,
                username: cachedProfile.username,
                avatarURL: cachedProfile.avatarUrl
            )
            TripPlannerDebugLog.message(
                "Current user snapshot loaded from cache duration=\(TripPlannerDebugLog.durationText(since: loadStart)) user=\(TripPlannerDebugLog.userLabel(userId))"
            )
            return
        }

        if let authSnapshot = currentUserAuthSnapshot(userId: userId) {
            currentUserSnapshot = authSnapshot
            TripPlannerDebugLog.message(
                "Current user snapshot primed from auth duration=\(TripPlannerDebugLog.durationText(since: loadStart)) user=\(TripPlannerDebugLog.userLabel(userId))"
            )
            return
        }

        TripPlannerDebugLog.message(
            "Current user snapshot unavailable without cache duration=\(TripPlannerDebugLog.durationText(since: loadStart)) user=\(TripPlannerDebugLog.userLabel(userId))"
        )
    }

    private func currentUserAuthSnapshot(userId: UUID) -> TripPlannerFriendSnapshot? {
        guard let user = SupabaseManager.shared.client.auth.currentUser,
              user.id == userId else {
            return nil
        }

        let metadata = user.userMetadata
        let firstName =
            metadata["first_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ??
            metadata["given_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName =
            metadata["full_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ??
            metadata["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarURL =
            metadata["avatar_url"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ??
            metadata["picture"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let username =
            metadata["user_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ??
            metadata["preferred_username"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ??
            "traveler"

        let displayName = [firstName, fullName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .first ?? String(localized: "trip_planner.you")

        if displayName.isEmpty && (avatarURL?.isEmpty ?? true) {
            return nil
        }

        return TripPlannerFriendSnapshot(
            id: userId,
            displayName: displayName,
            username: username,
            avatarURL: avatarURL?.isEmpty == true ? nil : avatarURL
        )
    }

    @MainActor
    private func preloadTripOwnerProfiles() async {
        let preloadStart = Date().timeIntervalSinceReferenceDate
        let ownerTargets = store.trips.compactMap { trip -> (tripId: UUID, ownerId: UUID, embeddedSnapshot: TripPlannerFriendSnapshot?)? in
            guard let ownerId = trip.ownerId,
                  ownerId != sessionManager.userId,
                  !trip.friends.contains(where: { $0.id == ownerId }) else {
                return nil
            }
            return (trip.id, ownerId, trip.effectiveOwnerSnapshot)
        }
        let uniqueOwnerCount = Set(ownerTargets.map(\.ownerId)).count

        TripPlannerDebugLog.message(
            "Owner preload started totalTrips=\(store.trips.count) ownerTargets=\(ownerTargets.count) uniqueOwners=\(uniqueOwnerCount)"
        )

        var nextSnapshots: [UUID: TripPlannerFriendSnapshot] = [:]
        var uncachedTripIDsByOwnerID: [UUID: [UUID]] = [:]
        TripPlannerDebugLog.probe("TripPlannerView.owner_preload.cache_scan.start")

        for target in ownerTargets {
            if let embeddedSnapshot = target.embeddedSnapshot {
                TripPlannerDebugLog.probe(
                    "TripPlannerView.owner_preload.embedded_snapshot",
                    "trip=\(target.tripId.uuidString) owner=\(TripPlannerDebugLog.userLabel(target.ownerId))"
                )
                nextSnapshots[target.tripId] = embeddedSnapshot
            } else if let cachedOwner = profileService.cachedProfile(userId: target.ownerId) {
                TripPlannerDebugLog.probe(
                    "TripPlannerView.owner_preload.cached_profile",
                    "trip=\(target.tripId.uuidString) owner=\(TripPlannerDebugLog.userLabel(target.ownerId))"
                )
                let snapshot = TripPlannerFriendSnapshot(
                    id: cachedOwner.id,
                    displayName: cachedOwner.tripDisplayName,
                    username: cachedOwner.username,
                    avatarURL: cachedOwner.avatarUrl
                )
                nextSnapshots[target.tripId] = snapshot
                store.cacheOwnerSnapshot(snapshot, forTripID: target.tripId)
            } else {
                TripPlannerDebugLog.probe(
                    "TripPlannerView.owner_preload.uncached_owner",
                    "trip=\(target.tripId.uuidString) owner=\(TripPlannerDebugLog.userLabel(target.ownerId))"
                )
                uncachedTripIDsByOwnerID[target.ownerId, default: []].append(target.tripId)
            }
        }
        TripPlannerDebugLog.probe(
            "TripPlannerView.owner_preload.cache_scan.end",
            "resolved=\(nextSnapshots.count) uncachedOwners=\(uncachedTripIDsByOwnerID.count) duration=\(TripPlannerDebugLog.durationText(since: preloadStart))"
        )

        ownerSnapshotsByTripID = nextSnapshots

        guard !uncachedTripIDsByOwnerID.isEmpty else {
            TripPlannerDebugLog.message(
                "Owner preload finished without remote fetch duration=\(TripPlannerDebugLog.durationText(since: preloadStart)) resolved=\(nextSnapshots.count)"
            )
            return
        }

        TripPlannerDebugLog.message(
            "Owner preload fetching remotely uncachedOwners=\(uncachedTripIDsByOwnerID.count) cachedResolved=\(nextSnapshots.count)"
        )

        await withTaskGroup(of: (UUID, TripPlannerFriendSnapshot?, [UUID]).self) { group in
            for (ownerId, tripIDs) in uncachedTripIDsByOwnerID {
                group.addTask {
                    let fetchStart = Date().timeIntervalSinceReferenceDate
                    let fetchedOwner = try? await profileService.fetchMyProfile(userId: ownerId)
                    let snapshot: TripPlannerFriendSnapshot?
                    if let fetchedOwner {
                        snapshot = await MainActor.run {
                            TripPlannerFriendSnapshot(
                                id: fetchedOwner.id,
                                displayName: fetchedOwner.tripDisplayName,
                                username: fetchedOwner.username,
                                avatarURL: fetchedOwner.avatarUrl
                            )
                        }
                        TripPlannerDebugLog.message(
                            "Owner profile fetched owner=\(fetchedOwner.username) tripCount=\(tripIDs.count) duration=\(TripPlannerDebugLog.durationText(since: fetchStart))"
                        )
                    } else {
                        snapshot = nil
                        TripPlannerDebugLog.message(
                            "Owner profile fetch failed ownerId=\(ownerId.uuidString) tripCount=\(tripIDs.count) duration=\(TripPlannerDebugLog.durationText(since: fetchStart))"
                        )
                    }
                    return (ownerId, snapshot, tripIDs)
                }
            }

            for await (_, snapshot, tripIDs) in group {
                guard let snapshot else { continue }
                for tripId in tripIDs {
                    ownerSnapshotsByTripID[tripId] = snapshot
                    store.cacheOwnerSnapshot(snapshot, forTripID: tripId)
                }
            }
        }

        TripPlannerDebugLog.message(
            "Owner preload finished duration=\(TripPlannerDebugLog.durationText(since: preloadStart)) resolved=\(ownerSnapshotsByTripID.count)"
        )
    }

    private static func seededCurrentUserSnapshot(profileService: ProfileService) -> TripPlannerFriendSnapshot? {
        guard let currentUserId = SupabaseManager.shared.currentUserId else {
            return nil
        }

        if let cachedProfile = profileService.cachedProfile(userId: currentUserId) {
            return TripPlannerFriendSnapshot(
                id: cachedProfile.id,
                displayName: cachedProfile.tripDisplayName,
                username: cachedProfile.username,
                avatarURL: cachedProfile.avatarUrl
            )
        }

        return TripPlannerFriendSnapshot.currentUserFallback(userId: currentUserId)
    }

    @ViewBuilder
    private func tripDetailDestination(for trip: TripPlannerTrip) -> some View {
        TripPlannerDetailView(
            trip: trip,
            onSave: { updatedTrip in
                store.upsert(updatedTrip)
            },
            onDelete: { choice in
                store.delete(id: trip.id, scope: choice.storeScope)
            },
            onAddToCalendar: { selectedTrip in
                Task {
                    await openCalendar(for: selectedTrip)
                }
            }
        )
        .task {
            sharedTripInbox.markSeen(tripId: trip.id)
        }
    }

    @MainActor
    private func openCalendar(for trip: TripPlannerTrip) async {
        guard let startDate = trip.startDate,
              let endDate = trip.endDate else {
            calendarError = String(localized: "trip_planner.calendar_error_missing_dates")
            return
        }

        let store = EKEventStore()

        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                calendarError = String(localized: "trip_planner.calendar_error_denied")
                return
            }

            let event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
            event.title = trip.title
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: startDate)
            event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate

            let travelerNames = calendarTravelerDisplayNames(for: trip)
            let noteParts = [
                trip.notes.isEmpty ? nil : trip.notes,
                trip.countryNames.isEmpty ? nil : String(
                    format: String(localized: "trip_planner.calendar_notes_countries"),
                    locale: AppDisplayLocale.current,
                    trip.countryNames.joined(separator: ", ")
                ),
                travelerNames.isEmpty ? nil : String(
                    format: String(localized: "trip_planner.calendar_notes_friends"),
                    locale: AppDisplayLocale.current,
                    travelerNames.joined(separator: ", ")
                )
            ].compactMap { $0 }
            event.notes = noteParts.joined(separator: "\n")

            calendarDraft = TripPlannerCalendarDraft(store: store, event: event)
        } catch {
            calendarError = error.localizedDescription.isEmpty
                ? String(localized: "trip_planner.calendar_error_generic")
                : error.localizedDescription
        }
    }

    private func calendarTravelerDisplayNames(for trip: TripPlannerTrip) -> [String] {
        var names = trip.travelerDisplayNames

        if let ownerId = trip.ownerId,
           ownerId != sessionManager.userId,
           !trip.friends.contains(where: { $0.id == ownerId }),
           let ownerName = trip.effectiveOwnerSnapshot?.displayName
            ?? ProfileService(supabase: SupabaseManager.shared).cachedProfile(userId: ownerId)?.tripDisplayName {
            names.insert(ownerName, at: 0)
        }

        var seen = Set<String>()
        return names.filter { rawName in
            let normalized = rawName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: AppDisplayLocale.current)
            guard !normalized.isEmpty else { return false }
            return seen.insert(normalized).inserted
        }
    }
}

private struct TripPlannerComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var bucketListStore: BucketListStore

    let onSave: (TripPlannerTrip) -> Void
    var existingTrip: TripPlannerTrip? = nil

    @State private var countries: [Country] = []
    @State private var bucketCountryIds: Set<String> = []
    @State private var selectedCountryIds: Set<String> = []
    @State private var friends: [Profile] = []
    @State private var selectedFriendIds: Set<UUID> = []
    @State private var friendBucketLists: [UUID: Set<String>] = [:]

    @State private var title = ""
    @State private var notes = ""
    @State private var searchText = ""
    @State private var includeDates = true
    @State private var includeFriends = false
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    @State private var isLoading = true
    @State private var isLoadingShared = false
    @State private var calendarDraft: TripPlannerCalendarDraft?
    @State private var calendarError: String?
    @State private var friendsError: String?
    @State private var showingAllFriends = false
    @State private var showingBucketCountries = false
    @StateObject private var usernameSearch = TripPlannerUsernameSearchController()

    private let friendService = FriendService()
    private let supabase = SupabaseManager.shared
    private let profileService = ProfileService(supabase: SupabaseManager.shared)

    init(
        existingTrip: TripPlannerTrip? = nil,
        onSave: @escaping (TripPlannerTrip) -> Void
    ) {
        self.onSave = onSave
        self.existingTrip = existingTrip
        _title = State(initialValue: existingTrip?.title ?? "")
        _notes = State(initialValue: existingTrip?.notes ?? "")
        _selectedCountryIds = State(initialValue: Set(existingTrip?.countryIds ?? []))
        _selectedFriendIds = State(initialValue: Set(existingTrip?.friendIds ?? []))
        _includeDates = State(initialValue: existingTrip?.startDate != nil || existingTrip?.endDate != nil)
        _includeFriends = State(initialValue: !(existingTrip?.friendIds.isEmpty ?? true))
        _startDate = State(initialValue: existingTrip?.startDate ?? Date())
        _endDate = State(initialValue: existingTrip?.endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
    }

    private var rankedFriends: [Profile] {
        friends.sorted { lhs, rhs in
            let lhsSelected = selectedFriendIds.contains(lhs.id)
            let rhsSelected = selectedFriendIds.contains(rhs.id)
            if lhsSelected != rhsSelected {
                return lhsSelected && !rhsSelected
            }

            let lhsCount = mutualBucketCount(for: lhs.id)
            let rhsCount = mutualBucketCount(for: rhs.id)
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }

            return displayName(for: lhs).localizedCaseInsensitiveCompare(displayName(for: rhs)) == .orderedAscending
        }
    }

    private var selectedFriends: [Profile] {
        friends.filter { selectedFriendIds.contains($0.id) }
    }

    private var friendPreview: [Profile] {
        Array(rankedFriends.prefix(3))
    }

    private var sharedCountryIds: Set<String> {
        guard includeFriends, !selectedFriendIds.isEmpty else { return [] }

        var intersection = bucketCountryIds
        for friendId in selectedFriendIds {
            guard let friendBuckets = friendBucketLists[friendId] else { return [] }
            intersection.formIntersection(friendBuckets)
        }
        return intersection
    }

    private var sharedCountries: [Country] {
        countries
            .filter { sharedCountryIds.contains($0.id) && !selectedCountryIds.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var countryBucketMatchCounts: [String: Int] {
        var counts: [String: Int] = [:]

        for countryId in bucketCountryIds {
            counts[countryId, default: 0] += 1
        }

        for friendId in selectedFriendIds {
            for countryId in friendBucketLists[friendId] ?? [] {
                counts[countryId, default: 0] += 1
            }
        }

        return counts
    }

    private var countryPickerSections: [TripPlannerCountryPickerSection] {
        let groupSize = selectedFriendIds.count + 1
        let unselectedCountries = countries.filter { !selectedCountryIds.contains($0.id) }
        var sections: [TripPlannerCountryPickerSection] = []

        if !selectedCountries.isEmpty {
            sections.append(
                TripPlannerCountryPickerSection(
                    title: String(localized: "trip_planner.country_picker.already_in_trip"),
                    countries: selectedCountries
                )
            )
        }

        if groupSize > 1 {
            let mutualCountries = unselectedCountries
                .filter { countryBucketMatchCounts[$0.id, default: 0] == groupSize }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            if !mutualCountries.isEmpty {
                sections.append(
                    TripPlannerCountryPickerSection(
                        title: String(localized: "trip_planner.country_picker.everyones_bucket"),
                        countries: mutualCountries
                    )
                )
            }
        }

        if groupSize > 2 {
            for matchCount in stride(from: groupSize - 1, through: 2, by: -1) {
                let matchingCountries = unselectedCountries
                    .filter { countryBucketMatchCounts[$0.id, default: 0] == matchCount }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                if !matchingCountries.isEmpty {
                    sections.append(
                        TripPlannerCountryPickerSection(
                            title: String(
                                format: String(localized: "trip_planner.country_picker.match_count_format"),
                                locale: AppDisplayLocale.current,
                                matchCount,
                                groupSize
                            ),
                            countries: matchingCountries
                        )
                    )
                }
            }
        }

        let oneBucketCountries = unselectedCountries
            .filter { countryBucketMatchCounts[$0.id, default: 0] == 1 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if !oneBucketCountries.isEmpty {
            sections.append(
                TripPlannerCountryPickerSection(
                    title: groupSize > 1 ? String(localized: "trip_planner.country_picker.one_person_bucket") : String(localized: "trip_planner.country_picker.from_your_bucket"),
                    countries: oneBucketCountries
                )
            )
        }

        let otherCountries = unselectedCountries
            .filter { countryBucketMatchCounts[$0.id, default: 0] == 0 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if !otherCountries.isEmpty {
            sections.append(
                TripPlannerCountryPickerSection(
                    title: String(localized: "trip_planner.country_picker.all_other_countries"),
                    countries: otherCountries
                )
            )
        }

        return sections
    }

    private var selectedCountries: [Country] {
        countries
            .filter { selectedCountryIds.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var canSave: Bool {
        !selectedCountryIds.isEmpty
            || !selectedFriendIds.isEmpty
            || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.create_trip_title"))

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("trip_planner.loading")
                            .font(.subheadline)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.basics.title"),
                                subtitle: String(localized: "trip_planner.basics.subtitle")
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    TripPlannerTextInput(
                                        title: String(localized: "trip_planner.trip_name"),
                                        text: $title,
                                        placeholder: String(localized: "trip_planner.trip_name_placeholder")
                                    )

                                    TripPlannerTextInput(
                                        title: String(localized: "trip_planner.notes"),
                                        text: $notes,
                                        placeholder: String(localized: "trip_planner.notes_placeholder"),
                                        axis: .vertical
                                    )

                                    Toggle("trip_planner.add_tentative_dates", isOn: $includeDates)
                                        .tint(.black)

                                    if includeDates {
                                        DatePicker("trip_planner.start", selection: $startDate, displayedComponents: .date)
                                            .tint(.black)

                                        DatePicker("trip_planner.end", selection: $endDate, in: startDate..., displayedComponents: .date)
                                            .tint(.black)

                                        Button {
                                            Task {
                                                await openDraftCalendar()
                                            }
                                        } label: {
                                            Label("trip_planner.preview_calendar", systemImage: "calendar.badge.plus")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.black)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(Color.white.opacity(0.82))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.whos_going.title"),
                                subtitle: String(localized: "trip_planner.whos_going.subtitle")
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Toggle("trip_planner.plan_with_friends", isOn: $includeFriends)
                                        .tint(.black)

                                    if includeFriends {
                                        if !sessionManager.isAuthenticated {
                                            TripPlannerInfoCard(
                                                text: String(localized: "trip_planner.friend_matching_locked"),
                                                systemImage: "lock.fill"
                                            )
                                        } else if let friendsError {
                                            TripPlannerInfoCard(
                                                text: friendsError,
                                                systemImage: "exclamationmark.triangle.fill"
                                            )
                                        } else if friends.isEmpty {
                                            TripPlannerInfoCard(
                                                text: String(localized: "trip_planner.no_friends_yet"),
                                                systemImage: "person.2.slash"
                                            )
                                        } else {
                                            HStack {
                                                Text("trip_planner.travel_friends")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.black)

                                                Spacer()

                                                if rankedFriends.count > 3 {
                                                    Button("trip_planner.see_more") {
                                                        showingAllFriends = true
                                                    }
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.black)
                                                }
                                            }

                                            LazyVStack(spacing: 10) {
                                                ForEach(friendPreview) { friend in
                                                    Button {
                                                        toggleFriend(friend.id)
                                                    } label: {
                                                        TripPlannerFriendRow(
                                                            profile: friend,
                                                            isSelected: selectedFriendIds.contains(friend.id),
                                                            displayName: displayName(for: friend),
                                                            mutualBucketCount: mutualBucketCount(for: friend.id)
                                                        )
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }

                                            if isLoadingShared {
                                                ProgressView("trip_planner.comparing_bucket_lists")
                                                    .tint(.black)
                                            }
                                        }

                                        TripPlannerTextInput(
                                            title: "Add by username",
                                            text: $usernameSearch.query,
                                            placeholder: "@username"
                                        )

                                        if usernameSearch.isSearching {
                                            ProgressView()
                                                .tint(.black)
                                        } else if !usernameSearch.results.isEmpty {
                                            LazyVStack(spacing: 10) {
                                                ForEach(usernameSearch.results) { profile in
                                                    Button {
                                                        addSearchedUser(profile)
                                                    } label: {
                                                        TripPlannerFriendRow(
                                                            profile: profile,
                                                            isSelected: selectedFriendIds.contains(profile.id),
                                                            displayName: displayName(for: profile),
                                                            mutualBucketCount: mutualBucketCount(for: profile.id)
                                                        )
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.countries.title"),
                                subtitle: String(localized: "trip_planner.countries.subtitle")
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    if !selectedCountries.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("trip_planner.included_in_trip")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.black)

                                            TripPlannerChipGrid(
                                                items: selectedCountries.map { country in
                                                    TripPlannerChipItem(
                                                        id: country.id,
                                                        title: "\(country.flagEmoji) \(country.localizedDisplayName)",
                                                        isSelected: true
                                                    )
                                                },
                                                onTap: { item in
                                                    toggleCountry(item.id)
                                                }
                                            )
                                        }
                                    } else {
                                        TripPlannerInfoCard(
                                            text: String(localized: "trip_planner.pick_country_before_save"),
                                            systemImage: "mappin.and.ellipse"
                                        )
                                    }

                                    if !sharedCountries.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text("trip_planner.shared_bucket_matches")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.black)

                                                Spacer()

                                                Button("trip_planner.add_all") {
                                                    selectedCountryIds.formUnion(sharedCountryIds)
                                                }
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.black)
                                            }

                                            TripPlannerChipGrid(
                                                items: sharedCountries.map { country in
                                                    TripPlannerChipItem(
                                                        id: country.id,
                                                        title: "\(country.flagEmoji) \(country.localizedDisplayName)",
                                                        isSelected: false
                                                    )
                                                },
                                                onTap: { item in
                                                    toggleCountry(item.id)
                                                }
                                            )
                                        }
                                    }

                                    Button {
                                        showingBucketCountries = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .bold))

                                            Text("trip_planner.add_more_countries")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.82))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.pageHorizontalInset)
                        .padding(.top, 18)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                saveTrip()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(canSave ? .black : .black.opacity(0.35))
            .disabled(!canSave)
        }
        .sheet(item: $calendarDraft) { draft in
            TripPlannerCalendarSheet(draft: draft)
        }
        .sheet(isPresented: $showingAllFriends) {
            NavigationStack {
                TripPlannerFriendPickerSheet(
                    friends: rankedFriends,
                    selectedIds: selectedFriendIds,
                    displayName: displayName(for:),
                    mutualBucketCount: mutualBucketCount(for:),
                    onToggle: toggleFriend
                )
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBucketCountries) {
            NavigationStack {
                TripPlannerCountryPickerSheet(
                    title: String(localized: "trip_planner.add_countries"),
                    sections: countryPickerSections,
                    selectedIds: selectedCountryIds,
                    bucketIds: Set(countryBucketMatchCounts.keys),
                    sharedIds: sharedCountryIds,
                    onTap: toggleCountry
                )
            }
            .presentationDragIndicator(.visible)
        }
        .alert(String(localized: "trip_planner.calendar_access"), isPresented: Binding(
            get: { calendarError != nil },
            set: { newValue in
                if !newValue {
                    calendarError = nil
                }
            }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(calendarError ?? "")
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedFriendIds) { _, _ in
            Task {
                await loadMissingFriendBuckets()
            }
        }
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
        .onChange(of: includeFriends) { _, enabled in
            if !enabled {
                selectedFriendIds.removeAll()
                usernameSearch.reset()
            }
        }
        .onChange(of: usernameSearch.query) { _, _ in
            usernameSearch.scheduleSearch(
                enabled: includeFriends,
                excluding: sessionManager.userId
            )
        }
        .onDisappear {
            usernameSearch.cancel()
        }
    }

    @MainActor
    private func loadData() async {
        if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
            countries = cached
        }

        bucketCountryIds = bucketListStore.ids

        let userId = sessionManager.userId
        async let freshCountriesTask = CountryAPI.refreshCountriesIfNeeded(minInterval: 60)
        async let fetchedBucketIdsTask: Set<String>? = {
            guard let userId else { return nil }
            return try? await profileService.fetchBucketListCountries(userId: userId)
        }()
        async let fetchedFriendsTask: [Profile]? = {
            guard let userId else { return nil }
            return try? await friendService.fetchFriends(for: userId)
        }()

        if userId != nil {
            if let bucketIds = await fetchedBucketIdsTask {
                bucketCountryIds = bucketIds
            }

            if let fetchedFriends = await fetchedFriendsTask {
                friends = fetchedFriends
                friendsError = nil
                await loadFriendBuckets(for: fetchedFriends.map(\.id))
            } else {
                friendsError = String(localized: "trip_planner.friends.load_error")
            }
        }

        if let freshCountries = await freshCountriesTask, !freshCountries.isEmpty {
            countries = freshCountries
        }

        isLoading = false
    }

    @MainActor
    private func loadMissingFriendBuckets() async {
        guard includeFriends, !selectedFriendIds.isEmpty else { return }

        let missing = selectedFriendIds.filter { friendBucketLists[$0] == nil }
        guard !missing.isEmpty else { return }

        isLoadingShared = true
        defer { isLoadingShared = false }

        await loadFriendBuckets(for: Array(missing))
    }

    private func displayName(for profile: Profile) -> String {
        profile.tripDisplayName
    }

    private func mutualBucketCount(for friendId: UUID) -> Int {
        bucketCountryIds.intersection(friendBucketLists[friendId] ?? []).count
    }

    @MainActor
    private func loadFriendBuckets(for friendIds: [UUID]) async {
        let uncachedFriendIds = friendIds.filter { friendBucketLists[$0] == nil }
        guard !uncachedFriendIds.isEmpty else { return }

        let fetchedBuckets = await withTaskGroup(of: (UUID, Set<String>).self, returning: [(UUID, Set<String>)].self) { group in
            for friendId in uncachedFriendIds {
                group.addTask {
                    let bucketIds = (try? await profileService.fetchBucketListCountries(userId: friendId)) ?? []
                    return (friendId, bucketIds)
                }
            }

            var results: [(UUID, Set<String>)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        for (friendId, bucketIds) in fetchedBuckets {
            friendBucketLists[friendId] = bucketIds
        }
    }

    private func toggleCountry(_ id: String) {
        if selectedCountryIds.contains(id) {
            selectedCountryIds.remove(id)
        } else {
            selectedCountryIds.insert(id)
        }
    }

    private func toggleFriend(_ id: UUID) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
        }
    }

    @MainActor
    private func addSearchedUser(_ profile: Profile) {
        if !friends.contains(where: { $0.id == profile.id }) {
            friends.append(profile)
        }
        selectedFriendIds.insert(profile.id)
        usernameSearch.reset()
        TripPlannerDebugLog.message(
            "Added searched user @\(profile.username) [\(profile.id.uuidString)] to draft trip for actor=\(TripPlannerDebugLog.userLabel(sessionManager.userId))"
        )
    }

    private func resolvedTripTitle() -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        if let firstCountry = selectedCountries.first {
            return String(format: String(localized: "trip_planner.generated_title_format"), locale: AppDisplayLocale.current, firstCountry.localizedDisplayName)
        }

        return String(localized: "trip_planner.new_trip")
    }

    @MainActor
    private func openDraftCalendar() async {
        let store = EKEventStore()

        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                calendarError = String(localized: "trip_planner.calendar_error_denied")
                return
            }

            let event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
            event.title = resolvedTripTitle()
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: startDate)
            event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            event.notes = notes
            calendarDraft = TripPlannerCalendarDraft(store: store, event: event)
        } catch {
            calendarError = error.localizedDescription
        }
    }

    private func saveTrip() {
        let trip = TripPlannerTrip(
            id: existingTrip?.id ?? UUID(),
            createdAt: existingTrip?.createdAt ?? Date(),
            title: resolvedTripTitle(),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: includeDates ? startDate : nil,
            endDate: includeDates ? endDate : nil,
            countryIds: selectedCountries.map(\.id),
            countryNames: selectedCountries.map(\.name),
            friendIds: selectedFriends.map(\.id),
            friendNames: selectedFriends.map(displayName),
            friends: selectedFriends.map(friendSnapshot),
            ownerId: existingTrip?.ownerId,
            ownerSnapshot: existingTrip?.effectiveOwnerSnapshot,
            plannerCurrencyCode: existingTrip?.plannerCurrencyCode ?? CurrencyPreferenceStore.persistedDefaultCurrencyCode(),
            availability: selectedFriends.isEmpty ? [] : (existingTrip?.availability ?? defaultAvailability()),
            dayPlans: TripPlannerDayPlanBuilder.syncedDayPlans(
                existingPlans: existingTrip?.dayPlans ?? [],
                startDate: includeDates ? startDate : nil,
                endDate: includeDates ? endDate : nil,
                countries: selectedCountries.map { ($0.id, $0.name) }
            ),
            overallChecklistItems: existingTrip?.overallChecklistItems ?? [],
            packingProgressEntries: existingTrip?.packingProgressEntries ?? [],
            expenses: existingTrip?.expenses ?? []
        )

        TripPlannerDebugLog.message(
            """
            Composer save prepared trip \(TripPlannerDebugLog.tripLabel(trip))
            actor=\(TripPlannerDebugLog.userLabel(sessionManager.userId))
            usernames=[\(trip.friends.map(\.username).joined(separator: ", "))]
            participantIds=[\(TripPlannerDebugLog.participantLabels(for: trip.participantIDs(including: sessionManager.userId)))]
            """
        )

        onSave(trip)
        dismiss()
    }

    private func friendSnapshot(for profile: Profile) -> TripPlannerFriendSnapshot {
        TripPlannerFriendSnapshot(
            id: profile.id,
            displayName: displayName(for: profile),
            username: profile.username,
            avatarURL: profile.avatarUrl
        )
    }

    private func defaultAvailability() -> [TripPlannerAvailabilityProposal] {
        guard includeDates else { return [] }
        let currentUserId = sessionManager.userId ?? supabase.currentUserId
        let currentProfile = currentUserId.flatMap { profileService.cachedProfile(userId: $0) }
        return [
            TripPlannerAvailabilityProposal(
                id: UUID(),
                participantId: currentUserId?.uuidString ?? "self",
                participantName: currentProfile?.tripDisplayName ?? String(localized: "trip_planner.you"),
                participantUsername: currentProfile?.username,
                participantAvatarURL: currentProfile?.avatarUrl,
                kind: .exactDates,
                startDate: startDate,
                endDate: endDate
            )
        ]
    }
}

private struct TripPlannerChecklistPresentation {
    let trip: TripPlannerTrip
    let actorId: UUID?
    let actorName: String
    let countries: [Country]
    let groupVisaNeeds: [TripPlannerTravelerVisaNeed]
    let saveAction: TripPlannerTripSaveAction
}

// Keep pushed checklist destinations on stable snapshot data and reference-stable
// actions. Building them from live parent state plus fresh closures caused SwiftUI
// to churn the active navigation stack and repeatedly recreate "What to pack".
private final class TripPlannerTripSaveAction {
    let handler: (TripPlannerTrip) -> Void

    init(handler: @escaping (TripPlannerTrip) -> Void) {
        self.handler = handler
    }
}

private struct TripPlannerPackingDraft {
    let item: TripPlannerChecklistItem
    let progressEntries: [TripPlannerPackingProgress]
}

private final class TripPlannerPackingCommitAction {
    let handler: (TripPlannerPackingDraft) -> Void

    init(handler: @escaping (TripPlannerPackingDraft) -> Void) {
        self.handler = handler
    }
}

private struct TripPlannerDetailView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    @State private var trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void
    let onDelete: (TripPlannerDeleteChoice) -> Void
    let onAddToCalendar: (TripPlannerTrip) -> Void

    @State private var resolvedFriends: [TripPlannerFriendSnapshot]
    @State private var isLoadingFriendProfiles = false
    @State private var resolvedCountries: [Country] = []
    @State private var currentUserSnapshot: TripPlannerFriendSnapshot?
    @State private var ownerSnapshot: TripPlannerFriendSnapshot?
    @State private var currentPassportPreferences: PassportPreferences = .empty
    @State private var travelerPassportPreferences: [UUID: PassportPreferences] = [:]
    @State private var travelerProfiles: [UUID: Profile] = [:]
    @State private var groupLanguageScoresByCountry: [String: Int] = [:]
    @State private var groupVisaNeeds: [TripPlannerTravelerVisaNeed] = []
    @State private var showingDeleteOptions = false
    @State private var pendingDeleteChoice: TripPlannerDeleteChoice?
    @State private var checklistPresentation: TripPlannerChecklistPresentation?
    @State private var isShowingChecklistEditor = false
    @State private var selectedCountryForDetail: Country?

    private let profileService = ProfileService(supabase: SupabaseManager.shared)
    private let visaStore = VisaRequirementsStore.shared
    private let scoreWeightsStore = ScoreWeightsStore()

    init(
        trip: TripPlannerTrip,
        onSave: @escaping (TripPlannerTrip) -> Void,
        onDelete: @escaping (TripPlannerDeleteChoice) -> Void,
        onAddToCalendar: @escaping (TripPlannerTrip) -> Void
    ) {
        let profileService = ProfileService(supabase: SupabaseManager.shared)
        let currentUserSnapshot = Self.seededCurrentUserSnapshot(profileService: profileService)

        let ownerSnapshot: TripPlannerFriendSnapshot?
        if let ownerId = trip.ownerId,
           ownerId != SupabaseManager.shared.currentUserId,
           let embeddedOwnerSnapshot = trip.effectiveOwnerSnapshot {
            ownerSnapshot = embeddedOwnerSnapshot
        } else if let ownerId = trip.ownerId,
                  ownerId != SupabaseManager.shared.currentUserId,
                  let cachedOwner = profileService.cachedProfile(userId: ownerId) {
            ownerSnapshot = TripPlannerFriendSnapshot(
                id: cachedOwner.id,
                displayName: cachedOwner.tripDisplayName,
                username: cachedOwner.username,
                avatarURL: cachedOwner.avatarUrl
            )
        } else {
            ownerSnapshot = nil
        }

        _trip = State(initialValue: trip)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onAddToCalendar = onAddToCalendar
        _resolvedFriends = State(initialValue: trip.friends)
        _currentUserSnapshot = State(initialValue: currentUserSnapshot)
        _ownerSnapshot = State(initialValue: ownerSnapshot)
    }

    private var tripContentRefreshKey: String {
        let startInterval = trip.startDate?.timeIntervalSince1970 ?? 0
        let endInterval = trip.endDate?.timeIntervalSince1970 ?? 0
        let countryKey = trip.countryIds.joined(separator: ",")
        let friendKey = trip.friendIds.map(\.uuidString).joined(separator: ",")
        return "\(trip.id.uuidString)|\(startInterval)|\(endInterval)|\(countryKey)|\(friendKey)"
    }

    private func saveTripChanges(_ updatedTrip: TripPlannerTrip) {
        let normalizedTrip = updatedTrip
            .preservingMissingState(from: trip)
            .normalizedForPersistence(currentUser: currentUserSnapshot)
        trip = normalizedTrip
        ownerSnapshot = normalizedTrip.effectiveOwnerSnapshot
        onSave(normalizedTrip)
    }

    private var displayedFriends: [TripPlannerFriendSnapshot] {
        resolvedFriends.isEmpty ? trip.friends : resolvedFriends
    }

    private static func seededCurrentUserSnapshot(profileService: ProfileService) -> TripPlannerFriendSnapshot? {
        guard let currentUserId = SupabaseManager.shared.currentUserId else {
            return nil
        }

        if let cachedProfile = profileService.cachedProfile(userId: currentUserId) {
            return TripPlannerFriendSnapshot(
                id: cachedProfile.id,
                displayName: cachedProfile.tripDisplayName,
                username: cachedProfile.username,
                avatarURL: cachedProfile.avatarUrl
            )
        }

        // Keep the planner neutral until the persisted profile arrives so
        // auth-provider metadata never flashes over a customized profile.
        return TripPlannerFriendSnapshot.currentUserFallback(userId: currentUserId)
    }

    private var displayedTravelers: [TripPlannerFriendSnapshot] {
        var travelers: [TripPlannerFriendSnapshot] = []

        if let currentUserSnapshot {
            travelers.append(currentUserSnapshot)
        }

        if let ownerSnapshot {
            travelers.append(ownerSnapshot)
        }

        travelers.append(contentsOf: displayedFriends)

        var seen = Set<UUID>()
        return travelers.filter { traveler in
            seen.insert(traveler.id).inserted
        }
    }

    private var displayedCountries: [Country] {
        resolvedCountries.isEmpty ? trip.countryIds.enumerated().map { index, id in
            Country(
                iso2: id,
                name: CountrySelectionFormatter.localizedName(for: id),
                score: nil
            )
        } : resolvedCountries
    }

    private var isDisplayedGroupTrip: Bool {
        displayedTravelers.count > 1
    }

    private var effectiveScoreWeights: ScoreWeights {
        isDisplayedGroupTrip ? .default : scoreWeightsStore.weights
    }

    private var checklistActorName: String {
        if let currentUserSnapshot {
            return currentUserSnapshot.displayName
        }

        if let ownerSnapshot, ownerSnapshot.id == sessionManager.userId {
            return ownerSnapshot.displayName
        }

        return "You"
    }

    private var syncedOverallChecklistItems: [TripPlannerChecklistItem] {
        TripPlannerChecklistBuilder.syncedOverallChecklistItems(
            existingItems: trip.overallChecklistItems,
            countries: displayedCountries,
            groupVisaNeeds: groupVisaNeeds
        )
    }

    private var syncedTrip: TripPlannerTrip {
        TripPlannerTrip(
            id: trip.id,
            createdAt: trip.createdAt,
            updatedAt: trip.updatedAt,
            title: trip.title,
            notes: trip.notes,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countryIds: trip.countryIds,
            countryNames: trip.countryNames,
            friendIds: trip.friendIds,
            friendNames: trip.friendNames,
            friends: trip.friends,
            ownerId: trip.ownerId,
            ownerSnapshot: trip.effectiveOwnerSnapshot,
            plannerCurrencyCode: trip.plannerCurrencyCode,
            availability: trip.availability,
            dayPlans: TripPlannerDayPlanBuilder.syncedDayPlans(
                existingPlans: trip.dayPlans,
                startDate: trip.startDate,
                endDate: trip.endDate,
                countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
            ),
            overallChecklistItems: syncedOverallChecklistItems,
            packingProgressEntries: trip.packingProgressEntries,
            expenses: trip.expenses
        )
    }

    private var effectivePlannerCurrencyCode: String {
        trip.effectivePlannerCurrencyCode
    }

    private var limitedVisaNeeds: [TripPlannerTravelerVisaNeed] {
        Array(groupVisaNeeds.prefix(3))
    }

    @ViewBuilder
    private var checklistSection: some View {
        Button {
            openChecklistEditor()
        } label: {
            TripPlannerNavigationSectionCard(
                title: "Planning checklist",
                subtitle: ""
            ) {
                TripPlannerChecklistPreviewSection(
                    trip: syncedTrip,
                    countries: displayedCountries,
                    groupVisaNeeds: groupVisaNeeds
                )
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tripDetailsSection: some View {
        TripPlannerEditableSectionCard(
            title: String(localized: "trip_planner.detail.trip_details"),
            subtitle: isDisplayedGroupTrip ? String(localized: "trip_planner.detail.group_trip") : String(localized: "trip_planner.detail.solo_trip")
        ) {
            NavigationLink {
                TripPlannerBasicsEditorView(trip: trip, onSave: saveTripChanges)
            } label: {
                Text("common.edit")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                if let rangeText = TripPlannerDateFormatter.rangeText(start: trip.startDate, end: trip.endDate) {
                    Label(rangeText, systemImage: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                }

                if !trip.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("trip_planner.notes")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black.opacity(0.75))

                        Text(trip.notes)
                            .font(.system(size: 16))
                            .foregroundStyle(.black)

                        TripPlannerDetectedLinkList(text: trip.notes)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var travelersSection: some View {
        TripPlannerEditableSectionCard(
            title: "Who's going",
            subtitle: displayedTravelers.isEmpty ? String(localized: "trip_planner.detail.just_you_for_now") : ""
        ) {
            NavigationLink {
                TripPlannerFriendsEditorView(trip: trip, onSave: saveTripChanges)
            } label: {
                Text("common.edit")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        } content: {
            if displayedTravelers.isEmpty {
                TripPlannerInfoCard(
                    text: String(localized: "trip_planner.detail.no_friends_added"),
                    systemImage: "person"
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if isLoadingFriendProfiles && displayedFriends.isEmpty {
                        ProgressView("trip_planner.detail.loading_profiles")
                            .tint(.black)
                    }

                    ForEach(displayedTravelers) { friend in
                        Group {
                            if friend.id == sessionManager.userId {
                                TripPlannerSelectedFriendCard(friend: friend)
                            } else {
                                NavigationLink {
                                    TripPlannerProfileDestinationView(userId: friend.id)
                                } label: {
                                    TripPlannerSelectedFriendCard(friend: friend)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var countriesSection: some View {
        TripPlannerEditableSectionCard(
            title: String(localized: "trip_planner.countries.title"),
            subtitle: ""
        ) {
            NavigationLink {
                TripPlannerCountriesEditorView(trip: trip, onSave: saveTripChanges)
            } label: {
                Text("common.edit")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        } content: {
            TripPlannerCountryNavigationGrid(
                countries: displayedCountries,
                onOpenCountry: { country in
                    selectedCountryForDetail = country
                }
            )
        }
    }

    @ViewBuilder
    private var expensesSectionLink: some View {
        NavigationLink {
            TripPlannerExpensesEditorView(
                trip: trip,
                participants: displayedTravelers,
                currencyCode: effectivePlannerCurrencyCode,
                onSave: saveTripChanges
            )
        } label: {
            TripPlannerNavigationSectionCard(
                title: String(localized: "trip_planner.expenses.title"),
                subtitle: ""
            ) {
                TripPlannerExpensesPreviewSection(
                    expenses: trip.expenses,
                    currencyCode: effectivePlannerCurrencyCode
                )
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statsSectionLink: some View {
        NavigationLink {
            TripPlannerTripScoreBreakdownView(
                countries: displayedCountries,
                startDate: trip.startDate,
                endDate: trip.endDate,
                tripDayPlans: syncedTrip.dayPlans,
                weights: effectiveScoreWeights,
                preferredMonth: scoreWeightsStore.selectedMonth,
                isGroupTrip: isDisplayedGroupTrip,
                travelerCount: displayedTravelers.count,
                currencyCode: effectivePlannerCurrencyCode,
                passportLabel: tripPassportLabel,
                groupLanguageScoresByCountry: groupLanguageScoresByCountry,
                groupVisaNeeds: groupVisaNeeds
            )
        } label: {
            TripPlannerNavigationSectionCard(
                title: String(localized: "trip_planner.detail.trip_stats"),
                subtitle: ""
            ) {
                TripPlannerStatsPreviewSection(
                    countries: displayedCountries,
                    startDate: trip.startDate,
                    endDate: trip.endDate,
                    tripDayPlans: syncedTrip.dayPlans,
                    weights: effectiveScoreWeights,
                    preferredMonth: scoreWeightsStore.selectedMonth,
                    isGroupTrip: isDisplayedGroupTrip,
                    travelerCount: displayedTravelers.count,
                    currencyCode: effectivePlannerCurrencyCode,
                    groupVisaNeeds: limitedVisaNeeds
                )
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var availabilitySectionLink: some View {
        TripPlannerSectionCard(
            title: String(localized: "trip_planner.availability.title"),
            subtitle: String(localized: "trip_planner.detail.availability_group_subtitle")
        ) {
            TripPlannerInlineAvailabilityEditor(
                trip: syncedTrip,
                onSave: saveTripChanges
            )
        }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel5")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(trip.title)

                ScrollView {
                    VStack(spacing: 18) {
                        tripDetailsSection
                        travelersSection
                        countriesSection
                        checklistSection
                        expensesSectionLink
                        statsSectionLink
                        if isDisplayedGroupTrip {
                            availabilitySectionLink
                        }

                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.actions.title"),
                            subtitle: String(localized: "trip_planner.actions.subtitle")
                        ) {
                            VStack(spacing: 12) {
                                if trip.startDate != nil, trip.endDate != nil {
                                    Button {
                                        onAddToCalendar(trip)
                                    } label: {
                                        Label("trip_planner.actions.add_to_calendar", systemImage: "calendar.badge.plus")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.black)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color.white.opacity(0.84))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button(role: .destructive) {
                                    showingDeleteOptions = true
                                } label: {
                                    Label("trip_planner.actions.delete_trip", systemImage: "trash")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.84))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            EmptyView()
        }
        .confirmationDialog("Delete Trip", isPresented: $showingDeleteOptions) {
            Button("Delete for me only", role: .destructive) {
                pendingDeleteChoice = .justMe
            }

            Button("Delete for everyone", role: .destructive) {
                pendingDeleteChoice = .everyone
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether to remove this trip only from your planner or from the whole group.")
        }
        .alert(
            pendingDeleteChoice?.confirmationTitle ?? "Delete Trip",
            isPresented: Binding(
                get: { pendingDeleteChoice != nil },
                set: { newValue in
                    if !newValue {
                        pendingDeleteChoice = nil
                    }
                }
            ),
            presenting: pendingDeleteChoice
        ) { choice in
            Button(choice.title, role: .destructive) {
                onDelete(choice)
                pendingDeleteChoice = nil
            }

            Button("Cancel", role: .cancel) {
                pendingDeleteChoice = nil
            }
        } message: { choice in
            Text(choice.confirmationMessage)
        }
        .task(id: tripContentRefreshKey) {
            await loadTravelerProfiles()
            await loadCountryStats()
            await loadGroupLanguageScores()
        }
        .navigationDestination(isPresented: $isShowingChecklistEditor) {
            if let presentation = checklistPresentation {
                TripPlannerChecklistEditorView(
                    trip: presentation.trip,
                    actorId: presentation.actorId,
                    actorName: presentation.actorName,
                    countries: presentation.countries,
                    groupVisaNeeds: presentation.groupVisaNeeds,
                    saveAction: presentation.saveAction
                )
            }
        }
        .navigationDestination(item: $selectedCountryForDetail) { country in
            CountryDetailView(country: country)
        }
    }

    private func openChecklistEditor() {
        checklistPresentation = TripPlannerChecklistPresentation(
            trip: syncedTrip,
            actorId: sessionManager.userId,
            actorName: checklistActorName,
            countries: displayedCountries,
            groupVisaNeeds: groupVisaNeeds,
            saveAction: TripPlannerTripSaveAction(handler: saveTripChanges)
        )
        isShowingChecklistEditor = true
    }

    @MainActor
    private func loadTravelerProfiles() async {
        isLoadingFriendProfiles = true
        defer { isLoadingFriendProfiles = false }

        if currentUserSnapshot == nil {
            currentUserSnapshot = Self.seededCurrentUserSnapshot(profileService: profileService)
        }

        var refreshed: [TripPlannerFriendSnapshot] = []
        var profilesByID: [UUID: Profile] = [:]
        var passportPreferencesByUserID: [UUID: PassportPreferences] = [:]

        if let currentUserId = sessionManager.userId {
            if let cached = profileService.cachedProfile(userId: currentUserId) {
                profilesByID[currentUserId] = cached
                currentUserSnapshot = friendSnapshot(from: cached)
            } else if let profile = try? await profileService.fetchMyProfile(userId: currentUserId) {
                profilesByID[currentUserId] = profile
                currentUserSnapshot = friendSnapshot(from: profile)
            }

            if let cachedPreferences = profileService.cachedPassportPreferences(userId: currentUserId) {
                currentPassportPreferences = cachedPreferences
                passportPreferencesByUserID[currentUserId] = cachedPreferences
            } else if let preferences = try? await profileService.fetchPassportPreferences(userId: currentUserId) {
                currentPassportPreferences = preferences
                passportPreferencesByUserID[currentUserId] = preferences
            }
        }

        if let ownerId = trip.ownerId, ownerId != sessionManager.userId {
            if let cachedOwner = profileService.cachedProfile(userId: ownerId) {
                profilesByID[ownerId] = cachedOwner
                ownerSnapshot = friendSnapshot(from: cachedOwner)
            } else if let ownerProfile = try? await profileService.fetchMyProfile(userId: ownerId) {
                profilesByID[ownerId] = ownerProfile
                ownerSnapshot = friendSnapshot(from: ownerProfile)
            }
        } else {
            ownerSnapshot = nil
        }

        for snapshot in trip.friends {
            if let cached = profileService.cachedProfile(userId: snapshot.id) {
                profilesByID[snapshot.id] = cached
                refreshed.append(friendSnapshot(from: cached))
            } else {
                do {
                    let profile = try await profileService.fetchMyProfile(userId: snapshot.id)
                    profilesByID[snapshot.id] = profile
                    refreshed.append(friendSnapshot(from: profile))
                } catch {
                    refreshed.append(snapshot)
                }
            }

            if let cachedPreferences = profileService.cachedPassportPreferences(userId: snapshot.id) {
                passportPreferencesByUserID[snapshot.id] = cachedPreferences
            } else if let preferences = try? await profileService.fetchPassportPreferences(userId: snapshot.id) {
                passportPreferencesByUserID[snapshot.id] = preferences
            }
        }

        travelerProfiles = profilesByID
        travelerPassportPreferences = passportPreferencesByUserID

        if !refreshed.isEmpty {
            resolvedFriends = refreshed
        }

        if let ownerSnapshot, ownerSnapshot != trip.effectiveOwnerSnapshot {
            trip = trip.withOwnerSnapshot(ownerSnapshot)
        }
    }

    private func friendSnapshot(from profile: Profile) -> TripPlannerFriendSnapshot {
        return TripPlannerFriendSnapshot(
            id: profile.id,
            displayName: profile.tripDisplayName,
            username: profile.username,
            avatarURL: profile.avatarUrl
        )
    }

    private var tripPassportLabel: String {
        if currentPassportPreferences.nationalityCountryCodes.count > 1 {
            return String(localized: "trip_planner.visa.best_saved_passport")
        }

        if let code = currentPassportPreferences.effectivePassportCountryCode {
            return CountrySelectionFormatter.localizedName(for: code)
        }

        return visaStore.activePassportLabel ?? String(localized: "trip_planner.visa.default_passport_label")
    }

    @MainActor
    private func loadCountryStats() async {
        var countries = CountryAPI.loadCachedCountries() ?? []

        if let fresh = await CountryAPI.refreshCountriesIfNeeded(minInterval: 60), !fresh.isEmpty {
            countries = fresh
        }

        let selected = countries
            .filter { trip.countryIds.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsIndex = trip.countryIds.firstIndex(of: lhs.id) ?? 0
                let rhsIndex = trip.countryIds.firstIndex(of: rhs.id) ?? 0
                return lhsIndex < rhsIndex
            }

        guard !selected.isEmpty else {
            resolvedCountries = []
            groupVisaNeeds = []
            return
        }

        let hydratedCountries = await visaStore.hydrate(
            countries: selected,
            passportCountryCodes: currentPassportPreferences.nationalityCountryCodes,
            fallbackPassportCountryCode: currentPassportPreferences.effectivePassportCountryCode
        )
        resolvedCountries = hydratedCountries

        let travelers = displayedTravelers
        var needs: [TripPlannerTravelerVisaNeed] = []

        for traveler in travelers {
            let preferences = travelerPassportPreferences[traveler.id] ?? .empty
            let travelerCountries = await visaStore.hydrate(
                countries: selected,
                passportCountryCodes: preferences.nationalityCountryCodes,
                fallbackPassportCountryCode: preferences.effectivePassportCountryCode
            )

            for country in travelerCountries {
                guard let visaType = country.visaType else { continue }

                let needsAdvanceVisa = ["evisa", "visa_required", "entry_permit", "ban"].contains(visaType)
                let exceedsAllowedStay = {
                    guard
                        let tripLengthDays = tripLengthDays,
                        let allowedDays = country.visaAllowedDays
                    else {
                        return false
                    }

                    return tripLengthDays > allowedDays
                }()

                guard needsAdvanceVisa || exceedsAllowedStay else { continue }

                needs.append(
                    TripPlannerTravelerVisaNeed(
                        travelerId: traveler.id,
                        travelerName: traveler.displayName,
                        countryID: country.id,
                        countryName: country.localizedDisplayName,
                        countryFlag: country.flagEmoji,
                        passportLabel: country.visaRecommendedPassportLabel ?? country.visaPassportLabel ?? resolvedPassportLabel(for: preferences),
                        visaType: visaType,
                        allowedDays: country.visaAllowedDays,
                        exceedsAllowedStay: exceedsAllowedStay
                    )
                )
            }
        }

        groupVisaNeeds = needs.sorted { lhs, rhs in
            if lhs.travelerName != rhs.travelerName {
                return lhs.travelerName.localizedCaseInsensitiveCompare(rhs.travelerName) == .orderedAscending
            }

            return lhs.countryName.localizedCaseInsensitiveCompare(rhs.countryName) == .orderedAscending
        }
    }

    private var tripLengthDays: Int? {
        guard let startDate = trip.startDate, let endDate = trip.endDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: endDate)
        ).day ?? 0
        return max(days + 1, 1)
    }

    private func resolvedPassportLabel(for preferences: PassportPreferences) -> String {
        if let code = preferences.effectivePassportCountryCode {
            return CountrySelectionFormatter.localizedName(for: code)
        }

        return String(localized: "trip_planner.visa.saved_passport")
    }

    @MainActor
    private func loadGroupLanguageScores() async {
        let countries = displayedCountries
        guard !countries.isEmpty else {
            groupLanguageScoresByCountry = [:]
            return
        }

        let allTravelerLanguages = travelerProfiles.values.flatMap(\.languages)
        guard !allTravelerLanguages.isEmpty else {
            groupLanguageScoresByCountry = [:]
            return
        }

        var scores: [String: Int] = [:]

        for country in countries {
            do {
                guard let languageProfile = try await TripPlannerCountryLanguageProfileStore.shared.profile(for: country.iso2) else {
                    continue
                }

                if let score = TripPlannerGroupLanguageCompatibilityScorer.score(
                    travelerLanguages: allTravelerLanguages,
                    countryProfile: languageProfile
                ) {
                    scores[country.id] = score
                }
            } catch {
                continue
            }
        }

        groupLanguageScoresByCountry = scores
    }
}

private struct TripPlannerBasicsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var title: String
    @State private var notes: String
    @State private var includeDates: Bool
    @State private var startDate: Date
    @State private var endDate: Date

    private let profileService = ProfileService(supabase: SupabaseManager.shared)

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _title = State(initialValue: trip.title)
        _notes = State(initialValue: trip.notes)
        _includeDates = State(initialValue: trip.startDate != nil || trip.endDate != nil)
        _startDate = State(initialValue: trip.startDate ?? Date())
        _endDate = State(initialValue: trip.endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: trip.startDate ?? Date()) ?? Date())
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.detail.trip_details"))

                ScrollView {
                    TripPlannerSectionCard(
                        title: String(localized: "trip_planner.detail.basics"),
                        subtitle: String(localized: "trip_planner.detail.basics_subtitle")
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            TripPlannerTextInput(
                                title: String(localized: "trip_planner.trip_name"),
                                text: $title,
                                placeholder: String(localized: "trip_planner.trip_name_placeholder")
                            )

                            TripPlannerTextInput(
                                title: String(localized: "trip_planner.notes"),
                                text: $notes,
                                placeholder: String(localized: "trip_planner.notes_placeholder"),
                                axis: .vertical
                            )

                            Toggle("trip_planner.add_tentative_dates", isOn: $includeDates)
                                .tint(.black)

                            if includeDates {
                                DatePicker("trip_planner.start", selection: $startDate, displayedComponents: .date)
                                    .tint(.black)

                                DatePicker("trip_planner.end", selection: $endDate, in: startDate..., displayedComponents: .date)
                                    .tint(.black)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trip.title : title.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                        startDate: includeDates ? startDate : nil,
                        endDate: includeDates ? endDate : nil,
                        countryIds: trip.countryIds,
                        countryNames: trip.countryNames,
                        friendIds: trip.friendIds,
                        friendNames: trip.friendNames,
                        friends: trip.friends,
                        ownerId: trip.ownerId,
                        ownerSnapshot: trip.effectiveOwnerSnapshot,
                        plannerCurrencyCode: trip.plannerCurrencyCode,
                        availability: updatedAvailability(),
                        dayPlans: TripPlannerDayPlanBuilder.syncedDayPlans(
                            existingPlans: trip.dayPlans,
                            startDate: includeDates ? startDate : nil,
                            endDate: includeDates ? endDate : nil,
                            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
                        ),
                        overallChecklistItems: trip.overallChecklistItems,
                        packingProgressEntries: trip.packingProgressEntries,
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
    }

    private func updatedAvailability() -> [TripPlannerAvailabilityProposal] {
        let currentUserId = sessionManager.userId ?? SupabaseManager.shared.currentUserId
        let currentParticipantId = currentUserId?.uuidString ?? "self"
        let currentProfile = currentUserId.flatMap { profileService.cachedProfile(userId: $0) }
        let nonSelf = trip.normalizedAvailabilityProposals(currentUserId: currentUserId)
            .filter { $0.participantId != currentParticipantId }
        guard includeDates else { return nonSelf }

        return nonSelf + [
            TripPlannerAvailabilityProposal(
                id: UUID(),
                participantId: currentParticipantId,
                participantName: currentProfile?.tripDisplayName ?? String(localized: "trip_planner.you"),
                participantUsername: currentProfile?.username,
                participantAvatarURL: currentProfile?.avatarUrl,
                kind: .exactDates,
                startDate: startDate,
                endDate: endDate
            )
        ]
    }
}

private struct TripPlannerFriendsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var friends: [Profile] = []
    @State private var selectedFriendIds: Set<UUID>
    @State private var isLoading = true
    @State private var errorMessage: String?
    @StateObject private var usernameSearch = TripPlannerUsernameSearchController()

    private let friendService = FriendService()
    private let supabase = SupabaseManager.shared

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _selectedFriendIds = State(initialValue: Set(trip.friendIds))
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.whos_going.title"))

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("trip_planner.friends.loading")
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.travel_friends"),
                                subtitle: String(localized: "trip_planner.friends.subtitle")
                            ) {
                                if let errorMessage {
                                    TripPlannerInfoCard(
                                        text: errorMessage,
                                        systemImage: "exclamationmark.triangle.fill"
                                    )
                                } else if friends.isEmpty {
                                    TripPlannerInfoCard(
                                        text: String(localized: "trip_planner.friends.none_added_yet"),
                                        systemImage: "person.2.slash"
                                    )
                                } else {
                                    LazyVStack(spacing: 10) {
                                        ForEach(friends.sorted(by: { displayName(for: $0) < displayName(for: $1) })) { friend in
                                            Button {
                                                toggle(friend.id)
                                            } label: {
                                                TripPlannerFriendRow(
                                                    profile: friend,
                                                    isSelected: selectedFriendIds.contains(friend.id),
                                                    displayName: displayName(for: friend)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                TripPlannerTextInput(
                                    title: "Add by username",
                                    text: $usernameSearch.query,
                                    placeholder: "@username"
                                )

                                if usernameSearch.isSearching {
                                    ProgressView()
                                        .tint(.black)
                                } else if !usernameSearch.results.isEmpty {
                                    LazyVStack(spacing: 10) {
                                        ForEach(usernameSearch.results) { profile in
                                            Button {
                                                addSearchedUser(profile)
                                            } label: {
                                                TripPlannerFriendRow(
                                                    profile: profile,
                                                    isSelected: selectedFriendIds.contains(profile.id),
                                                    displayName: displayName(for: profile)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.pageHorizontalInset)
                            .padding(.top, 18)
                            .padding(.bottom, 32)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                let selectedFriends = friends
                    .filter { selectedFriendIds.contains($0.id) }
                    .sorted { displayName(for: $0) < displayName(for: $1) }

                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: trip.title,
                        notes: trip.notes,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        countryIds: trip.countryIds,
                        countryNames: trip.countryNames,
                        friendIds: selectedFriends.map(\.id),
                        friendNames: selectedFriends.map(displayName),
                        friends: selectedFriends.map(friendSnapshot),
                        ownerId: trip.ownerId,
                        ownerSnapshot: trip.effectiveOwnerSnapshot,
                        plannerCurrencyCode: trip.plannerCurrencyCode,
                        availability: preservedAvailability(with: selectedFriends.map(friendSnapshot)),
                        dayPlans: trip.dayPlans,
                        overallChecklistItems: trip.overallChecklistItems,
                        packingProgressEntries: trip.packingProgressEntries,
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .task {
            await loadFriends()
        }
        .onChange(of: usernameSearch.query) { _, _ in
            usernameSearch.scheduleSearch(excluding: sessionManager.userId)
        }
        .onDisappear {
            usernameSearch.cancel()
        }
    }

    @MainActor
    private func loadFriends() async {
        defer { isLoading = false }

        guard let userId = sessionManager.userId else {
            errorMessage = String(localized: "trip_planner.friends.sign_in_required")
            return
        }

        do {
            async let fetchedFriendsTask = friendService.fetchFriends(for: userId)
            async let existingParticipantsTask = fetchProfiles(for: trip.friendIds)
            let fetchedFriends = try await fetchedFriendsTask
            let existingParticipants = try await existingParticipantsTask
            friends = mergedProfiles(fetchedFriends + existingParticipants)
        } catch {
            errorMessage = String(localized: "trip_planner.friends.load_error")
        }
    }

    private func toggle(_ id: UUID) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
        }
    }

    private func addSearchedUser(_ profile: Profile) {
        friends = mergedProfiles(friends + [profile])
        selectedFriendIds.insert(profile.id)
        usernameSearch.reset()
    }

    private func fetchProfiles(for ids: [UUID]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }

        let response: PostgrestResponse<[Profile]> = try await supabase.client
            .from("profiles")
            .select("*")
            .in("id", values: ids.map(\.uuidString))
            .execute()

        return response.value
    }

    private func mergedProfiles(_ profiles: [Profile]) -> [Profile] {
        var seen = Set<UUID>()
        return profiles.filter { profile in
            seen.insert(profile.id).inserted
        }
    }

    private func displayName(for profile: Profile) -> String {
        profile.tripDisplayName
    }

    private func friendSnapshot(for profile: Profile) -> TripPlannerFriendSnapshot {
        TripPlannerFriendSnapshot(
            id: profile.id,
            displayName: displayName(for: profile),
            username: profile.username,
            avatarURL: profile.avatarUrl
        )
    }

    private func preservedAvailability(with selectedFriends: [TripPlannerFriendSnapshot]) -> [TripPlannerAvailabilityProposal] {
        guard !selectedFriends.isEmpty else { return [] }
        let currentUserId = sessionManager.userId ?? supabase.currentUserId
        let validIds = Set(selectedFriends.map { $0.id.uuidString })
            .union([trip.ownerId?.uuidString, currentUserId?.uuidString].compactMap { $0 })
        let normalizedProposals = trip.normalizedAvailabilityProposals(currentUserId: currentUserId)
        TripPlannerDebugLog.probe(
            "TripPlannerFriendsEditor.preserved_availability",
            "trip=\(TripPlannerDebugLog.tripLabel(trip)) current=\(TripPlannerDebugLog.userLabel(currentUserId)) owner=\(TripPlannerDebugLog.userLabel(trip.ownerId)) selected=\(selectedFriends.map { "\($0.id.uuidString)=\($0.displayName)" }.joined(separator: ",")) kept=\(normalizedProposals.filter { validIds.contains($0.participantId) }.map { "\($0.participantId)=\($0.participantName):\($0.kind.rawValue)" }.joined(separator: ","))"
        )
        return normalizedProposals.filter { validIds.contains($0.participantId) }
    }
}

private struct TripPlannerInlineAvailabilityEditor: View {
    @EnvironmentObject private var sessionManager: SessionManager

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var proposals: [TripPlannerAvailabilityProposal]
    @State private var selectedMonth: Date
    @State private var selectedDates: Set<Date>
    @State private var expandedTravelerIds: Set<String> = []

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        let currentUserId = SupabaseManager.shared.currentUserId
        let normalizedProposals = trip.normalizedAvailabilityProposals(currentUserId: currentUserId)
            .sorted { $0.startDate < $1.startDate }
        let initialMonth = TripPlannerAvailabilityCalculator.primaryDisplayMonth(for: trip)
            ?? TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
        _proposals = State(initialValue: normalizedProposals)
        _selectedMonth = State(initialValue: initialMonth)
        _selectedDates = State(initialValue: Self.selectedDates(
            from: normalizedProposals,
            currentParticipantId: Self.currentParticipantID(for: trip, currentUserId: currentUserId)
        ))
    }

    private var participants: [TripPlannerAvailabilityParticipant] {
        trip.availabilityParticipants(currentUserId: sessionManager.userId)
    }

    private var currentParticipant: TripPlannerAvailabilityParticipant {
        participants.first(where: { $0.id == currentParticipantId }) ?? .you
    }

    private var currentParticipantId: String {
        Self.currentParticipantID(for: trip, currentUserId: sessionManager.userId)
    }

    private var overlapMatches: [TripPlannerAvailabilityOverlap] {
        TripPlannerAvailabilityCalculator.overlaps(for: trip, proposals: proposals)
    }

    private var everyoneHasAvailability: Bool {
        !participants.isEmpty && participants.allSatisfy { participant in
            hasAvailability(for: participant.id)
        }
    }

    private var currentMonthIsFlexible: Bool {
        proposals.contains {
            $0.participantId == currentParticipantId
                && $0.kind == .flexibleMonth
                && TripPlannerAvailabilityCalculator.startOfMonth(for: $0.startDate) == selectedMonth
        }
    }

    private var currentParticipantColor: Color {
        let participantIndex = participants.firstIndex(where: { $0.id == currentParticipantId }) ?? 0
        return TripPlannerAvailabilityTheme.color(for: currentParticipantId, index: participantIndex)
    }

    private var selectedDateRangeText: String {
        let sorted = selectedDates.sorted()
        guard let first = sorted.first else { return "Tap dates you can travel." }
        guard sorted.count > 1 else {
            return AppDateFormatting.dateString(from: first, dateStyle: .medium)
        }
        return "\(sorted.count) dates selected"
    }

    private var availabilitySignature: String {
        trip.availability
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString):\($0.participantId):\($0.kind.rawValue):\($0.startDate.timeIntervalSince1970):\($0.endDate.timeIntervalSince1970)" }
            .joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            monthPicker
            availabilityLegend

            TripPlannerAvailabilitySelectionMonth(
                month: selectedMonth,
                proposals: proposals,
                participants: participants,
                selectedDates: selectedDates,
                flexibleMonthSelected: currentMonthIsFlexible,
                selectedColor: currentParticipantColor,
                onToggleDate: toggleSelectedDate
            )

            HStack(spacing: 10) {
                Button {
                    toggleFlexibleMonth()
                } label: {
                    Label(
                        currentMonthIsFlexible ? "All month" : "Available all month",
                        systemImage: currentMonthIsFlexible ? "checkmark.circle.fill" : "calendar.badge.clock"
                    )
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(currentMonthIsFlexible ? TripPlannerAvailabilityTheme.gold : Color.white.opacity(0.86))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(currentMonthIsFlexible ? TripPlannerAvailabilityTheme.goldDeep.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    clearMyAvailability()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TripPlannerAvailabilityTheme.ink.opacity(0.66))
                        .frame(width: 46, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.72))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasAvailability(for: currentParticipant.id))
                .opacity(hasAvailability(for: currentParticipant.id) ? 1 : 0.4)
            }

            suggestedWindowsSection

            travelerAvailabilityList
        }
        .onAppear {
            logParticipantResolution("appear")
        }
        .onChange(of: availabilitySignature) { _, _ in
            resetFromTrip()
        }
    }

    private var availabilityLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(participants.enumerated()), id: \.1.id) { index, participant in
                    TripPlannerAvailabilityParticipantBubble(
                        participant: participant,
                        color: TripPlannerAvailabilityTheme.color(for: participant.id, index: index),
                        isComplete: hasAvailability(for: participant.id)
                    )
                }

                TripPlannerAvailabilityEveryoneBubble(isComplete: everyoneHasAvailability)
            }
        }
    }

    private var monthPicker: some View {
        HStack(spacing: 10) {
            Button {
                moveSelectedMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.84)))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(TripPlannerAvailabilityCalculator.monthTitle(for: selectedMonth))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.86)))

            Spacer()

            Button {
                moveSelectedMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.84)))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var suggestedWindowsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested windows")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)

            if overlapMatches.isEmpty {
                TripPlannerInfoCard(
                    text: "Shared dates will highlight in gold once availability overlaps.",
                    systemImage: "sparkles"
                )
            } else {
                TripPlannerBestMatchHero(overlap: overlapMatches[0])

                ForEach(Array(overlapMatches.dropFirst().prefix(4).enumerated()), id: \.element.id) { index, overlap in
                    TripPlannerAvailabilityMatchCard(
                        rank: index + 2,
                        overlap: overlap
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var travelerAvailabilityList: some View {
        let groups = groupedProposals()
        if groups.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Availability by traveler")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)

                ForEach(Array(groups.enumerated()), id: \.1.participant.id) { index, group in
                    TripPlannerTravelerAvailabilityRow(
                        participant: group.participant,
                        proposals: group.proposals,
                        color: TripPlannerAvailabilityTheme.color(for: group.participant.id, index: index),
                        editableParticipantId: currentParticipantId,
                        isExpanded: expandedTravelerIds.contains(group.participant.id),
                        onToggle: {
                            if expandedTravelerIds.contains(group.participant.id) {
                                expandedTravelerIds.remove(group.participant.id)
                            } else {
                                expandedTravelerIds.insert(group.participant.id)
                            }
                        },
                        onDelete: { proposal in
                            guard proposal.participantId == currentParticipantId else { return }
                            proposals.removeAll { $0.id == proposal.id }
                            selectedDates = Self.selectedDates(from: proposals, currentParticipantId: currentParticipantId)
                            persist()
                        }
                    )
                }
            }
        }
    }

    private func groupedProposals() -> [(participant: TripPlannerAvailabilityParticipant, proposals: [TripPlannerAvailabilityProposal])] {
        participants.compactMap { participant in
            let matches = proposals.filter { $0.participantId == participant.id }.sorted { $0.startDate < $1.startDate }
            guard !matches.isEmpty else { return nil }
            return (participant, matches)
        }
    }

    private func hasAvailability(for participantId: String) -> Bool {
        proposals.contains { $0.participantId == participantId }
    }

    private func toggleSelectedDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        if selectedDates.contains(normalized) {
            selectedDates.remove(normalized)
        } else {
            selectedDates.insert(normalized)
        }
        syncSelectedDatesToProposals()
    }

    private func syncSelectedDatesToProposals() {
        proposals.removeAll { $0.participantId == currentParticipantId && $0.kind == .exactDates }
        proposals.append(contentsOf: Self.exactDateProposals(
            from: selectedDates,
            participant: currentParticipant
        ))
        proposals.sort { $0.startDate < $1.startDate }
        persist()
    }

    private func toggleFlexibleMonth() {
        if currentMonthIsFlexible {
            proposals.removeAll {
                $0.participantId == currentParticipantId
                    && $0.kind == .flexibleMonth
                    && TripPlannerAvailabilityCalculator.startOfMonth(for: $0.startDate) == selectedMonth
            }
        } else {
            proposals.append(
                TripPlannerAvailabilityProposal(
                    participantId: currentParticipantId,
                    participantName: currentParticipant.name,
                    participantUsername: currentParticipant.username,
                    participantAvatarURL: currentParticipant.avatarURL,
                    kind: .flexibleMonth,
                    startDate: selectedMonth,
                    endDate: TripPlannerAvailabilityCalculator.endOfMonth(for: selectedMonth)
                )
            )
        }
        proposals.sort { $0.startDate < $1.startDate }
        persist()
    }

    private func clearMyAvailability() {
        proposals.removeAll { $0.participantId == currentParticipantId }
        selectedDates.removeAll()
        persist()
    }

    private func moveSelectedMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: next)
        }
    }

    private func persist() {
        onSave(savedTrip(with: proposals))
    }

    private func savedTrip(with proposals: [TripPlannerAvailabilityProposal]) -> TripPlannerTrip {
        TripPlannerTrip(
            id: trip.id,
            createdAt: trip.createdAt,
            title: trip.title,
            notes: trip.notes,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countryIds: trip.countryIds,
            countryNames: trip.countryNames,
            friendIds: trip.friendIds,
            friendNames: trip.friendNames,
            friends: trip.friends,
            ownerId: trip.ownerId,
            ownerSnapshot: trip.effectiveOwnerSnapshot,
            plannerCurrencyCode: trip.plannerCurrencyCode,
            availability: proposals.sorted { $0.startDate < $1.startDate },
            dayPlans: trip.dayPlans,
            overallChecklistItems: trip.overallChecklistItems,
            packingProgressEntries: trip.packingProgressEntries,
            expenses: trip.expenses
        )
    }

    private func resetFromTrip() {
        let normalizedProposals = trip.normalizedAvailabilityProposals(currentUserId: sessionManager.userId)
            .sorted { $0.startDate < $1.startDate }
        proposals = normalizedProposals
        selectedDates = Self.selectedDates(from: normalizedProposals, currentParticipantId: currentParticipantId)
    }

    private static func selectedDates(
        from proposals: [TripPlannerAvailabilityProposal],
        currentParticipantId: String
    ) -> Set<Date> {
        Set(proposals
            .filter { $0.participantId == currentParticipantId && $0.kind == .exactDates }
            .flatMap { dates(from: $0.startDate, through: $0.endDate) })
    }

    private static func exactDateProposals(
        from dates: Set<Date>,
        participant: TripPlannerAvailabilityParticipant
    ) -> [TripPlannerAvailabilityProposal] {
        contiguousRanges(from: dates).map { range in
            TripPlannerAvailabilityProposal(
                participantId: participant.id,
                participantName: participant.name,
                participantUsername: participant.username,
                participantAvatarURL: participant.avatarURL,
                kind: .exactDates,
                startDate: range.start,
                endDate: range.end
            )
        }
    }

    private static func contiguousRanges(from dates: Set<Date>) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        let sorted = dates.map { calendar.startOfDay(for: $0) }.sorted()
        guard let first = sorted.first else { return [] }

        var ranges: [(start: Date, end: Date)] = []
        var currentStart = first
        var currentEnd = first

        for date in sorted.dropFirst() {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: currentEnd) ?? currentEnd
            if calendar.isDate(date, inSameDayAs: nextDay) {
                currentEnd = date
            } else {
                ranges.append((currentStart, currentEnd))
                currentStart = date
                currentEnd = date
            }
        }

        ranges.append((currentStart, currentEnd))
        return ranges
    }

    private static func dates(from startDate: Date, through endDate: Date) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return [] }

        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    private static func currentParticipantID(for trip: TripPlannerTrip, currentUserId: UUID?) -> String {
        if let currentUserId {
            return currentUserId.uuidString
        }
        return trip.ownerId?.uuidString ?? "self"
    }

    private func logParticipantResolution(_ context: String) {
        let participantSummary = participants.map {
            "\($0.id)=\($0.name)"
        }.joined(separator: ",")
        let proposalSummary = proposals.map {
            "\($0.participantId)=\($0.participantName):\($0.kind.rawValue)"
        }.joined(separator: ",")
        TripPlannerDebugLog.probe(
            "TripPlannerInlineAvailabilityEditor.participants",
            "context=\(context) trip=\(TripPlannerDebugLog.tripLabel(trip)) current=\(TripPlannerDebugLog.userLabel(sessionManager.userId)) owner=\(TripPlannerDebugLog.userLabel(trip.ownerId)) ownerSnapshot=\(trip.effectiveOwnerSnapshot?.displayName ?? "nil") participants=\(participantSummary) proposals=\(proposalSummary)"
        )
    }
}

private struct TripPlannerAvailabilityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var proposals: [TripPlannerAvailabilityProposal]
    @State private var selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
    @State private var selectedDates: Set<Date>
    @State private var expandedTravelerIds: Set<String> = []

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        let normalizedProposals = trip.normalizedAvailabilityProposals(currentUserId: SupabaseManager.shared.currentUserId)
            .sorted { $0.startDate < $1.startDate }
        _proposals = State(initialValue: normalizedProposals)
        _selectedDates = State(initialValue: Self.initialSelectedDates(
            from: normalizedProposals,
            currentParticipantId: Self.currentParticipantID(for: trip, currentUserId: SupabaseManager.shared.currentUserId)
        ))
    }

    private var participants: [TripPlannerAvailabilityParticipant] {
        trip.availabilityParticipants(currentUserId: sessionManager.userId)
    }

    private var currentParticipant: TripPlannerAvailabilityParticipant {
        participants.first(where: { $0.id == currentParticipantId }) ?? .you
    }

    private var currentParticipantId: String {
        Self.currentParticipantID(for: trip, currentUserId: sessionManager.userId)
    }

    private var overlapMatches: [TripPlannerAvailabilityOverlap] {
        TripPlannerAvailabilityCalculator.overlaps(for: trip, proposals: proposals)
    }

    private var monthOptions: [Date] {
        let calendar = Calendar.current
        let allDates = proposals.flatMap { [$0.startDate, $0.endDate] }
        let start = TripPlannerAvailabilityCalculator.startOfMonth(for: allDates.min() ?? Date())
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }

    private var yourFlexibleMonths: Set<Date> {
        Set(proposals
            .filter { $0.participantId == currentParticipantId && $0.kind == .flexibleMonth }
            .map { TripPlannerAvailabilityCalculator.startOfMonth(for: $0.startDate) })
    }

    private var currentMonthIsFlexible: Bool {
        yourFlexibleMonths.contains(selectedMonth)
    }

    private var currentParticipantColor: Color {
        let participantIndex = participants.firstIndex(where: { $0.id == currentParticipantId }) ?? 0
        return TripPlannerAvailabilityTheme.color(for: currentParticipantId, index: participantIndex)
    }

    private var selectedDateRangeText: String {
        let sorted = selectedDates.sorted()
        guard let first = sorted.first else { return "No exact days selected" }

        if sorted.count == 1 {
            return AppDateFormatting.dateString(from: first, dateStyle: .medium)
        }

        return "\(sorted.count) dates selected"
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.availability.title"))

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: "Suggested trip dates",
                            subtitle: overlapMatches.isEmpty ? "Add availability to generate matches." : "Ranked by shared availability."
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                if overlapMatches.isEmpty {
                                    TripPlannerInfoCard(
                                        text: "No shared window yet.",
                                        systemImage: "sparkles"
                                    )
                                } else {
                                    TripPlannerBestMatchHero(
                                        overlap: overlapMatches[0]
                                    )

                                    ForEach(Array(overlapMatches.dropFirst().prefix(2).enumerated()), id: \.element.id) { index, overlap in
                                        TripPlannerAvailabilityMatchCard(
                                            rank: index + 2,
                                            overlap: overlap
                                        )
                                    }
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: "Your availability",
                            subtitle: selectedDateRangeText
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    TripPlannerAvatarView(
                                        name: currentParticipant.name,
                                        username: currentParticipant.username ?? currentParticipant.name,
                                        avatarURL: currentParticipant.avatarURL,
                                        size: 42
                                    )

                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(currentParticipant.name)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.black)

                                        if currentMonthIsFlexible {
                                            TripPlannerBadge(text: "Available all month")
                                        }
                                    }

                                    Spacer(minLength: 0)
                                }

                                monthPicker
                                availabilityLegend

                                TripPlannerAvailabilitySelectionMonth(
                                    month: selectedMonth,
                                    proposals: proposals,
                                    participants: participants,
                                    selectedDates: selectedDates,
                                    flexibleMonthSelected: currentMonthIsFlexible,
                                    selectedColor: currentParticipantColor,
                                    onToggleDate: toggleSelectedDate
                                )

                                HStack(spacing: 10) {
                                    Button {
                                        toggleFlexibleMonth()
                                    } label: {
                                        Label(
                                            currentMonthIsFlexible ? "All month" : "Available all month",
                                            systemImage: currentMonthIsFlexible ? "checkmark.circle.fill" : "calendar.badge.clock"
                                        )
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(currentMonthIsFlexible ? TripPlannerAvailabilityTheme.gold : Color.white.opacity(0.86))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .stroke(currentMonthIsFlexible ? TripPlannerAvailabilityTheme.goldDeep.opacity(0.35) : Color.clear, lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    Button(role: .destructive) {
                                        clearMyAvailability()
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.72))
                                            .frame(width: 46, height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color.white.opacity(0.72))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: "Availability by traveler",
                            subtitle: proposals.isEmpty ? "No dates added yet." : "\(proposals.count) saved option\(proposals.count == 1 ? "" : "s")"
                        ) {
                            travelerAvailabilityList
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logParticipantResolution("appear")
        }
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                onSave(savedTrip())
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
    }

    private var availabilityLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(participants.enumerated()), id: \.1.id) { index, participant in
                    TripPlannerAvailabilityParticipantBubble(
                        participant: participant,
                        color: TripPlannerAvailabilityTheme.color(for: participant.id, index: index),
                        isComplete: proposals.contains { $0.participantId == participant.id }
                    )
                }

                TripPlannerAvailabilityEveryoneBubble(
                    isComplete: !participants.isEmpty && participants.allSatisfy { participant in
                        proposals.contains { $0.participantId == participant.id }
                    }
                )
            }
        }
    }

    private var monthPicker: some View {
        HStack(spacing: 10) {
            Button {
                moveSelectedMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.84)))
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                ForEach(monthOptions, id: \.self) { month in
                    Button(TripPlannerAvailabilityCalculator.monthTitle(for: month)) {
                        selectedMonth = month
                    }
                }
            } label: {
                Label(TripPlannerAvailabilityCalculator.monthTitle(for: selectedMonth), systemImage: "calendar")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.86))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                moveSelectedMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.84)))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var travelerAvailabilityList: some View {
        if proposals.isEmpty {
            TripPlannerInfoCard(
                text: "No one has added availability yet.",
                systemImage: "calendar.badge.plus"
            )
        } else {
            VStack(spacing: 10) {
                ForEach(Array(groupedProposals().enumerated()), id: \.1.participant.id) { index, group in
                    TripPlannerTravelerAvailabilityRow(
                        participant: group.participant,
                        proposals: group.proposals,
                        color: TripPlannerAvailabilityTheme.color(for: group.participant.id, index: index),
                        editableParticipantId: currentParticipantId,
                        isExpanded: expandedTravelerIds.contains(group.participant.id),
                        onToggle: {
                            if expandedTravelerIds.contains(group.participant.id) {
                                expandedTravelerIds.remove(group.participant.id)
                            } else {
                                expandedTravelerIds.insert(group.participant.id)
                            }
                        },
                        onDelete: { proposal in
                            guard proposal.participantId == currentParticipantId else { return }
                            proposals.removeAll { $0.id == proposal.id }
                            selectedDates = Self.selectedDates(from: proposals, currentParticipantId: currentParticipantId)
                        }
                    )
                }
            }
        }
    }

    private func groupedProposals() -> [(participant: TripPlannerAvailabilityParticipant, proposals: [TripPlannerAvailabilityProposal])] {
        participants.compactMap { participant in
            let matches = proposals.filter { $0.participantId == participant.id }.sorted { $0.startDate < $1.startDate }
            guard !matches.isEmpty else { return nil }
            return (participant, matches)
        }
    }

    private func toggleSelectedDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        if selectedDates.contains(normalized) {
            selectedDates.remove(normalized)
        } else {
            selectedDates.insert(normalized)
        }
        syncSelectedDatesToProposals()
    }

    private func syncSelectedDatesToProposals() {
        proposals.removeAll { $0.participantId == currentParticipantId && $0.kind == .exactDates }
        proposals.append(contentsOf: Self.exactDateProposals(
            from: selectedDates,
            participant: currentParticipant
        ))
        proposals.sort { $0.startDate < $1.startDate }
    }

    private func toggleFlexibleMonth() {
        if currentMonthIsFlexible {
            proposals.removeAll {
                $0.participantId == currentParticipantId
                    && $0.kind == .flexibleMonth
                    && TripPlannerAvailabilityCalculator.startOfMonth(for: $0.startDate) == selectedMonth
            }
        } else {
            proposals.append(
                TripPlannerAvailabilityProposal(
                    participantId: currentParticipantId,
                    participantName: currentParticipant.name,
                    participantUsername: currentParticipant.username,
                    participantAvatarURL: currentParticipant.avatarURL,
                    kind: .flexibleMonth,
                    startDate: selectedMonth,
                    endDate: TripPlannerAvailabilityCalculator.endOfMonth(for: selectedMonth)
                )
            )
        }
        proposals.sort { $0.startDate < $1.startDate }
    }

    private func clearMyAvailability() {
        proposals.removeAll { $0.participantId == currentParticipantId }
        selectedDates.removeAll()
    }

    private func moveSelectedMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: next)
        }
    }

    private func savedTrip() -> TripPlannerTrip {
        TripPlannerTrip(
            id: trip.id,
            createdAt: trip.createdAt,
            title: trip.title,
            notes: trip.notes,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countryIds: trip.countryIds,
            countryNames: trip.countryNames,
            friendIds: trip.friendIds,
            friendNames: trip.friendNames,
            friends: trip.friends,
            ownerId: trip.ownerId,
            ownerSnapshot: trip.effectiveOwnerSnapshot,
            plannerCurrencyCode: trip.plannerCurrencyCode,
            availability: proposals.sorted { $0.startDate < $1.startDate },
            dayPlans: trip.dayPlans,
            overallChecklistItems: trip.overallChecklistItems,
            packingProgressEntries: trip.packingProgressEntries,
            expenses: trip.expenses
        )
    }

    private static func initialSelectedDates(
        from proposals: [TripPlannerAvailabilityProposal],
        currentParticipantId: String
    ) -> Set<Date> {
        selectedDates(from: proposals, currentParticipantId: currentParticipantId)
    }

    private static func selectedDates(
        from proposals: [TripPlannerAvailabilityProposal],
        currentParticipantId: String
    ) -> Set<Date> {
        Set(proposals
            .filter { $0.participantId == currentParticipantId && $0.kind == .exactDates }
            .flatMap { dates(from: $0.startDate, through: $0.endDate) })
    }

    private static func exactDateProposals(
        from dates: Set<Date>,
        participant: TripPlannerAvailabilityParticipant
    ) -> [TripPlannerAvailabilityProposal] {
        contiguousRanges(from: dates).map { range in
            TripPlannerAvailabilityProposal(
                participantId: participant.id,
                participantName: participant.name,
                participantUsername: participant.username,
                participantAvatarURL: participant.avatarURL,
                kind: .exactDates,
                startDate: range.start,
                endDate: range.end
            )
        }
    }

    private static func contiguousRanges(from dates: Set<Date>) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        let sorted = dates.map { calendar.startOfDay(for: $0) }.sorted()
        guard let first = sorted.first else { return [] }

        var ranges: [(start: Date, end: Date)] = []
        var currentStart = first
        var currentEnd = first

        for date in sorted.dropFirst() {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: currentEnd) ?? currentEnd
            if calendar.isDate(date, inSameDayAs: nextDay) {
                currentEnd = date
            } else {
                ranges.append((currentStart, currentEnd))
                currentStart = date
                currentEnd = date
            }
        }

        ranges.append((currentStart, currentEnd))
        return ranges
    }

    private static func dates(from startDate: Date, through endDate: Date) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return [] }

        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    private static func currentParticipantID(for trip: TripPlannerTrip, currentUserId: UUID?) -> String {
        if let currentUserId {
            return currentUserId.uuidString
        }
        return trip.ownerId?.uuidString ?? "self"
    }

    private func logParticipantResolution(_ context: String) {
        let participantSummary = participants.map {
            "\($0.id)=\($0.name)"
        }.joined(separator: ",")
        let proposalSummary = proposals.map {
            "\($0.participantId)=\($0.participantName):\($0.kind.rawValue)"
        }.joined(separator: ",")
        TripPlannerDebugLog.probe(
            "TripPlannerAvailabilityEditor.participants",
            "context=\(context) trip=\(TripPlannerDebugLog.tripLabel(trip)) current=\(TripPlannerDebugLog.userLabel(sessionManager.userId)) owner=\(TripPlannerDebugLog.userLabel(trip.ownerId)) ownerSnapshot=\(trip.effectiveOwnerSnapshot?.displayName ?? "nil") friends=\(trip.friends.map { "\($0.id.uuidString)=\($0.displayName)" }.joined(separator: ",")) participants=\(participantSummary) proposals=\(proposalSummary)"
        )
    }
}

private struct TripPlannerBestMatchHero: View {
    let overlap: TripPlannerAvailabilityOverlap

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: overlap.isFullMatch ? "sparkles" : "calendar.badge.clock")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.78)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested window")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(TripPlannerAvailabilityTheme.ink.opacity(0.48))

                    Text(TripPlannerDateFormatter.rangeText(start: overlap.startDate, end: displayEndDate) ?? "Shared window")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.91, green: 0.84, blue: 0.64).opacity(0.78))
        )
    }

    private var displayEndDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: overlap.endDate) ?? overlap.endDate
    }
}

private struct TripPlannerAvailabilityParticipantBubble: View {
    let participant: TripPlannerAvailabilityParticipant
    let color: Color
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 7) {
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(color.opacity(0.72)))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
            }

            Text(participant.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isComplete ? .white : TripPlannerAvailabilityTheme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isComplete ? color : Color.white.opacity(0.82))
        )
    }
}

private struct TripPlannerAvailabilityEveryoneBubble: View {
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 7) {
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(TripPlannerAvailabilityTheme.goldDeep)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.white.opacity(0.72)))
            } else {
                Circle()
                    .fill(TripPlannerAvailabilityTheme.gold)
                    .frame(width: 9, height: 9)
            }

            Text("Everyone")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(TripPlannerAvailabilityTheme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isComplete ? TripPlannerAvailabilityTheme.gold : Color.white.opacity(0.82))
                .overlay(
                    Capsule()
                        .stroke(isComplete ? TripPlannerAvailabilityTheme.goldDeep.opacity(0.34) : Color.clear, lineWidth: 1)
                )
        )
    }
}

private struct TripPlannerAvailabilitySelectionMonth: View {
    let month: Date
    let proposals: [TripPlannerAvailabilityProposal]
    let participants: [TripPlannerAvailabilityParticipant]
    let selectedDates: Set<Date>
    let flexibleMonthSelected: Bool
    let selectedColor: Color
    let onToggleDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var daySlots: [Date?] {
        TripPlannerAvailabilityCalculator.daySlots(for: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(TripPlannerAvailabilityCalculator.monthTitle(for: month))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TripPlannerAvailabilityTheme.ink)

                Spacer()

                if flexibleMonthSelected {
                    TripPlannerBadge(text: "Flexible")
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TripPlannerAvailabilityCalculator.weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TripPlannerAvailabilityTheme.ink.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(daySlots.enumerated()), id: \.offset) { _, day in
                    if let day {
                        TripPlannerAvailabilitySelectionDayCell(
                            date: day,
                            month: month,
                            selectedDates: selectedDates,
                            availableColors: availableColors(on: day),
                            participantCount: participants.count,
                            selectedColor: selectedColor,
                            onTap: { onToggleDate(day) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private func availableColors(on date: Date) -> [Color] {
        participants.enumerated().compactMap { index, participant in
            let isAvailable = proposals.contains { proposal in
                proposal.participantId == participant.id
                    && TripPlannerAvailabilityCalculator.includes(date: date, in: proposal)
            }
            guard isAvailable else { return nil }
            return TripPlannerAvailabilityTheme.color(for: participant.id, index: index)
        }
    }
}

private struct TripPlannerAvailabilitySelectionDayCell: View {
    let date: Date
    let month: Date
    let selectedDates: Set<Date>
    let availableColors: [Color]
    let participantCount: Int
    let selectedColor: Color
    let onTap: () -> Void

    private var isSelected: Bool {
        selectedDates.contains(Calendar.current.startOfDay(for: date))
    }

    private var inMonth: Bool {
        Calendar.current.isDate(date, equalTo: month, toGranularity: .month)
    }

    private var isSharedDay: Bool {
        participantCount > 0 && availableColors.count == participantCount
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TripPlannerAvailabilityTheme.ink)

                HStack(spacing: 2) {
                    ForEach(Array(availableColors.prefix(4).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(selectedColor))
                        .offset(x: 4, y: -4)
                }
            }
            .opacity(inMonth ? 1 : 0.32)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSharedDay {
            return TripPlannerAvailabilityTheme.gold
        }
        if isSelected {
            return selectedColor.opacity(0.18)
        }
        if !availableColors.isEmpty {
            return Color.white.opacity(0.94)
        }
        return Color.white.opacity(0.48)
    }

    private var borderColor: Color {
        if isSelected {
            return selectedColor
        }
        if isSharedDay {
            return TripPlannerAvailabilityTheme.goldDeep.opacity(0.34)
        }
        return TripPlannerAvailabilityTheme.ink.opacity(0.08)
    }
}

private struct TripPlannerAvailabilityMatchCard: View {
    let rank: Int
    let overlap: TripPlannerAvailabilityOverlap

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(TripPlannerAvailabilityTheme.gold))

            VStack(alignment: .leading, spacing: 4) {
                Text(TripPlannerDateFormatter.rangeText(start: overlap.startDate, end: displayEndDate) ?? "Shared window")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(TripPlannerAvailabilityTheme.ink)

                if overlap.isFullMatch {
                    Text("Everyone is available")
                        .font(.system(size: 12))
                        .foregroundStyle(TripPlannerAvailabilityTheme.ink.opacity(0.64))
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(overlap.isFullMatch ? Color(red: 0.91, green: 0.84, blue: 0.64).opacity(0.72) : Color.white.opacity(0.72))
        )
    }

    private var displayEndDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: overlap.endDate) ?? overlap.endDate
    }
}

private struct TripPlannerTravelerAvailabilityRow: View {
    let participant: TripPlannerAvailabilityParticipant
    let proposals: [TripPlannerAvailabilityProposal]
    let color: Color
    let editableParticipantId: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: (TripPlannerAvailabilityProposal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)

                    TripPlannerAvatarView(
                        name: participant.name,
                        username: participant.username ?? participant.name,
                        avatarURL: participant.avatarURL,
                        size: 34
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(participant.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)

                        Text("\(proposals.count) option\(proposals.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.black.opacity(0.62))
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(proposals) { proposal in
                    HStack(spacing: 10) {
                        TripPlannerProposalChip(proposal: proposal, color: color)

                        Spacer()

                        if proposal.participantId == editableParticipantId {
                            Button(role: .destructive) {
                                onDelete(proposal)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.72))
                                    .padding(8)
                                    .background(Circle().fill(Color.white.opacity(0.82)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

private struct TripPlannerCountriesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bucketListStore: BucketListStore

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var sharedBucketCountryIds: Set<String> = []
    @State private var countries: [Country] = []
    @State private var selectedCountryIds: Set<String>
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var showingAllRecommendations = false

    private let profileService = ProfileService(supabase: SupabaseManager.shared)

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _selectedCountryIds = State(initialValue: Set(trip.countryIds))
    }

    private var fallbackTripCountries: [Country] {
        trip.countryIds.enumerated().map { index, id in
            let savedName = trip.countryNames.indices.contains(index) ? trip.countryNames[index] : CountrySelectionFormatter.localizedName(for: id)
            return Country(
                iso2: id,
                name: savedName,
                score: nil
            )
        }
    }

    private var allKnownCountries: [Country] {
        var merged: [String: Country] = Dictionary(
            uniqueKeysWithValues: fallbackTripCountries.map { ($0.id, $0) }
        )

        for country in countries {
            merged[country.id] = country
        }

        return Array(merged.values)
    }

    private var selectedCountries: [Country] {
        allKnownCountries
            .filter { selectedCountryIds.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsIndex = trip.countryIds.firstIndex(of: lhs.id) ?? Int.max
                let rhsIndex = trip.countryIds.firstIndex(of: rhs.id) ?? Int.max
                if lhsIndex != rhsIndex {
                    return lhsIndex < rhsIndex
                }
                return lhs.localizedDisplayName.localizedCaseInsensitiveCompare(rhs.localizedDisplayName) == .orderedAscending
            }
    }

    private var visibleCountries: [Country] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = trimmed.normalizedSearchKey
        let filtered = allKnownCountries.filter { country in
            guard !trimmed.isEmpty else { return true }
            return country.localizedSearchableNames.contains {
                $0.normalizedSearchKey.contains(normalizedSearch)
            }
                || country.id.localizedCaseInsensitiveContains(trimmed)
        }
        return filtered.sorted { $0.localizedDisplayName.localizedCaseInsensitiveCompare($1.localizedDisplayName) == .orderedAscending }
    }

    private var sharedBucketCountries: [Country] {
        allKnownCountries
            .filter { sharedBucketCountryIds.contains($0.id) }
            .sorted { $0.localizedDisplayName.localizedCaseInsensitiveCompare($1.localizedDisplayName) == .orderedAscending }
    }

    private var recommendationMonth: Int? {
        guard let startDate = trip.startDate else { return nil }
        return Calendar.current.component(.month, from: startDate)
    }

    private var recommendedCountries: [Country] {
        let selectedRegions = Set(selectedCountries.compactMap(\.region))
        let selectedSubregions = Set(selectedCountries.compactMap(\.subregion))
        let selectedIDs = Set(selectedCountries.map(\.id))

        return allKnownCountries
            .filter { !selectedIDs.contains($0.id) }
            .filter { country in
                if selectedRegions.isEmpty && selectedSubregions.isEmpty {
                    return true
                }
                return selectedRegions.contains(country.region ?? "")
                    || selectedSubregions.contains(country.subregion ?? "")
            }
            .map { country in
                (country: country, score: recommendationScore(for: country))
            }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.country.localizedDisplayName.localizedCaseInsensitiveCompare(rhs.country.localizedDisplayName) == .orderedAscending
            }
            .map(\.country)
    }

    private var visibleRecommendedCountries: [Country] {
        showingAllRecommendations ? recommendedCountries : Array(recommendedCountries.prefix(2))
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.countries.title"))

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("trip_planner.countries.loading")
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: String(localized: "trip_planner.countries.included_title"),
                                subtitle: String(localized: "trip_planner.countries.included_subtitle")
                            ) {
                                if !selectedCountries.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(String(localized: "trip_planner.countries.included_title"))
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.black)

                                        TripPlannerChipGrid(
                                            items: selectedCountries.map { country in
                                                TripPlannerChipItem(
                                                    id: country.id,
                                                    title: "\(country.flagEmoji) \(country.localizedDisplayName)",
                                                    isSelected: true
                                                )
                                            },
                                            onTap: { item in
                                                toggle(item.id)
                                            }
                                        )
                                    }
                                }

                                if !sharedBucketCountries.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("trip_planner.countries.mutual_bucket_list")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.black)

                                                Spacer()

                                            Button("trip_planner.add_all") {
                                                selectedCountryIds.formUnion(sharedBucketCountryIds)
                                            }
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.black)
                                        }

                                        TripPlannerChipGrid(
                                            items: sharedBucketCountries.map { country in
                                                TripPlannerChipItem(
                                                    id: country.id,
                                                    title: "\(country.flagEmoji) \(country.localizedDisplayName)",
                                                    isSelected: selectedCountryIds.contains(country.id)
                                                )
                                            },
                                            onTap: { item in
                                                toggle(item.id)
                                            }
                                        )
                                    }
                                }

                                if !recommendedCountries.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("Recommended for this trip")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.black)

                                            Spacer()

                                            if recommendedCountries.count > 2 {
                                                Button(showingAllRecommendations ? "Show less" : "Show more") {
                                                    showingAllRecommendations.toggle()
                                                }
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.black)
                                            }
                                        }

                                        Text(recommendationSubtitle)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.black.opacity(0.62))

                                        TripPlannerChipGrid(
                                            items: visibleRecommendedCountries.map { country in
                                                TripPlannerChipItem(
                                                    id: country.id,
                                                    title: "\(country.flagEmoji) \(country.localizedDisplayName)",
                                                    isSelected: selectedCountryIds.contains(country.id)
                                                )
                                            },
                                            onTap: { item in
                                                toggle(item.id)
                                            }
                                        )
                                    }
                                }

                                TripPlannerTextInput(
                                    title: String(localized: "trip_planner.countries.search_title"),
                                    text: $searchText,
                                    placeholder: String(localized: "trip_planner.countries.search_placeholder")
                                )

                                TripPlannerCountryList(
                                    countries: visibleCountries,
                                    selectedIds: selectedCountryIds,
                                    bucketIds: bucketListStore.ids,
                                    sharedIds: [],
                                    onTap: toggle
                                )
                            }
                            .padding(.horizontal, Theme.pageHorizontalInset)
                            .padding(.top, 18)
                            .padding(.bottom, 32)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                let selectedCountries = self.selectedCountries

                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: trip.title,
                        notes: trip.notes,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        countryIds: selectedCountries.map(\.id),
                        countryNames: selectedCountries.map(\.name),
                        friendIds: trip.friendIds,
                        friendNames: trip.friendNames,
                        friends: trip.friends,
                        ownerId: trip.ownerId,
                        ownerSnapshot: trip.effectiveOwnerSnapshot,
                        plannerCurrencyCode: trip.plannerCurrencyCode,
                        availability: trip.availability,
                        dayPlans: TripPlannerDayPlanBuilder.syncedDayPlans(
                            existingPlans: trip.dayPlans,
                            startDate: trip.startDate,
                            endDate: trip.endDate,
                            countries: selectedCountries.map { ($0.id, $0.name) }
                        ),
                        overallChecklistItems: trip.overallChecklistItems,
                        packingProgressEntries: trip.packingProgressEntries,
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .task {
            await loadCountries()
        }
    }

    @MainActor
    private func loadCountries() async {
        if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
            countries = cached
        }

        await loadSharedBucketCountries()

        if let fresh = await CountryAPI.refreshCountriesIfNeeded(minInterval: 60), !fresh.isEmpty {
            countries = fresh
        }

        countries.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false
    }

    @MainActor
    private func loadSharedBucketCountries() async {
        guard !trip.friendIds.isEmpty else {
            sharedBucketCountryIds = []
            return
        }

        let bucketResults = await withTaskGroup(of: Set<String>?.self, returning: [Set<String>?].self) { group in
            for friendId in trip.friendIds {
                group.addTask {
                    try? await profileService.fetchBucketListCountries(userId: friendId)
                }
            }

            var results: [Set<String>?] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        guard bucketResults.allSatisfy({ $0 != nil }) else {
            sharedBucketCountryIds = []
            return
        }

        var intersection = bucketListStore.ids
        for friendBucketIds in bucketResults.compactMap({ $0 }) {
            intersection.formIntersection(friendBucketIds)
        }

        sharedBucketCountryIds = intersection
    }

    private func toggle(_ id: String) {
        if selectedCountryIds.contains(id) {
            selectedCountryIds.remove(id)
        } else {
            selectedCountryIds.insert(id)
        }
    }

    private func recommendationScore(for country: Country) -> Int {
        let seasonalityScore = country.resolvedSeasonalityScore(for: recommendationMonth) ?? country.seasonalityScore ?? 0
        let selectedCountries = countries.filter { selectedCountryIds.contains($0.id) }
        let sharesSubregion = selectedCountries.contains { $0.subregion == country.subregion && country.subregion != nil }
        let sharesRegion = selectedCountries.contains { $0.region == country.region && country.region != nil }
        let regionBoost = sharesSubregion ? 20 : (sharesRegion ? 10 : 0)
        return seasonalityScore + regionBoost
    }

    private var recommendationSubtitle: String {
        if let recommendationMonth {
            let formatter = DateFormatter()
            formatter.locale = AppDisplayLocale.current
            let monthName = formatter.monthSymbols[recommendationMonth - 1]
            return "Good timing for \(monthName) and close to the regions already in this trip."
        }
        return "Good timing and nearby additions for the regions already in this trip."
    }
}

private struct TripPlannerItineraryPreview: View {
    let trip: TripPlannerTrip

    private var normalizedPlans: [TripPlannerDayPlan] {
        TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: trip.dayPlans,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
        )
    }

    var body: some View {
        if normalizedPlans.isEmpty {
            TripPlannerInfoCard(
                text: String(localized: "trip_planner.itinerary.preview_empty"),
                systemImage: "calendar.badge.plus"
            )
        } else {
            VStack(spacing: 10) {
                ForEach(Array(normalizedPlans.prefix(4))) { plan in
                    TripPlannerDayPlanRow(plan: plan)
                }

                if normalizedPlans.count > 4 {
                    TripPlannerInfoCard(
                        text: String(
                            format: String(localized: "trip_planner.itinerary.more_days"),
                            locale: AppDisplayLocale.current,
                            normalizedPlans.count - 4
                        ),
                        systemImage: "ellipsis.circle.fill"
                    )
                }
            }
        }
    }
}

private struct TripPlannerItineraryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var dayPlans: [TripPlannerDayPlan]

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _dayPlans = State(initialValue: TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: trip.dayPlans,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
        ))
    }

    private var countryOptions: [(id: String, name: String)] {
        zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.itinerary.title"))

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.itinerary.day_by_day_title"),
                            subtitle: String(localized: "trip_planner.itinerary.day_by_day_subtitle")
                        ) {
                            VStack(spacing: 10) {
                                ForEach(dayPlans.indices, id: \.self) { index in
                                    TripPlannerDayPlanEditorRow(
                                        plan: binding(for: index),
                                        countryOptions: countryOptions,
                                        previousPlan: index > 0 ? dayPlans[index - 1] : nil,
                                        nextPlan: index + 1 < dayPlans.count ? dayPlans[index + 1] : nil
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, Theme.pageHorizontalInset)
                        .padding(.top, 18)
                        .padding(.bottom, 32)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                onSave(
                    TripPlannerTrip(
                        id: trip.id,
                        createdAt: trip.createdAt,
                        title: trip.title,
                        notes: trip.notes,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        countryIds: trip.countryIds,
                        countryNames: trip.countryNames,
                        friendIds: trip.friendIds,
                        friendNames: trip.friendNames,
                        friends: trip.friends,
                        ownerId: trip.ownerId,
                        ownerSnapshot: trip.effectiveOwnerSnapshot,
                        plannerCurrencyCode: trip.plannerCurrencyCode,
                        availability: trip.availability,
                        dayPlans: normalizedDayPlans(),
                        overallChecklistItems: trip.overallChecklistItems,
                        packingProgressEntries: trip.packingProgressEntries,
                        expenses: trip.expenses
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
    }

    private func binding(for index: Int) -> Binding<TripPlannerDayPlan> {
        Binding(
            get: { dayPlans[index] },
            set: { newValue in
                dayPlans[index] = newValue
            }
        )
    }

    private func normalizedDayPlans() -> [TripPlannerDayPlan] {
        dayPlans.sorted { $0.date < $1.date }.map { plan in
            if plan.kind == .travel {
                return TripPlannerDayPlan(
                    id: plan.id,
                    date: plan.date,
                    kind: .travel,
                    checklistItems: TripPlannerDayPlanBuilder.syncedChecklistItems(plan.checklistItems, dayKind: .travel)
                )
            }

            let matchingCountry = countryOptions.first { $0.id == plan.countryId } ?? countryOptions.first
            return TripPlannerDayPlan(
                id: plan.id,
                date: plan.date,
                kind: matchingCountry == nil ? .travel : .country,
                countryId: matchingCountry?.id,
                countryName: matchingCountry?.name,
                checklistItems: TripPlannerDayPlanBuilder.syncedChecklistItems(plan.checklistItems, dayKind: .country)
            )
        }
    }
}

private struct TripPlannerDayPlanEditorRow: View {
    @Binding var plan: TripPlannerDayPlan
    let countryOptions: [(id: String, name: String)]
    let previousPlan: TripPlannerDayPlan?
    let nextPlan: TripPlannerDayPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(String(localized: "trip_planner.itinerary.type"), selection: kindBinding) {
                Text("trip_planner.itinerary.country").tag(TripPlannerDayPlanKind.country)
                Text("trip_planner.itinerary.travel").tag(TripPlannerDayPlanKind.travel)
            }
            .pickerStyle(.segmented)

            if plan.kind == .country {
                Menu {
                    ForEach(countryOptions, id: \.id) { option in
                        Button {
                            countryBinding.wrappedValue = option.id
                        } label: {
                            Text(countryLabel(for: option.id, name: option.name))
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stay in")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.58))

                            Text(selectedCountryLabel)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black.opacity(0.52))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                )
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Travel route")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.58))

                        HStack(spacing: 8) {
                            Text(travelOriginLabel)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .lineLimit(1)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black.opacity(0.55))

                            Text(travelDestinationLabel)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.58))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private var kindBinding: Binding<TripPlannerDayPlanKind> {
        Binding(
            get: { plan.kind },
            set: { newKind in
                let syncedChecklistItems = TripPlannerDayPlanBuilder.syncedChecklistItems(
                    plan.checklistItems,
                    dayKind: newKind
                )

                if newKind == .travel {
                    plan = TripPlannerDayPlan(
                        id: plan.id,
                        date: plan.date,
                        kind: .travel,
                        checklistItems: syncedChecklistItems
                    )
                } else {
                    let country = preferredCountryOption
                    plan = TripPlannerDayPlan(
                        id: plan.id,
                        date: plan.date,
                        kind: .country,
                        countryId: country?.id,
                        countryName: country?.name,
                        checklistItems: syncedChecklistItems
                    )
                }
            }
        )
    }

    private var countryBinding: Binding<String?> {
        Binding(
            get: { plan.countryId ?? preferredCountryOption?.id },
            set: { newCountryID in
                let country = countryOptions.first { $0.id == newCountryID } ?? preferredCountryOption
                plan = TripPlannerDayPlan(
                    id: plan.id,
                    date: plan.date,
                    kind: country == nil ? .travel : .country,
                    countryId: country?.id,
                    countryName: country?.name,
                    checklistItems: plan.checklistItems
                )
            }
        )
    }

    private var selectedCountryLabel: String {
        let option = countryOptions.first { $0.id == (plan.countryId ?? preferredCountryOption?.id) } ?? preferredCountryOption
        guard let option else { return "Select a country" }
        return countryLabel(for: option.id, name: option.name)
    }

    private var preferredCountryOption: (id: String, name: String)? {
        if let countryId = plan.countryId,
           let matchingOption = countryOptions.first(where: { $0.id == countryId }) {
            return matchingOption
        }

        if let previousCountryId = previousPlan?.countryId,
           let matchingPreviousOption = countryOptions.first(where: { $0.id == previousCountryId }) {
            return matchingPreviousOption
        }

        return countryOptions.first
    }

    private var travelOriginLabel: String {
        travelEndpointLabel(from: previousPlan) ?? "Home"
    }

    private var travelDestinationLabel: String {
        travelEndpointLabel(from: nextPlan) ?? "Home"
    }

    private func travelEndpointLabel(from plan: TripPlannerDayPlan?) -> String? {
        guard let plan, plan.kind == .country else { return nil }
        let option = countryOptions.first { $0.id == plan.countryId }
        let id = option?.id ?? plan.countryId
        let name = option?.name ?? plan.countryName
        guard let id, let name else { return nil }
        return countryLabel(for: id, name: name)
    }

    private func countryLabel(for id: String, name: String) -> String {
        "\(id.flagEmoji) \(name)"
    }
}

private struct TripPlannerDayPlanRow: View {
    let plan: TripPlannerDayPlan

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppDateFormatting.dateString(from: plan.date, template: "EEE MMM d"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)

                Text(labelText)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.74))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }

    private var labelText: String {
        if plan.kind == .travel {
            return String(localized: "trip_planner.itinerary.travel_day")
        }
        return plan.countryName ?? String(localized: "trip_planner.itinerary.country_day")
    }
}

private struct TripPlannerChecklistPreviewEntry: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let completedByName: String?
}

private struct TripPlannerChecklistPreviewSection: View {
    let trip: TripPlannerTrip
    let countries: [Country]
    let groupVisaNeeds: [TripPlannerTravelerVisaNeed]

    private var overallItems: [TripPlannerChecklistItem] {
        TripPlannerChecklistBuilder.syncedOverallChecklistItems(
            existingItems: trip.overallChecklistItems,
            countries: countries,
            groupVisaNeeds: groupVisaNeeds
        )
    }

    private var dayPlans: [TripPlannerDayPlan] {
        TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: trip.dayPlans,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
        )
    }

    private var previewEntries: [TripPlannerChecklistPreviewEntry] {
        let overall = overallItems
            .filter { $0.category != .packing }
            .map {
            TripPlannerChecklistPreviewEntry(
                id: $0.id,
                title: $0.title,
                subtitle: $0.category == .visa ? "Visas" : "Trip prep",
                isCompleted: $0.isCompleted,
                completedByName: $0.completedByName
            )
        }

        let daily = dayPlans.flatMap { plan in
            plan.checklistItems.map {
                TripPlannerChecklistPreviewEntry(
                    id: $0.id,
                    title: $0.title,
                    subtitle: AppDateFormatting.dateString(from: plan.date, template: "EEE MMM d"),
                    isCompleted: $0.isCompleted,
                    completedByName: $0.completedByName
                )
            }
        }

        return overall + daily
    }

    private var completedCount: Int {
        previewEntries.filter(\.isCompleted).count
    }

    var body: some View {
        if previewEntries.isEmpty {
            TripPlannerInfoCard(
                text: "Start with accommodation for each day, then add tickets or other prep items.",
                systemImage: "checklist"
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TripPlannerStatPill(
                        title: "Progress",
                        value: "\(completedCount)/\(previewEntries.count)",
                        detail: completedCount == previewEntries.count ? "Everything checked off" : "Tasks completed"
                    )

                    TripPlannerStatPill(
                        title: "Open items",
                        value: "\(max(previewEntries.count - completedCount, 0))",
                        detail: overallItems.contains(where: { $0.category == .visa }) ? "Includes visas" : "Daily prep only"
                    )
                }
            }
        }
    }
}

private struct TripPlannerChecklistEditorView: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let trip: TripPlannerTrip
    let actorId: UUID?
    let actorName: String
    let countries: [Country]
    let groupVisaNeeds: [TripPlannerTravelerVisaNeed]
    let saveAction: TripPlannerTripSaveAction

    @State private var overallItems: [TripPlannerChecklistItem]
    @State private var dayPlans: [TripPlannerDayPlan]
    @State private var selectedMonthPage: Date
    @State private var selectedDayPlanID: UUID?
    @State private var isShowingPackingList = false
    @State private var packingProgressEntries: [TripPlannerPackingProgress]
    @State private var packingDraft = TripPlannerPackingDraft(
        item: TripPlannerChecklistTemplates.defaultPackingItem(),
        progressEntries: []
    )
    @State private var packingCommitAction: TripPlannerPackingCommitAction?
    @State private var lastSavedSnapshot: TripPlannerChecklistDraftSnapshot
    @State private var saveFeedbackNonce = 0
    @State private var showSaveSuccess = false

    init(
        trip: TripPlannerTrip,
        actorId: UUID?,
        actorName: String,
        countries: [Country],
        groupVisaNeeds: [TripPlannerTravelerVisaNeed],
        saveAction: TripPlannerTripSaveAction
    ) {
        self.trip = trip
        self.actorId = actorId
        self.actorName = actorName
        self.countries = countries
        self.groupVisaNeeds = groupVisaNeeds
        self.saveAction = saveAction
        _overallItems = State(initialValue: TripPlannerChecklistBuilder.syncedOverallChecklistItems(
            existingItems: trip.overallChecklistItems,
            countries: countries,
            groupVisaNeeds: groupVisaNeeds
        ))
        _packingProgressEntries = State(initialValue: trip.packingProgressEntries)
        let initialPlans = Self.sanitizedChecklistItemIDs(
            in: TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: trip.dayPlans,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countries: zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
            )
        )
        _dayPlans = State(initialValue: initialPlans)
        let initialOverallItems = TripPlannerChecklistBuilder.syncedOverallChecklistItems(
            existingItems: trip.overallChecklistItems,
            countries: countries,
            groupVisaNeeds: groupVisaNeeds
        )
        let initialSharedPackingEntries = TripPlannerPackingCodec.decodeEntries(
            from: initialOverallItems.first(where: { $0.category == .packing })?.notes ?? ""
        )
        let initialSelectedDate = initialPlans.first?.date
            ?? trip.startDate
            ?? Date()
        _selectedMonthPage = State(
            initialValue: TripPlannerAvailabilityCalculator.startOfMonth(for: initialSelectedDate)
        )
        _selectedDayPlanID = State(initialValue: initialPlans.first?.id)
        _lastSavedSnapshot = State(
            initialValue: TripPlannerChecklistDraftSnapshot(
                overallItems: initialOverallItems,
                dayPlans: initialPlans.map { plan in
                    TripPlannerDayPlan(
                        id: plan.id,
                        date: plan.date,
                        kind: plan.kind,
                        countryId: plan.countryId,
                        countryName: plan.countryName,
                        checklistItems: TripPlannerDayPlanBuilder.syncedChecklistItems(plan.checklistItems, dayKind: plan.kind)
                    )
                },
                packingProgressEntries: TripPlannerPackingCodec.sanitizedProgressEntries(
                    trip.packingProgressEntries,
                    sharedEntries: initialSharedPackingEntries
                )
            )
        )
    }

    private var countryOptions: [(id: String, name: String)] {
        zip(trip.countryIds, trip.countryNames).map { ($0, $1) }
    }

    private var monthsToDisplay: [Date] {
        let planDates = dayPlans.map(\.date)
        guard let minDate = planDates.min(), let maxDate = planDates.max() else { return [] }

        let calendar = Calendar.current
        let startMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: minDate)
        let endMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: maxDate)

        var months: [Date] = []
        var current = startMonth

        while current <= endMonth {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }

        return months
    }

    private var selectedDayIndex: Int? {
        if let selectedDayPlanID,
           let selectedIndex = dayPlans.firstIndex(where: { $0.id == selectedDayPlanID }) {
            return selectedIndex
        }

        return dayPlans.indices.first
    }

    private var visaItems: [TripPlannerChecklistItem] {
        overallItems.filter { $0.category == .visa }
    }

    private var packingItemIndex: Int? {
        overallItems.firstIndex { $0.category == .packing }
    }

    private var currentDraftSnapshot: TripPlannerChecklistDraftSnapshot {
        let syncedOverallItems = TripPlannerChecklistBuilder.syncedOverallChecklistItems(
            existingItems: overallItems,
            countries: countries,
            groupVisaNeeds: groupVisaNeeds
        )
        let sharedPackingEntries = TripPlannerPackingCodec.decodeEntries(
            from: syncedOverallItems.first(where: { $0.category == .packing })?.notes ?? ""
        )

        return TripPlannerChecklistDraftSnapshot(
            overallItems: syncedOverallItems,
            dayPlans: Self.sanitizedChecklistItemIDs(in: dayPlans.map { plan in
                TripPlannerDayPlan(
                    id: plan.id,
                    date: plan.date,
                    kind: plan.kind,
                    countryId: plan.countryId,
                    countryName: plan.countryName,
                    checklistItems: TripPlannerDayPlanBuilder.syncedChecklistItems(plan.checklistItems, dayKind: plan.kind)
                )
            }),
            packingProgressEntries: TripPlannerPackingCodec.sanitizedProgressEntries(
                packingProgressEntries,
                sharedEntries: sharedPackingEntries
            )
        )
    }

    private var hasUnsavedChanges: Bool {
        currentDraftSnapshot != lastSavedSnapshot
    }

    private var plannerCurrencyCode: String {
        trip.effectivePlannerCurrencyCode
    }

    private var countryCurrencyCodesByID: [String: String] {
        var currencyCodes: [String: String] = [:]

        for country in countries {
            if let currencyCode = TripPlannerCountryCurrencyLookup.currencyCode(for: country) {
                currencyCodes[country.id.uppercased()] = currencyCode
            }
        }

        for country in TripPlannerCountryLookup.countries(for: trip.countryIds) {
            if let currencyCode = TripPlannerCountryCurrencyLookup.currencyCode(for: country) {
                currencyCodes[country.id.uppercased()] = currencyCode
            }
        }

        for countryId in trip.countryIds {
            let normalizedID = countryId.uppercased()
            if currencyCodes[normalizedID] == nil,
               let currencyCode = TripPlannerCountryCurrencyLookup.currencyCode(forCountryID: normalizedID) {
                currencyCodes[normalizedID] = currencyCode
            }
        }

        return currencyCodes
    }

    private var tripLocalCurrencyCodes: [String] {
        uniqueCurrencyCodes(trip.countryIds.compactMap { countryCurrencyCodesByID[$0.uppercased()] })
    }

    private var tripLocalCurrencyCode: String? {
        tripLocalCurrencyCodes.first
    }

    private var displayedMonthPage: Date? {
        if monthsToDisplay.contains(selectedMonthPage) {
            return selectedMonthPage
        }

        return monthsToDisplay.first
    }

    private var displayedMonthIndex: Int? {
        guard let displayedMonthPage else { return nil }
        return monthsToDisplay.firstIndex(of: displayedMonthPage)
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("Planning checklist")

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: "Overall trip",
                            subtitle: ""
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                NavigationLink {
                                    TripPlannerVisaChecklistView(
                                        overallItems: $overallItems,
                                        currencyCode: plannerCurrencyCode,
                                        localCurrencyCodes: tripLocalCurrencyCodes,
                                        actorId: actorId,
                                        actorName: actorName
                                    )
                                } label: {
                                    TripPlannerNavigationSectionCard(
                                        title: "Visas",
                                        subtitle: visaItems.isEmpty
                                            ? "No visa prep is needed right now"
                                            : "\(visaItems.count) visa item\(visaItems.count == 1 ? "" : "s")"
                                    ) {
                                        EmptyView()
                                    }
                                }
                                .buttonStyle(.plain)

                                if packingItemIndex != nil {
                                    Button {
                                        openPackingList()
                                    } label: {
                                        TripPlannerNavigationSectionCard(
                                            title: "What to pack",
                                            subtitle: "Shared group list plus your own personal checkoffs"
                                        ) {
                                            EmptyView()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: "Daily plans",
                            subtitle: "Tap a date to edit that day’s schedule and checklist"
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                if !monthsToDisplay.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select a day")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.72))

                                        if let displayedMonthPage,
                                           let displayedMonthIndex {
                                            VStack(alignment: .leading, spacing: 12) {
                                                if monthsToDisplay.count > 1 {
                                                    HStack(spacing: 12) {
                                                        monthNavigationButton(
                                                            systemImage: "chevron.left",
                                                            isEnabled: displayedMonthIndex > 0
                                                        ) {
                                                            selectedMonthPage = monthsToDisplay[displayedMonthIndex - 1]
                                                        }

                                                        Spacer(minLength: 0)

                                                        Text(TripPlannerAvailabilityCalculator.monthTitle(for: displayedMonthPage))
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundStyle(.black)
                                                            .multilineTextAlignment(.center)

                                                        Spacer(minLength: 0)

                                                        monthNavigationButton(
                                                            systemImage: "chevron.right",
                                                            isEnabled: displayedMonthIndex < monthsToDisplay.count - 1
                                                        ) {
                                                            selectedMonthPage = monthsToDisplay[displayedMonthIndex + 1]
                                                        }
                                                    }
                                                }

                                                TripPlannerChecklistMonthCard(
                                                    month: displayedMonthPage,
                                                    plans: dayPlans,
                                                    selectedDayPlanID: $selectedDayPlanID,
                                                    showsMonthTitle: monthsToDisplay.count == 1
                                                )
                                            }
                                        }
                                    }
                                }

                                if let selectedDayIndex {
                                    let plan = dayPlans[selectedDayIndex]

                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(AppDateFormatting.dateString(from: plan.date, dateStyle: .full))
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.black)

                                        TripPlannerDayPlanEditorRow(
                                            plan: bindingForDayPlan(at: selectedDayIndex),
                                            countryOptions: countryOptions,
                                            previousPlan: previousPlan(for: selectedDayIndex),
                                            nextPlan: nextPlan(for: selectedDayIndex)
                                        )

                                        VStack(spacing: 10) {
                                            ForEach(Array(plan.checklistItems.enumerated()), id: \.element.id) { itemIndex, _ in
                                                TripPlannerChecklistItemEditorRow(
                                                    item: bindingForDayItem(dayIndex: selectedDayIndex, itemIndex: itemIndex),
                                                    planDate: plan.date,
                                                    currencyCode: plannerCurrencyCode,
                                                    localCurrencyCodes: localCurrencyCodes(for: plan, at: selectedDayIndex),
                                                    saveFeedbackNonce: saveFeedbackNonce,
                                                    actorId: actorId,
                                                    actorName: actorName,
                                                    showsRemove: true,
                                                    onRemove: {
                                                        removeDayItem(at: itemIndex, from: selectedDayIndex)
                                                    }
                                                )
                                            }
                                        }

                                        if let accommodationSuggestion = accommodationCarryForwardSuggestion(for: selectedDayIndex) {
                                            Button {
                                                applyAccommodationSuggestion(accommodationSuggestion, to: selectedDayIndex)
                                            } label: {
                                                HStack(alignment: .center, spacing: 10) {
                                                    Image(systemName: "arrow.turn.down.right")
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundStyle(.black.opacity(0.7))

                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text("Use last night's accommodation")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundStyle(.black)
                                                        Text(accommodationSuggestion.notes)
                                                            .font(.system(size: 12))
                                                            .foregroundStyle(.black.opacity(0.66))
                                                            .lineLimit(2)
                                                        if let completedByName = accommodationSuggestion.completedByName,
                                                           accommodationSuggestion.isCompleted {
                                                            Text("Completed by \(completedByName)")
                                                                .font(.system(size: 12, weight: .medium))
                                                                .foregroundStyle(.black.opacity(0.55))
                                                        }
                                                    }

                                                    Spacer()

                                                    Text("Apply")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundStyle(.black)
                                                }
                                                .padding(14)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                        .fill(Color.white.opacity(0.78))
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        checklistSuggestionButtons(
                                            items: availableDaySuggestions(for: plan),
                                            addAction: { addDaySuggestion($0, to: selectedDayIndex) }
                                        )
                                    }
                                } else {
                                    VStack(spacing: 10) {
                                        TripPlannerInfoCard(
                                            text: "Add trip dates to start planning day-by-day details.",
                                            systemImage: "calendar.badge.plus"
                                        )
                                    }
                                }
                            }
                        }

                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                persistChecklist()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(hasUnsavedChanges ? Theme.accent : Color.gray.opacity(0.55))
            )
            .buttonStyle(.plain)
            .disabled(!hasUnsavedChanges)
            .opacity(hasUnsavedChanges ? 1 : 0.5)
        }
        .overlay(alignment: .top) {
            if showSaveSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Planning checklist saved")
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
        .onAppear {
            logCurrencyContext("appear")
            guard selectedDayPlanID == nil else { return }
            selectedDayPlanID = dayPlans.first?.id
        }
        .onChange(of: monthsToDisplay) { _, months in
            guard let firstMonth = months.first else { return }
            if !months.contains(selectedMonthPage) {
                selectedMonthPage = firstMonth
            }
        }
        .onChange(of: dayPlans.map(\.id)) { _, ids in
            guard !ids.isEmpty else {
                selectedDayPlanID = nil
                return
            }

            if let selectedDayPlanID, ids.contains(selectedDayPlanID) {
                return
            }

            selectedDayPlanID = ids.first
        }
        .navigationDestination(isPresented: $isShowingPackingList) {
            if let packingCommitAction {
                TripPlannerPackingListView(
                    item: packingDraft.item,
                    progressEntries: packingDraft.progressEntries,
                    currencyCode: plannerCurrencyCode,
                    localCurrencyCodes: tripLocalCurrencyCodes,
                    actorId: actorId,
                    actorName: actorName,
                    commitAction: packingCommitAction
                )
            }
        }
    }

    @ViewBuilder
    private func monthNavigationButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black.opacity(isEnabled ? 0.82 : 0.28))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isEnabled ? 0.84 : 0.45))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func availableDaySuggestions(for plan: TripPlannerDayPlan) -> [TripPlannerChecklistItem] {
        let existingKeys = Set(plan.checklistItems.map { suggestionKey(for: $0) })
        return TripPlannerChecklistTemplates.daySuggestions.filter { !existingKeys.contains(suggestionKey(for: $0)) }
    }

    private func localCurrencyCodes(for plan: TripPlannerDayPlan, at dayIndex: Int? = nil) -> [String] {
        let result: [String]
        if plan.kind == .travel {
            var codes: [String] = []

            if let dayIndex,
               let previousCurrencyCode = countryCurrencyCode(for: previousPlan(for: dayIndex)) {
                codes.append(previousCurrencyCode)
            }

            if let dayIndex,
               let nextCurrencyCode = countryCurrencyCode(for: nextPlan(for: dayIndex)) {
                codes.append(nextCurrencyCode)
            }

            result = uniqueCurrencyCodes(codes.isEmpty ? tripLocalCurrencyCodes : codes)
        } else if let currencyCode = countryCurrencyCode(for: plan) {
            result = [currencyCode]
        } else {
            result = tripLocalCurrencyCodes
        }

        TripPlannerDebugLog.probe(
            "TripPlannerChecklistEditor.local_currency_codes",
            "trip=\(TripPlannerDebugLog.tripLabel(trip)) kind=\(plan.kind.rawValue) country=\(plan.countryId ?? "nil") dayIndex=\(dayIndex.map(String.init) ?? "nil") result=\(result.joined(separator: ","))"
        )
        return result
    }

    private func countryCurrencyCode(for plan: TripPlannerDayPlan?) -> String? {
        guard let countryId = plan?.countryId?.uppercased() else { return nil }
        return countryCurrencyCodesByID[countryId]
    }

    private func uniqueCurrencyCodes(_ codes: [String]) -> [String] {
        var seen = Set<String>()
        return codes.compactMap { rawCode in
            guard let code = AppCurrencyCatalog.normalizedCode(rawCode),
                  seen.insert(code).inserted
            else {
                return nil
            }
            return code
        }
    }

    private func logCurrencyContext(_ context: String) {
        let mapping = countryCurrencyCodesByID
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        TripPlannerDebugLog.probe(
            "TripPlannerChecklistEditor.currency_context",
            "context=\(context) trip=\(TripPlannerDebugLog.tripLabel(trip)) ids=\(trip.countryIds.joined(separator: ",")) countriesProp=\(countries.count) map=\(mapping) locals=\(tripLocalCurrencyCodes.joined(separator: ","))"
        )
    }

    @ViewBuilder
    private func checklistSuggestionButtons(
        items: [TripPlannerChecklistItem],
        addAction: @escaping (TripPlannerChecklistItem) -> Void
    ) -> some View {
        if !items.isEmpty {
            TripPlannerChipGrid(
                items: items.map {
                    TripPlannerChipItem(
                        id: $0.id.uuidString,
                        title: "+ \($0.title)",
                        isSelected: false
                    )
                } + [
                    TripPlannerChipItem(id: "custom", title: "+ Custom", isSelected: false)
                ],
                onTap: { item in
                    if item.id == "custom" {
                        addAction(TripPlannerChecklistItem(category: .custom, title: "Custom task"))
                    } else if let suggestion = items.first(where: { $0.id.uuidString == item.id }) {
                        addAction(suggestion)
                    }
                }
            )
        } else {
            Button {
                addAction(TripPlannerChecklistItem(category: .custom, title: "Custom task"))
            } label: {
                Label("Add custom item", systemImage: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.82))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func bindingForVisaItem(at index: Int) -> Binding<TripPlannerChecklistItem> {
        Binding(
            get: { visaItems[index] },
            set: { newValue in
                if let overallIndex = overallItems.firstIndex(where: { $0.id == visaItems[index].id }) {
                    overallItems[overallIndex] = newValue
                }
            }
        )
    }

    private func openPackingList() {
        guard let packingItemIndex else { return }
        packingDraft = TripPlannerPackingDraft(
            item: overallItems[packingItemIndex],
            progressEntries: packingProgressEntries
        )
        packingCommitAction = TripPlannerPackingCommitAction(handler: commitPackingDraft)
        isShowingPackingList = true
    }

    private func commitPackingDraft(_ draft: TripPlannerPackingDraft) {
        let normalized = TripPlannerChecklistTemplates.defaultPackingItem(existing: draft.item)
        guard let packingItemIndex else { return }
        overallItems[packingItemIndex] = normalized
        let sharedEntries = TripPlannerPackingCodec.decodeEntries(from: normalized.notes)
        packingProgressEntries = TripPlannerPackingCodec.sanitizedProgressEntries(
            draft.progressEntries,
            sharedEntries: sharedEntries
        )
    }

    private func bindingForDayPlan(at index: Int) -> Binding<TripPlannerDayPlan> {
        Binding(
            get: { dayPlans[index] },
            set: { newValue in
                let previousValue = dayPlans[index]
                dayPlans[index] = newValue
                cascadeInheritedCountryChanges(from: index, previousValue: previousValue, newValue: newValue)
            }
        )
    }

    private func bindingForDayItem(dayIndex: Int, itemIndex: Int) -> Binding<TripPlannerChecklistItem> {
        Binding(
            get: { dayPlans[dayIndex].checklistItems[itemIndex] },
            set: { newValue in
                var updatedItems = dayPlans[dayIndex].checklistItems
                updatedItems[itemIndex] = newValue
                dayPlans[dayIndex] = TripPlannerDayPlan(
                    id: dayPlans[dayIndex].id,
                    date: dayPlans[dayIndex].date,
                    kind: dayPlans[dayIndex].kind,
                    countryId: dayPlans[dayIndex].countryId,
                    countryName: dayPlans[dayIndex].countryName,
                    checklistItems: updatedItems
                )

                synchronizeLinkedAccommodationItems(using: newValue)
            }
        )
    }

    private func previousPlan(for dayIndex: Int) -> TripPlannerDayPlan? {
        guard dayIndex > 0 else { return nil }
        return dayPlans[dayIndex - 1]
    }

    private func nextPlan(for dayIndex: Int) -> TripPlannerDayPlan? {
        guard dayIndex < dayPlans.count - 1 else { return nil }
        return dayPlans[dayIndex + 1]
    }

    private func cascadeInheritedCountryChanges(
        from dayIndex: Int,
        previousValue: TripPlannerDayPlan,
        newValue: TripPlannerDayPlan
    ) {
        guard previousValue.kind == .country, newValue.kind == .country else { return }
        guard previousValue.countryId != newValue.countryId else { return }

        let previousCountryId = previousValue.countryId
        let previousCountryName = previousValue.countryName

        for followingIndex in dayPlans.indices where followingIndex > dayIndex {
            let followingPlan = dayPlans[followingIndex]

            if followingPlan.kind == .travel {
                break
            }

            guard followingPlan.kind == .country else { continue }

            let shouldInherit =
                followingPlan.countryId == nil ||
                (previousCountryId != nil && followingPlan.countryId == previousCountryId) ||
                (followingPlan.countryId == nil && followingPlan.countryName == nil) ||
                (previousCountryName != nil && followingPlan.countryName == previousCountryName)

            guard shouldInherit else { break }

            dayPlans[followingIndex] = TripPlannerDayPlan(
                id: followingPlan.id,
                date: followingPlan.date,
                kind: .country,
                countryId: newValue.countryId,
                countryName: newValue.countryName,
                checklistItems: followingPlan.checklistItems
            )
        }
    }

    private func synchronizeLinkedAccommodationItems(using updatedItem: TripPlannerChecklistItem) {
        guard updatedItem.category == .accommodation else { return }

        let syncKey = updatedItem.expenseSyncKey

        for dayIndex in dayPlans.indices {
            var didUpdateDay = false
            var updatedItems = dayPlans[dayIndex].checklistItems

            for itemIndex in updatedItems.indices {
                let existingItem = updatedItems[itemIndex]
                guard existingItem.category == .accommodation else { continue }
                guard existingItem.expenseSyncKey == syncKey else { continue }

                let targetSourceItemId: UUID? = existingItem.id == syncKey ? nil : syncKey
                let synchronizedItem = TripPlannerChecklistItem(
                    id: existingItem.id,
                    category: existingItem.category,
                    title: updatedItem.title,
                    notes: updatedItem.notes,
                    expenseSourceItemId: targetSourceItemId,
                    linkedExpenseId: updatedItem.linkedExpenseId,
                    linkedExpenseAmount: updatedItem.linkedExpenseAmount,
                    linkedExpenseCurrencyCode: updatedItem.linkedExpenseCurrencyCode,
                    linkedExpenseDate: updatedItem.linkedExpenseDate,
                    isCompleted: updatedItem.isCompleted,
                    completedById: updatedItem.completedById,
                    completedByName: updatedItem.completedByName,
                    completedAt: updatedItem.completedAt
                )

                if synchronizedItem != existingItem {
                    updatedItems[itemIndex] = synchronizedItem
                    didUpdateDay = true
                }
            }

            if didUpdateDay {
                dayPlans[dayIndex] = TripPlannerDayPlan(
                    id: dayPlans[dayIndex].id,
                    date: dayPlans[dayIndex].date,
                    kind: dayPlans[dayIndex].kind,
                    countryId: dayPlans[dayIndex].countryId,
                    countryName: dayPlans[dayIndex].countryName,
                    checklistItems: updatedItems
                )
            }
        }
    }

    private func accommodationCarryForwardSuggestion(for dayIndex: Int) -> TripPlannerChecklistItem? {
        guard dayIndex > 0 else { return nil }

        let currentPlan = dayPlans[dayIndex]
        guard currentPlan.kind == .country else { return nil }

        let currentItems = dayPlans[dayIndex].checklistItems
        let currentAccommodation = currentItems.first { $0.category == .accommodation }
        let currentNotes = currentAccommodation?.notes.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard currentNotes.isEmpty else { return nil }

        var searchIndex = dayIndex - 1

        while searchIndex >= 0 {
            let priorPlan = dayPlans[searchIndex]

            if priorPlan.kind == .country, priorPlan.countryId != currentPlan.countryId {
                return nil
            }

            if let priorAccommodation = priorPlan.checklistItems.first(where: {
                $0.category == .accommodation && !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) {
                return priorAccommodation
            }

            searchIndex -= 1
        }

        return nil
    }

    private func applyAccommodationSuggestion(_ suggestion: TripPlannerChecklistItem, to dayIndex: Int) {
        var updatedItems = dayPlans[dayIndex].checklistItems
        let sharedExpenseSourceId = suggestion.expenseSourceItemId ?? suggestion.id

        if let existingIndex = updatedItems.firstIndex(where: { $0.category == .accommodation }) {
            let existing = updatedItems[existingIndex]
            updatedItems[existingIndex] = TripPlannerChecklistItem(
                id: existing.id,
                category: existing.category,
                title: suggestion.title,
                notes: suggestion.notes,
                expenseSourceItemId: sharedExpenseSourceId,
                linkedExpenseId: suggestion.linkedExpenseId,
                linkedExpenseAmount: suggestion.linkedExpenseAmount,
                linkedExpenseCurrencyCode: suggestion.linkedExpenseCurrencyCode,
                linkedExpenseDate: suggestion.linkedExpenseDate,
                isCompleted: existing.isCompleted,
                completedById: existing.completedById,
                completedByName: existing.completedByName,
                completedAt: existing.completedAt
            )
        } else {
            updatedItems.insert(
                TripPlannerChecklistItem(
                    category: .accommodation,
                    title: suggestion.title,
                    notes: suggestion.notes,
                    expenseSourceItemId: sharedExpenseSourceId,
                    linkedExpenseId: suggestion.linkedExpenseId,
                    linkedExpenseAmount: suggestion.linkedExpenseAmount,
                    linkedExpenseCurrencyCode: suggestion.linkedExpenseCurrencyCode,
                    linkedExpenseDate: suggestion.linkedExpenseDate
                ),
                at: 0
            )
        }

        dayPlans[dayIndex] = TripPlannerDayPlan(
            id: dayPlans[dayIndex].id,
            date: dayPlans[dayIndex].date,
            kind: dayPlans[dayIndex].kind,
            countryId: dayPlans[dayIndex].countryId,
            countryName: dayPlans[dayIndex].countryName,
            checklistItems: updatedItems
        )
    }

    private func addDaySuggestion(_ item: TripPlannerChecklistItem, to dayIndex: Int) {
        var updatedItems = dayPlans[dayIndex].checklistItems
        updatedItems.append(item.duplicatedForNewChecklistEntry())
        dayPlans[dayIndex] = TripPlannerDayPlan(
            id: dayPlans[dayIndex].id,
            date: dayPlans[dayIndex].date,
            kind: dayPlans[dayIndex].kind,
            countryId: dayPlans[dayIndex].countryId,
            countryName: dayPlans[dayIndex].countryName,
            checklistItems: updatedItems
        )
    }

    private func removeDayItem(at itemIndex: Int, from dayIndex: Int) {
        var updatedItems = dayPlans[dayIndex].checklistItems
        updatedItems.remove(at: itemIndex)
        dayPlans[dayIndex] = TripPlannerDayPlan(
            id: dayPlans[dayIndex].id,
            date: dayPlans[dayIndex].date,
            kind: dayPlans[dayIndex].kind,
            countryId: dayPlans[dayIndex].countryId,
            countryName: dayPlans[dayIndex].countryName,
            checklistItems: updatedItems
        )
    }

    private func suggestionKey(for item: TripPlannerChecklistItem) -> String {
        "\(item.category.rawValue)::\(item.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: AppDisplayLocale.current))"
    }

    private func removeVisaItem(at index: Int) {
        let visaID = visaItems[index].id
        overallItems.removeAll { $0.id == visaID }
    }

    private func canRemoveOverallItem(_ item: TripPlannerChecklistItem) -> Bool {
        item.category != .visa
    }

    private func persistChecklist() {
        let snapshot = currentDraftSnapshot

        saveAction.handler(
            TripPlannerTrip(
                id: trip.id,
                createdAt: trip.createdAt,
                updatedAt: trip.updatedAt,
                title: trip.title,
                notes: trip.notes,
                startDate: trip.startDate,
                endDate: trip.endDate,
                countryIds: trip.countryIds,
                countryNames: trip.countryNames,
                friendIds: trip.friendIds,
                friendNames: trip.friendNames,
                friends: trip.friends,
                ownerId: trip.ownerId,
                ownerSnapshot: trip.effectiveOwnerSnapshot,
                plannerCurrencyCode: trip.plannerCurrencyCode,
                availability: trip.availability,
                dayPlans: snapshot.dayPlans,
                overallChecklistItems: snapshot.overallItems,
                packingProgressEntries: snapshot.packingProgressEntries,
                expenses: trip.expenses
            )
        )

        lastSavedSnapshot = snapshot
        saveFeedbackNonce += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showSaveSuccess = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                showSaveSuccess = false
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private static func sanitizedChecklistItemIDs(in plans: [TripPlannerDayPlan]) -> [TripPlannerDayPlan] {
        var seen = Set<UUID>()

        return plans.map { plan in
            var updatedItems: [TripPlannerChecklistItem] = []

            for item in plan.checklistItems {
                if seen.insert(item.id).inserted {
                    updatedItems.append(item)
                } else {
                    updatedItems.append(
                        TripPlannerChecklistItem(
                            category: item.category,
                            title: item.title,
                            notes: item.notes,
                            expenseSourceItemId: item.expenseSourceItemId,
                            linkedExpenseId: item.linkedExpenseId,
                            linkedExpenseAmount: item.linkedExpenseAmount,
                            linkedExpenseCurrencyCode: item.linkedExpenseCurrencyCode,
                            linkedExpenseDate: item.linkedExpenseDate,
                            isCompleted: item.isCompleted,
                            completedById: item.completedById,
                            completedByName: item.completedByName,
                            completedAt: item.completedAt
                        )
                    )
                }
            }

            return TripPlannerDayPlan(
                id: plan.id,
                date: plan.date,
                kind: plan.kind,
                countryId: plan.countryId,
                countryName: plan.countryName,
                checklistItems: updatedItems
            )
        }
    }
}

private struct TripPlannerChecklistDraftSnapshot: Equatable {
    let overallItems: [TripPlannerChecklistItem]
    let dayPlans: [TripPlannerDayPlan]
    let packingProgressEntries: [TripPlannerPackingProgress]
}

private struct TripPlannerChecklistMonthCard: View {
    let month: Date
    let plans: [TripPlannerDayPlan]
    @Binding var selectedDayPlanID: UUID?
    var showsMonthTitle = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var daySlots: [Date?] {
        TripPlannerAvailabilityCalculator.daySlots(for: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsMonthTitle {
                Text(TripPlannerAvailabilityCalculator.monthTitle(for: month))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TripPlannerAvailabilityCalculator.weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(daySlots.enumerated()), id: \.offset) { _, day in
                    if let day {
                        TripPlannerChecklistDayCell(
                            date: day,
                            month: month,
                            plans: plans,
                            selectedDayPlanID: $selectedDayPlanID
                        )
                    } else {
                        Color.clear
                            .frame(height: 42)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

private struct TripPlannerVisaChecklistView: View {
    @Binding var overallItems: [TripPlannerChecklistItem]
    let currencyCode: String
    var localCurrencyCodes: [String] = []
    let actorId: UUID?
    let actorName: String

    private var visaItems: [TripPlannerChecklistItem] {
        overallItems.filter { $0.category == .visa }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("Visas")

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: "Visa requirements",
                            subtitle: "Each traveler and country that still needs visa prep"
                        ) {
                            if visaItems.isEmpty {
                                TripPlannerInfoCard(
                                    text: "No visa prep is needed for this trip right now.",
                                    systemImage: "globe"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(visaItems.indices, id: \.self) { index in
                                        TripPlannerChecklistItemEditorRow(
                                            item: visaBinding(at: index),
                                            planDate: Date(),
                                            currencyCode: currencyCode,
                                            localCurrencyCodes: localCurrencyCodes,
                                            saveFeedbackNonce: 0,
                                            actorId: actorId,
                                            actorName: actorName,
                                            showsRemove: false,
                                            onRemove: {}
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.pageHorizontalInset)
                        .padding(.top, 18)
                        .padding(.bottom, 32)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func visaBinding(at index: Int) -> Binding<TripPlannerChecklistItem> {
        Binding(
            get: { visaItems[index] },
            set: { newValue in
                if let overallIndex = overallItems.firstIndex(where: { $0.id == visaItems[index].id }) {
                    overallItems[overallIndex] = newValue
                }
            }
        )
    }
}

private struct TripPlannerPackingListView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var item: TripPlannerChecklistItem
    @State private var progressEntries: [TripPlannerPackingProgress]
    let currencyCode: String
    let localCurrencyCodes: [String]
    let actorId: UUID?
    let actorName: String
    let commitAction: TripPlannerPackingCommitAction

    init(
        item: TripPlannerChecklistItem,
        progressEntries: [TripPlannerPackingProgress],
        currencyCode: String,
        localCurrencyCodes: [String] = [],
        actorId: UUID?,
        actorName: String,
        commitAction: TripPlannerPackingCommitAction
    ) {
        self._item = State(initialValue: item)
        self._progressEntries = State(initialValue: progressEntries)
        self.currencyCode = currencyCode
        self.localCurrencyCodes = localCurrencyCodes
        self.actorId = actorId
        self.actorName = actorName
        self.commitAction = commitAction
    }

    private var sharedEntries: [TripPlannerPackingEntry] {
        TripPlannerPackingCodec.decodeEntries(from: item.notes)
    }

    private var actorKey: String {
        actorId?.uuidString ?? "local-user"
    }

    private var actorDisplayName: String {
        let trimmed = actorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "You" : trimmed
    }

    private var checkedEntryIDs: Set<UUID> {
        Set(progressEntries.first(where: { $0.userKey == actorKey })?.checkedEntryIDs ?? [])
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("What to pack")

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: "Packing list",
                            subtitle: "If traveling with friends, this packing list is shared so everyone can use the same reference while packing."
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                TripPlannerInfoCard(
                                    text: "Most airports apply a 100 mL / 3.4 oz carry-on liquid limit, but rules can vary by airport, country, and airline. Check requirements before you fly, and place larger liquids in checked baggage when needed.",
                                    systemImage: "suitcase.rolling.fill"
                                )

                                TripPlannerChecklistItemEditorRow(
                                    item: $item,
                                    planDate: Date(),
                                    currencyCode: currencyCode,
                                    localCurrencyCodes: localCurrencyCodes,
                                    saveFeedbackNonce: 0,
                                    actorId: actorId,
                                    actorName: actorName,
                                    showsRemove: false,
                                    showsCompletion: false,
                                    showsTitleField: false,
                                    showsCategoryLabel: false,
                                    onRemove: {}
                                )
                            }
                        }
                        
                        TripPlannerSectionCard(
                            title: "My packing progress",
                            subtitle: "Only \(actorDisplayName) sees these checkmarks."
                        ) {
                            if sharedEntries.isEmpty {
                                TripPlannerInfoCard(
                                    text: "Add items to the group packing list first, then check them off here as you pack.",
                                    systemImage: "checkmark.circle"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(sharedEntries) { entry in
                                        TripPlannerPersonalPackingEntryRow(
                                            entry: entry,
                                            isChecked: checkedEntryIDs.contains(entry.id),
                                            onToggle: {
                                                togglePersonalEntry(entry.id)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tripPlannerNavigationChrome {
            Button(String(localized: "common.save")) {
                commitAndDismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .onDisappear {
            commitAction.handler(sanitizedDraft())
        }
    }

    private func commitAndDismiss() {
        commitAction.handler(sanitizedDraft())
        dismiss()
    }

    private func togglePersonalEntry(_ id: UUID) {
        var updatedIDs = checkedEntryIDs
        if updatedIDs.contains(id) {
            updatedIDs.remove(id)
        } else {
            updatedIDs.insert(id)
        }

        let updatedProgress = TripPlannerPackingProgress(
            userKey: actorKey,
            userName: actorDisplayName,
            checkedEntryIDs: Array(updatedIDs).sorted { $0.uuidString < $1.uuidString }
        )

        if let existingIndex = progressEntries.firstIndex(where: { $0.userKey == actorKey }) {
            progressEntries[existingIndex] = updatedProgress
        } else {
            progressEntries.append(updatedProgress)
        }
    }

    private func sanitizedDraft() -> TripPlannerPackingDraft {
        let normalizedItem = TripPlannerChecklistTemplates.defaultPackingItem(existing: item)
        let normalizedSharedEntries = TripPlannerPackingCodec.decodeEntries(from: normalizedItem.notes)
        return TripPlannerPackingDraft(
            item: normalizedItem,
            progressEntries: TripPlannerPackingCodec.sanitizedProgressEntries(
                progressEntries,
                sharedEntries: normalizedSharedEntries
            )
        )
    }
}

private struct TripPlannerPersonalPackingEntryRow: View {
    let entry: TripPlannerPackingEntry
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isChecked ? Color(red: 0.14, green: 0.50, blue: 0.25) : .black.opacity(0.42))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)

                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.system(size: 12))
                            .foregroundStyle(.black.opacity(0.62))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TripPlannerChecklistDayCell: View {
    let date: Date
    let month: Date
    let plans: [TripPlannerDayPlan]
    @Binding var selectedDayPlanID: UUID?

    private var planForDate: TripPlannerDayPlan? {
        let calendar = Calendar.current
        return plans.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var isSelected: Bool {
        guard let planForDate else { return false }
        return planForDate.id == selectedDayPlanID
    }

    private var isInMonth: Bool {
        Calendar.current.isDate(date, equalTo: month, toGranularity: .month)
    }

    private var isCompletedDay: Bool {
        guard let planForDate else { return false }
        let items = planForDate.checklistItems
        guard !items.isEmpty else { return false }
        return items.allSatisfy(\.isCompleted)
    }

    var body: some View {
        Button {
            selectedDayPlanID = planForDate?.id
        } label: {
            VStack(spacing: 4) {
                Text(AppNumberFormatting.integerString(Calendar.current.component(.day, from: date)))
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected || isCompletedDay ? .white : .black)

                if let planForDate {
                    Image(systemName: planForDate.kind == .travel ? "airplane" : "bed.double.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected || isCompletedDay ? .white.opacity(0.95) : .black.opacity(0.58))
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 1.4 : 1)
            )
            .opacity(isInMonth ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(planForDate == nil)
    }

    private var backgroundColor: Color {
        if isSelected {
            if isCompletedDay {
                return Color(red: 0.17, green: 0.55, blue: 0.28)
            }
            return Color.black.opacity(0.84)
        }
        if isCompletedDay {
            return Color(red: 0.22, green: 0.66, blue: 0.34)
        }
        if planForDate != nil {
            return Color.white.opacity(0.88)
        }
        return Color.white.opacity(0.42)
    }

    private var borderColor: Color {
        if isSelected {
            if isCompletedDay {
                return Color(red: 0.13, green: 0.42, blue: 0.21)
            }
            return Color.black.opacity(0.9)
        }
        if isCompletedDay {
            return Color(red: 0.13, green: 0.42, blue: 0.21).opacity(0.75)
        }
        return Color.black.opacity(planForDate != nil ? 0.08 : 0.03)
    }
}

private struct TripPlannerChecklistItemEditorRow: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    @Binding var item: TripPlannerChecklistItem
    let planDate: Date
    let currencyCode: String
    let localCurrencyCodes: [String]
    let saveFeedbackNonce: Int
    let actorId: UUID?
    let actorName: String
    let showsRemove: Bool
    let showsCompletion: Bool
    let showsTitleField: Bool
    let showsCategoryLabel: Bool
    let onRemove: () -> Void

    @State private var linkedExpenseAmountText = ""
    @State private var linkedExpenseCurrencyCode = ""

    private var notePlaceholder: String {
        switch item.category {
        case .accommodation:
            return "Add hotel name, address, confirmation number, or notes"
        case .packing:
            return ""
        default:
            return "Add notes"
        }
    }

    private var titlePlaceholder: String {
        switch item.category {
        case .accommodation:
            return "Accommodation"
        case .attractionTickets:
            return "Book attraction tickets"
        case .transportBooking:
            return "Book transport in advance"
        case .reservation:
            return "Reserve a restaurant or experience"
        case .visa:
            return "Apply for visas"
        case .insurance:
            return "Add insurance details"
        case .packing:
            return "What to pack"
        case .custom:
            return "Add checklist item"
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: {
                let trimmed = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed == titlePlaceholder ? "" : item.title
            },
            set: { newValue in
                item = item.updatedTitle(newValue)
            }
        )
    }

    init(
        item: Binding<TripPlannerChecklistItem>,
        planDate: Date,
        currencyCode: String,
        localCurrencyCodes: [String] = [],
        saveFeedbackNonce: Int,
        actorId: UUID?,
        actorName: String,
        showsRemove: Bool,
        showsCompletion: Bool = true,
        showsTitleField: Bool = true,
        showsCategoryLabel: Bool = true,
        onRemove: @escaping () -> Void
    ) {
        self._item = item
        self.planDate = planDate
        self.currencyCode = currencyCode
        self.localCurrencyCodes = localCurrencyCodes
        self.saveFeedbackNonce = saveFeedbackNonce
        self.actorId = actorId
        self.actorName = actorName
        self.showsRemove = showsRemove
        self.showsCompletion = showsCompletion
        self.showsTitleField = showsTitleField
        self.showsCategoryLabel = showsCategoryLabel
        self.onRemove = onRemove
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if showsCompletion {
                    Button {
                        item = item.updatedCompletion(
                            isCompleted: !item.isCompleted,
                            actorId: actorId,
                            actorName: actorName
                        )
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(item.isCompleted ? Color(red: 0.14, green: 0.50, blue: 0.25) : .black.opacity(0.42))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if showsTitleField {
                        TextField(titlePlaceholder, text: titleBinding)
                        .textInputAutocapitalization(.sentences)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)

                        if let completedByName = item.completedByName,
                           item.isCompleted,
                           showsCompletion {
                            Text("Completed by \(completedByName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.black.opacity(0.55))
                        }
                    }

                    if item.category == .packing {
                        TripPlannerPackingEntriesEditor(item: $item)
                    } else {
                        TextField(notePlaceholder, text: Binding(
                            get: { item.notes },
                            set: { item = item.updatedNotes($0) }
                        ))
                        .textInputAutocapitalization(.sentences)
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.78))

                        if !item.notes.detectedURLs.isEmpty {
                            TripPlannerDetectedLinkList(text: item.notes)
                        }
                    }

                    if item.supportsExpenseTracking {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Add a cost here and it will automatically appear in expenses.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.black.opacity(0.58))

                            HStack(alignment: .top, spacing: 10) {
                                TripPlannerCurrencyInput(
                                    title: "Cost",
                                    currencyCode: linkedExpenseCurrencyCode,
                                    currencySelection: $linkedExpenseCurrencyCode,
                                    suggestedCurrencyCodes: [
                                        currencyPreferenceStore.defaultCurrencyCode
                                    ] + localCurrencyCodes.map(Optional.some),
                                    text: Binding(
                                        get: { linkedExpenseAmountText },
                                        set: { newValue in
                                            linkedExpenseAmountText = newValue
                                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                            let amount = Double(trimmed)
                                            item = item.updatedExpenseLink(
                                                expenseId: item.linkedExpenseId,
                                                amount: amount.map {
                                                    TripPlannerCurrencyDisplay.amountToUSD(
                                                        $0,
                                                        currencyCode: linkedExpenseCurrencyCode,
                                                        snapshot: currencyPreferenceStore.exchangeRateSnapshot
                                                    )
                                                },
                                                currencyCode: linkedExpenseCurrencyCode,
                                                date: amount == nil ? nil : planDate
                                            )
                                        }
                                    ),
                                    placeholder: "0.00"
                                )
                            }

                            if item.hasLinkedExpenseDetails {
                                Label("Automatically synced to expenses", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.75))
                            }
                        }
                    }

                    if showsCategoryLabel {
                        HStack(spacing: 8) {
                            if showsCategoryLabel {
                                Label(item.category.title, systemImage: item.category.symbolName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.6))
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                if showsRemove {
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black.opacity(0.7))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.8)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .onAppear {
            linkedExpenseCurrencyCode = item.linkedExpenseCurrencyCode ?? currencyCode
            linkedExpenseAmountText = item.linkedExpenseAmount.map {
                TripPlannerCurrencyDisplay.editableTextFromUSD(
                    $0,
                    currencyCode: linkedExpenseCurrencyCode,
                    snapshot: currencyPreferenceStore.exchangeRateSnapshot
                )
            } ?? ""
        }
        .onChange(of: item.id) { _, _ in
            linkedExpenseCurrencyCode = item.linkedExpenseCurrencyCode ?? currencyCode
            linkedExpenseAmountText = item.linkedExpenseAmount.map {
                TripPlannerCurrencyDisplay.editableTextFromUSD(
                    $0,
                    currencyCode: linkedExpenseCurrencyCode,
                    snapshot: currencyPreferenceStore.exchangeRateSnapshot
                )
            } ?? ""
        }
        .onChange(of: saveFeedbackNonce) { _, _ in
            linkedExpenseCurrencyCode = item.linkedExpenseCurrencyCode ?? currencyCode
            linkedExpenseAmountText = item.linkedExpenseAmount.map {
                TripPlannerCurrencyDisplay.editableTextFromUSD(
                    $0,
                    currencyCode: linkedExpenseCurrencyCode,
                    snapshot: currencyPreferenceStore.exchangeRateSnapshot
                )
            } ?? ""
        }
        .onChange(of: linkedExpenseCurrencyCode) { _, newCode in
            let normalizedCode = AppCurrencyCatalog.normalizedCode(newCode) ?? currencyCode
            linkedExpenseCurrencyCode = normalizedCode
            item = item.updatedExpenseLink(
                expenseId: item.linkedExpenseId,
                amount: item.linkedExpenseAmount,
                currencyCode: normalizedCode,
                date: item.linkedExpenseDate
            )

            linkedExpenseAmountText = item.linkedExpenseAmount.map {
                TripPlannerCurrencyDisplay.editableTextFromUSD(
                    $0,
                    currencyCode: normalizedCode,
                    snapshot: currencyPreferenceStore.exchangeRateSnapshot
                )
            } ?? ""
        }
    }
}

private struct TripPlannerPackingEntriesEditor: View {
    @Binding var item: TripPlannerChecklistItem
    @State private var entries: [TripPlannerPackingEntry]
    @State private var customPackingItem = ""
    @State private var customPackingNote = ""

    init(item: Binding<TripPlannerChecklistItem>) {
        self._item = item
        self._entries = State(initialValue: TripPlannerPackingCodec.decodeEntries(from: item.wrappedValue.notes))
    }

    private var availablePackingSuggestions: [String] {
        TripPlannerChecklistTemplates.packingSuggestions.filter { suggestion in
            !entries.contains { $0.title.caseInsensitiveCompare(suggestion) == .orderedSame }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !entries.isEmpty {
                VStack(spacing: 8) {
                    ForEach($entries) { $entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.black.opacity(0.42))

                                Text(entry.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.black.opacity(0.78))

                                Spacer(minLength: 0)

                                Button {
                                    removePackingItem(id: entry.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.black.opacity(0.45))
                                }
                                .buttonStyle(.plain)
                            }

                            TextField("Add note (optional)", text: $entry.note)
                                .textInputAutocapitalization(.sentences)
                                .font(.system(size: 12))
                                .foregroundStyle(.black.opacity(0.68))
                                .padding(.leading, 14)
                        }
                    }
                }
            }

            if !availablePackingSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availablePackingSuggestions, id: \.self) { suggestion in
                            Button {
                                appendPackingItem(suggestion)
                            } label: {
                                Text("+ \(suggestion)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.86))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                VStack(spacing: 8) {
                    TextField("Add custom item", text: $customPackingItem)
                        .textInputAutocapitalization(.sentences)
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.78))

                    TextField("Add note (optional)", text: $customPackingNote)
                        .textInputAutocapitalization(.sentences)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.68))
                }

                Button {
                    let trimmed = customPackingItem.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    appendPackingItem(trimmed, note: customPackingNote)
                    customPackingItem = ""
                    customPackingNote = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: entries) { _, newEntries in
            let encoded = TripPlannerPackingCodec.encodeEntries(newEntries)
            if item.notes != encoded {
                item = item.updatedNotes(encoded)
            }
        }
        .onChange(of: item.notes) { _, newValue in
            let encodedEntries = TripPlannerPackingCodec.encodeEntries(entries)
            guard newValue != encodedEntries else { return }
            entries = TripPlannerPackingCodec.decodeEntries(from: newValue)
        }
    }

    private func appendPackingItem(_ value: String, note: String = "") {
        entries.append(
            TripPlannerPackingEntry(
                id: UUID(),
                title: value,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    private func removePackingItem(id: UUID) {
        entries.removeAll { $0.id == id }
    }
}

private struct TripPlannerExpenseParticipant: Identifiable, Hashable {
    let id: String
    let name: String
    let username: String?
    let avatarURL: String?

    var firstName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return username ?? "" }
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    nonisolated init(friend: TripPlannerFriendSnapshot) {
        self.id = friend.id.uuidString
        self.name = friend.displayName
        self.username = friend.username
        self.avatarURL = friend.avatarURL
    }
}

private struct TripPlannerExpenseShareDraftState: Equatable {
    var isPaid: Bool
    var paymentMethod: TripPlannerExpensePaymentMethod?
}

private struct TripPlannerExpenseBalance: Identifiable {
    let participantId: String
    let participantName: String
    let amount: Double

    var id: String { participantId }
    var isOwed: Bool { amount > 0.009 }
    var owes: Bool { amount < -0.009 }
}

private struct TripPlannerExpensesPreviewSection: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let expenses: [TripPlannerExpense]
    let currencyCode: String

    private var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.totalAmount }
    }

    private var outstandingTotal: Double {
        expenses.flatMap(\.shares).filter { !$0.isPaid }.reduce(0) { $0 + $1.amountOwed }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TripPlannerStatPill(
                title: String(localized: "trip_planner.expenses.stats.total_logged"),
                detail: "\(expenses.count) expenses"
            ) {
                amountValue(totalSpent)
            }

            TripPlannerStatPill(
                title: String(localized: "trip_planner.expenses.stats.still_owed"),
                detail: outstandingTotal > 0 ? "Tap to view balances" : "Tap to manage expenses"
            ) {
                amountValue(outstandingTotal)
            }
        }
    }

    @ViewBuilder
    private func amountValue(_ amount: Double) -> some View {
        AppCurrencyAmountLabel(
            amount: TripPlannerCurrencyDisplay.amountFromUSD(
                amount,
                currencyCode: currencyCode,
                snapshot: currencyPreferenceStore.exchangeRateSnapshot
            ),
            currencyCode: currencyCode,
            font: .system(size: 21, weight: .bold),
            fontSize: 21,
            color: .black
        )
    }
}

private struct TripPlannerExpensesSection: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let expenses: [TripPlannerExpense]
    let participants: [TripPlannerFriendSnapshot]
    let currencyCode: String

    private var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.totalAmount }
    }

    private var outstandingTotal: Double {
        expenses.flatMap(\.shares).filter { !$0.isPaid }.reduce(0) { $0 + $1.amountOwed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TripPlannerStatPill(
                    title: String(localized: "trip_planner.expenses.stats.total_logged"),
                    detail: String(
                        format: String(localized: "trip_planner.expenses.stats.expense_count"),
                        locale: AppDisplayLocale.current,
                        expenses.count
                    )
                ) {
                    amountValue(totalSpent)
                }

                TripPlannerStatPill(
                    title: String(localized: "trip_planner.expenses.stats.still_owed"),
                    detail: outstandingTotal > 0 ? String(localized: "trip_planner.expenses.stats.unpaid_balances") : String(localized: "trip_planner.expenses.stats.everyone_settled")
                ) {
                    amountValue(outstandingTotal)
                }
            }

            if expenses.isEmpty {
                TripPlannerInfoCard(
                    text: String(localized: "trip_planner.expenses.stats.empty"),
                    systemImage: "creditcard"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(expenses.prefix(3)) { expense in
                        TripPlannerExpenseRow(
                            expense: expense,
                            participants: participants.map(TripPlannerExpenseParticipant.init(friend:)),
                            currencyCode: currencyCode,
                            onEdit: nil
                        )
                    }

                    if expenses.count > 3 {
                        TripPlannerInfoCard(
                            text: String(
                                format: String(localized: "trip_planner.expenses.stats.more_expenses"),
                                locale: AppDisplayLocale.current,
                                expenses.count - 3
                            ),
                            systemImage: "ellipsis.circle.fill"
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func amountValue(_ amount: Double) -> some View {
        AppCurrencyAmountLabel(
            amount: TripPlannerCurrencyDisplay.amountFromUSD(
                amount,
                currencyCode: currencyCode,
                snapshot: currencyPreferenceStore.exchangeRateSnapshot
            ),
            currencyCode: currencyCode,
            font: .system(size: 21, weight: .bold),
            fontSize: 21,
            color: .black
        )
    }
}

private struct TripPlannerExpensesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let trip: TripPlannerTrip
    let participants: [TripPlannerFriendSnapshot]
    let currencyCode: String
    let onSave: (TripPlannerTrip) -> Void

    @State private var expenses: [TripPlannerExpense]
    @State private var composerPresentation: TripPlannerExpenseComposerPresentation?

    init(
        trip: TripPlannerTrip,
        participants: [TripPlannerFriendSnapshot],
        currencyCode: String,
        onSave: @escaping (TripPlannerTrip) -> Void
    ) {
        self.trip = trip
        self.participants = participants
        self.currencyCode = currencyCode
        self.onSave = onSave
        _expenses = State(initialValue: Self.sortedExpenses(trip.expenses))
    }

    private var expenseParticipants: [TripPlannerExpenseParticipant] {
        participants.map(TripPlannerExpenseParticipant.init(friend:))
    }

    private var countryCurrencyCodesByID: [String: String] {
        var currencyCodes: [String: String] = [:]
        for country in TripPlannerCountryLookup.countries(for: trip.countryIds) {
            if let currencyCode = TripPlannerCountryCurrencyLookup.currencyCode(for: country) {
                currencyCodes[country.id.uppercased()] = currencyCode
            }
        }
        for countryId in trip.countryIds {
            let normalizedID = countryId.uppercased()
            if currencyCodes[normalizedID] == nil,
               let currencyCode = TripPlannerCountryCurrencyLookup.currencyCode(forCountryID: normalizedID) {
                currencyCodes[normalizedID] = currencyCode
            }
        }
        return currencyCodes
    }

    private var tripLocalCurrencyCodes: [String] {
        uniqueCurrencyCodes(trip.countryIds.compactMap { countryCurrencyCodesByID[$0.uppercased()] })
    }

    private var balances: [TripPlannerExpenseBalance] {
        var totals = Dictionary(uniqueKeysWithValues: expenseParticipants.map { ($0.id, 0.0) })

        for expense in expenses {
            for share in expense.shares where !share.isPaid {
                totals[expense.paidById, default: 0] += share.amountOwed
                totals[share.participantId, default: 0] -= share.amountOwed
            }
        }

        return expenseParticipants.map { participant in
            TripPlannerExpenseBalance(
                participantId: participant.id,
                participantName: participant.name,
                amount: totals[participant.id, default: 0]
            )
        }
        .sorted {
            abs($0.amount) > abs($1.amount)
        }
    }

    private var categoryBreakdown: [TripPlannerExpenseCategoryBreakdown] {
        let total = expenses.reduce(0) { $0 + $1.totalAmount }
        guard total > 0.009 else { return [] }

        var groupedAmounts: [String: (amount: Double, tintColor: Color)] = [:]
        for expense in expenses {
            let key = expense.categoryDisplayTitle
            groupedAmounts[key, default: (0, expense.categoryTintColor)].amount += expense.totalAmount
        }

        return groupedAmounts.compactMap { title, info in
            guard info.amount > 0.009 else { return nil }
            return TripPlannerExpenseCategoryBreakdown(
                title: title,
                tintColor: info.tintColor,
                amount: info.amount,
                percentage: info.amount / total
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(String(localized: "trip_planner.expenses.title"))

                ScrollView {
                    VStack(spacing: 18) {
                        if let rateDescription = currencyPreferenceStore.exchangeRateDescription(
                            to: currencyCode
                        ), currencyCode != "USD" {
                            TripPlannerInfoCard(
                                text: rateDescription,
                                systemImage: "chart.line.uptrend.xyaxis"
                            )
                        }

                        if !categoryBreakdown.isEmpty {
                            TripPlannerSectionCard(
                                title: "Spending breakdown",
                                subtitle: ""
                            ) {
                                TripPlannerExpenseCategoryBreakdownView(
                                    breakdown: categoryBreakdown,
                                    totalSpent: expenses.reduce(0) { $0 + $1.totalAmount },
                                    currencyCode: currencyCode
                                )
                            }
                        }

                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.expenses.outstanding_balances"),
                            subtitle: ""
                        ) {
                            if balances.isEmpty {
                                TripPlannerInfoCard(
                                    text: String(localized: "trip_planner.expenses.add_people_first"),
                                    systemImage: "person.2"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(balances) { balance in
                                        TripPlannerExpenseBalanceCard(
                                            balance: balance,
                                            currencyCode: currencyCode
                                        )
                                    }
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: String(localized: "trip_planner.expenses.logged_expenses"),
                            subtitle: ""
                        ) {
                            if expenses.isEmpty {
                                TripPlannerInfoCard(
                                    text: String(localized: "trip_planner.expenses.none_yet"),
                                    systemImage: "creditcard"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(expenses) { expense in
                                        TripPlannerExpenseRow(
                                            expense: expense,
                                            participants: expenseParticipants,
                                            currencyCode: currencyCode,
                                            onEdit: {
                                                composerPresentation = TripPlannerExpenseComposerPresentation(expense: expense)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }

            if let composerPresentation {
                TripPlannerExpenseComposerOverlay(
                    participants: expenseParticipants,
                    currencyCode: currencyCode,
                    suggestedCurrencyCodes: suggestedCurrencyCodes(for:),
                    existingExpense: composerPresentation.expense,
                    onClose: {
                        self.composerPresentation = nil
                    },
                    onDeleteExpense: composerPresentation.expense == nil ? nil : {
                        if let expense = composerPresentation.expense {
                            expenses.removeAll { $0.id == expense.id }
                            persistExpenses()
                        }
                        self.composerPresentation = nil
                    },
                    onSaveExpense: { expense in
                        if expenses.contains(where: { $0.id == expense.id }) {
                            updateExpense(expense)
                        } else {
                            expenses.insert(expense, at: 0)
                            persistExpenses()
                        }
                        self.composerPresentation = nil
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: composerPresentation != nil)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(composerPresentation != nil)
        .onAppear {
            logCurrencyContext("appear")
        }
        .tripPlannerNavigationChrome(showsBackButton: composerPresentation == nil) {
            if composerPresentation == nil {
                Button {
                    composerPresentation = TripPlannerExpenseComposerPresentation(expense: nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))

                        Text("+")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func updateExpense(_ expense: TripPlannerExpense) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[index] = expense
        expenses = Self.sortedExpenses(expenses)
        persistExpenses()
    }

    private func suggestedCurrencyCodes(for date: Date) -> [String] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard let dayIndex = trip.dayPlans.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) else {
            TripPlannerDebugLog.probe(
                "TripPlannerExpensesEditor.suggested_currency_codes",
                "trip=\(TripPlannerDebugLog.tripLabel(trip)) date=\(AppDateFormatting.dateString(from: date, dateStyle: .short)) matchedPlan=false result=\(tripLocalCurrencyCodes.joined(separator: ","))"
            )
            return tripLocalCurrencyCodes
        }

        let plan = trip.dayPlans[dayIndex]
        let result: [String]
        if plan.kind == .travel {
            var codes: [String] = []

            if dayIndex > 0,
               let previousCode = countryCurrencyCode(for: trip.dayPlans[dayIndex - 1]) {
                codes.append(previousCode)
            }

            if dayIndex < trip.dayPlans.count - 1,
               let nextCode = countryCurrencyCode(for: trip.dayPlans[dayIndex + 1]) {
                codes.append(nextCode)
            }

            result = uniqueCurrencyCodes(codes.isEmpty ? tripLocalCurrencyCodes : codes)
        } else if let currencyCode = countryCurrencyCode(for: plan) {
            result = [currencyCode]
        } else {
            result = tripLocalCurrencyCodes
        }

        TripPlannerDebugLog.probe(
            "TripPlannerExpensesEditor.suggested_currency_codes",
            "trip=\(TripPlannerDebugLog.tripLabel(trip)) date=\(AppDateFormatting.dateString(from: date, dateStyle: .short)) matchedPlan=true kind=\(plan.kind.rawValue) country=\(plan.countryId ?? "nil") result=\(result.joined(separator: ","))"
        )
        return result
    }

    private func countryCurrencyCode(for plan: TripPlannerDayPlan?) -> String? {
        guard let countryId = plan?.countryId?.uppercased() else { return nil }
        return countryCurrencyCodesByID[countryId]
    }

    private func uniqueCurrencyCodes(_ codes: [String]) -> [String] {
        var seen = Set<String>()
        return codes.compactMap { rawCode in
            guard let code = AppCurrencyCatalog.normalizedCode(rawCode),
                  seen.insert(code).inserted
            else {
                return nil
            }
            return code
        }
    }

    private func logCurrencyContext(_ context: String) {
        let mapping = countryCurrencyCodesByID
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        TripPlannerDebugLog.probe(
            "TripPlannerExpensesEditor.currency_context",
            "context=\(context) trip=\(TripPlannerDebugLog.tripLabel(trip)) ids=\(trip.countryIds.joined(separator: ",")) map=\(mapping) locals=\(tripLocalCurrencyCodes.joined(separator: ","))"
        )
    }

    private func persistExpenses() {
        let sortedExpenses = Self.sortedExpenses(expenses)
        expenses = sortedExpenses
        let tripWithChecklistUpdates = trip.applyingExpenseEditsToLinkedChecklistItems(sortedExpenses)
        onSave(
            TripPlannerTrip(
                id: tripWithChecklistUpdates.id,
                createdAt: tripWithChecklistUpdates.createdAt,
                title: tripWithChecklistUpdates.title,
                notes: tripWithChecklistUpdates.notes,
                startDate: tripWithChecklistUpdates.startDate,
                endDate: tripWithChecklistUpdates.endDate,
                countryIds: tripWithChecklistUpdates.countryIds,
                countryNames: tripWithChecklistUpdates.countryNames,
                friendIds: tripWithChecklistUpdates.friendIds,
                friendNames: tripWithChecklistUpdates.friendNames,
                friends: tripWithChecklistUpdates.friends,
                ownerId: tripWithChecklistUpdates.ownerId,
                ownerSnapshot: tripWithChecklistUpdates.effectiveOwnerSnapshot,
                plannerCurrencyCode: tripWithChecklistUpdates.plannerCurrencyCode,
                availability: tripWithChecklistUpdates.availability,
                dayPlans: tripWithChecklistUpdates.dayPlans,
                overallChecklistItems: tripWithChecklistUpdates.overallChecklistItems,
                packingProgressEntries: tripWithChecklistUpdates.packingProgressEntries,
                expenses: sortedExpenses
            )
        )
    }

    static func sortedExpenses(_ expenses: [TripPlannerExpense]) -> [TripPlannerExpense] {
        expenses.sorted { lhs, rhs in
            if lhs.isSettled != rhs.isSettled {
                return !lhs.isSettled && rhs.isSettled
            }
            return lhs.date > rhs.date
        }
    }
}

private struct TripPlannerExpenseComposerPresentation: Identifiable {
    let id = UUID()
    let expense: TripPlannerExpense?
}

private struct TripPlannerExpenseBalanceCard: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let balance: TripPlannerExpenseBalance
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(balance.participantName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)

                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(balanceColor.opacity(0.9))
            }

            Spacer()

            AppCurrencyAmountLabel(
                amount: TripPlannerCurrencyDisplay.amountFromUSD(
                    abs(balance.amount),
                    currencyCode: currencyCode,
                    snapshot: currencyPreferenceStore.exchangeRateSnapshot
                ),
                currencyCode: currencyCode,
                font: .system(size: 24, weight: .bold),
                fontSize: 24,
                color: balanceColor
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(balanceBackground)
        )
    }

    private var statusText: String {
        if balance.isOwed { return String(localized: "trip_planner.expenses.should_receive") }
        if balance.owes { return String(localized: "trip_planner.expenses.still_owes") }
        return String(localized: "trip_planner.expenses.settled_up")
    }

    private var balanceColor: Color {
        if balance.isOwed { return Color(red: 0.12, green: 0.50, blue: 0.25) }
        if balance.owes { return Color(red: 0.72, green: 0.18, blue: 0.18) }
        return .black.opacity(0.68)
    }

    private var balanceBackground: Color {
        if balance.isOwed { return Color(red: 0.90, green: 0.97, blue: 0.90) }
        if balance.owes { return Color(red: 0.99, green: 0.91, blue: 0.91) }
        return Color.white.opacity(0.74)
    }
}

private struct TripPlannerExpenseComposerOverlay: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let participants: [TripPlannerExpenseParticipant]
    let currencyCode: String
    let suggestedCurrencyCodes: (Date) -> [String]
    let existingExpense: TripPlannerExpense?
    let onClose: () -> Void
    let onDeleteExpense: (() -> Void)?
    let onSaveExpense: (TripPlannerExpense) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var entryCurrencyCode: String
    @State private var category: TripPlannerExpenseCategory = .other
    @State private var customCategoryName = ""
    @State private var selectedPayerId: String = ""
    @State private var splitMode: TripPlannerExpenseSplitMode = .everyone
    @State private var expenseDate = Date()
    @State private var selectedParticipantIds: Set<String> = []
    @State private var shareStates: [String: TripPlannerExpenseShareDraftState] = [:]
    @State private var isShowingCustomCategoryPrompt = false
    @State private var isShowingTitlePrompt = false
    @State private var isShowingDeleteConfirmation = false

    init(
        participants: [TripPlannerExpenseParticipant],
        currencyCode: String,
        suggestedCurrencyCodes: @escaping (Date) -> [String] = { _ in [] },
        existingExpense: TripPlannerExpense? = nil,
        onClose: @escaping () -> Void,
        onDeleteExpense: (() -> Void)? = nil,
        onSaveExpense: @escaping (TripPlannerExpense) -> Void
    ) {
        self.participants = participants
        self.currencyCode = currencyCode
        self.suggestedCurrencyCodes = suggestedCurrencyCodes
        self.existingExpense = existingExpense
        self.onClose = onClose
        self.onDeleteExpense = onDeleteExpense
        self.onSaveExpense = onSaveExpense
        _title = State(initialValue: existingExpense?.title ?? "")
        _entryCurrencyCode = State(initialValue: existingExpense?.entryCurrencyCode ?? currencyCode)
        if let existingExpense {
            _amountText = State(
                initialValue: existingExpense.totalAmount == 0
                    ? ""
                    : TripPlannerCurrencyDisplay.editableTextFromUSD(
                        existingExpense.totalAmount,
                        currencyCode: existingExpense.entryCurrencyCode ?? currencyCode,
                        snapshot: CurrencyPreferenceStore.persistedExchangeRateSnapshot()
                    )
            )
            _category = State(initialValue: existingExpense.category)
            _customCategoryName = State(initialValue: existingExpense.customCategoryName ?? "")
            _selectedPayerId = State(initialValue: existingExpense.paidById)
            _splitMode = State(initialValue: existingExpense.splitMode)
            _expenseDate = State(initialValue: existingExpense.date)
            _selectedParticipantIds = State(initialValue: Set(existingExpense.participantIds))
            _shareStates = State(
                initialValue: Dictionary(
                    uniqueKeysWithValues: existingExpense.shares.map {
                        (
                            $0.participantId,
                            TripPlannerExpenseShareDraftState(isPaid: $0.isPaid, paymentMethod: $0.paymentMethod)
                        )
                    }
                )
            )
        } else {
            _amountText = State(initialValue: "")
            _category = State(initialValue: .other)
            _customCategoryName = State(initialValue: "")
            _selectedPayerId = State(initialValue: "")
            _splitMode = State(initialValue: TripPlannerExpenseCategory.other.suggestedSplitMode)
            _expenseDate = State(initialValue: Date())
            _selectedParticipantIds = State(initialValue: [])
            _shareStates = State(initialValue: [:])
        }
    }

    private var canSaveExpense: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedAmount != nil
            && !selectedBeneficiaryIds.isEmpty
            && !selectedPayerId.isEmpty
    }

    private var parsedAmount: Double? {
        Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var selectedBeneficiaryIds: [String] {
        switch splitMode {
        case .everyone:
            return participants.map(\.id)
        case .selectedPeople:
            return Array(selectedParticipantIds)
        }
    }

    private var selectedPayer: TripPlannerExpenseParticipant? {
        participants.first(where: { $0.id == selectedPayerId })
    }

    private var selectedBeneficiaries: [TripPlannerExpenseParticipant] {
        participants.filter { selectedBeneficiaryIds.contains($0.id) }
    }

    private var payerMenuLabel: some View {
        Group {
            if let selectedPayer {
                TripPlannerExpenseInlineParticipantBadge(participant: selectedPayer)
            } else {
                Text(String(localized: "trip_planner.expenses.paid_by"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
    }

    private var draftShares: [TripPlannerExpenseShare] {
        let amount = parsedAmount ?? 0
        let equalShare = selectedBeneficiaries.isEmpty ? 0 : amount / Double(selectedBeneficiaries.count)

        return selectedBeneficiaries.compactMap { participant in
            guard participant.id != selectedPayerId else { return nil }
            let state = shareStates[participant.id] ?? TripPlannerExpenseShareDraftState(isPaid: false, paymentMethod: nil)
            return TripPlannerExpenseShare(
                participantId: participant.id,
                participantName: participant.name,
                participantUsername: participant.username,
                amountOwed: equalShare,
                isPaid: state.isPaid,
                paymentMethod: state.paymentMethod
            )
        }
    }

    private var selectedCategoryLabel: String {
        let trimmedCustom = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if category == .other, !trimmedCustom.isEmpty {
            return trimmedCustom
        }
        return category.title
    }

    private var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Expense title" : trimmed
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black.opacity(0.82))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.82)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(existingExpense == nil ? String(localized: "common.add") : String(localized: "common.save")) {
                        saveExpense()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .opacity(canSaveExpense ? 1 : 0.45)
                    .disabled(!canSaveExpense)
                }
                .padding(.bottom, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                isShowingTitlePrompt = true
                            } label: {
                                HStack(spacing: 8) {
                                    Text(displayTitle)
                                        .font(.system(size: 24, weight: .black, design: .rounded))
                                        .foregroundStyle(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .black.opacity(0.42) : .black)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.55))
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer(minLength: 0)

                            DatePicker(
                                "",
                                selection: $expenseDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.84))
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            TripPlannerCurrencyInput(
                                title: "Amount",
                                currencyCode: entryCurrencyCode,
                                currencySelection: $entryCurrencyCode,
                                suggestedCurrencyCodes: [
                                    currencyPreferenceStore.defaultCurrencyCode
                                ] + suggestedCurrencyCodes(expenseDate).map(Optional.some),
                                text: $amountText,
                                placeholder: "0.00"
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Category")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.72))

                                Menu {
                                    ForEach(TripPlannerExpenseCategory.allCases) { category in
                                        Button(category.title) {
                                            self.category = category
                                            self.customCategoryName = ""
                                        }
                                    }

                                    Button("Custom...") {
                                        isShowingCustomCategoryPrompt = true
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(selectedCategoryLabel)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.black)

                                        Spacer(minLength: 0)

                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.48))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.84))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(alignment: .center, spacing: 12) {
                            Text("trip_planner.expenses.paid_by")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.72))

                            Menu {
                                ForEach(participants) { participant in
                                    Button(participant.name) {
                                        selectedPayerId = participant.id
                                    }
                                }
                            } label: {
                                payerMenuLabel
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Picker(String(localized: "trip_planner.expenses.split"), selection: $splitMode) {
                                ForEach(TripPlannerExpenseSplitMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            if splitMode == .selectedPeople {
                                TripPlannerExpenseParticipantGrid(
                                    participants: participants,
                                    selectedIDs: selectedParticipantIds,
                                    onToggle: { id in
                                        if selectedParticipantIds.contains(id) {
                                            selectedParticipantIds.remove(id)
                                        } else {
                                            selectedParticipantIds.insert(id)
                                        }
                                    }
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Who shared this expense")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.72))

                            if draftShares.isEmpty {
                                Text("trip_planner.expenses.no_one_owes")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.58))
                                    .padding(.horizontal, 2)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(draftShares) { share in
                                        TripPlannerExpenseShareEditorRow(
                                            share: share,
                                            currencyCode: currencyCode,
                                            participant: participants.first(where: { $0.id == share.participantId }),
                                            onUpdate: { isPaid in
                                                shareStates[share.participantId] = TripPlannerExpenseShareDraftState(
                                                    isPaid: isPaid,
                                                    paymentMethod: isPaid ? .manual : nil
                                                )
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        if onDeleteExpense != nil {
                            Button(role: .destructive) {
                                isShowingDeleteConfirmation = true
                            } label: {
                                Text("trip_planner.expenses.delete_expense")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.18))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.84))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color(red: 0.72, green: 0.18, blue: 0.18).opacity(0.18), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(22)
            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 620))
            .frame(maxHeight: min(UIScreen.main.bounds.height - 64, 760))
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.95, blue: 0.88).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(.horizontal, 16)
            .padding(.vertical, 32)

            if isShowingCustomCategoryPrompt {
                TripPlannerCustomExpenseCategoryPrompt(
                    initialValue: customCategoryName,
                    onCancel: {
                        isShowingCustomCategoryPrompt = false
                    },
                    onSave: { name in
                        customCategoryName = name
                        category = .other
                        isShowingCustomCategoryPrompt = false
                    }
                )
                .zIndex(2)
            }

            if isShowingTitlePrompt {
                TripPlannerExpenseTitlePrompt(
                    initialValue: title,
                    onCancel: {
                        isShowingTitlePrompt = false
                    },
                    onSave: { newTitle in
                        title = newTitle
                        isShowingTitlePrompt = false
                    }
                )
                .zIndex(3)
            }

            if isShowingDeleteConfirmation {
                TripPlannerExpenseDeleteConfirmationPrompt(
                    onCancel: {
                        isShowingDeleteConfirmation = false
                    },
                    onDelete: {
                        isShowingDeleteConfirmation = false
                        onDeleteExpense?()
                    }
                )
                .zIndex(3)
            }
        }
        .onAppear {
            entryCurrencyCode = AppCurrencyCatalog.normalizedCode(entryCurrencyCode) ?? currencyCode
            if selectedPayerId.isEmpty {
                selectedPayerId = participants.first?.id ?? ""
            }
            if selectedParticipantIds.isEmpty {
                if category.suggestedSplitMode == .selectedPeople, let firstParticipant = participants.first {
                    selectedParticipantIds = [firstParticipant.id]
                } else {
                    selectedParticipantIds = Set(participants.map(\.id))
                }
            }
            normalizeShareStates()
        }
        .onChange(of: category) { _, newCategory in
            splitMode = newCategory.suggestedSplitMode
            if newCategory.suggestedSplitMode == .everyone {
                selectedParticipantIds = Set(participants.map(\.id))
            } else if selectedParticipantIds.isEmpty, let payer = participants.first(where: { $0.id == selectedPayerId }) ?? participants.first {
                selectedParticipantIds = [payer.id]
            }
            normalizeShareStates()
        }
        .onChange(of: selectedPayerId) { _, newPayerId in
            if splitMode == .selectedPeople, selectedParticipantIds.isEmpty, !newPayerId.isEmpty {
                selectedParticipantIds = [newPayerId]
            }
            normalizeShareStates()
        }
        .onChange(of: splitMode) { _, _ in
            normalizeShareStates()
        }
        .onChange(of: selectedParticipantIds) { _, _ in
            normalizeShareStates()
        }
        .onChange(of: amountText) { _, _ in
            normalizeShareStates()
        }
        .onChange(of: entryCurrencyCode) { _, newCode in
            let normalizedCode = AppCurrencyCatalog.normalizedCode(newCode) ?? currencyCode
            entryCurrencyCode = normalizedCode

            if let existingExpense {
                amountText = existingExpense.totalAmount == 0
                    ? ""
                    : TripPlannerCurrencyDisplay.editableTextFromUSD(
                        existingExpense.totalAmount,
                        currencyCode: normalizedCode,
                        snapshot: currencyPreferenceStore.exchangeRateSnapshot
                    )
            }
        }
    }

    private func saveExpense() {
        guard
            let amount = parsedAmount,
            let payer = participants.first(where: { $0.id == selectedPayerId })
        else {
            return
        }

        let beneficiaries = selectedBeneficiaries
        let amountInUSD = TripPlannerCurrencyDisplay.amountToUSD(
            amount,
            currencyCode: entryCurrencyCode,
            snapshot: currencyPreferenceStore.exchangeRateSnapshot
        )
        let convertedShares = draftShares.map { share in
            TripPlannerExpenseShare(
                id: share.id,
                participantId: share.participantId,
                participantName: share.participantName,
                participantUsername: share.participantUsername,
                amountOwed: TripPlannerCurrencyDisplay.amountToUSD(
                    share.amountOwed,
                    currencyCode: entryCurrencyCode,
                    snapshot: currencyPreferenceStore.exchangeRateSnapshot
                ),
                isPaid: share.isPaid,
                paymentMethod: share.paymentMethod
            )
        }

        onSaveExpense(
            TripPlannerExpense(
                id: existingExpense?.id ?? UUID(),
                linkedChecklistItemId: existingExpense?.linkedChecklistItemId,
                category: category,
                customCategoryName: customCategoryName,
                entryCurrencyCode: entryCurrencyCode,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                totalAmount: amountInUSD,
                paidById: payer.id,
                paidByName: payer.name,
                paidByUsername: payer.username,
                splitMode: splitMode,
                date: expenseDate,
                participantIds: beneficiaries.map(\.id),
                participantNames: beneficiaries.map(\.name),
                shares: convertedShares
            )
        )
    }

    private func normalizeShareStates() {
        let validIDs = Set(draftShares.map(\.participantId))
        shareStates = shareStates.filter { validIDs.contains($0.key) }
        for share in draftShares where shareStates[share.participantId] == nil {
            shareStates[share.participantId] = TripPlannerExpenseShareDraftState(
                isPaid: share.isPaid,
                paymentMethod: share.paymentMethod
            )
        }
    }
}

private struct TripPlannerExpenseRow: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let expense: TripPlannerExpense
    let participants: [TripPlannerExpenseParticipant]
    let currencyCode: String
    let onEdit: (() -> Void)?

    var body: some View {
        Group {
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    rowContent(showsChevron: true)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(showsChevron: false)
            }
        }
    }

    @ViewBuilder
    private func rowContent(showsChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(expense.categoryDisplayTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(expense.categoryTintColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(expense.categoryBackgroundTint))

                        AppCurrencyAmountLabel(
                            amount: TripPlannerCurrencyDisplay.amountFromUSD(
                                expense.totalAmount,
                                currencyCode: currencyCode,
                                snapshot: currencyPreferenceStore.exchangeRateSnapshot
                            ),
                            currencyCode: currencyCode,
                            font: .system(size: 14, weight: .black),
                            fontSize: 14,
                            color: .black
                        )
                    }

                    Text(expense.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    Text(AppDateFormatting.dateString(from: expense.date, dateStyle: .medium))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.58))

                    HStack(spacing: 8) {
                        if let payer = participants.first(where: { $0.id == expense.paidById }) {
                            TripPlannerAvatarView(
                                name: payer.name,
                                username: payer.username ?? "",
                                avatarURL: payer.avatarURL,
                                size: 22
                            )

                            Text("Paid by \(payer.firstName)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.74))
                        } else {
                            Text("Paid by \(expense.paidByName)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.74))
                        }
                    }
                }

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.38))
                        .padding(.top, 4)
                }
            }

            if expense.isSettled {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.25))

                    Text(String(localized: "trip_planner.expenses.settled_up"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.50, blue: 0.25))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(red: 0.90, green: 0.97, blue: 0.90))
                )
            } else if expense.shares.isEmpty {
                Text("trip_planner.expenses.no_one_owes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.56))
            } else {
                HStack(spacing: 8) {
                    Text("\(unpaidShares.count) open")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.18))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.88)))

                    Text(unpaidSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.66))
                        .lineLimit(1)
                }
            }

            if expense.linkedChecklistItemId != nil {
                Label("Linked to planning checklist", systemImage: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black.opacity(0.62))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(expense.isSettled ? Color(red: 0.95, green: 0.99, blue: 0.95) : Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(expense.isSettled ? Color(red: 0.12, green: 0.50, blue: 0.25).opacity(0.16) : Color.clear, lineWidth: 1)
        )
    }

    private var unpaidShares: [TripPlannerExpenseShare] {
        expense.shares.filter { !$0.isPaid }
    }

    private var unpaidSummary: String {
        let names = unpaidShares.prefix(2).map { share in
            share.participantName.split(separator: " ").first.map(String.init) ?? share.participantName
        }
        if unpaidShares.isEmpty {
            return String(localized: "trip_planner.expenses.settled_up")
        }
        if unpaidShares.count > 2 {
            return "\(names.joined(separator: ", ")) +\(unpaidShares.count - 2) more"
        }
        return names.joined(separator: ", ")
    }

}

private struct TripPlannerExpenseInlineParticipantBadge: View {
    let participant: TripPlannerExpenseParticipant

    var body: some View {
        HStack(spacing: 8) {
            TripPlannerAvatarView(
                name: participant.name,
                username: participant.username ?? "",
                avatarURL: participant.avatarURL,
                size: 28
            )

            Text(participant.firstName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black.opacity(0.48))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.84))
        )
    }
}

private struct TripPlannerExpenseCategoryBreakdown: Identifiable {
    let title: String
    let tintColor: Color
    let amount: Double
    let percentage: Double

    var id: String { title }
}

private struct TripPlannerExpenseCategoryBreakdownView: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let breakdown: [TripPlannerExpenseCategoryBreakdown]
    let totalSpent: Double
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Array(breakdown.enumerated()), id: \.element.id) { index, item in
                        item.tintColor
                            .frame(
                                width: segmentWidth(
                                    for: item,
                                    totalWidth: geometry.size.width,
                                    index: index,
                                    count: breakdown.count
                                )
                            )
                    }
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            VStack(spacing: 10) {
                ForEach(breakdown) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(item.tintColor)
                            .frame(width: 8, height: 8)

                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)

                        Spacer()

                        Text(percentText(item.percentage))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(item.tintColor)

                        AppCurrencyAmountLabel(
                            amount: TripPlannerCurrencyDisplay.amountFromUSD(
                                item.amount,
                                currencyCode: currencyCode,
                                snapshot: currencyPreferenceStore.exchangeRateSnapshot
                            ),
                            currencyCode: currencyCode,
                            font: .system(size: 12, weight: .semibold),
                            fontSize: 12,
                            color: .black.opacity(0.58)
                        )
                    }
                }
            }

            HStack(spacing: 4) {
                Text("Total tracked:")
                AppCurrencyAmountLabel(
                    amount: TripPlannerCurrencyDisplay.amountFromUSD(
                        totalSpent,
                        currencyCode: currencyCode,
                        snapshot: currencyPreferenceStore.exchangeRateSnapshot
                    ),
                    currencyCode: currencyCode,
                    font: .system(size: 12, weight: .semibold),
                    fontSize: 12,
                    color: .black.opacity(0.56)
                )
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.black.opacity(0.56))
        }
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func segmentWidth(
        for item: TripPlannerExpenseCategoryBreakdown,
        totalWidth: CGFloat,
        index: Int,
        count: Int
    ) -> CGFloat {
        if index == count - 1 {
            let used = breakdown.prefix(index).reduce(CGFloat.zero) { partial, item in
                partial + max(6, totalWidth * item.percentage)
            }
            return max(6, totalWidth - used)
        }
        return max(6, totalWidth * item.percentage)
    }

}

private struct TripPlannerCustomExpenseCategoryPrompt: View {
    let initialValue: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var name: String

    init(
        initialValue: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.initialValue = initialValue
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: initialValue)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(alignment: .leading, spacing: 14) {
                Text("Custom category")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                TextField("Type a category name", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.9))
                    )

                HStack(spacing: 10) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.65))

                    Spacer()

                    Button("Save") {
                        onSave(trimmedName)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .opacity(trimmedName.isEmpty ? 0.4 : 1)
                    .disabled(trimmedName.isEmpty)
                }
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.95, blue: 0.88).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

private struct TripPlannerExpenseTitlePrompt: View {
    let initialValue: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var title: String

    init(
        initialValue: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.initialValue = initialValue
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: initialValue)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(alignment: .leading, spacing: 14) {
                Text("Expense title")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                TextField("Name this expense", text: $title)
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.9))
                    )

                HStack(spacing: 10) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.65))

                    Spacer()

                    Button("Save") {
                        onSave(trimmedTitle)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .opacity(trimmedTitle.isEmpty ? 0.4 : 1)
                    .disabled(trimmedTitle.isEmpty)
                }
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.95, blue: 0.88).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

private struct TripPlannerExpenseDeleteConfirmationPrompt: View {
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Delete this expense?")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    Text("This will permanently remove it from the trip expenses.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.66))
                }

                HStack(spacing: 10) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.65))

                    Spacer()

                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.18))
                }
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.95, blue: 0.88).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

private struct TripPlannerExpenseParticipantGrid: View {
    let participants: [TripPlannerExpenseParticipant]
    let selectedIDs: Set<String>
    let onToggle: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(participants) { participant in
                Button {
                    onToggle(participant.id)
                } label: {
                    HStack(spacing: 8) {
                        TripPlannerAvatarView(
                            name: participant.name,
                            username: participant.username ?? "",
                            avatarURL: participant.avatarURL,
                            size: 26
                        )

                        Text(participant.firstName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if selectedIDs.contains(participant.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(selectedIDs.contains(participant.id) ? 0.95 : 0.78))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selectedIDs.contains(participant.id) ? Color.black.opacity(0.22) : Color.clear, lineWidth: 1.4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TripPlannerExpenseShareEditorRow: View {
    let share: TripPlannerExpenseShare
    let currencyCode: String
    let participant: TripPlannerExpenseParticipant?
    let onUpdate: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let participant {
                TripPlannerAvatarView(
                    name: participant.name,
                    username: participant.username ?? "",
                    avatarURL: participant.avatarURL,
                    size: 34
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(participant?.firstName ?? share.participantName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(share.isPaid ? Color(red: 0.14, green: 0.47, blue: 0.25) : .black)

                AppCurrencyAmountLabel(
                    amount: share.amountOwed,
                    currencyCode: currencyCode,
                    font: .system(size: 13, weight: .semibold),
                    fontSize: 13,
                    color: share.isPaid ? Color(red: 0.14, green: 0.47, blue: 0.25).opacity(0.78) : .black.opacity(0.64)
                )
            }

            Spacer()

            TripPlannerExpensePaidStatusControl(
                isPaid: share.isPaid,
                onChange: onUpdate
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(share.isPaid ? Color(red: 0.90, green: 0.97, blue: 0.90) : Color.white.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(share.isPaid ? Color(red: 0.12, green: 0.50, blue: 0.25).opacity(0.18) : Color.clear, lineWidth: 1)
        )
    }

}

private struct TripPlannerExpensePaidStatusControl: View {
    let isPaid: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 3
            let thumbWidth = max((geometry.size.width - (inset * 2)) / 2, 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.045))

                Capsule()
                    .fill(isPaid ? Color(red: 0.84, green: 0.95, blue: 0.88) : Color.white.opacity(0.96))
                    .overlay(
                        Capsule()
                            .stroke(isPaid ? Color(red: 0.25, green: 0.63, blue: 0.40).opacity(0.16) : Color.black.opacity(0.05), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                    .frame(width: thumbWidth, height: geometry.size.height - (inset * 2))
                    .offset(x: isPaid ? thumbWidth : 0)
                    .padding(inset)

                HStack(spacing: 0) {
                    optionButton(
                        title: String(localized: "trip_planner.expenses.not_paid"),
                        isActive: !isPaid,
                        activeColor: Color(red: 0.63, green: 0.18, blue: 0.18),
                        action: { onChange(false) }
                    )

                    optionButton(
                        title: String(localized: "trip_planner.expenses.paid"),
                        isActive: isPaid,
                        activeColor: Color(red: 0.17, green: 0.52, blue: 0.28),
                        action: { onChange(true) }
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(width: 152, height: 38)
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.58), lineWidth: 0.8)
        )
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.14), value: isPaid)
    }

    private func optionButton(
        title: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? activeColor : .black.opacity(0.46))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension TripPlannerExpense {
    var isSettled: Bool {
        shares.allSatisfy(\.isPaid)
    }

    var categoryDisplayTitle: String {
        let trimmedCustom = customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if category == .other, !trimmedCustom.isEmpty {
            return trimmedCustom
        }
        return category.title
    }

    var categoryTintColor: Color {
        if category == .other,
           let customCategoryName,
           !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Self.customCategoryColor(for: customCategoryName)
        }
        return category.tintColor
    }

    var categoryBackgroundTint: Color {
        categoryTintColor.opacity(0.14)
    }

    private static func customCategoryColor(for name: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.20, green: 0.47, blue: 0.62),
            Color(red: 0.22, green: 0.54, blue: 0.38),
            Color(red: 0.78, green: 0.36, blue: 0.24),
            Color(red: 0.71, green: 0.45, blue: 0.22),
            Color(red: 0.54, green: 0.33, blue: 0.64),
            Color(red: 0.76, green: 0.30, blue: 0.46),
            Color(red: 0.28, green: 0.57, blue: 0.56),
            Color(red: 0.55, green: 0.41, blue: 0.25)
        ]

        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scalarTotal = normalized.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }

        return palette[abs(scalarTotal) % palette.count]
    }
}

private extension TripPlannerTrip {
    var countryChipItems: [(id: String, title: String)] {
        countryIds.map { id in
            (id: id, title: "\(id.flagEmoji) \(CountrySelectionFormatter.localizedName(for: id))")
        }
    }

    var effectivePlannerCurrencyCode: String {
        CurrencyPreferenceStore.persistedDefaultCurrencyCode()
    }

    var availabilityParticipants: [TripPlannerAvailabilityParticipant] {
        availabilityParticipants(currentUserId: SupabaseManager.shared.currentUserId)
    }

    func availabilityParticipants(currentUserId: UUID?) -> [TripPlannerAvailabilityParticipant] {
        var ordered: [TripPlannerAvailabilityParticipant] = []
        var seen = Set<String>()
        let profileService = ProfileService(supabase: SupabaseManager.shared)

        func append(snapshot: TripPlannerFriendSnapshot, preferCurrentUserName: Bool = false) {
            let id = snapshot.id.uuidString
            guard seen.insert(id).inserted else { return }

            if preferCurrentUserName,
               let currentUserId,
               snapshot.id == currentUserId,
               let cachedProfile = profileService.cachedProfile(userId: currentUserId) {
                ordered.append(
                    TripPlannerAvailabilityParticipant(
                        id: id,
                        name: cachedProfile.tripDisplayName,
                        username: cachedProfile.username,
                        avatarURL: cachedProfile.avatarUrl
                    )
                )
            } else {
                ordered.append(
                    TripPlannerAvailabilityParticipant(
                        id: id,
                        name: snapshot.displayName,
                        username: snapshot.username,
                        avatarURL: snapshot.avatarURL
                    )
                )
            }
        }

        func append(userId: UUID, fallbackName: String? = nil, preferCurrentUserName: Bool = false) {
            if let existing = friends.first(where: { $0.id == userId }) {
                append(snapshot: existing, preferCurrentUserName: preferCurrentUserName)
            } else if let ownerSnapshot = effectiveOwnerSnapshot, ownerSnapshot.id == userId {
                append(snapshot: ownerSnapshot, preferCurrentUserName: preferCurrentUserName)
            } else if let cachedProfile = profileService.cachedProfile(userId: userId) {
                append(
                    snapshot: TripPlannerFriendSnapshot(
                        id: cachedProfile.id,
                        displayName: cachedProfile.tripDisplayName,
                        username: cachedProfile.username,
                        avatarURL: cachedProfile.avatarUrl
                    ),
                    preferCurrentUserName: preferCurrentUserName
                )
            } else {
                append(
                    snapshot: TripPlannerFriendSnapshot(
                        id: userId,
                        displayName: fallbackName ?? "Traveler",
                        username: "traveler",
                        avatarURL: nil
                    ),
                    preferCurrentUserName: preferCurrentUserName
                )
            }
        }

        if let ownerId {
            append(userId: ownerId, fallbackName: "Owner", preferCurrentUserName: ownerId == currentUserId)
        } else if let currentUserId {
            append(userId: currentUserId, fallbackName: String(localized: "trip_planner.you"), preferCurrentUserName: true)
        } else {
            ordered.append(.you)
            seen.insert(TripPlannerAvailabilityParticipant.you.id)
        }

        for friend in friends {
            append(snapshot: friend, preferCurrentUserName: friend.id == currentUserId)
        }

        if let currentUserId {
            append(userId: currentUserId, fallbackName: String(localized: "trip_planner.you"), preferCurrentUserName: true)
        }

        return ordered
    }

    func normalizedAvailabilityProposals(currentUserId: UUID?) -> [TripPlannerAvailabilityProposal] {
        let legacySelfId = ownerId ?? currentUserId
        let participantsByID = Dictionary(uniqueKeysWithValues: availabilityParticipants(currentUserId: currentUserId).map { ($0.id, $0) })

        return availability.map { proposal in
            guard proposal.participantId == "self",
                  let legacySelfId else {
                return proposal
            }

            let normalizedID = legacySelfId.uuidString
            let participant = participantsByID[normalizedID]
            return TripPlannerAvailabilityProposal(
                id: proposal.id,
                participantId: normalizedID,
                participantName: participant?.name ?? proposal.participantName,
                participantUsername: participant?.username ?? proposal.participantUsername,
                participantAvatarURL: participant?.avatarURL ?? proposal.participantAvatarURL,
                kind: proposal.kind,
                startDate: proposal.startDate,
                endDate: proposal.endDate
            )
        }
    }
}

private struct TripPlannerAvailabilityParticipant: Identifiable, Hashable {
    let id: String
    let name: String
    let username: String?
    let avatarURL: String?

    static let you = TripPlannerAvailabilityParticipant(
        id: "self",
        name: String(localized: "trip_planner.you"),
        username: nil,
        avatarURL: nil
    )
}

private enum TripPlannerCurrencyDisplay {
    static func amountFromUSD(
        _ amount: Double,
        currencyCode: String,
        snapshot: ExchangeRateSnapshot?
    ) -> Double {
        CurrencyConversion.convert(
            amount,
            from: "USD",
            to: currencyCode,
            snapshot: snapshot
        ) ?? amount
    }

    static func amountToUSD(
        _ amount: Double,
        currencyCode: String,
        snapshot: ExchangeRateSnapshot?
    ) -> Double {
        CurrencyConversion.convert(
            amount,
            from: currencyCode,
            to: "USD",
            snapshot: snapshot
        ) ?? amount
    }

    static func stringFromUSD(
        _ amount: Double,
        currencyCode: String,
        snapshot: ExchangeRateSnapshot?,
        maximumFractionDigits: Int = 2,
        minimumFractionDigits: Int = 0
    ) -> String {
        let converted = amountFromUSD(amount, currencyCode: currencyCode, snapshot: snapshot)
        return AppCurrencyFormatter.string(
            amount: converted,
            currencyCode: currencyCode,
            maximumFractionDigits: maximumFractionDigits,
            minimumFractionDigits: minimumFractionDigits
        )
    }

    static func editableTextFromUSD(
        _ amount: Double,
        currencyCode: String,
        snapshot: ExchangeRateSnapshot?
    ) -> String {
        let converted = amountFromUSD(amount, currencyCode: currencyCode, snapshot: snapshot)
        return AppCurrencyFormatter.editableText(amount: converted)
    }
}

private struct TripPlannerAvailabilityOverlap: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let exactParticipantCount: Int
    let totalParticipantCount: Int

    var isFullMatch: Bool {
        exactParticipantCount == totalParticipantCount
    }
}

private struct TripPlannerStatsPreviewSection: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let countries: [Country]
    let startDate: Date?
    let endDate: Date?
    let tripDayPlans: [TripPlannerDayPlan]
    let weights: ScoreWeights
    let preferredMonth: Int
    let isGroupTrip: Bool
    let travelerCount: Int
    let currencyCode: String
    let groupVisaNeeds: [TripPlannerTravelerVisaNeed]

    private var selectedMonth: Int {
        guard let startDate else { return preferredMonth }
        return Calendar.current.component(.month, from: startDate)
    }

    private var effectiveWeights: ScoreWeights {
        isGroupTrip ? .default : weights
    }

    private var countryByID: [String: Country] {
        Dictionary(uniqueKeysWithValues: countries.map { ($0.id, $0) })
    }

    private var normalizedDayPlans: [TripPlannerDayPlan] {
        TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: tripDayPlans,
            startDate: startDate,
            endDate: endDate,
            countries: countries.map { ($0.id, $0.name) }
        )
    }

    private var weightedCountryDays: [Country] {
        normalizedDayPlans.compactMap { plan in
            guard plan.kind == .country, let countryId = plan.countryId else { return nil }
            return countryByID[countryId]
        }
    }

    private var tripScore: Int? {
        let values = countries.map {
            $0.applyingOverallScore(using: effectiveWeights, selectedMonth: selectedMonth).score
        }
        .compactMap { $0 }

        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private var tripLengthDays: Int? {
        guard let startDate, let endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day ?? 0
        return max(days + 1, 1)
    }

    private var estimatedTripCostPerPerson: Int? {
        let weightedSpend = weightedCountryDays.compactMap(estimatedDailySpendPerTraveler)
        if !weightedSpend.isEmpty {
            return Int(weightedSpend.reduce(0, +).rounded())
        }

        let fallbackSpend = countries.compactMap(estimatedDailySpendPerTraveler)
        guard
            !fallbackSpend.isEmpty,
            let tripLengthDays
        else {
            return nil
        }

        let average = fallbackSpend.reduce(0, +) / Double(fallbackSpend.count)
        return Int((average * Double(tripLengthDays)).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overall trip Score")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.62))

                    if let tripScore {
                        ScorePill(score: tripScore)
                            .fixedSize(horizontal: true, vertical: true)
                    } else {
                        Text("trip_planner.stats.na")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.black)
                    }

                    if !summaryText.isEmpty {
                        Text(summaryText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    costTextView

                    Text(isGroupTrip ? "Hotel share is split across travelers" : "Per-person estimate")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.56))
                        .multilineTextAlignment(.trailing)
                }
            }

        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
    }

    private var summaryText: String {
        return ""
    }

    @ViewBuilder
    private var costTextView: some View {
        if let estimatedTripCostPerPerson {
            AppCurrencyAmountLabel(
                amount: TripPlannerCurrencyDisplay.amountFromUSD(
                    Double(estimatedTripCostPerPerson),
                    currencyCode: currencyCode,
                    snapshot: currencyPreferenceStore.exchangeRateSnapshot
                ),
                currencyCode: currencyCode,
                font: .system(size: 18, weight: .bold),
                fontSize: 18,
                color: .black,
                maximumFractionDigits: 0
            )
        } else {
            Text("Add dates")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.trailing)
        }
    }

    private func estimatedDailySpendPerTraveler(for country: Country) -> Double? {
        let hotel = country.dailySpendHotelUsd ?? 0
        let food = country.dailySpendFoodUsd ?? 0
        let activities = country.dailySpendActivitiesUsd ?? 0
        let total = country.dailySpendTotalUsd
        let uncategorized = max((total ?? 0) - hotel - food - activities, 0)

        if isGroupTrip, travelerCount > 1 {
            let groupAdjusted = (hotel / Double(travelerCount)) + food + activities + uncategorized
            if groupAdjusted > 0 {
                return groupAdjusted
            }
        }

        if let total, total > 0 {
            return total
        }

        let componentTotal = hotel + food + activities
        return componentTotal > 0 ? componentTotal : nil
    }
}

private struct TripPlannerTripScoreBreakdownView: View {
    let countries: [Country]
    let startDate: Date?
    let endDate: Date?
    let tripDayPlans: [TripPlannerDayPlan]
    let weights: ScoreWeights
    let preferredMonth: Int
    let isGroupTrip: Bool
    let travelerCount: Int
    let currencyCode: String
    let passportLabel: String
    let groupLanguageScoresByCountry: [String: Int]
    let groupVisaNeeds: [TripPlannerTravelerVisaNeed]

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("Trip Score")

                ScrollView {
                    VStack(spacing: 18) {
                        if isGroupTrip {
                            TripPlannerInfoCard(
                                text: "This group score uses equal weighting across the five planner categories.",
                                systemImage: "person.3.sequence.fill"
                            )
                        }

                            TripPlannerStatsSection(
                                countries: countries,
                                startDate: startDate,
                                endDate: endDate,
                                tripDayPlans: tripDayPlans,
                                weights: weights,
                                preferredMonth: preferredMonth,
                                isGroupTrip: isGroupTrip,
                                travelerCount: travelerCount,
                                currencyCode: currencyCode,
                                passportLabel: passportLabel,
                                groupLanguageScoresByCountry: groupLanguageScoresByCountry,
                                groupVisaNeeds: groupVisaNeeds
                        )
                    }
                    .padding(.horizontal, Theme.pageHorizontalInset)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TripPlannerStatsSection: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let countries: [Country]
    let startDate: Date?
    let endDate: Date?
    let tripDayPlans: [TripPlannerDayPlan]
    let weights: ScoreWeights
    let preferredMonth: Int
    let isGroupTrip: Bool
    let travelerCount: Int
    let currencyCode: String
    let passportLabel: String
    let groupLanguageScoresByCountry: [String: Int]
    let groupVisaNeeds: [TripPlannerTravelerVisaNeed]
    @State private var isShowingEstimatedCostBreakdown = false

    private var selectedMonth: Int {
        guard let startDate else { return preferredMonth }
        return Calendar.current.component(.month, from: startDate)
    }

    private var effectiveWeights: ScoreWeights {
        isGroupTrip ? .default : weights
    }

    private var scoredCountries: [Country] {
        countries.map {
            $0.applyingOverallScore(using: effectiveWeights, selectedMonth: selectedMonth)
        }
    }

    private var affordabilityScores: [Int] {
        countries.compactMap(\.affordabilityScore)
    }

    private var dailySpendValues: [Double] {
        countries.compactMap(\.dailySpendTotalUsd)
    }

    private var countryByID: [String: Country] {
        Dictionary(uniqueKeysWithValues: countries.map { ($0.id, $0) })
    }

    private var normalizedDayPlans: [TripPlannerDayPlan] {
        TripPlannerDayPlanBuilder.syncedDayPlans(
            existingPlans: tripDayPlans,
            startDate: startDate,
            endDate: endDate,
            countries: countries.map { ($0.id, $0.name) }
        )
    }

    private var weightedCountryDays: [Country] {
        normalizedDayPlans.compactMap { plan in
            guard plan.kind == .country, let countryId = plan.countryId else { return nil }
            return countryByID[countryId]
        }
    }

    private var averageAffordability: Int? {
        guard !affordabilityScores.isEmpty else { return nil }
        return Int((Double(affordabilityScores.reduce(0, +)) / Double(affordabilityScores.count)).rounded())
    }

    private var averageDailySpend: Int? {
        let weightedSpend = weightedCountryDays.compactMap(estimatedDailySpendPerTraveler)
        if !weightedSpend.isEmpty {
            return Int((weightedSpend.reduce(0, +) / Double(weightedSpend.count)).rounded())
        }
        let fallbackSpend = countries.compactMap(estimatedDailySpendPerTraveler)
        guard !fallbackSpend.isEmpty else { return nil }
        return Int((fallbackSpend.reduce(0, +) / Double(fallbackSpend.count)).rounded())
    }

    private var tripLengthDays: Int? {
        guard let startDate, let endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day ?? 0
        return max(days + 1, 1)
    }

    private var estimatedTripCostPerPerson: Int? {
        let breakdownTotal = estimatedCostBreakdown.reduce(0) { $0 + $1.amount }
        if breakdownTotal > 0.009 {
            return Int(breakdownTotal.rounded())
        }
        guard let averageDailySpend, let tripLengthDays else { return nil }
        return averageDailySpend * tripLengthDays
    }

    private var estimatedCostBreakdown: [TripPlannerCostBreakdownLine] {
        let itineraryBreakdown = itineraryCostBreakdown
        if !itineraryBreakdown.isEmpty {
            return itineraryBreakdown
        }

        guard let tripLengthDays, !countries.isEmpty else { return [] }

        let averageAccommodation = countries.compactMap(accommodationCostPerNight).averageOrZero * Double(tripLengthDays)
        let averageFood = countries.compactMap(\.dailySpendFoodUsd).averageOrZero * Double(tripLengthDays)
        let averageActivities = countries.compactMap(\.dailySpendActivitiesUsd).averageOrZero * Double(tripLengthDays)
        let averageOther = countries.compactMap(otherDailyCost).averageOrZero * Double(tripLengthDays)

        return [
            TripPlannerCostBreakdownLine(title: "Accommodation", amount: averageAccommodation, detail: "Nightly stays across the full trip"),
            TripPlannerCostBreakdownLine(title: "Food", amount: averageFood, detail: "Average daily food spend"),
            TripPlannerCostBreakdownLine(title: "Activities", amount: averageActivities, detail: "Average daily activities spend"),
            TripPlannerCostBreakdownLine(title: "Other", amount: averageOther, detail: "Local transport and other daily costs")
        ]
        .filter { $0.amount > 0.009 }
    }

    private var itineraryCostBreakdown: [TripPlannerCostBreakdownLine] {
        guard !normalizedDayPlans.isEmpty else { return [] }

        var accommodation = 0.0
        var food = 0.0
        var activities = 0.0
        var other = 0.0

        for index in normalizedDayPlans.indices {
            let plan = normalizedDayPlans[index]

            if let overnightCountry = overnightCountry(for: index) {
                accommodation += accommodationCostPerNight(for: overnightCountry)
            }

            if plan.kind == .country,
               let countryId = plan.countryId,
               let country = countryByID[countryId] {
                food += country.dailySpendFoodUsd ?? 0
                activities += country.dailySpendActivitiesUsd ?? 0
                other += otherDailyCost(for: country)
            }
        }

        return [
            TripPlannerCostBreakdownLine(title: "Accommodation", amount: accommodation, detail: "Includes arrival-night stays on travel days"),
            TripPlannerCostBreakdownLine(title: "Food", amount: food, detail: "Country days only"),
            TripPlannerCostBreakdownLine(title: "Activities", amount: activities, detail: "Country days only"),
            TripPlannerCostBreakdownLine(title: "Other", amount: other, detail: "Local transport and uncategorized daily costs")
        ]
        .filter { $0.amount > 0.009 }
    }

    private var visaPrepCountries: [Country] {
        countries.filter {
            ["evisa", "visa_required", "entry_permit", "ban"].contains($0.visaType ?? "")
        }
    }

    private var easyEntryCountries: [Country] {
        countries.filter {
            ["own_passport", "freedom_of_movement", "visa_free", "voa"].contains($0.visaType ?? "")
        }
    }

    private var overstayRiskCountries: [Country] {
        guard let tripLengthDays else { return [] }
        return countries.filter { country in
            guard let allowedDays = country.visaAllowedDays else { return false }
            return tripLengthDays > allowedDays
        }
    }

    private var allCountriesVisaFreeForTrip: Bool {
        !countries.isEmpty && countries.allSatisfy { country in
            ["own_passport", "freedom_of_movement", "visa_free"].contains(country.visaType ?? "")
        } && overstayRiskCountries.isEmpty
    }

    private var allCountriesNeedNoAdvanceVisa: Bool {
        !countries.isEmpty && countries.allSatisfy { country in
            ["own_passport", "freedom_of_movement", "visa_free", "voa"].contains(country.visaType ?? "")
        } && overstayRiskCountries.isEmpty
    }

    private var averageOverallScore: Int? {
        average(of: scoredCountries.compactMap(\.score))
    }

    private var averageAdvisoryScore: Int? {
        average(of: countries.compactMap(\.advisoryScore))
    }

    private var averageSeasonalityScore: Int? {
        average(of: countries.compactMap { $0.resolvedSeasonalityScore(for: selectedMonth) })
    }

    private var categoryAverages: [TripPlannerScoreAverage] {
        [
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.overall"), subtitle: String(localized: "trip_planner.stats.category.overall_subtitle"), score: averageOverallScore),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.advisory"), subtitle: String(localized: "trip_planner.stats.category.advisory_subtitle"), score: averageAdvisoryScore),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.seasonality"), subtitle: monthSummaryText, score: averageSeasonalityScore),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.visa"), subtitle: String(localized: "trip_planner.stats.category.visa_subtitle"), score: average(of: countries.compactMap(\.visaEaseScore))),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.budget"), subtitle: String(localized: "trip_planner.stats.category.budget_subtitle"), score: averageAffordability),
            TripPlannerScoreAverage(title: String(localized: "trip_planner.stats.category.language"), subtitle: isGroupTrip ? String(localized: "trip_planner.stats.category.language_group_subtitle") : String(localized: "trip_planner.stats.category.language_solo_subtitle"), score: averageLanguageScore)
        ]
    }

    private var averageLanguageScore: Int? {
        let values = countries.compactMap { groupLanguageScoresByCountry[$0.id] }
        return average(of: values)
    }

    private var affectedTravelerCount: Int {
        Set(groupVisaNeeds.map(\.travelerId)).count
    }

    private var visibleVisaSummaries: [TripPlannerVisaSummary] {
        Array(visaSummaries.prefix(3))
    }

    private var hiddenVisaSummaryCount: Int {
        max(visaSummaries.count - visibleVisaSummaries.count, 0)
    }

    private var visaSummaries: [TripPlannerVisaSummary] {
        if isGroupTrip {
            var grouped: [String: TripPlannerVisaSummary] = [:]

            for need in groupVisaNeeds {
                if var existing = grouped[need.countryID] {
                    existing.add(need)
                    grouped[need.countryID] = existing
                } else {
                    grouped[need.countryID] = TripPlannerVisaSummary(need: need)
                }
            }

            return grouped.values.sorted { lhs, rhs in
                if lhs.exceedsAllowedStay != rhs.exceedsAllowedStay {
                    return lhs.exceedsAllowedStay && !rhs.exceedsAllowedStay
                }
                if lhs.travelerCount != rhs.travelerCount {
                    return lhs.travelerCount > rhs.travelerCount
                }
                return lhs.countryName.localizedCaseInsensitiveCompare(rhs.countryName) == .orderedAscending
            }
        }

        let riskByCountry = Dictionary(uniqueKeysWithValues: overstayRiskCountries.map { ($0.id, $0) })
        let prepOnlyCountries = visaPrepCountries.filter { riskByCountry[$0.id] == nil }
        let combined = overstayRiskCountries + prepOnlyCountries

        return combined.map { country in
            TripPlannerVisaSummary(
                countryID: country.id,
                countryName: country.name,
                countryFlag: country.flagEmoji,
                passportLabels: [country.visaPassportLabel ?? passportLabel],
                travelerNames: [],
                travelerCount: 0,
                allowedDays: country.visaAllowedDays,
                exceedsAllowedStay: overstayRiskCountries.contains(where: { $0.id == country.id }),
                visaType: country.visaType
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !categoryAverages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("trip_planner.stats.score_breakdown")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10, alignment: .top),
                            GridItem(.flexible(), spacing: 10, alignment: .top)
                        ],
                        spacing: 10
                    ) {
                        ForEach(categoryAverages) { metric in
                            TripPlannerCategoryAverageCard(metric: metric)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                )
            }

            HStack(spacing: 10) {
                TripPlannerStatPill(
                    title: String(localized: "trip_planner.stats.estimated_total_per_person"),
                    detail: estimatedCostDetail,
                    accessorySystemImage: estimatedCostBreakdown.isEmpty ? nil : (isShowingEstimatedCostBreakdown ? "chevron.up" : "chevron.down"),
                    action: estimatedCostBreakdown.isEmpty ? nil : {
                        isShowingEstimatedCostBreakdown.toggle()
                    }
                ) {
                    if let estimatedTripCostPerPerson {
                        AppCurrencyAmountLabel(
                            amount: TripPlannerCurrencyDisplay.amountFromUSD(
                                Double(estimatedTripCostPerPerson),
                                currencyCode: currencyCode,
                                snapshot: currencyPreferenceStore.exchangeRateSnapshot
                            ),
                            currencyCode: currencyCode,
                            font: .system(size: 21, weight: .bold),
                            fontSize: 21,
                            color: .black,
                            maximumFractionDigits: 0
                        )
                    } else {
                        Text(String(localized: "trip_planner.stats.add_trip_dates"))
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }

                TripPlannerStatPill(
                    title: String(localized: "trip_planner.stats.typical_daily_spend"),
                    detail: dailySpendDetail
                ) {
                    if let averageDailySpend {
                        AppCurrencyAmountLabel(
                            amount: TripPlannerCurrencyDisplay.amountFromUSD(
                                Double(averageDailySpend),
                                currencyCode: currencyCode,
                                snapshot: currencyPreferenceStore.exchangeRateSnapshot
                            ),
                            currencyCode: currencyCode,
                            font: .system(size: 21, weight: .bold),
                            fontSize: 21,
                            color: .black,
                            maximumFractionDigits: 0
                        )
                    } else {
                        Text(String(localized: "trip_planner.stats.na"))
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
            }

            if isShowingEstimatedCostBreakdown, !estimatedCostBreakdown.isEmpty {
                TripPlannerEstimatedCostBreakdownCard(
                    breakdown: estimatedCostBreakdown,
                    totalAmount: Double(estimatedTripCostPerPerson ?? 0),
                    currencyCode: currencyCode
                )
            }

            TripPlannerVisaSummaryCard(
                headline: visaSummaryValue,
                badges: visaBadges,
                summaries: visibleVisaSummaries,
                hiddenSummaryCount: hiddenVisaSummaryCount,
                tripLengthDays: tripLengthDays,
                passportLabel: passportLabel,
                isGroupTrip: isGroupTrip,
                allClearMessage: visaAllClearMessage
            )
        }
    }

    private var estimatedCostDetail: String {
        guard let tripLengthDays else {
            return String(localized: "trip_planner.stats.estimate_when_dates_set")
        }
        return "Includes \(tripLengthDays) day\(tripLengthDays == 1 ? "" : "s"), travel dates, and arrival-night stays"
    }

    private var dailySpendDetail: String {
        if !weightedCountryDays.isEmpty {
            let travelDayCount = normalizedDayPlans.filter { $0.kind == .travel }.count
            if travelDayCount > 0 {
                return String(format: String(localized: "trip_planner.stats.weighted_excluding_travel_days_format"), locale: AppDisplayLocale.current, travelDayCount)
            }
            return String(localized: "trip_planner.stats.weighted_by_itinerary")
        }
        guard let averageAffordability else { return String(localized: "trip_planner.stats.across_selected_countries") }
        switch averageAffordability {
        case 80...:
            return String(localized: "trip_planner.stats.budget_friendly")
        case 60..<80:
            return String(localized: "trip_planner.stats.pretty_balanced")
        case 40..<60:
            return String(localized: "trip_planner.stats.mid_range_to_pricey")
        default:
            return String(localized: "trip_planner.stats.expensive")
        }
    }

    private var visaSummaryValue: String {
        if !overstayRiskCountries.isEmpty {
            return String(localized: "trip_planner.visa.plan_needed")
        }
        if isGroupTrip, affectedTravelerCount > 0 {
            return String(format: String(localized: "trip_planner.visa.traveler_prep_format"), locale: AppDisplayLocale.current, affectedTravelerCount)
        }
        if allCountriesVisaFreeForTrip {
            return String(localized: "trip_planner.visa.none_required")
        }
        if allCountriesNeedNoAdvanceVisa {
            return String(localized: "trip_planner.visa.no_advance_needed")
        }
        return String(format: String(localized: "trip_planner.visa.stops_to_prep_format"), locale: AppDisplayLocale.current, visaPrepCountries.count)
    }

    private var monthSummaryText: String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        return String(format: String(localized: "trip_planner.stats.month_timing_format"), locale: AppDisplayLocale.current, formatter.monthSymbols[selectedMonth - 1])
    }

    private func average(of values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private func estimatedDailySpendPerTraveler(for country: Country) -> Double? {
        let hotel = accommodationCostPerNight(for: country)
        let food = country.dailySpendFoodUsd ?? 0
        let activities = country.dailySpendActivitiesUsd ?? 0
        let total = country.dailySpendTotalUsd
        let uncategorized = max((total ?? 0) - hotel - food - activities, 0)

        if let total, total > 0 {
            let adjustedTotal = food + activities + uncategorized + hotel
            return adjustedTotal > 0 ? adjustedTotal : total
        }

        let componentTotal = hotel + food + activities
        return componentTotal > 0 ? componentTotal : nil
    }

    private func accommodationCostPerNight(for country: Country) -> Double {
        guard let hotel = country.dailySpendHotelUsd, hotel > 0 else { return 0 }
        if isGroupTrip, travelerCount > 1 {
            return hotel / Double(travelerCount)
        }
        return hotel
    }

    private func otherDailyCost(for country: Country) -> Double {
        let hotel = accommodationCostPerNight(for: country)
        let food = country.dailySpendFoodUsd ?? 0
        let activities = country.dailySpendActivitiesUsd ?? 0
        let total = country.dailySpendTotalUsd ?? 0
        return max(total - hotel - food - activities, 0)
    }

    private func overnightCountry(for index: Int) -> Country? {
        guard normalizedDayPlans.indices.contains(index) else { return nil }

        let plan = normalizedDayPlans[index]
        if plan.kind == .country,
           let countryId = plan.countryId,
           let country = countryByID[countryId] {
            return country
        }

        for followingIndex in normalizedDayPlans.indices where followingIndex > index {
            let followingPlan = normalizedDayPlans[followingIndex]
            guard followingPlan.kind == .country,
                  let countryId = followingPlan.countryId,
                  let country = countryByID[countryId] else {
                continue
            }
            return country
        }

        return nil
    }

    private var overstayWarningText: String {
        let countriesText = overstayRiskCountries.map { "\($0.flagEmoji) \($0.name)" }.joined(separator: ", ")
        guard let tripLengthDays else {
            return String(localized: "trip_planner.visa.overstay_warning_generic")
        }
        return String(format: String(localized: "trip_planner.visa.overstay_warning_format"), locale: AppDisplayLocale.current, countriesText, tripLengthDays)
    }

    private var visaBadges: [String] {
        var badges: [String] = []

        if !countries.isEmpty {
            badges.append(String(format: String(localized: "trip_planner.visa.stop_count_format"), locale: AppDisplayLocale.current, countries.count))
        }

        if isGroupTrip {
            badges.append(String(format: String(localized: "trip_planner.visa.traveler_count_format"), locale: AppDisplayLocale.current, travelerCount))
            if !groupVisaNeeds.isEmpty {
                badges.append(String(format: String(localized: "trip_planner.visa.flag_count_format"), locale: AppDisplayLocale.current, groupVisaNeeds.count))
            }
        } else if !visaPrepCountries.isEmpty {
            badges.append(String(format: String(localized: "trip_planner.visa.stop_prep_count_format"), locale: AppDisplayLocale.current, visaPrepCountries.count))
        }

        if let tripLengthDays {
            badges.append(String(format: String(localized: "trip_planner.visa.day_count_format"), locale: AppDisplayLocale.current, tripLengthDays))
        }

        return badges
    }

    private var visaAllClearMessage: String? {
        if isGroupTrip, groupVisaNeeds.isEmpty {
            return String(localized: "trip_planner.visa.group_all_clear")
        }
        if allCountriesVisaFreeForTrip {
            return String(localized: "trip_planner.visa.every_stop_visa_free")
        }
        if allCountriesNeedNoAdvanceVisa {
            return String(localized: "trip_planner.visa.every_stop_no_advance")
        }
        return nil
    }
}

private struct TripPlannerTravelerVisaNeed: Identifiable, Hashable {
    let travelerId: UUID
    let travelerName: String
    let countryID: String
    let countryName: String
    let countryFlag: String
    let passportLabel: String
    let visaType: String
    let allowedDays: Int?
    let exceedsAllowedStay: Bool

    var id: String {
        "\(travelerId.uuidString)::\(countryID)"
    }

    func summaryText(tripLengthDays: Int?) -> String {
        if exceedsAllowedStay, let tripLengthDays, let allowedDays {
            return String(format: String(localized: "trip_planner.visa.traveler_overstay_summary_format"), locale: AppDisplayLocale.current, travelerName, countryFlag, countryName, passportLabel, allowedDays, tripLengthDays)
        }

        return String(format: String(localized: "trip_planner.visa.traveler_prep_summary_format"), locale: AppDisplayLocale.current, travelerName, countryFlag, countryName, passportLabel)
    }
}

private struct TripPlannerVisaSummary: Identifiable, Hashable {
    let countryID: String
    let countryName: String
    let countryFlag: String
    var passportLabels: [String]
    var travelerNames: [String]
    var travelerCount: Int
    let allowedDays: Int?
    var exceedsAllowedStay: Bool
    let visaType: String?

    init(
        countryID: String,
        countryName: String,
        countryFlag: String,
        passportLabels: [String],
        travelerNames: [String],
        travelerCount: Int,
        allowedDays: Int?,
        exceedsAllowedStay: Bool,
        visaType: String?
    ) {
        self.countryID = countryID
        self.countryName = countryName
        self.countryFlag = countryFlag
        self.passportLabels = passportLabels
        self.travelerNames = travelerNames
        self.travelerCount = travelerCount
        self.allowedDays = allowedDays
        self.exceedsAllowedStay = exceedsAllowedStay
        self.visaType = visaType
    }

    init(need: TripPlannerTravelerVisaNeed) {
        self.init(
            countryID: need.countryID,
            countryName: need.countryName,
            countryFlag: need.countryFlag,
            passportLabels: [need.passportLabel],
            travelerNames: [need.travelerName],
            travelerCount: 1,
            allowedDays: need.allowedDays,
            exceedsAllowedStay: need.exceedsAllowedStay,
            visaType: need.visaType
        )
    }

    var id: String { countryID }

    mutating func add(_ need: TripPlannerTravelerVisaNeed) {
        travelerCount += 1
        exceedsAllowedStay = exceedsAllowedStay || need.exceedsAllowedStay
        travelerNames = Array(NSOrderedSet(array: travelerNames + [need.travelerName])) as? [String] ?? travelerNames
        passportLabels = Array(NSOrderedSet(array: passportLabels + [need.passportLabel])) as? [String] ?? passportLabels
    }
}

private struct TripPlannerVisaSummaryCard: View {
    let headline: String
    let badges: [String]
    let summaries: [TripPlannerVisaSummary]
    let hiddenSummaryCount: Int
    let tripLengthDays: Int?
    let passportLabel: String
    let isGroupTrip: Bool
    let allClearMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 40, height: 40)

                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.75))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("trip_planner.visa.title")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.58))

                    Text(headline)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black)
                }
            }

            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(badges, id: \.self) { badge in
                            TripPlannerBadge(text: badge)
                        }
                    }
                }
            }

            if let allClearMessage, summaries.isEmpty {
                TripPlannerInfoCard(
                    text: allClearMessage,
                    systemImage: "checkmark.seal.fill"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(summaries) { summary in
                        TripPlannerVisaCountryRow(
                            summary: summary,
                            tripLengthDays: tripLengthDays,
                            passportLabel: passportLabel,
                            isGroupTrip: isGroupTrip
                        )
                    }
                }

                if hiddenSummaryCount > 0 {
                    TripPlannerInfoCard(
                        text: String(format: String(localized: "trip_planner.visa.hidden_summary_format"), locale: AppDisplayLocale.current, hiddenSummaryCount),
                        systemImage: "ellipsis.circle.fill"
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.93))
        )
    }

    private var iconName: String {
        summaries.contains(where: \.exceedsAllowedStay) ? "exclamationmark.triangle.fill" : "globe.badge.chevron.backward"
    }

    private var iconBackgroundColor: Color {
        summaries.contains(where: \.exceedsAllowedStay)
            ? Color(red: 0.94, green: 0.84, blue: 0.73)
            : Color.black.opacity(0.08)
    }
}

private struct TripPlannerVisaCountryRow: View {
    let summary: TripPlannerVisaSummary
    let tripLengthDays: Int?
    let passportLabel: String
    let isGroupTrip: Bool

    private var countryDestination: Country {
        Country(
            iso2: summary.countryID,
            name: summary.countryName,
            score: nil
        )
    }

    private var travelerPreview: String {
        let names = summary.travelerNames
        guard !names.isEmpty else { return "" }
        return ListFormatter.localizedString(byJoining: names)
    }

    private var statusText: String {
        if summary.exceedsAllowedStay, let tripLengthDays, let allowedDays = summary.allowedDays {
            if isGroupTrip, summary.travelerCount > 0 {
                return String(format: String(localized: "trip_planner.visa.group_overstay_status_format"), locale: AppDisplayLocale.current, travelerPreview, allowedDays, tripLengthDays)
            }
            return String(format: String(localized: "trip_planner.visa.solo_overstay_status_format"), locale: AppDisplayLocale.current, allowedDays, tripLengthDays)
        }

        if isGroupTrip, summary.travelerCount > 0 {
            if summary.travelerCount == 1 {
                return String(format: String(localized: "trip_planner.visa.one_traveler_needs_visa_format"), locale: AppDisplayLocale.current, travelerPreview)
            }
            return String(format: String(localized: "trip_planner.visa.multiple_travelers_need_visa_format"), locale: AppDisplayLocale.current, travelerPreview)
        }

        let label = summary.passportLabels.first ?? passportLabel
        let country = Country(iso2: summary.countryID, name: summary.countryName, score: nil).applyingVisa(
            visaEaseScore: nil,
            visaType: summary.visaType,
            visaAllowedDays: summary.allowedDays,
            visaFeeUsd: nil,
            visaNotes: nil,
            visaSourceUrl: nil,
            visaPassportCode: nil,
            visaPassportLabel: label,
            visaRecommendedPassportLabel: nil
        )
        return CountryVisaHelpers.headline(for: country, passportLabel: label)
    }

    var body: some View {
        NavigationLink {
            CountryDetailView(country: countryDestination)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(summary.countryFlag) \(CountrySelectionFormatter.localizedName(for: summary.countryID))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)

                    Text(statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.78))
                }

                Spacer(minLength: 0)

                Image(systemName: summary.exceedsAllowedStay ? "exclamationmark.triangle.fill" : "chevron.forward.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black.opacity(0.42))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95).opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TripPlannerScoreHighlightCard: View {
    let title: String
    let subtitle: String
    let score: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black.opacity(0.62))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let score {
                ScorePill(score: score)
                    .fixedSize(horizontal: true, vertical: true)
            } else {
                Text("trip_planner.stats.na")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: true, vertical: true)
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.66))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.93))
        )
    }
}

private struct TripPlannerScoreAverage: Identifiable {
    let title: String
    let subtitle: String
    let score: Int?

    var id: String { title }
}

private struct TripPlannerCategoryAverageCard: View {
    let metric: TripPlannerScoreAverage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            if let score = metric.score {
                ScorePill(score: score)
                    .fixedSize(horizontal: true, vertical: true)
            } else {
                Text("trip_planner.stats.na")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black.opacity(0.58))
                    .fixedSize(horizontal: true, vertical: true)
            }

            Text(metric.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.66))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.91))
        )
    }
}

private struct TripPlannerCostBreakdownLine: Identifiable {
    let title: String
    let amount: Double
    let detail: String

    var id: String { title }
}

private struct TripPlannerEstimatedCostBreakdownCard: View {
    @EnvironmentObject private var currencyPreferenceStore: CurrencyPreferenceStore

    let breakdown: [TripPlannerCostBreakdownLine]
    let totalAmount: Double
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated cost breakdown")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)

            ForEach(breakdown) { line in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)

                        Text(line.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.black.opacity(0.62))
                    }

                    Spacer()

                    AppCurrencyAmountLabel(
                        amount: TripPlannerCurrencyDisplay.amountFromUSD(
                            line.amount,
                            currencyCode: currencyCode,
                            snapshot: currencyPreferenceStore.exchangeRateSnapshot
                        ),
                        currencyCode: currencyCode,
                        font: .system(size: 13, weight: .bold),
                        fontSize: 13,
                        color: .black
                    )
                }
            }

            Divider()

            HStack {
                Text("Estimated total")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                AppCurrencyAmountLabel(
                    amount: TripPlannerCurrencyDisplay.amountFromUSD(
                        totalAmount,
                        currencyCode: currencyCode,
                        snapshot: currencyPreferenceStore.exchangeRateSnapshot
                    ),
                    currencyCode: currencyCode,
                    font: .system(size: 14, weight: .black),
                    fontSize: 14,
                    color: .black
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
    }

}

private struct TripPlannerCountryLanguageProfile: Decodable {
    let countryISO2: String
    let languages: [TripPlannerCountryLanguageCoverage]

    enum CodingKeys: String, CodingKey {
        case countryISO2 = "country_iso2"
        case languages
    }
}

private struct TripPlannerCountryLanguageCoverage: Decodable, Hashable {
    let code: String
    let type: String
    let coverage: Double
}

private actor TripPlannerCountryLanguageProfileStore {
    static let shared = TripPlannerCountryLanguageProfileStore()

    private var cache: [String: TripPlannerCountryLanguageProfile] = [:]
    private var missingISO2: Set<String> = []

    func profile(for iso2: String) async throws -> TripPlannerCountryLanguageProfile? {
        let normalizedISO2 = iso2.uppercased()

        if let cached = cache[normalizedISO2] {
            return cached
        }

        if missingISO2.contains(normalizedISO2) {
            return nil
        }

        let response: PostgrestResponse<[TripPlannerCountryLanguageProfile]> = try await SupabaseManager.shared.client
            .from("country_language_profiles")
            .select("country_iso2,languages")
            .eq("country_iso2", value: normalizedISO2)
            .limit(1)
            .execute()

        guard let profile = response.value.first else {
            missingISO2.insert(normalizedISO2)
            return nil
        }

        cache[normalizedISO2] = profile
        return profile
    }
}

private enum TripPlannerGroupLanguageCompatibilityScorer {
    static func score(
        travelerLanguages: [Profile.LanguageJSON],
        countryProfile: TripPlannerCountryLanguageProfile
    ) -> Int? {
        guard !countryProfile.languages.isEmpty else { return 0 }

        let spokenCodes = Set(
            travelerLanguages.flatMap { language in
                Array(LanguageRepository.shared.compatibilityLanguageCodes(for: language.code))
            }
        )

        guard !spokenCodes.isEmpty else { return nil }

        let countryCodes = Set(
            countryProfile.languages.flatMap { coverage in
                Array(LanguageRepository.shared.compatibilityLanguageCodes(for: coverage.code))
            }
        )

        return spokenCodes.isDisjoint(with: countryCodes) ? 0 : 100
    }
}

private struct TripPlannerStatPill: View {
    let title: String
    let detail: String
    private let valueText: String?
    private let valueView: AnyView?
    var accessorySystemImage: String? = nil
    var action: (() -> Void)? = nil

    init(
        title: String,
        value: String,
        detail: String,
        accessorySystemImage: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.valueText = value
        self.valueView = nil
        self.accessorySystemImage = accessorySystemImage
        self.action = action
    }

    init<V: View>(
        title: String,
        detail: String,
        accessorySystemImage: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder valueView: () -> V
    ) {
        self.title = title
        self.detail = detail
        self.valueText = nil
        self.valueView = AnyView(valueView())
        self.accessorySystemImage = accessorySystemImage
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black.opacity(0.62))

                Spacer(minLength: 0)

                if let accessorySystemImage {
                    Image(systemName: accessorySystemImage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black.opacity(0.46))
                }
            }

            if let valueView {
                valueView
            } else if let valueText {
                Text(valueText)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.black)
            }

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }
}

private extension Array where Element == Double {
    var averageOrZero: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

private struct TripPlannerAvailabilitySection: View {
    let trip: TripPlannerTrip

    private var overlaps: [TripPlannerAvailabilityOverlap] {
        TripPlannerAvailabilityCalculator.overlaps(for: trip)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if trip.availability.isEmpty {
                TripPlannerInfoCard(
                    text: trip.isGroupTrip
                        ? String(localized: "trip_planner.availability.summary_empty_group")
                        : String(localized: "trip_planner.availability.summary_empty_solo")
                    ,
                    systemImage: "calendar.badge.plus"
                )
            } else {
                TripPlannerAvailabilityCalendarBoard(trip: trip)

                VStack(alignment: .leading, spacing: 8) {
                    Text("trip_planner.availability.best_shared_windows")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)

                    if overlaps.isEmpty {
                        TripPlannerInfoCard(
                            text: String(localized: "trip_planner.availability.summary_no_shared_window"),
                            systemImage: "sparkles"
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(overlaps.prefix(3)) { overlap in
                                TripPlannerOverlapCard(overlap: overlap)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TripPlannerAvailabilityPreviewSection: View {
    let trip: TripPlannerTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if trip.availability.isEmpty {
                TripPlannerInfoCard(
                    text: trip.isGroupTrip
                        ? String(localized: "trip_planner.availability.summary_empty_group")
                        : String(localized: "trip_planner.availability.summary_empty_solo"),
                    systemImage: "calendar.badge.plus"
                )
            } else {
                TripPlannerAvailabilityCalendarBoard(trip: trip)
            }
        }
    }
}

private struct TripPlannerAvailabilityCalendarBoard: View {
    let trip: TripPlannerTrip
    @State private var selectedMonthPage: Date

    init(trip: TripPlannerTrip) {
        self.trip = trip
        _selectedMonthPage = State(
            initialValue: TripPlannerAvailabilityCalculator.primaryDisplayMonth(for: trip)
                ?? TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
        )
    }

    private var proposalsByParticipant: [(TripPlannerAvailabilityParticipant, [TripPlannerAvailabilityProposal])] {
        let currentUserId = SupabaseManager.shared.currentUserId
        let normalizedProposals = trip.normalizedAvailabilityProposals(currentUserId: currentUserId)
        return trip.availabilityParticipants(currentUserId: currentUserId).map { participant in
            let participantProposals = normalizedProposals.filter { $0.participantId == participant.id }
            return (participant, participantProposals)
        }
    }

    private var everyoneHasAvailability: Bool {
        !proposalsByParticipant.isEmpty && proposalsByParticipant.allSatisfy { !$0.1.isEmpty }
    }

    private var monthsToDisplay: [Date] {
        let calendar = Calendar.current
        let allDates = trip.normalizedAvailabilityProposals(currentUserId: SupabaseManager.shared.currentUserId).flatMap { [$0.startDate, $0.endDate] }

        guard
            let minDate = allDates.min(),
            let maxDate = allDates.max()
        else {
            if let primary = TripPlannerAvailabilityCalculator.primaryDisplayMonth(for: trip) {
                return [primary]
            }
            return []
        }

        let startMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: minDate)
        let endMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: maxDate)

        var months: [Date] = []
        var current = startMonth

        while current <= endMonth {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }

        return months
    }

    private var currentMonthPage: Date? {
        if monthsToDisplay.contains(selectedMonthPage) {
            return selectedMonthPage
        }
        return monthsToDisplay.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(proposalsByParticipant.enumerated()), id: \.1.0.id) { index, entry in
                        let participant = entry.0

                        TripPlannerAvailabilityParticipantBubble(
                            participant: participant,
                            color: TripPlannerAvailabilityTheme.color(for: participant.id, index: index),
                            isComplete: !entry.1.isEmpty
                        )
                    }

                    TripPlannerAvailabilityEveryoneBubble(isComplete: everyoneHasAvailability)
                }
            }

            if let currentMonthPage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button {
                            moveMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.white.opacity(0.82)))
                        }
                        .buttonStyle(.plain)
                        .disabled(previousMonth == nil)
                        .opacity(previousMonth == nil ? 0.35 : 1)

                        Spacer()

                        Text(TripPlannerAvailabilityCalculator.monthTitle(for: currentMonthPage))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TripPlannerAvailabilityTheme.ink.opacity(0.68))

                        Spacer()

                        Button {
                            moveMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(TripPlannerAvailabilityTheme.ink)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.white.opacity(0.82)))
                        }
                        .buttonStyle(.plain)
                        .disabled(nextMonth == nil)
                        .opacity(nextMonth == nil ? 0.35 : 1)
                    }

                    TripPlannerAvailabilityMonthCard(
                        month: currentMonthPage,
                        proposalsByParticipant: proposalsByParticipant
                    )
                }
            }
        }
        .onAppear {
            logParticipantResolution("appear")
        }
    }

    private var currentMonthIndex: Int? {
        guard let currentMonthPage else { return nil }
        return monthsToDisplay.firstIndex(of: currentMonthPage)
    }

    private var previousMonth: Date? {
        guard let index = currentMonthIndex, index > 0 else { return nil }
        return monthsToDisplay[index - 1]
    }

    private var nextMonth: Date? {
        guard let index = currentMonthIndex, index + 1 < monthsToDisplay.count else { return nil }
        return monthsToDisplay[index + 1]
    }

    private func moveMonth(by offset: Int) {
        guard let index = currentMonthIndex else { return }
        let nextIndex = index + offset
        guard monthsToDisplay.indices.contains(nextIndex) else { return }
        selectedMonthPage = monthsToDisplay[nextIndex]
    }

    private func logParticipantResolution(_ context: String) {
        let currentUserId = SupabaseManager.shared.currentUserId
        let participants = trip.availabilityParticipants(currentUserId: currentUserId)
        let normalizedProposals = trip.normalizedAvailabilityProposals(currentUserId: currentUserId)
        TripPlannerDebugLog.probe(
            "TripPlannerAvailabilityCalendarBoard.participants",
            "context=\(context) trip=\(TripPlannerDebugLog.tripLabel(trip)) current=\(TripPlannerDebugLog.userLabel(currentUserId)) owner=\(TripPlannerDebugLog.userLabel(trip.ownerId)) ownerSnapshot=\(trip.effectiveOwnerSnapshot?.displayName ?? "nil") participants=\(participants.map { "\($0.id)=\($0.name)" }.joined(separator: ",")) proposals=\(normalizedProposals.map { "\($0.participantId)=\($0.participantName):\($0.kind.rawValue)" }.joined(separator: ","))"
        )
    }
}

private struct TripPlannerAvailabilityMonthCard: View {
    let month: Date
    let proposalsByParticipant: [(TripPlannerAvailabilityParticipant, [TripPlannerAvailabilityProposal])]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var daySlots: [Date?] {
        TripPlannerAvailabilityCalculator.daySlots(for: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TripPlannerAvailabilityCalculator.monthTitle(for: month))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TripPlannerAvailabilityTheme.ink)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TripPlannerAvailabilityCalculator.weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TripPlannerAvailabilityTheme.ink.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(daySlots.enumerated()), id: \.offset) { _, day in
                    if let day {
                        TripPlannerAvailabilityDayCell(
                            date: day,
                            month: month,
                            proposalsByParticipant: proposalsByParticipant
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

private struct TripPlannerAvailabilityDayCell: View {
    let date: Date
    let month: Date
    let proposalsByParticipant: [(TripPlannerAvailabilityParticipant, [TripPlannerAvailabilityProposal])]

    private var inMonth: Bool {
        Calendar.current.isDate(date, equalTo: month, toGranularity: .month)
    }

    private var availableColors: [Color] {
        proposalsByParticipant.enumerated().compactMap { index, entry in
            let hasAvailability = entry.1.contains { proposal in
                TripPlannerAvailabilityCalculator.includes(date: date, in: proposal)
            }
            guard hasAvailability else { return nil }
            return TripPlannerAvailabilityTheme.color(for: entry.0.id, index: index)
        }
    }

    private var isSharedDay: Bool {
        !availableColors.isEmpty && availableColors.count == proposalsByParticipant.count
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textColor)

            HStack(spacing: 2) {
                ForEach(Array(availableColors.prefix(3).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .opacity(inMonth ? 1 : 0.35)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSharedDay {
            return TripPlannerAvailabilityTheme.gold
        }
        if !availableColors.isEmpty {
            return Color.white.opacity(0.92)
        }
        return Color.white.opacity(0.48)
    }

    private var borderColor: Color {
        if isSharedDay {
            return TripPlannerAvailabilityTheme.goldDeep.opacity(0.34)
        }
        if !availableColors.isEmpty {
            return TripPlannerAvailabilityTheme.ink.opacity(0.1)
        }
        return .clear
    }

    private var textColor: Color {
        TripPlannerAvailabilityTheme.ink
    }
}

private struct TripPlannerProposalChip: View {
    let proposal: TripPlannerAvailabilityProposal
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(TripPlannerAvailabilityCalculator.label(for: proposal))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.88))
        )
    }
}

private struct TripPlannerOverlapCard: View {
    let overlap: TripPlannerAvailabilityOverlap

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: overlap.isFullMatch ? "checkmark.seal.fill" : "calendar.badge.clock")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)

            VStack(alignment: .leading, spacing: 4) {
                Text(TripPlannerDateFormatter.rangeText(start: overlap.startDate, end: overlap.endDate) ?? String(localized: "trip_planner.availability.shared_window"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)

                Text(overlap.isFullMatch
                    ? String(localized: "trip_planner.availability.overlap_full_match")
                    : String(
                        format: String(localized: "trip_planner.availability.overlap_partial_match"),
                        locale: AppDisplayLocale.current,
                        overlap.exactParticipantCount,
                        overlap.totalParticipantCount
                    ))
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.68))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct TripPlannerSavedTripCard: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var hasLoggedInitialAppearance = false
    let trip: TripPlannerTrip
    let isNewSharedTrip: Bool
    let currentUserSnapshot: TripPlannerFriendSnapshot?
    let ownerSnapshot: TripPlannerFriendSnapshot?
    let onOpen: () -> Void
    let onOpenCountry: (Country) -> Void
    let onDelete: () -> Void
    let onAddToCalendar: () -> Void
    private let profileService = ProfileService(supabase: SupabaseManager.shared)

    private var isDisplayedGroupTrip: Bool {
        travelerChips.count > 1
            || (trip.ownerId != nil && trip.ownerId != sessionManager.userId)
    }

    private var ownerChip: TripPlannerTravelerChip? {
        guard let ownerId = trip.ownerId,
              ownerId != sessionManager.userId,
              !trip.friends.contains(where: { $0.id == ownerId }) else {
            return nil
        }

        if let ownerSnapshot = ownerSnapshot ?? trip.effectiveOwnerSnapshot {
            return TripPlannerTravelerChip(
                id: ownerSnapshot.id.uuidString,
                name: ownerSnapshot.displayName,
                username: ownerSnapshot.username,
                avatarURL: ownerSnapshot.avatarURL
            )
        }

        if let cachedProfile = profileService.cachedProfile(userId: ownerId) {
            return TripPlannerTravelerChip(
                id: cachedProfile.id.uuidString,
                name: cachedProfile.tripDisplayName,
                username: cachedProfile.username,
                avatarURL: cachedProfile.avatarUrl
            )
        }

        return nil
    }

    private var currentUserChip: TripPlannerTravelerChip? {
        if let currentUserSnapshot {
            return TripPlannerTravelerChip(
                id: currentUserSnapshot.id.uuidString,
                name: String(localized: "trip_planner.you"),
                username: currentUserSnapshot.username,
                avatarURL: currentUserSnapshot.avatarURL
            )
        }

        guard let currentUserId = sessionManager.userId,
              !trip.friends.contains(where: { $0.id == currentUserId }) else {
            return nil
        }

        if let cachedProfile = profileService.cachedProfile(userId: currentUserId) {
            return TripPlannerTravelerChip(
                id: cachedProfile.id.uuidString,
                name: String(localized: "trip_planner.you"),
                username: cachedProfile.username,
                avatarURL: cachedProfile.avatarUrl
            )
        }

        return TripPlannerTravelerChip(
            id: currentUserId.uuidString,
            name: String(localized: "trip_planner.you"),
            username: String(localized: "trip_planner.you"),
            avatarURL: nil
        )
    }

    private var travelerChips: [TripPlannerTravelerChip] {
        var chips: [TripPlannerTravelerChip] = []

        let participantSnapshots: [TripPlannerFriendSnapshot]
        if trip.friends.isEmpty {
            participantSnapshots = zip(trip.friendIds, trip.friendNames).map { id, name in
                TripPlannerFriendSnapshot(
                    id: id,
                    displayName: name,
                    username: name.replacingOccurrences(of: " ", with: "").lowercased(),
                    avatarURL: nil
                )
            }
        } else {
            participantSnapshots = trip.friends
        }

        if let currentUserChip {
            chips.append(currentUserChip)
        }

        if let ownerChip {
            chips.append(ownerChip)
        }

        chips.append(contentsOf: participantSnapshots.map {
            TripPlannerTravelerChip(
                id: $0.id.uuidString,
                name: $0.displayName,
                username: $0.username,
                avatarURL: $0.avatarURL
            )
        })

        var seen = Set<String>()
        return chips.filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if isNewSharedTrip {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 11, weight: .black))

                            Text("New shared trip")
                                .font(.system(size: 11, weight: .black))
                                .tracking(0.3)
                        }
                        .foregroundStyle(Color(red: 0.52, green: 0.24, blue: 0.08))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.78))
                        )
                    }

                    Text(trip.title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(isDisplayedGroupTrip ? String(localized: "trip_planner.detail.group_trip") : String(localized: "trip_planner.detail.solo_trip"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.62))
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.75)))
                }
                .buttonStyle(.plain)
            }

            if let rangeText = TripPlannerDateFormatter.rangeText(start: trip.startDate, end: trip.endDate) {
                Label(rangeText, systemImage: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.8))
            }

            if !travelerChips.isEmpty {
                HStack(alignment: .center, spacing: 14) {
                    TripPlannerAvatarStack(travelers: travelerChips)
                    TripPlannerTravelerNameList(travelers: travelerChips)
                }
            }

            TripPlannerSavedTripCountryPreview(
                countryIds: trip.countryIds,
                onOpenCountry: onOpenCountry
            )

            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.74))
            }

            if trip.startDate != nil, trip.endDate != nil {
                Button {
                    onAddToCalendar()
                } label: {
                    Label("trip_planner.actions.add_to_calendar", systemImage: "calendar.badge.plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.85))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture(perform: onOpen)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
        .onAppear {
            guard !hasLoggedInitialAppearance else { return }
            hasLoggedInitialAppearance = true
            TripPlannerDebugLog.probe(
                "TripPlannerSavedTripCard.onAppear",
                TripPlannerDebugLog.tripCardState(
                    trip: trip,
                    ownerSnapshot: ownerSnapshot ?? trip.effectiveOwnerSnapshot,
                    travelerCount: travelerChips.count
                )
            )
            TripPlannerDebugLog.message(
                "Saved trip card appeared \(TripPlannerDebugLog.tripCardState(trip: trip, ownerSnapshot: ownerSnapshot ?? trip.effectiveOwnerSnapshot, travelerCount: travelerChips.count))"
            )
        }
    }
}

private struct TripPlannerSharedTripNotificationCard: View {
    let trip: TripPlannerTrip
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label("Shared trip", systemImage: "bell.badge.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black.opacity(0.72))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.72))
                    )

                Spacer(minLength: 8)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white.opacity(0.76)))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                        .frame(width: 48, height: 48)

                    Image(systemName: "airplane.departure")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.black.opacity(0.82))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Added to your planner")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    Text(trip.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.86))

                    Text("This trip is ready to edit with the rest of the group.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.68))
                        .multilineTextAlignment(.leading)
                }
            }

            HStack(spacing: 8) {
                TripPlannerBadge(text: "Shared")

                if let rangeText = TripPlannerDateFormatter.rangeText(start: trip.startDate, end: trip.endDate) {
                    TripPlannerBadge(text: rangeText)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerLoadingStateCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.black.opacity(0.82))

            Text("Loading your trips")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerEmptyStateCard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "suitcase.rolling.fill")
                .font(.system(size: 32))
                .foregroundStyle(.black.opacity(0.82))

            Text("trip_planner.empty.title")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)

            Text("trip_planner.empty.subtitle")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black.opacity(0.72))

            Text("trip_planner.empty.cta")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                )
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerEditableSectionCard<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String
    let accessory: Accessory
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        let hasSubtitle = !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: hasSubtitle ? 4 : 0) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    if hasSubtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(.black.opacity(0.68))
                    }
                }

                Spacer()
                accessory
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: subtitle.isEmpty ? 0 : 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.68))
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
    }
}

private struct TripPlannerNavigationSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: subtitle.isEmpty ? 0 : 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(.black.opacity(0.68))
                    }
                }

                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.45), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 10, y: 6)

            Image(systemName: "chevron.forward")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.black.opacity(0.62))
                .padding(18)
        }
    }
}

private struct TripPlannerCountryList: View {
    let countries: [Country]
    let selectedIds: Set<String>
    let bucketIds: Set<String>
    let sharedIds: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(countries) { country in
                Button {
                    onTap(country.id)
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flagEmoji)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(country.localizedDisplayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)

                            HStack(spacing: 6) {
                                if bucketIds.contains(country.id) {
                                    TripPlannerBadge(text: String(localized: "planning.list_kind.bucket.short"))
                                }

                                if sharedIds.contains(country.id) {
                                    TripPlannerBadge(text: String(localized: "trip_planner.shared"))
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: selectedIds.contains(country.id) ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(selectedIds.contains(country.id) ? 0.9 : 0.72))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TripPlannerFriendRow: View {
    let profile: Profile
    let isSelected: Bool
    let displayName: String
    var mutualBucketCount: Int? = nil

    var body: some View {
        HStack(spacing: 12) {
            TripPlannerAvatarView(
                name: displayName,
                username: profile.username,
                avatarURL: profile.avatarUrl,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let mutualBucketCount {
                        Text(String(format: String(localized: "trip_planner.friends.mutual_count_format"), locale: AppDisplayLocale.current, mutualBucketCount))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black.opacity(0.62))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.07))
                            )
                    }
                }

                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.62))
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.black)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.9 : 0.72))
        )
    }
}

private struct TripPlannerSelectedFriendCard: View {
    let friend: TripPlannerFriendSnapshot

    var body: some View {
        HStack(spacing: 12) {
            TripPlannerAvatarView(
                name: friend.displayName,
                username: friend.username,
                avatarURL: friend.avatarURL,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)

                Text("@\(friend.username)")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.62))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct TripPlannerTravelerChip: Identifiable {
    let id: String
    let name: String
    let username: String
    let avatarURL: String?
}

private struct TripPlannerTravelerChipGrid: View {
    let travelers: [TripPlannerTravelerChip]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 132), spacing: 10, alignment: .leading)
            ],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(travelers) { traveler in
                HStack(spacing: 10) {
                    TripPlannerAvatarView(
                        name: traveler.name,
                        username: traveler.username,
                        avatarURL: traveler.avatarURL,
                        size: 34
                    )

                    Text(traveler.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.8))
                )
            }
        }
    }
}

private struct TripPlannerAvatarStack: View {
    let travelers: [TripPlannerTravelerChip]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(travelers.prefix(5).enumerated()), id: \.element.id) { index, traveler in
                TripPlannerAvatarView(
                    name: traveler.name,
                    username: traveler.username,
                    avatarURL: traveler.avatarURL,
                    size: 36
                )
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.97, green: 0.94, blue: 0.88), lineWidth: 2)
                )
                .zIndex(Double(travelers.count - index))
            }

            if travelers.count > 5 {
                Text("+\(travelers.count - 5)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.86)))
                    .overlay(Circle().stroke(Color(red: 0.97, green: 0.94, blue: 0.88), lineWidth: 2))
                    .padding(.leading, 6)
            }
        }
    }
}

private struct TripPlannerTravelerNameList: View {
    let travelers: [TripPlannerTravelerChip]

    private var firstNamesText: String {
        travelers
            .map { traveler in
                let trimmed = traveler.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return traveler.username }
                return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
            }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
    }

    var body: some View {
        if !firstNamesText.isEmpty {
            Text(firstNamesText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.82))
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct TripPlannerAvatarView: View {
    let name: String
    let username: String
    let avatarURL: String?
    let size: CGFloat
    @State private var avatarLoadStart = Date().timeIntervalSinceReferenceDate

    private var initials: String {
        let source = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? username : name
        let parts = source.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        Group {
            if let avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .onAppear {
                                guard TripPlannerAvatarLogDeduper.shouldLog(
                                    key: "success:\(avatarURL)",
                                    cooldown: 60
                                ) else { return }
                                TripPlannerDebugLog.message(
                                    "Avatar loaded username=@\(username) duration=\(TripPlannerDebugLog.durationText(since: avatarLoadStart)) url=\(avatarURL)"
                                )
                            }
                    } else {
                        fallbackAvatar
                            .onAppear {
                                guard state.error != nil else { return }
                                guard TripPlannerAvatarLogDeduper.shouldLog(
                                    key: "failure:\(avatarURL)",
                                    cooldown: 60
                                ) else { return }
                                TripPlannerDebugLog.message(
                                    "Avatar failed username=@\(username) duration=\(TripPlannerDebugLog.durationText(since: avatarLoadStart)) url=\(avatarURL) error=\(String(describing: state.error))"
                                )
                            }
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            avatarLoadStart = Date().timeIntervalSinceReferenceDate
            if let avatarURL, !avatarURL.isEmpty {
                guard TripPlannerAvatarLogDeduper.shouldLog(
                    key: "request:\(avatarURL)",
                    cooldown: 60
                ) else { return }
                TripPlannerDebugLog.message("Avatar request started username=@\(username) url=\(avatarURL)")
            } else {
                guard TripPlannerAvatarLogDeduper.shouldLog(
                    key: "fallback:\(username.lowercased())",
                    cooldown: 60
                ) else { return }
                TripPlannerDebugLog.message("Avatar fallback used username=@\(username) reason=missing_url")
            }
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.08))

            Text(initials)
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))
        }
    }
}

private struct TripPlannerProfileDestinationView: View {
    let userId: UUID

    @StateObject private var socialNav = SocialNavigationController()

    var body: some View {
        ProfileView(userId: userId, showsBackButton: true)
            .environmentObject(socialNav)
            .navigationDestination(for: SocialRoute.self) { route in
                socialDestination(route)
            }
    }

    @ViewBuilder
    private func socialDestination(_ route: SocialRoute) -> some View {
        switch route {
        case .profile(let routeUserId):
            ProfileView(userId: routeUserId, showsBackButton: true)
                .environmentObject(socialNav)
        case .friends(let routeUserId):
            FriendsView(userId: routeUserId, showsBackButton: true)
                .environmentObject(socialNav)
        case .friendRequests:
            FriendRequestsView()
                .environmentObject(socialNav)
        }
    }
}

private struct TripPlannerFriendPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let friends: [Profile]
    let selectedIds: Set<UUID>
    let displayName: (Profile) -> String
    let mutualBucketCount: (UUID) -> Int
    let onToggle: (UUID) -> Void

    @State private var searchText = ""

    private var filteredFriends: [Profile] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return friends }

        return friends.filter { friend in
            let name = displayName(friend)
            return name.localizedCaseInsensitiveContains(trimmed)
                || friend.username.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TripPlannerTextInput(
                    title: String(localized: "trip_planner.friends.search_title"),
                    text: $searchText,
                    placeholder: String(localized: "trip_planner.friends.search_placeholder")
                )

                LazyVStack(spacing: 10) {
                    ForEach(filteredFriends) { friend in
                        Button {
                            onToggle(friend.id)
                        } label: {
                            TripPlannerFriendRow(
                                profile: friend,
                                isSelected: selectedIds.contains(friend.id),
                                displayName: displayName(friend),
                                mutualBucketCount: mutualBucketCount(friend.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(
            Theme.pageBackground("travel1")
                .ignoresSafeArea()
        )
        .navigationTitle(String(localized: "trip_planner.travel_friends"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.done")) {
                    dismiss()
                }
                .foregroundStyle(.black)
            }
        }
    }
}

private struct TripPlannerCountryPickerSection: Identifiable {
    let title: String
    let countries: [Country]

    var id: String { title }
}

private struct TripPlannerCountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let sections: [TripPlannerCountryPickerSection]
    let selectedIds: Set<String>
    let bucketIds: Set<String>
    let sharedIds: Set<String>
    let onTap: (String) -> Void

    @State private var searchText = ""

    private var filteredSections: [TripPlannerCountryPickerSection] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sections }

        return sections.compactMap { section in
            let filteredCountries = section.countries.filter { country in
                country.localizedSearchableNames.contains {
                    $0.localizedCaseInsensitiveContains(trimmed)
                }
                    || country.id.localizedCaseInsensitiveContains(trimmed)
            }
            guard !filteredCountries.isEmpty else { return nil }
            return TripPlannerCountryPickerSection(title: section.title, countries: filteredCountries)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TripPlannerTextInput(
                    title: String(localized: "trip_planner.countries.search_title"),
                    text: $searchText,
                    placeholder: String(localized: "trip_planner.countries.search_placeholder")
                )

                ForEach(filteredSections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)

                        TripPlannerCountryList(
                            countries: section.countries,
                            selectedIds: selectedIds,
                            bucketIds: bucketIds,
                            sharedIds: sharedIds,
                            onTap: onTap
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(
            Theme.pageBackground("travel1")
                .ignoresSafeArea()
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.done")) {
                    dismiss()
                }
                .foregroundStyle(.black)
            }
        }
    }
}

private struct TripPlannerChipItem: Identifiable, Hashable {
    let id: String
    let title: String
    let isSelected: Bool
}

private enum TripPlannerCountryLookup {
    static func countries(for ids: [String]) -> [Country] {
        let cachedCountries = CountryAPI.loadCachedCountries() ?? []
        let countriesByID = Dictionary(uniqueKeysWithValues: cachedCountries.map { ($0.id.uppercased(), $0) })

        let resolvedCountries = ids.map { id in
            let normalizedID = id.uppercased()
            if let country = countriesByID[normalizedID] {
                return country
            }

            return Country(
                iso2: normalizedID,
                name: CountrySelectionFormatter.localizedName(for: normalizedID),
                score: nil
            )
        }
        let summary = resolvedCountries.map { country in
            let currencyCode = TripPlannerCountryCurrencyLookup.currencyCode(for: country)
            return "\(country.id.uppercased())=\(currencyCode ?? "nil")"
        }.joined(separator: ",")
        TripPlannerDebugLog.probe(
            "TripPlannerCountryLookup.resolve",
            "ids=\(ids.joined(separator: ",")) cached=\(cachedCountries.count) resolved=\(summary)"
        )
        return resolvedCountries
    }
}

private enum TripPlannerCountryCurrencyLookup {
    private static let currencyCodesByCountryID: [String: String] = {
        var result: [String: String] = [:]

        for identifier in Locale.availableIdentifiers {
            let locale = Locale(identifier: identifier)
            guard let regionCode = locale.region?.identifier.uppercased(),
                  result[regionCode] == nil,
                  let currencyCode = AppCurrencyCatalog.normalizedCode(locale.currency?.identifier)
            else {
                continue
            }

            result[regionCode] = currencyCode
        }

        return result
    }()

    static func currencyCode(for country: Country) -> String? {
        country.currencyCode ?? currencyCode(forCountryID: country.id)
    }

    static func currencyCode(forCountryID countryID: String) -> String? {
        currencyCodesByCountryID[countryID.uppercased()]
    }
}

private struct TripPlannerCountryNavigationGrid: View {
    let countries: [Country]
    let onOpenCountry: (Country) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(countries) { country in
                Button {
                    onOpenCountry(country)
                } label: {
                    HStack(spacing: 8) {
                        Text("\(country.flagEmoji) \(country.localizedDisplayName)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.78))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TripPlannerSavedTripCountryPreview: View {
    let countryIds: [String]
    let onOpenCountry: (Country) -> Void

    private var previewCountries: [Country] {
        Array(TripPlannerCountryLookup.countries(for: countryIds).prefix(6))
    }

    private var remainingCount: Int {
        max(countryIds.count - previewCountries.count, 0)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(previewCountries) { country in
                Button {
                    onOpenCountry(country)
                } label: {
                    HStack(spacing: 7) {
                        Text("\(country.flagEmoji) \(country.localizedDisplayName)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black.opacity(0.44))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.78))
                    )
                }
                .buttonStyle(.plain)
            }

            if remainingCount > 0 {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))

                    Text("\(remainingCount) more")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black.opacity(0.68))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.58))
                )
            }
        }
    }
}

private struct TripPlannerChipGrid: View {
    let items: [TripPlannerChipItem]
    let onTap: (TripPlannerChipItem) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                Button {
                    onTap(item)
                } label: {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        if item.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(item.isSelected ? 0.95 : 0.78))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(item.isSelected ? Color.black.opacity(0.22) : Color.clear, lineWidth: 1.4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TripPlannerBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.black.opacity(0.72))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.08))
            )
    }
}

private struct TripPlannerInfoCard: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black.opacity(0.7))
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.74))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.68))
        )
    }
}

private struct TripPlannerTextInput: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black.opacity(0.72))

            Group {
                if axis == .vertical {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(4...8)
                } else {
                    TextField(placeholder, text: $text)
                        .lineLimit(1)
                }
            }
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .foregroundStyle(.black)
        }
    }
}

private struct TripPlannerCurrencyInput: View {
    let title: String
    let currencyCode: String
    var currencySelection: Binding<String>? = nil
    var suggestedCurrencyCodes: [String?] = []
    @Binding var text: String
    let placeholder: String
    @State private var loggedSuggestionSignature: String?

    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    private var normalizedSuggestedCurrencyCodes: [String] {
        var seen = Set<String>()
        return suggestedCurrencyCodes.compactMap { rawCode in
            guard let code = AppCurrencyCatalog.normalizedCode(rawCode),
                  seen.insert(code).inserted
            else {
                return nil
            }
            return code
        }
    }

    private var regularCurrencyCodes: [String] {
        let suggestedCodes = Set(normalizedSuggestedCurrencyCodes)
        return AppCurrencyCatalog.supportedCodes.filter { !suggestedCodes.contains($0) }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black.opacity(0.72))

            HStack(spacing: 8) {
                if let currencySelection {
                    Menu {
                        if !normalizedSuggestedCurrencyCodes.isEmpty {
                            Section("Suggested") {
                                ForEach(normalizedSuggestedCurrencyCodes, id: \.self) { code in
                                    currencyMenuButton(code: code, currencySelection: currencySelection)
                                }
                            }

                            Divider()
                        }

                        ForEach(regularCurrencyCodes, id: \.self) { code in
                            currencyMenuButton(code: code, currencySelection: currencySelection)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                            Text(AppCurrencyCatalog.symbol(for: currencyCode))
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.trailing, 4)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(AppCurrencyCatalog.symbol(for: currencyCode))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }

                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: text) { _, newValue in
                        let sanitized = sanitizedCurrencyText(from: newValue)
                        if sanitized != newValue {
                            text = sanitized
                        }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            logSuggestedCurrenciesIfNeeded(context: "appear")
        }
        .onChange(of: normalizedSuggestedCurrencyCodes) { _, _ in
            logSuggestedCurrenciesIfNeeded(context: "change")
        }
    }

    private func currencyMenuButton(code: String, currencySelection: Binding<String>) -> some View {
        Button("\(AppCurrencyCatalog.displayName(for: code)) (\(code))") {
            currencySelection.wrappedValue = code
        }
    }

    private func sanitizedCurrencyText(from rawValue: String) -> String {
        var result = ""
        var hasDecimalSeparator = false
        var fractionalDigitCount = 0

        for character in rawValue {
            if character.isNumber {
                if hasDecimalSeparator {
                    guard fractionalDigitCount < 2 else { continue }
                    fractionalDigitCount += 1
                }
                result.append(character)
                continue
            }

            if String(character) == decimalSeparator, !hasDecimalSeparator {
                hasDecimalSeparator = true
                result.append(character)
            }
        }

        return result
    }

    private func logSuggestedCurrenciesIfNeeded(context: String) {
        let normalized = normalizedSuggestedCurrencyCodes
        let raw = suggestedCurrencyCodes.map { $0 ?? "nil" }
        let signature = "\(title)|\(currencyCode)|\(normalized.joined(separator: ","))|\(raw.joined(separator: ","))"
        guard loggedSuggestionSignature != signature else { return }
        loggedSuggestionSignature = signature
        TripPlannerDebugLog.probe(
            "TripPlannerCurrencyInput.suggestions",
            "context=\(context) title=\(title) current=\(currencyCode) normalized=\(normalized.joined(separator: ",")) raw=\(raw.joined(separator: ","))"
        )
    }
}

private enum TripPlannerAvailabilityTheme {
    static let gold = Color(red: 0.91, green: 0.80, blue: 0.38)
    static let goldDeep = Color(red: 0.66, green: 0.48, blue: 0.12)
    static let ink = Color(red: 0.24, green: 0.18, blue: 0.10)

    private static let palette: [Color] = [
        Color(red: 0.82, green: 0.46, blue: 0.36),
        Color(red: 0.30, green: 0.56, blue: 0.78),
        Color(red: 0.52, green: 0.66, blue: 0.34),
        Color(red: 0.74, green: 0.56, blue: 0.78),
        Color(red: 0.88, green: 0.68, blue: 0.30),
        Color(red: 0.31, green: 0.63, blue: 0.57)
    ]

    static func color(for participantId: String, index: Int) -> Color {
        let seed = abs(participantId.hashValue + index)
        return palette[seed % palette.count]
    }
}

private enum TripPlannerAvailabilityCalculator {
    static func overlaps(for trip: TripPlannerTrip, proposals: [TripPlannerAvailabilityProposal]? = nil) -> [TripPlannerAvailabilityOverlap] {
        let currentUserId = SupabaseManager.shared.currentUserId
        let proposals = proposals ?? trip.normalizedAvailabilityProposals(currentUserId: currentUserId)
        let participants = trip.availabilityParticipants(currentUserId: currentUserId)
        guard participants.count > 1 else { return [] }

        let grouped = participants.map { participant in
            proposals
                .filter { $0.participantId == participant.id }
                .map { interval(for: $0) }
        }

        guard grouped.allSatisfy({ !$0.isEmpty }) else { return [] }

        let normalized = grouped.map(merge(_:))
        let exactCounts = participants.reduce(into: [String: Int]()) { partial, participant in
            partial[participant.id] = proposals.filter {
                $0.participantId == participant.id && $0.kind == .exactDates
            }.count
        }

        var matches: [TripPlannerAvailabilityOverlap] = []
        let first = normalized[0]
        for baseInterval in first {
            var intersections = [baseInterval]
            for other in normalized.dropFirst() {
                intersections = intersections.flatMap { current in
                    other.compactMap { candidate in
                        intersect(current, candidate)
                    }
                }
                if intersections.isEmpty { break }
            }

            for result in intersections {
                let exactCount = participants.reduce(into: 0) { count, participant in
                    let hasExactMatch = proposals.contains { proposal in
                        proposal.participantId == participant.id
                            && proposal.kind == .exactDates
                            && interval(for: proposal).intersects(result)
                    }
                    if hasExactMatch {
                        count += 1
                    } else if exactCounts[participant.id] == 0 {
                        count += 1
                    }
                }

                matches.append(
                    TripPlannerAvailabilityOverlap(
                        startDate: result.start,
                        endDate: result.end,
                        exactParticipantCount: exactCount,
                        totalParticipantCount: participants.count
                    )
                )
            }
        }

        return merge(matches)
            .sorted {
                if $0.exactParticipantCount == $1.exactParticipantCount {
                    return $0.startDate < $1.startDate
                }
                return $0.exactParticipantCount > $1.exactParticipantCount
            }
    }

    static func visibleMonths(for trip: TripPlannerTrip) -> [Date] {
        let calendar = Calendar.current
        let dates = trip.availability.flatMap { [$0.startDate, $0.endDate] } + [trip.startDate, trip.endDate].compactMap { $0 }
        let anchor = dates.min() ?? Date()
        let start = startOfMonth(for: anchor)
        return (0..<6).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }

    static func primaryDisplayMonth(for trip: TripPlannerTrip) -> Date? {
        if let overlap = overlaps(for: trip).first {
            return startOfMonth(for: overlap.startDate)
        }

        if let startDate = trip.startDate {
            return startOfMonth(for: startDate)
        }

        if let proposal = trip.availability.sorted(by: { lhs, rhs in
            if lhs.kind == rhs.kind {
                return lhs.startDate < rhs.startDate
            }
            return lhs.kind == .exactDates
        }).first {
            return startOfMonth(for: proposal.startDate)
        }

        return nil
    }

    static func label(for proposal: TripPlannerAvailabilityProposal) -> String {
        switch proposal.kind {
        case .exactDates:
            return String(format: String(localized: "trip_planner.availability.label_exact_format"), locale: AppDisplayLocale.current, TripPlannerDateFormatter.rangeText(start: proposal.startDate, end: proposal.endDate) ?? String(localized: "trip_planner.availability.label_dates"))
        case .flexibleMonth:
            return String(format: String(localized: "trip_planner.availability.label_flexible_format"), locale: AppDisplayLocale.current, monthTitle(for: proposal.startDate))
        }
    }

    static func monthLabel(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: month)
    }

    static func monthTitle(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: month)
    }

    static func weekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = AppDisplayLocale.current
        return formatter.shortStandaloneWeekdaySymbols
    }

    static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func endOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = startOfMonth(for: date)
        return calendar.date(byAdding: .month, value: 1, to: start) ?? start
    }

    static func intersectsMonth(_ proposal: TripPlannerAvailabilityProposal, month: Date) -> Bool {
        interval(for: proposal).intersects(DateInterval(start: startOfMonth(for: month), end: endOfMonth(for: month)))
    }

    static func rangeIntersectsMonth(start: Date?, end: Date?, month: Date) -> Bool {
        guard let start, let end else { return false }
        return DateInterval(start: start, end: Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end).intersects(
            DateInterval(start: startOfMonth(for: month), end: endOfMonth(for: month))
        )
    }

    static func includes(date: Date, in proposal: TripPlannerAvailabilityProposal) -> Bool {
        includes(date: date, start: proposal.startDate, end: proposal.endDate)
    }

    static func includes(date: Date, start: Date?, end: Date?) -> Bool {
        guard let start, let end else { return false }
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        return normalizedDate >= normalizedStart && normalizedDate <= normalizedEnd
    }

    static func daySlots(for month: Date) -> [Date?] {
        let calendar = Calendar.current
        let monthStart = startOfMonth(for: month)
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingPadding = (firstWeekday - calendar.firstWeekday + 7) % 7

        var slots: [Date?] = Array(repeating: nil, count: leadingPadding)
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                slots.append(date)
            }
        }

        while slots.count % 7 != 0 {
            slots.append(nil)
        }

        return slots
    }

    nonisolated private static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.sorted { $0.start < $1.start }
        var result: [DateInterval] = []

        for interval in sorted {
            guard let last = result.last else {
                result.append(interval)
                continue
            }

            if last.intersects(interval) || Calendar.current.isDate(last.end, inSameDayAs: interval.start) {
                let merged = DateInterval(start: last.start, end: max(last.end, interval.end))
                result[result.count - 1] = merged
            } else {
                result.append(interval)
            }
        }

        return result
    }

    private static func interval(for proposal: TripPlannerAvailabilityProposal) -> DateInterval {
        DateInterval(
            start: proposal.startDate,
            end: Calendar.current.date(byAdding: .day, value: 1, to: proposal.endDate) ?? proposal.endDate
        )
    }

    private static func intersect(_ lhs: DateInterval, _ rhs: DateInterval) -> DateInterval? {
        let start = max(lhs.start, rhs.start)
        let end = min(lhs.end, rhs.end)
        guard start < end else { return nil }
        return DateInterval(start: start, end: end)
    }

    nonisolated private static func merge(_ overlaps: [TripPlannerAvailabilityOverlap]) -> [TripPlannerAvailabilityOverlap] {
        var result: [TripPlannerAvailabilityOverlap] = []

        for overlap in overlaps.sorted(by: { $0.startDate < $1.startDate }) {
            if let last = result.last,
               Calendar.current.isDate(last.startDate, inSameDayAs: overlap.startDate),
               Calendar.current.isDate(last.endDate, inSameDayAs: overlap.endDate),
               last.exactParticipantCount == overlap.exactParticipantCount {
                continue
            }
            result.append(overlap)
        }

        return result
    }
}

private enum TripPlannerDateFormatter {
    static func rangeText(start: Date?, end: Date?) -> String? {
        guard let start, let end else { return nil }
        return AppDateFormatting.dateRangeString(start: start, end: end)
    }
}

private struct TripPlannerCalendarSheet: UIViewControllerRepresentable {
    let draft: TripPlannerCalendarDraft

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = draft.store
        controller.event = draft.event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
        }
    }
}
