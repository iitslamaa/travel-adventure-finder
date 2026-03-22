//
//  PlanningView.swift
//  TravelScoreriOS
//
//  Created by Lama Yassine on 3/5/26.
//

import SwiftUI
import Combine
import EventKit
import EventKitUI
import NukeUI
import Supabase
import PostgREST

enum PlanningListKind {
    case bucket
    case visited

    var title: String {
        switch self {
        case .bucket: return "Bucket List"
        case .visited: return "Visited Countries"
        }
    }

    var shortTitle: String {
        switch self {
        case .bucket: return "Bucket"
        case .visited: return "Visited"
        }
    }

    var subtitle: String {
        switch self {
        case .bucket: return "Places you want to visit"
        case .visited: return "Track places you've been"
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
        case .bucket: return "Also visited"
        case .visited: return "Also in bucket"
        }
    }

    var otherListName: String {
        switch self {
        case .bucket: return "Visited"
        case .visited: return "Bucket"
        }
    }

    var pickerTitle: String {
        switch self {
        case .bucket: return "Edit Bucket List"
        case .visited: return "Edit Visited"
        }
    }

    var pickerSubtitle: String {
        switch self {
        case .bucket: return "Tap any country to add it or remove it from your bucket list."
        case .visited: return "Tap any country to add it or remove it from your visited list."
        }
    }

    var navigationTitle: String {
        switch self {
        case .bucket: return "🪣 Bucket List"
        case .visited: return "🎒 My Travels"
        }
    }

    var emptyTitle: String {
        switch self {
        case .bucket: return "No Bucket List Yet"
        case .visited: return "No trips yet"
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
        case .bucket: return "Tap Edit to add countries here, or swipe left on a country and tap Bucket."
        case .visited: return "Tap Edit to add countries here, or swipe left on a country and tap Visited."
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
    @State private var scrollAnchor: String? = nil

    var body: some View {
        VStack(spacing: 0) {

            Theme.titleBanner("Planning")

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {

                        NavigationLink {
                            BucketListView()
                        } label: {
                            PlanningCard(
                                title: "Bucket List",
                                subtitle: "Places you want to visit",
                                icon: "bookmark"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MyTravelsView()
                        } label: {
                            PlanningCard(
                                title: "Visited Countries",
                                subtitle: "Track places you've been",
                                icon: "checkmark.circle"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TripPlannerView()
                        } label: {
                            PlanningCard(
                                title: "Trip Planner",
                                subtitle: "Build a trip with dates, countries, and friends",
                                icon: "airplane.departure"
                            )
                        }
                        .buttonStyle(.plain)

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
            ? "Remove \(kind.shortTitle) for this country"
            : "Add \(kind.shortTitle) for this country"
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
                    Text(isSaving ? "Saving..." : "Save")
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

struct TripPlannerFriendSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarURL: String?
}

enum TripPlannerAvailabilityKind: String, Codable, CaseIterable, Identifiable {
    case exactDates
    case flexibleMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exactDates:
            return "Exact dates"
        case .flexibleMonth:
            return "Flexible month"
        }
    }

    var subtitle: String {
        switch self {
        case .exactDates:
            return "A specific range someone knows works."
        case .flexibleMonth:
            return "A month someone could likely make work."
        }
    }
}

struct TripPlannerAvailabilityProposal: Codable, Identifiable, Hashable {
    let id: UUID
    let participantId: String
    let participantName: String
    let participantUsername: String?
    let participantAvatarURL: String?
    let kind: TripPlannerAvailabilityKind
    let startDate: Date
    let endDate: Date
}

struct TripPlannerTrip: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let title: String
    let notes: String
    let startDate: Date?
    let endDate: Date?
    let countryIds: [String]
    let countryNames: [String]
    let friendIds: [UUID]
    let friendNames: [String]
    let friends: [TripPlannerFriendSnapshot]
    let availability: [TripPlannerAvailabilityProposal]

    var isGroupTrip: Bool {
        !friendIds.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case title
        case notes
        case startDate
        case endDate
        case countryIds
        case countryNames
        case friendIds
        case friendNames
        case friends
        case availability
    }

    init(
        id: UUID,
        createdAt: Date,
        title: String,
        notes: String,
        startDate: Date?,
        endDate: Date?,
        countryIds: [String],
        countryNames: [String],
        friendIds: [UUID],
        friendNames: [String],
        friends: [TripPlannerFriendSnapshot],
        availability: [TripPlannerAvailabilityProposal]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.countryIds = countryIds
        self.countryNames = countryNames
        self.friendIds = friendIds
        self.friendNames = friendNames
        self.friends = friends
        self.availability = availability
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decode(String.self, forKey: .notes)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
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
        availability = try container.decodeIfPresent([TripPlannerAvailabilityProposal].self, forKey: .availability) ?? []
    }
}

@MainActor
final class TripPlannerStore: ObservableObject {
    @Published private(set) var trips: [TripPlannerTrip] = []

    private let legacySaveKey = "trip_planner_trips_v1"
    private let guestSaveKey = "trip_planner_trips_guest_v1"
    private let supabase = SupabaseManager.shared
    private let syncService = TripPlannerSyncService(supabase: SupabaseManager.shared)
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadLocal()
        observeAuthState()

        Task {
            await refreshFromRemoteIfNeeded(migrateLocalTrips: true)
        }
    }

    func add(_ trip: TripPlannerTrip) {
        trips.insert(trip, at: 0)
        persistLocal()

        Task {
            await syncUpsert(trip)
        }
    }

    func upsert(_ trip: TripPlannerTrip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            trips.sort { $0.createdAt > $1.createdAt }
        } else {
            trips.insert(trip, at: 0)
        }
        persistLocal()

        Task {
            await syncUpsert(trip)
        }
    }

    func delete(id: UUID) {
        trips.removeAll { $0.id == id }
        persistLocal()

        Task {
            await syncDelete(id: id)
        }
    }

    private func observeAuthState() {
        supabase.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                Task {
                    await self.handleAuthStateChange()
                }
            }
            .store(in: &cancellables)
    }

    private func handleAuthStateChange() async {
        loadLocal()
        await refreshFromRemoteIfNeeded(migrateLocalTrips: true)
    }

    private var localSaveKey: String {
        guard let userId = supabase.currentUserId else {
            return guestSaveKey
        }

        return "trip_planner_trips_user_\(userId.uuidString)"
    }

    private func loadLocal() {
        let defaults = UserDefaults.standard
        let candidateKeys = [localSaveKey, legacySaveKey]

        for key in candidateKeys {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([TripPlannerTrip].self, from: data) else {
                continue
            }

            trips = decoded.sorted { $0.createdAt > $1.createdAt }
            return
        }

        trips = []
    }

    private func persistLocal() {
        guard let data = try? JSONEncoder().encode(trips) else { return }
        UserDefaults.standard.set(data, forKey: localSaveKey)
    }

    private func refreshFromRemoteIfNeeded(migrateLocalTrips: Bool) async {
        guard let userId = supabase.currentUserId else { return }

        let localTrips = trips

        do {
            let remoteTrips = try await syncService.fetchTrips(userId: userId)
            let mergedTrips = mergedTrips(local: localTrips, remote: remoteTrips)

            if migrateLocalTrips {
                let localOnlyTrips = mergedTrips.filter { mergedTrip in
                    !remoteTrips.contains(where: { $0.id == mergedTrip.id })
                }

                for trip in localOnlyTrips {
                    try await syncService.upsertTrip(userId: userId, trip: trip)
                }
            }

            trips = mergedTrips
            persistLocal()

            if !mergedTrips.isEmpty {
                UserDefaults.standard.removeObject(forKey: legacySaveKey)
            }
        } catch {
            print("❌ Trip planner sync failed:", error)
        }
    }

    private func syncUpsert(_ trip: TripPlannerTrip) async {
        guard let userId = supabase.currentUserId else { return }

        do {
            try await syncService.upsertTrip(userId: userId, trip: trip)
            let remoteTrips = try await syncService.fetchTrips(userId: userId)
            trips = mergedTrips(local: trips, remote: remoteTrips)
            persistLocal()
        } catch {
            print("❌ Trip planner upsert failed:", error)
        }
    }

    private func syncDelete(id: UUID) async {
        guard let userId = supabase.currentUserId else { return }

        do {
            try await syncService.deleteTrip(userId: userId, tripId: id)
        } catch {
            print("❌ Trip planner delete failed:", error)
        }
    }

    private func mergedTrips(local: [TripPlannerTrip], remote: [TripPlannerTrip]) -> [TripPlannerTrip] {
        var mergedByID = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })

        for trip in local where mergedByID[trip.id] == nil {
            mergedByID[trip.id] = trip
        }

        return mergedByID.values.sorted { $0.createdAt > $1.createdAt }
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

private struct TripPlannerSyncService {
    let supabase: SupabaseManager

    func fetchTrips(userId: UUID) async throws -> [TripPlannerTrip] {
        let rows: [TripPlannerRemoteTripRow] = try await supabase.client
            .from("user_trip_plans")
            .select("user_id,trip_id,trip_data")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return rows
            .map(\.tripData)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func upsertTrip(userId: UUID, trip: TripPlannerTrip) async throws {
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
    }

    func deleteTrip(userId: UUID, tripId: UUID) async throws {
        try await supabase.client
            .from("user_trip_plans")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("trip_id", value: tripId.uuidString)
            .execute()
    }
}

private struct TripPlannerCalendarDraft: Identifiable {
    let id = UUID()
    let store: EKEventStore
    let event: EKEvent
}

struct TripPlannerView: View {
    @StateObject private var store = TripPlannerStore()
    @State private var calendarDraft: TripPlannerCalendarDraft?
    @State private var calendarError: String?

    var body: some View {
        ZStack {
            Theme.pageBackground("travel5")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("Trip Planner")

                ScrollView {
                    VStack(spacing: 20) {
                        if store.trips.isEmpty {
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
                                    NavigationLink {
                                        TripPlannerDetailView(
                                            trip: trip,
                                            onSave: { updatedTrip in
                                                store.upsert(updatedTrip)
                                            },
                                            onDelete: {
                                                store.delete(id: trip.id)
                                            },
                                            onAddToCalendar: { selectedTrip in
                                                Task {
                                                    await openCalendar(for: selectedTrip)
                                                }
                                            }
                                        )
                                    } label: {
                                        TripPlannerSavedTripCard(
                                            trip: trip,
                                            onDelete: {
                                                store.delete(id: trip.id)
                                            },
                                            onAddToCalendar: {
                                                Task {
                                                    await openCalendar(for: trip)
                                                }
                                            }
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
                .scrollIndicators(.hidden)
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
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))

                    Text("New Trip")
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
            .buttonStyle(.plain)
        }
        .sheet(item: $calendarDraft) { draft in
            TripPlannerCalendarSheet(draft: draft)
        }
        .alert("Calendar Access", isPresented: Binding(
            get: { calendarError != nil },
            set: { newValue in
                if !newValue {
                    calendarError = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarError ?? "")
        }
    }

    @MainActor
    private func openCalendar(for trip: TripPlannerTrip) async {
        guard let startDate = trip.startDate,
              let endDate = trip.endDate else {
            calendarError = "This trip needs tentative dates before it can be added to Apple Calendar."
            return
        }

        let store = EKEventStore()

        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                calendarError = "Calendar access was denied. You can enable it later in Settings."
                return
            }

            let event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
            event.title = trip.title
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: startDate)
            event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate

            let noteParts = [
                trip.notes.isEmpty ? nil : trip.notes,
                trip.countryNames.isEmpty ? nil : "Countries: \(trip.countryNames.joined(separator: ", "))",
                trip.friendNames.isEmpty ? nil : "Friends: \(trip.friendNames.joined(separator: ", "))"
            ].compactMap { $0 }
            event.notes = noteParts.joined(separator: "\n")

            calendarDraft = TripPlannerCalendarDraft(store: store, event: event)
        } catch {
            calendarError = error.localizedDescription
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

    private let friendService = FriendService()
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

    private var sortedFriends: [Profile] {
        friends.sorted { displayName(for: $0) < displayName(for: $1) }
    }

    private var selectedFriends: [Profile] {
        friends.filter { selectedFriendIds.contains($0.id) }
    }

    private var visibleCountries: [Country] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = countries.filter { country in
            guard !trimmed.isEmpty else { return true }
            return country.name.localizedCaseInsensitiveContains(trimmed)
                || country.id.localizedCaseInsensitiveContains(trimmed)
        }
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var bucketCountries: [Country] {
        visibleCountries.filter { bucketCountryIds.contains($0.id) }
    }

    private var extraCountries: [Country] {
        visibleCountries.filter { !bucketCountryIds.contains($0.id) }
    }

    private var bucketPreviewCountries: [Country] {
        Array(bucketCountries.prefix(4))
    }

    private var friendPreview: [Profile] {
        Array(sortedFriends.prefix(3))
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
            .filter { sharedCountryIds.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
                Theme.titleBanner("Create Trip")

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading planner...")
                            .font(.subheadline)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: "Trip Basics",
                                subtitle: "Give it a name and rough timing so you can start shaping it."
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    TripPlannerTextInput(
                                        title: "Trip name",
                                        text: $title,
                                        placeholder: "Summer city escape"
                                    )

                                    TripPlannerTextInput(
                                        title: "Notes",
                                        text: $notes,
                                        placeholder: "What kind of trip are you imagining?",
                                        axis: .vertical
                                    )

                                    Toggle("Add tentative dates", isOn: $includeDates)
                                        .tint(.black)

                                    if includeDates {
                                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                                            .tint(.black)

                                        DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                                            .tint(.black)

                                        Button {
                                            Task {
                                                await openDraftCalendar()
                                            }
                                        } label: {
                                            Label("Preview in Apple Calendar", systemImage: "calendar.badge.plus")
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
                                title: "Who’s Going",
                                subtitle: "Keep it solo or add friends to compare shared bucket-list countries."
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Toggle("Plan with friends", isOn: $includeFriends)
                                        .tint(.black)

                                    if includeFriends {
                                        if !sessionManager.isAuthenticated {
                                            TripPlannerInfoCard(
                                                text: "Friend matching needs a signed-in account.",
                                                systemImage: "lock.fill"
                                            )
                                        } else if let friendsError {
                                            TripPlannerInfoCard(
                                                text: friendsError,
                                                systemImage: "exclamationmark.triangle.fill"
                                            )
                                        } else if friends.isEmpty {
                                            TripPlannerInfoCard(
                                                text: "You don’t have any friends added yet, so this trip will stay solo for now.",
                                                systemImage: "person.2.slash"
                                            )
                                        } else {
                                            HStack {
                                                Text("Travel friends")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.black)

                                                Spacer()

                                                if sortedFriends.count > 3 {
                                                    Button("See more") {
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
                                                            displayName: displayName(for: friend)
                                                        )
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }

                                            if isLoadingShared {
                                                ProgressView("Comparing bucket lists...")
                                                    .tint(.black)
                                            }

                                            if !sharedCountries.isEmpty {
                                                VStack(alignment: .leading, spacing: 10) {
                                                    HStack {
                                                        Text("Shared bucket-list matches")
                                                            .font(.system(size: 15, weight: .bold))
                                                            .foregroundStyle(.black)

                                                        Spacer()

                                                        Button("Add All") {
                                                            selectedCountryIds.formUnion(sharedCountryIds)
                                                        }
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundStyle(.black)
                                                    }

                                                    TripPlannerChipGrid(
                                                        items: sharedCountries.map { country in
                                                            TripPlannerChipItem(
                                                                id: country.id,
                                                                title: "\(country.flagEmoji) \(country.name)",
                                                                isSelected: selectedCountryIds.contains(country.id)
                                                            )
                                                        },
                                                        onTap: { item in
                                                            toggleCountry(item.id)
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            TripPlannerSectionCard(
                                title: "Countries",
                                subtitle: "Choose from your bucket list first, then add any others you want."
                            ) {
                                VStack(alignment: .leading, spacing: 14) {
                                    if !selectedCountries.isEmpty {
                                        TripPlannerChipGrid(
                                            items: selectedCountries.map { country in
                                                TripPlannerChipItem(
                                                    id: country.id,
                                                    title: "\(country.flagEmoji) \(country.name)",
                                                    isSelected: true
                                                )
                                            },
                                            onTap: { item in
                                                toggleCountry(item.id)
                                            }
                                        )
                                    } else {
                                        TripPlannerInfoCard(
                                            text: "Pick at least one country before saving the trip.",
                                            systemImage: "mappin.and.ellipse"
                                        )
                                    }

                                    TripPlannerTextInput(
                                        title: "Search countries",
                                        text: $searchText,
                                        placeholder: "Japan, Brazil, Morocco..."
                                    )

                                    if !bucketCountries.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text("From your bucket list")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(.black)

                                                Spacer()

                                                if bucketCountries.count > bucketPreviewCountries.count {
                                                    Button("See more") {
                                                        showingBucketCountries = true
                                                    }
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.black)
                                                }
                                            }

                                            TripPlannerCountryList(
                                                countries: bucketPreviewCountries,
                                                selectedIds: selectedCountryIds,
                                                bucketIds: bucketCountryIds,
                                                sharedIds: sharedCountryIds,
                                                onTap: toggleCountry
                                            )
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(bucketCountries.isEmpty ? "All countries" : "More countries")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.black)

                                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            TripPlannerInfoCard(
                                                text: "Search for a country to go beyond your bucket list.",
                                                systemImage: "magnifyingglass"
                                            )
                                        } else {
                                            TripPlannerCountryList(
                                                countries: extraCountries,
                                                selectedIds: selectedCountryIds,
                                                bucketIds: bucketCountryIds,
                                                sharedIds: sharedCountryIds,
                                                onTap: toggleCountry
                                            )
                                        }
                                    }
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
            Button("Save") {
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
                    friends: sortedFriends,
                    selectedIds: selectedFriendIds,
                    displayName: displayName(for:),
                    onToggle: toggleFriend
                )
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBucketCountries) {
            NavigationStack {
                TripPlannerCountryPickerSheet(
                    title: "Bucket List Countries",
                    countries: bucketCountries,
                    selectedIds: selectedCountryIds,
                    bucketIds: bucketCountryIds,
                    sharedIds: sharedCountryIds,
                    onTap: toggleCountry
                )
            }
            .presentationDragIndicator(.visible)
        }
        .alert("Calendar Access", isPresented: Binding(
            get: { calendarError != nil },
            set: { newValue in
                if !newValue {
                    calendarError = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
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
            }
        }
    }

    @MainActor
    private func loadData() async {
        if let cached = CountryAPI.loadCachedCountries(), !cached.isEmpty {
            countries = cached
        }

        bucketCountryIds = bucketListStore.ids

        async let freshCountriesTask = CountryAPI.refreshCountriesIfNeeded(minInterval: 60)

        if let userId = sessionManager.userId {
            if let bucketIds = try? await profileService.fetchBucketListCountries(userId: userId) {
                bucketCountryIds = bucketIds
            }

            do {
                friends = try await friendService.fetchFriends(for: userId)
            } catch {
                friendsError = "We couldn't load your friends right now."
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

        for friendId in missing {
            if let ids = try? await profileService.fetchBucketListCountries(userId: friendId) {
                friendBucketLists[friendId] = ids
            } else {
                friendBucketLists[friendId] = []
            }
        }
    }

    private func displayName(for profile: Profile) -> String {
        let trimmed = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? profile.username : trimmed
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

    private func resolvedTripTitle() -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        if let firstCountry = selectedCountries.first {
            return "\(firstCountry.name) Trip"
        }

        return "New Trip"
    }

    @MainActor
    private func openDraftCalendar() async {
        let store = EKEventStore()

        do {
            let granted = try await store.requestFullAccessToEvents()
            guard granted else {
                calendarError = "Calendar access was denied. You can enable it later in Settings."
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
            availability: existingTrip?.availability ?? defaultAvailability()
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
        return [
            TripPlannerAvailabilityProposal(
                id: UUID(),
                participantId: "self",
                participantName: "You",
                participantUsername: nil,
                participantAvatarURL: nil,
                kind: .exactDates,
                startDate: startDate,
                endDate: endDate
            )
        ]
    }
}

private struct TripPlannerDetailView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void
    let onDelete: () -> Void
    let onAddToCalendar: (TripPlannerTrip) -> Void

    @State private var resolvedFriends: [TripPlannerFriendSnapshot]
    @State private var isLoadingFriendProfiles = false
    @State private var resolvedCountries: [Country] = []
    @State private var currentUserSnapshot: TripPlannerFriendSnapshot?
    @State private var currentPassportPreferences: PassportPreferences = .empty
    @State private var travelerPassportPreferences: [UUID: PassportPreferences] = [:]
    @State private var travelerProfiles: [UUID: Profile] = [:]
    @State private var groupLanguageScoresByCountry: [String: Int] = [:]
    @State private var groupVisaNeeds: [TripPlannerTravelerVisaNeed] = []

    private let profileService = ProfileService(supabase: SupabaseManager.shared)
    private let visaStore = VisaRequirementsStore.shared
    private let scoreWeightsStore = ScoreWeightsStore()

    init(
        trip: TripPlannerTrip,
        onSave: @escaping (TripPlannerTrip) -> Void,
        onDelete: @escaping () -> Void,
        onAddToCalendar: @escaping (TripPlannerTrip) -> Void
    ) {
        _trip = State(initialValue: trip)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onAddToCalendar = onAddToCalendar
        _resolvedFriends = State(initialValue: trip.friends)
    }

    private var tripContentRefreshKey: String {
        let startInterval = trip.startDate?.timeIntervalSince1970 ?? 0
        let endInterval = trip.endDate?.timeIntervalSince1970 ?? 0
        let countryKey = trip.countryIds.joined(separator: ",")
        let friendKey = trip.friendIds.map(\.uuidString).joined(separator: ",")
        return "\(trip.id.uuidString)|\(startInterval)|\(endInterval)|\(countryKey)|\(friendKey)"
    }

    private func saveTripChanges(_ updatedTrip: TripPlannerTrip) {
        trip = updatedTrip
        onSave(updatedTrip)
    }

    private var displayedFriends: [TripPlannerFriendSnapshot] {
        resolvedFriends.isEmpty ? trip.friends : resolvedFriends
    }

    private var displayedTravelers: [TripPlannerFriendSnapshot] {
        var travelers: [TripPlannerFriendSnapshot] = []

        if let currentUserSnapshot {
            travelers.append(currentUserSnapshot)
        }

        travelers.append(contentsOf: displayedFriends)
        return travelers
    }

    private var displayedCountries: [Country] {
        resolvedCountries.isEmpty ? trip.countryIds.enumerated().map { index, id in
            Country(
                iso2: id,
                name: trip.countryNames.indices.contains(index) ? trip.countryNames[index] : id,
                score: nil
            )
        } : resolvedCountries
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel5")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner(trip.title)

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerEditableSectionCard(
                            title: "Trip Details",
                            subtitle: trip.isGroupTrip ? "Group trip" : "Solo trip"
                        ) {
                            NavigationLink {
                                TripPlannerBasicsEditorView(trip: trip, onSave: saveTripChanges)
                            } label: {
                                Text("Edit")
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
                                        Text("Notes")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.black.opacity(0.75))

                                        Text(trip.notes)
                                            .font(.system(size: 16))
                                            .foregroundStyle(.black)
                                    }
                                }
                            }
                        }

                        TripPlannerEditableSectionCard(
                            title: "Who’s Going",
                            subtitle: displayedTravelers.isEmpty ? "Just you for now." : "Everyone currently included in this trip."
                        ) {
                            NavigationLink {
                                TripPlannerFriendsEditorView(trip: trip, onSave: saveTripChanges)
                            } label: {
                                Text("Edit")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        } content: {
                            if displayedTravelers.isEmpty {
                                TripPlannerInfoCard(
                                    text: "No friends have been added to this trip yet.",
                                    systemImage: "person"
                                )
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    if isLoadingFriendProfiles && displayedFriends.isEmpty {
                                        ProgressView("Loading profiles...")
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

                        TripPlannerEditableSectionCard(
                            title: "Countries",
                            subtitle: "Everything currently included in this trip."
                        ) {
                            NavigationLink {
                                TripPlannerCountriesEditorView(trip: trip, onSave: saveTripChanges)
                            } label: {
                                Text("Edit")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        } content: {
                            TripPlannerCountryNavigationGrid(countries: displayedCountries)
                        }

                        TripPlannerSectionCard(
                            title: "Trip Stats",
                            subtitle: "Based on the countries currently in this plan."
                        ) {
                            TripPlannerStatsSection(
                                countries: displayedCountries,
                                startDate: trip.startDate,
                                endDate: trip.endDate,
                                weights: scoreWeightsStore.weights,
                                preferredMonth: scoreWeightsStore.selectedMonth,
                                isGroupTrip: trip.isGroupTrip,
                                travelerCount: displayedTravelers.count,
                                passportLabel: tripPassportLabel,
                                groupLanguageScoresByCountry: groupLanguageScoresByCountry,
                                groupVisaNeeds: groupVisaNeeds
                            )
                        }

                        TripPlannerEditableSectionCard(
                            title: "Availability",
                            subtitle: trip.isGroupTrip ? "Compare when everyone is free and lock in the best window." : "Keep rough options visible until your dates are finalized."
                        ) {
                            NavigationLink {
                                TripPlannerAvailabilityEditorView(trip: trip, onSave: saveTripChanges)
                            } label: {
                                Text("Edit")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                        } content: {
                            TripPlannerAvailabilitySection(trip: trip)
                        }

                        TripPlannerSectionCard(
                            title: "Actions",
                            subtitle: "Update the plan, send it to Calendar, or remove it."
                        ) {
                            VStack(spacing: 12) {
                                if trip.startDate != nil, trip.endDate != nil {
                                    Button {
                                        onAddToCalendar(trip)
                                    } label: {
                                        Label("Add To Apple Calendar", systemImage: "calendar.badge.plus")
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
                                    onDelete()
                                } label: {
                                    Label("Delete Trip", systemImage: "trash")
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
        .task(id: tripContentRefreshKey) {
            await loadTravelerProfiles()
            await loadCountryStats()
            await loadGroupLanguageScores()
        }
    }

    @MainActor
    private func loadTravelerProfiles() async {
        isLoadingFriendProfiles = true
        defer { isLoadingFriendProfiles = false }

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
    }

    private func friendSnapshot(from profile: Profile) -> TripPlannerFriendSnapshot {
        let trimmed = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return TripPlannerFriendSnapshot(
            id: profile.id,
            displayName: trimmed.isEmpty ? profile.username : trimmed,
            username: profile.username,
            avatarURL: profile.avatarUrl
        )
    }

    private var tripPassportLabel: String {
        if currentPassportPreferences.nationalityCountryCodes.count > 1 {
            return "best saved passport"
        }

        if let code = currentPassportPreferences.effectivePassportCountryCode {
            return CountrySelectionFormatter.localizedName(for: code)
        }

        return visaStore.activePassportLabel ?? "United States"
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
                        countryName: country.name,
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

        return "saved passport"
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

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var title: String
    @State private var notes: String
    @State private var includeDates: Bool
    @State private var startDate: Date
    @State private var endDate: Date

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
                Theme.titleBanner("Trip Details")

                ScrollView {
                    TripPlannerSectionCard(
                        title: "Basics",
                        subtitle: "Update the trip name, notes, and dates."
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            TripPlannerTextInput(
                                title: "Trip name",
                                text: $title,
                                placeholder: "Summer city escape"
                            )

                            TripPlannerTextInput(
                                title: "Notes",
                                text: $notes,
                                placeholder: "What kind of trip are you imagining?",
                                axis: .vertical
                            )

                            Toggle("Add tentative dates", isOn: $includeDates)
                                .tint(.black)

                            if includeDates {
                                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                                    .tint(.black)

                                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
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
            Button("Save") {
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
                        availability: updatedAvailability()
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
        let nonSelf = trip.availability.filter { $0.participantId != "self" }
        guard includeDates else { return nonSelf }

        return nonSelf + [
            TripPlannerAvailabilityProposal(
                id: UUID(),
                participantId: "self",
                participantName: "You",
                participantUsername: nil,
                participantAvatarURL: nil,
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

    private let friendService = FriendService()

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
                Theme.titleBanner("Who’s Going")

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading friends...")
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: "Travel Friends",
                                subtitle: "Choose who’s joining this trip."
                            ) {
                                if let errorMessage {
                                    TripPlannerInfoCard(
                                        text: errorMessage,
                                        systemImage: "exclamationmark.triangle.fill"
                                    )
                                } else if friends.isEmpty {
                                    TripPlannerInfoCard(
                                        text: "You don’t have any friends added yet.",
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
            Button("Save") {
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
                        availability: preservedAvailability(with: selectedFriends.map(friendSnapshot))
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
    }

    @MainActor
    private func loadFriends() async {
        defer { isLoading = false }

        guard let userId = sessionManager.userId else {
            errorMessage = "Sign in to edit trip companions."
            return
        }

        do {
            friends = try await friendService.fetchFriends(for: userId)
        } catch {
            errorMessage = "We couldn't load your friends right now."
        }
    }

    private func toggle(_ id: UUID) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
        }
    }

    private func displayName(for profile: Profile) -> String {
        let trimmed = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? profile.username : trimmed
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
        let validIds = Set(selectedFriends.map { String($0.id.uuidString) }).union(["self"])
        return trip.availability.filter { validIds.contains($0.participantId) }
    }
}

private struct TripPlannerAvailabilityEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var proposals: [TripPlannerAvailabilityProposal]
    @State private var selectedKind: TripPlannerAvailabilityKind = .exactDates
    @State private var rangeStart = Date()
    @State private var rangeEnd = Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
    @State private var selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
    @State private var editingProposalId: UUID?

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _proposals = State(initialValue: trip.availability.sorted { $0.startDate < $1.startDate })
    }

    private var participants: [TripPlannerAvailabilityParticipant] {
        trip.availabilityParticipants
    }

    private var currentParticipant: TripPlannerAvailabilityParticipant {
        participants.first(where: { $0.id == "self" }) ?? .you
    }

    private var overlapMatches: [TripPlannerAvailabilityOverlap] {
        TripPlannerAvailabilityCalculator.overlaps(for: trip, proposals: proposals)
    }

    private var monthOptions: [Date] {
        let calendar = Calendar.current
        let start = TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("Availability")

                ScrollView {
                    VStack(spacing: 18) {
                        TripPlannerSectionCard(
                            title: "How this works",
                            subtitle: "Add either exact windows or flexible months for each traveler, then let the planner surface the strongest overlap."
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                TripPlannerInfoCard(
                                    text: "Use exact dates when someone already knows the week they’re free. Use flexible months when they only know the general timing.",
                                    systemImage: "calendar"
                                )

                                if overlapMatches.isEmpty {
                                    TripPlannerInfoCard(
                                        text: "No shared window yet. Add a few more ideas across the group and the planner will suggest stronger matches here.",
                                        systemImage: "person.3.sequence.fill"
                                    )
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(overlapMatches.prefix(2)) { overlap in
                                            TripPlannerOverlapCard(overlap: overlap)
                                        }
                                    }
                                }
                            }
                        }

                        TripPlannerSectionCard(
                            title: "Current proposals",
                            subtitle: "Each traveler can have multiple windows."
                        ) {
                            if proposals.isEmpty {
                                TripPlannerInfoCard(
                                    text: "No availability has been proposed yet.",
                                    systemImage: "calendar.badge.plus"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(Array(groupedProposals().enumerated()), id: \.1.participant.id) { index, group in
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack(spacing: 10) {
                                                Circle()
                                                    .fill(TripPlannerAvailabilityTheme.color(for: group.participant.id, index: index))
                                                    .frame(width: 10, height: 10)

                                                TripPlannerAvatarView(
                                                    name: group.participant.name,
                                                    username: group.participant.username ?? group.participant.name,
                                                    avatarURL: group.participant.avatarURL,
                                                    size: 34
                                                )

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(group.participant.name)
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundStyle(.black)

                                                    if let username = group.participant.username {
                                                        Text("@\(username)")
                                                            .font(.caption)
                                                            .foregroundStyle(.black.opacity(0.62))
                                                    }
                                                }
                                            }

                                            ForEach(group.proposals) { proposal in
                                                HStack(spacing: 10) {
                                                    TripPlannerProposalChip(
                                                        proposal: proposal,
                                                        color: TripPlannerAvailabilityTheme.color(for: group.participant.id, index: index)
                                                    )

                                                    Spacer()

                                                    if proposal.participantId == "self" {
                                                        Button {
                                                            beginEditing(proposal)
                                                        } label: {
                                                            Text("Edit")
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundStyle(.black)
                                                                .padding(.horizontal, 12)
                                                                .padding(.vertical, 8)
                                                                .background(Capsule().fill(Color.white.opacity(0.86)))
                                                        }
                                                        .buttonStyle(.plain)

                                                        Button(role: .destructive) {
                                                            proposals.removeAll { $0.id == proposal.id }
                                                            if editingProposalId == proposal.id {
                                                                resetComposer()
                                                            }
                                                        } label: {
                                                            Image(systemName: "trash")
                                                                .font(.system(size: 14, weight: .bold))
                                                                .foregroundStyle(.black)
                                                                .padding(8)
                                                                .background(Circle().fill(Color.white.opacity(0.82)))
                                                        }
                                                        .buttonStyle(.plain)
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
                            }
                        }

                        TripPlannerSectionCard(
                            title: editingProposalId == nil ? "Your availability" : "Edit your availability",
                            subtitle: editingProposalId == nil
                                ? "Share the months or exact dates that work for you. Everyone else’s availability stays read-only here."
                                : "Update your submitted window without deleting it first."
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    TripPlannerAvatarView(
                                        name: currentParticipant.name,
                                        username: currentParticipant.username ?? currentParticipant.name,
                                        avatarURL: currentParticipant.avatarURL,
                                        size: 42
                                    )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(currentParticipant.name)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(.black)

                                        Text("Only you can edit these submissions.")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.black.opacity(0.62))
                                    }
                                }

                                Picker("Type", selection: $selectedKind) {
                                    ForEach(TripPlannerAvailabilityKind.allCases) { kind in
                                        Text(kind.title).tag(kind)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if selectedKind == .exactDates {
                                    DatePicker("Start", selection: $rangeStart, displayedComponents: .date)
                                        .tint(.black)

                                    DatePicker("End", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date)
                                        .tint(.black)
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Month")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.black.opacity(0.72))

                                        Picker("Month", selection: $selectedMonth) {
                                            ForEach(monthOptions, id: \.self) { month in
                                                Text(TripPlannerAvailabilityCalculator.monthTitle(for: month)).tag(month)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.78))
                                        )
                                    }
                                }

                                Button {
                                    saveProposal()
                                } label: {
                                    Label(editingProposalId == nil ? "Save Availability" : "Update Availability", systemImage: editingProposalId == nil ? "plus" : "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.84))
                                        )
                                }
                                .buttonStyle(.plain)

                                if editingProposalId != nil {
                                    Button("Cancel Editing") {
                                        resetComposer()
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.75))
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
            Button("Save") {
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
                        availability: proposals.sorted { $0.startDate < $1.startDate }
                    )
                )
                dismiss()
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
        }
        .onChange(of: rangeStart) { _, newValue in
            if rangeEnd < newValue {
                rangeEnd = newValue
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

    private func saveProposal() {
        let proposal = composedProposal(id: editingProposalId ?? UUID())

        if let editingProposalId, let index = proposals.firstIndex(where: { $0.id == editingProposalId }) {
            proposals[index] = proposal
        } else {
            proposals.append(proposal)
        }
        proposals.sort { $0.startDate < $1.startDate }
        resetComposer()
    }

    private func beginEditing(_ proposal: TripPlannerAvailabilityProposal) {
        editingProposalId = proposal.id
        selectedKind = proposal.kind

        if proposal.kind == .exactDates {
            rangeStart = proposal.startDate
            rangeEnd = proposal.endDate
        } else {
            selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: proposal.startDate)
        }
    }

    private func resetComposer() {
        editingProposalId = nil
        selectedKind = .exactDates
        rangeStart = Date()
        rangeEnd = Calendar.current.date(byAdding: .day, value: 5, to: rangeStart) ?? rangeStart
        selectedMonth = TripPlannerAvailabilityCalculator.startOfMonth(for: Date())
    }

    private func composedProposal(id: UUID) -> TripPlannerAvailabilityProposal {
        if selectedKind == .exactDates {
            return TripPlannerAvailabilityProposal(
                id: id,
                participantId: "self",
                participantName: currentParticipant.name,
                participantUsername: currentParticipant.username,
                participantAvatarURL: currentParticipant.avatarURL,
                kind: .exactDates,
                startDate: rangeStart,
                endDate: rangeEnd
            )
        } else {
            let monthStart = TripPlannerAvailabilityCalculator.startOfMonth(for: selectedMonth)
            return TripPlannerAvailabilityProposal(
                id: id,
                participantId: "self",
                participantName: currentParticipant.name,
                participantUsername: currentParticipant.username,
                participantAvatarURL: currentParticipant.avatarURL,
                kind: .flexibleMonth,
                startDate: monthStart,
                endDate: TripPlannerAvailabilityCalculator.endOfMonth(for: monthStart)
            )
        }
    }
}

private struct TripPlannerCountriesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bucketListStore: BucketListStore

    let trip: TripPlannerTrip
    let onSave: (TripPlannerTrip) -> Void

    @State private var countries: [Country] = []
    @State private var selectedCountryIds: Set<String>
    @State private var searchText = ""
    @State private var isLoading = true

    init(trip: TripPlannerTrip, onSave: @escaping (TripPlannerTrip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _selectedCountryIds = State(initialValue: Set(trip.countryIds))
    }

    private var visibleCountries: [Country] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = countries.filter { country in
            guard !trimmed.isEmpty else { return true }
            return country.name.localizedCaseInsensitiveContains(trimmed)
                || country.id.localizedCaseInsensitiveContains(trimmed)
        }
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Theme.pageBackground("travel2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Theme.titleBanner("Countries")

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading countries...")
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            TripPlannerSectionCard(
                                title: "Included Countries",
                                subtitle: "Update which countries belong in this plan."
                            ) {
                                TripPlannerTextInput(
                                    title: "Search countries",
                                    text: $searchText,
                                    placeholder: "Japan, Brazil, Morocco..."
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
            Button("Save") {
                let selectedCountries = countries
                    .filter { selectedCountryIds.contains($0.id) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

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
                        availability: trip.availability
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

        if let fresh = await CountryAPI.refreshCountriesIfNeeded(minInterval: 60), !fresh.isEmpty {
            countries = fresh
        }

        countries.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false
    }

    private func toggle(_ id: String) {
        if selectedCountryIds.contains(id) {
            selectedCountryIds.remove(id)
        } else {
            selectedCountryIds.insert(id)
        }
    }
}

private extension TripPlannerTrip {
    var countryChipItems: [(id: String, title: String)] {
        zip(countryIds, countryNames).map { id, name in
            (id: id, title: "\(id.flagEmoji) \(name)")
        }
    }

    var availabilityParticipants: [TripPlannerAvailabilityParticipant] {
        [TripPlannerAvailabilityParticipant.you] + friends.map {
            TripPlannerAvailabilityParticipant(
                id: $0.id.uuidString,
                name: $0.displayName,
                username: $0.username,
                avatarURL: $0.avatarURL
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
        name: "You",
        username: nil,
        avatarURL: nil
    )
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

private struct TripPlannerStatsSection: View {
    let countries: [Country]
    let startDate: Date?
    let endDate: Date?
    let weights: ScoreWeights
    let preferredMonth: Int
    let isGroupTrip: Bool
    let travelerCount: Int
    let passportLabel: String
    let groupLanguageScoresByCountry: [String: Int]
    let groupVisaNeeds: [TripPlannerTravelerVisaNeed]

    private var selectedMonth: Int {
        guard let startDate else { return preferredMonth }
        return Calendar.current.component(.month, from: startDate)
    }

    private var scoredCountries: [Country] {
        countries.map {
            $0.applyingOverallScore(using: weights, selectedMonth: selectedMonth)
        }
    }

    private var affordabilityScores: [Int] {
        countries.compactMap(\.affordabilityScore)
    }

    private var dailySpendValues: [Double] {
        countries.compactMap(\.dailySpendTotalUsd)
    }

    private var averageAffordability: Int? {
        guard !affordabilityScores.isEmpty else { return nil }
        return Int((Double(affordabilityScores.reduce(0, +)) / Double(affordabilityScores.count)).rounded())
    }

    private var averageDailySpend: Int? {
        guard !dailySpendValues.isEmpty else { return nil }
        return Int((dailySpendValues.reduce(0, +) / Double(dailySpendValues.count)).rounded())
    }

    private var tripLengthDays: Int? {
        guard let startDate, let endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day ?? 0
        return max(days + 1, 1)
    }

    private var estimatedTripCostPerPerson: Int? {
        guard let averageDailySpend, let tripLengthDays else { return nil }
        return averageDailySpend * tripLengthDays
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

    private var primaryVisaWarningCountry: Country? {
        if let overstayCountry = overstayRiskCountries.first {
            return overstayCountry
        }
        return visaPrepCountries.min { ($0.visaEaseScore ?? 999) < ($1.visaEaseScore ?? 999) }
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
            TripPlannerScoreAverage(title: "Overall", subtitle: "Weighted trip score", score: averageOverallScore),
            TripPlannerScoreAverage(title: "Advisory", subtitle: "Safety and travel guidance", score: averageAdvisoryScore),
            TripPlannerScoreAverage(title: "Seasonality", subtitle: monthSummaryText, score: averageSeasonalityScore),
            TripPlannerScoreAverage(title: "Visa", subtitle: "Entry ease across stops", score: average(of: countries.compactMap(\.visaEaseScore))),
            TripPlannerScoreAverage(title: "Budget", subtitle: "Affordability across stops", score: averageAffordability),
            TripPlannerScoreAverage(title: "Language", subtitle: isGroupTrip ? "Group language coverage" : "Your language coverage", score: averageLanguageScore)
        ]
    }

    private var averageLanguageScore: Int? {
        let values = countries.compactMap { groupLanguageScoresByCountry[$0.id] }
        return average(of: values)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !countries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isGroupTrip ? "Group snapshot" : "Trip snapshot")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)

                    Text(snapshotSummary)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.68))

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10, alignment: .top),
                            GridItem(.flexible(), spacing: 10, alignment: .top)
                        ],
                        spacing: 10
                    ) {
                        TripPlannerScoreHighlightCard(
                            title: "Average overall",
                            subtitle: "Across \(countries.count) stop\(countries.count == 1 ? "" : "s")",
                            score: averageOverallScore
                        )

                        TripPlannerScoreHighlightCard(
                            title: "Average advisory",
                            subtitle: "Shared safety picture",
                            score: averageAdvisoryScore
                        )

                        TripPlannerScoreHighlightCard(
                            title: "Average seasonality",
                            subtitle: monthSummaryText,
                            score: averageSeasonalityScore
                        )
                    }
                }
            }

            if !categoryAverages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Score breakdown")
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
            }

            HStack(spacing: 10) {
                TripPlannerStatPill(
                    title: "Estimated total per person",
                    value: estimatedTripCostPerPerson.map { "$\($0) USD" } ?? "Add trip dates",
                    detail: "\(estimatedCostDetail) · USD"
                )

                TripPlannerStatPill(
                    title: "Typical daily spend",
                    value: averageDailySpend.map { "$\($0) USD" } ?? "N/A",
                    detail: "\(dailySpendDetail) · USD"
                )
            }

            TripPlannerStatPill(
                title: "Visa check",
                value: visaSummaryValue,
                detail: visaSummaryDetail
            )

            if isGroupTrip, !countries.isEmpty {
                if groupVisaNeeds.isEmpty {
                    TripPlannerInfoCard(
                        text: "No group member currently needs advance visa prep for these stops based on each person's strongest saved passport.",
                        systemImage: "person.3.fill"
                    )
                } else {
                    ForEach(groupVisaNeedHighlights) { need in
                        TripPlannerInfoCard(
                            text: need.summaryText(tripLengthDays: tripLengthDays),
                            systemImage: need.exceedsAllowedStay
                                ? "person.crop.circle.badge.exclamationmark"
                                : "person.crop.circle.badge.clock"
                        )
                    }

                    if groupVisaNeeds.count > groupVisaNeedHighlights.count {
                        let remaining = groupVisaNeeds.count - groupVisaNeedHighlights.count
                        TripPlannerInfoCard(
                            text: "\(remaining) more traveler-specific visa flag\(remaining == 1 ? "" : "s") are in this itinerary.",
                            systemImage: "ellipsis.circle.fill"
                        )
                    }
                }
            }

            if !overstayRiskCountries.isEmpty {
                TripPlannerInfoCard(
                    text: overstayWarningText,
                    systemImage: "exclamationmark.triangle.fill"
                )
            } else if allCountriesVisaFreeForTrip {
                TripPlannerInfoCard(
                    text: "No visa required for this trip based on the app's current \(passportLabel) passport data.",
                    systemImage: "checkmark.seal.fill"
                )
            } else if allCountriesNeedNoAdvanceVisa {
                TripPlannerInfoCard(
                    text: "No advance visa needed for this trip based on the app's current \(passportLabel) passport data.",
                    systemImage: "checkmark.seal.fill"
                )
            }

            if let primaryVisaWarningCountry {
                TripPlannerInfoCard(
                    text: primaryVisaWarningText(for: primaryVisaWarningCountry),
                    systemImage: overstayRiskCountries.contains(where: { $0.id == primaryVisaWarningCountry.id })
                        ? "exclamationmark.triangle.fill"
                        : "globe.badge.chevron.backward"
                )
            }
        }
    }

    private var estimatedCostDetail: String {
        guard let tripLengthDays else {
            return "We’ll estimate this once trip dates are set"
        }
        return "\(tripLengthDays)-day estimate across selected countries"
    }

    private var dailySpendDetail: String {
        guard let averageAffordability else { return "Across selected countries" }
        switch averageAffordability {
        case 80...:
            return "Leans more budget-friendly"
        case 60..<80:
            return "Pretty balanced overall"
        case 40..<60:
            return "More mid-range to pricey"
        default:
            return "Leans expensive overall"
        }
    }

    private var visaSummaryValue: String {
        if !overstayRiskCountries.isEmpty {
            return "Visa stay warning"
        }
        if allCountriesVisaFreeForTrip {
            return "No visa required"
        }
        if allCountriesNeedNoAdvanceVisa {
            return "No advance visa needed"
        }
        return "\(visaPrepCountries.count) stop\(visaPrepCountries.count == 1 ? "" : "s") to prep for"
    }

    private var visaSummaryDetail: String {
        if !overstayRiskCountries.isEmpty {
            return "One or more stops exceed the allowed stay for this trip"
        }
        if isGroupTrip {
            if groupVisaNeeds.isEmpty {
                return "Uses each member's strongest saved passport"
            }
            return "\(groupVisaNeeds.count) traveler-specific flag\(groupVisaNeeds.count == 1 ? "" : "s") across the group"
        }
        return "Current \(passportLabel) passport visa data in the app"
    }

    private var groupVisaNeedHighlights: [TripPlannerTravelerVisaNeed] {
        Array(groupVisaNeeds.prefix(3))
    }

    private var monthSummaryText: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        return "\(formatter.monthSymbols[selectedMonth - 1]) timing"
    }

    private var snapshotSummary: String {
        if isGroupTrip {
            return "\(travelerCount) travelers, \(countries.count) countries, one cleaner view of how the trip balances overall score, safety, seasonality, and logistics."
        }

        return "\(countries.count) selected countr\(countries.count == 1 ? "y" : "ies") with a combined scoring view for the trip."
    }

    private func average(of values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private var overstayWarningText: String {
        let countriesText = overstayRiskCountries.map { "\($0.flagEmoji) \($0.name)" }.joined(separator: ", ")
        guard let tripLengthDays else {
            return "One or more stops may exceed the allowed stay for this trip."
        }
        return "\(countriesText) may exceed the allowed visa-free stay for a \(tripLengthDays)-day trip."
    }

    private func primaryVisaWarningText(for country: Country) -> String {
        if let tripLengthDays, let allowedDays = country.visaAllowedDays, tripLengthDays > allowedDays {
            return "\(country.flagEmoji) \(country.name) allows about \(allowedDays) day\(allowedDays == 1 ? "" : "s") on this entry status, so your \(tripLengthDays)-day trip would need a visa plan."
        }

        let winningPassportLabel = country.visaPassportLabel ?? passportLabel
        return "\(country.flagEmoji) \(country.name): \(CountryVisaHelpers.headline(for: country, passportLabel: winningPassportLabel))"
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
            return "\(travelerName) may exceed the allowed stay in \(countryFlag) \(countryName) on their best saved passport (\(passportLabel)): about \(allowedDays) day\(allowedDays == 1 ? "" : "s") allowed for a \(tripLengthDays)-day trip."
        }

        return "\(travelerName) may need visa prep for \(countryFlag) \(countryName). Best saved passport for that stop: \(passportLabel)."
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
                Text("N/A")
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
                .fill(Color.white.opacity(0.82))
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
                Text("N/A")
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
                .fill(Color.white.opacity(0.76))
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
            travelerLanguages.map { language in
                LanguageRepository.shared.canonicalLanguageCode(for: language.code)
                    ?? language.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )

        guard !spokenCodes.isEmpty else { return nil }

        let countryCodes = Set(
            countryProfile.languages.map { coverage in
                LanguageRepository.shared.canonicalLanguageCode(for: coverage.code)
                    ?? coverage.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )

        return spokenCodes.isDisjoint(with: countryCodes) ? 0 : 100
    }
}

private struct TripPlannerStatPill: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black.opacity(0.62))

            Text(value)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.black)

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct TripPlannerAvailabilitySection: View {
    let trip: TripPlannerTrip

    private var overlaps: [TripPlannerAvailabilityOverlap] {
        TripPlannerAvailabilityCalculator.overlaps(for: trip)
    }

    private var exactProposalCount: Int {
        trip.availability.filter { $0.kind == .exactDates }.count
    }

    private var monthProposalCount: Int {
        trip.availability.filter { $0.kind == .flexibleMonth }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if trip.availability.isEmpty {
                TripPlannerInfoCard(
                    text: trip.isGroupTrip
                        ? "Start collecting free months or exact date ranges so the planner can spotlight the best shared window."
                        : "Add a couple of date ideas here to keep your planning options visible."
                    ,
                    systemImage: "calendar.badge.plus"
                )
            } else {
                TripPlannerAvailabilityCalendarBoard(trip: trip)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Best shared windows")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)

                    if overlaps.isEmpty {
                        TripPlannerInfoCard(
                            text: "No shared window yet. Ask everyone to add a few more free months or date ranges so the planner can find a better match.",
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

                HStack(spacing: 8) {
                    TripPlannerBadge(text: "\(exactProposalCount) date range\(exactProposalCount == 1 ? "" : "s")")
                    if monthProposalCount > 0 {
                        TripPlannerBadge(text: "\(monthProposalCount) flexible month\(monthProposalCount == 1 ? "" : "s")")
                    }
                }
            }
        }
    }
}

private struct TripPlannerAvailabilityCalendarBoard: View {
    let trip: TripPlannerTrip

    private var displayMonth: Date? {
        TripPlannerAvailabilityCalculator.primaryDisplayMonth(for: trip)
    }

    private var proposalsByParticipant: [(TripPlannerAvailabilityParticipant, [TripPlannerAvailabilityProposal])] {
        trip.availabilityParticipants.compactMap { participant in
            let proposals = trip.availability.filter { $0.participantId == participant.id }
            guard !proposals.isEmpty else { return nil }
            return (participant, proposals)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar view")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(proposalsByParticipant.enumerated()), id: \.1.0.id) { index, entry in
                        let participant = entry.0

                        HStack(spacing: 8) {
                            Circle()
                                .fill(TripPlannerAvailabilityTheme.color(for: participant.id, index: index))
                                .frame(width: 10, height: 10)

                            Text(participant.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.82))
                        )
                    }

                    if trip.startDate != nil, trip.endDate != nil {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.black)
                                .frame(width: 10, height: 10)

                            Text("Trip dates")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.82))
                        )
                    }
                }
            }

            if let displayMonth {
                TripPlannerAvailabilityMonthCard(
                    month: displayMonth,
                    trip: trip,
                    proposalsByParticipant: proposalsByParticipant
                )
            }
        }
    }
}

private struct TripPlannerAvailabilityMonthCard: View {
    let month: Date
    let trip: TripPlannerTrip
    let proposalsByParticipant: [(TripPlannerAvailabilityParticipant, [TripPlannerAvailabilityProposal])]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var daySlots: [Date?] {
        TripPlannerAvailabilityCalculator.daySlots(for: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TripPlannerAvailabilityCalculator.monthTitle(for: month))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TripPlannerAvailabilityCalculator.weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(daySlots.enumerated()), id: \.offset) { _, day in
                    if let day {
                        TripPlannerAvailabilityDayCell(
                            date: day,
                            month: month,
                            trip: trip,
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
    let trip: TripPlannerTrip
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

    private var isConfirmedTripDay: Bool {
        TripPlannerAvailabilityCalculator.includes(date: date, start: trip.startDate, end: trip.endDate)
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
        if isConfirmedTripDay {
            return .black
        }
        if isSharedDay {
            return Color(red: 0.91, green: 0.84, blue: 0.64)
        }
        if !availableColors.isEmpty {
            return Color.white.opacity(0.92)
        }
        return Color.black.opacity(0.05)
    }

    private var borderColor: Color {
        if isConfirmedTripDay {
            return .black
        }
        if isSharedDay {
            return Color.black.opacity(0.22)
        }
        if !availableColors.isEmpty {
            return Color.black.opacity(0.1)
        }
        return .clear
    }

    private var textColor: Color {
        isConfirmedTripDay ? .white : .black
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
                Text(TripPlannerDateFormatter.rangeText(start: overlap.startDate, end: overlap.endDate) ?? "Shared window")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)

                Text(overlap.isFullMatch
                    ? "Works across everyone’s current proposals."
                    : "This lines up for \(overlap.exactParticipantCount) of \(overlap.totalParticipantCount) people so far.")
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
    let trip: TripPlannerTrip
    let onDelete: () -> Void
    let onAddToCalendar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.black)

                    Text(trip.isGroupTrip ? "Group trip" : "Solo trip")
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

            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.74))
            }

            if !trip.friendNames.isEmpty {
                Text("With \(trip.friendNames.joined(separator: ", "))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black.opacity(0.8))
            }

            TripPlannerChipGrid(
                items: trip.countryChipItems.map {
                    TripPlannerChipItem(id: $0.id, title: $0.title, isSelected: false)
                },
                onTap: { _ in }
            )

            if trip.startDate != nil, trip.endDate != nil {
                Button {
                    onAddToCalendar()
                } label: {
                    Label("Add To Apple Calendar", systemImage: "calendar.badge.plus")
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

            Text("No Trips Yet")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)

            Text("Start with one rough trip idea and refine it as dates, countries, and people come into focus.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black.opacity(0.72))

            Text("Create New Trip")
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.68))
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
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.black.opacity(0.68))
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
                            Text(country.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)

                            HStack(spacing: 6) {
                                if bucketIds.contains(country.id) {
                                    TripPlannerBadge(text: "Bucket")
                                }

                                if sharedIds.contains(country.id) {
                                    TripPlannerBadge(text: "Shared")
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

    var body: some View {
        HStack(spacing: 12) {
            TripPlannerAvatarView(
                name: displayName,
                username: profile.username,
                avatarURL: profile.avatarUrl,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)

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

private struct TripPlannerAvatarView: View {
    let name: String
    let username: String
    let avatarURL: String?
    let size: CGFloat

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
                    } else {
                        fallbackAvatar
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
    let onToggle: (UUID) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(friends) { friend in
                    Button {
                        onToggle(friend.id)
                    } label: {
                        TripPlannerFriendRow(
                            profile: friend,
                            isSelected: selectedIds.contains(friend.id),
                            displayName: displayName(friend)
                        )
                    }
                    .buttonStyle(.plain)
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
        .navigationTitle("Travel Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.black)
            }
        }
    }
}

private struct TripPlannerCountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let countries: [Country]
    let selectedIds: Set<String>
    let bucketIds: Set<String>
    let sharedIds: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        ScrollView {
            TripPlannerCountryList(
                countries: countries,
                selectedIds: selectedIds,
                bucketIds: bucketIds,
                sharedIds: sharedIds,
                onTap: onTap
            )
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
                Button("Done") {
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

private struct TripPlannerCountryNavigationGrid: View {
    let countries: [Country]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(countries) { country in
                NavigationLink {
                    CountryDetailView(country: country)
                } label: {
                    HStack(spacing: 8) {
                        Text("\(country.flagEmoji) \(country.name)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)

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

private enum TripPlannerAvailabilityTheme {
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
        let proposals = proposals ?? trip.availability
        let participants = trip.availabilityParticipants
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
            return "Exact: \(TripPlannerDateFormatter.rangeText(start: proposal.startDate, end: proposal.endDate) ?? "Dates")"
        case .flexibleMonth:
            return "Flexible: \(monthTitle(for: proposal.startDate))"
        }
    }

    static func monthLabel(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }

    static func monthTitle(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    static func weekdaySymbols() -> [String] {
        let formatter = DateFormatter()
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

    private static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
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

    private static func merge(_ overlaps: [TripPlannerAvailabilityOverlap]) -> [TripPlannerAvailabilityOverlap] {
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
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start, to: end)
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
