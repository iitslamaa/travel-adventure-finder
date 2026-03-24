import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';
import * as Calendar from 'expo-calendar';
import { router } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../context/AuthContext';
import { useScorePreferences } from '../context/ScorePreferencesContext';
import { useCountries } from '../hooks/useCountries';
import { useFriends } from '../hooks/useFriends';
import { useTheme } from '../hooks/useTheme';
import { seasonalityScoreForMonth } from '../utils/scoring';

type AvailabilityKind = 'exact_dates' | 'flexible_month';

type TripAvailabilityProposal = {
  id: string;
  participantId: string;
  participantName: string;
  kind: AvailabilityKind;
  startDate: string;
  endDate: string;
};

type TripExpense = {
  id: string;
  title: string;
  totalAmount: number;
  paidById: string;
  paidByName: string;
  splitWithIds: string[];
};

type PlannedTrip = {
  id: string;
  title: string;
  notes: string;
  startDate: string | null;
  endDate: string | null;
  countryIso2s: string[];
  friendIds: string[];
  availability: TripAvailabilityProposal[];
  expenses: TripExpense[];
  createdAt: string;
  updatedAt: string;
};

type TripDraft = {
  id: string | null;
  title: string;
  notes: string;
  includeDates: boolean;
  startDate: string;
  endDate: string;
  countryIso2s: string[];
  friendIds: string[];
  availability: TripAvailabilityProposal[];
  expenses: TripExpense[];
};

type Traveler = {
  id: string;
  name: string;
};

type AvailabilityOverlap = {
  startDate: string;
  endDate: string;
  exactParticipantCount: number;
  totalParticipantCount: number;
};

type AvailabilityDraft = {
  participantId: string | null;
  kind: AvailabilityKind;
  startDate: string;
  endDate: string;
  flexibleMonth: string;
};

const STORAGE_KEY = 'travelaf-trip-plans-v1';

function emptyDraft(): TripDraft {
  return {
    id: null,
    title: '',
    notes: '',
    includeDates: false,
    startDate: '',
    endDate: '',
    countryIso2s: [],
    friendIds: [],
    availability: [],
    expenses: [],
  };
}

function emptyAvailabilityDraft(): AvailabilityDraft {
  return {
    participantId: null,
    kind: 'exact_dates',
    startDate: '',
    endDate: '',
    flexibleMonth: '',
  };
}

function formatDate(dateValue: string | null) {
  if (!dateValue) return 'No dates';
  const date = new Date(dateValue);
  if (Number.isNaN(date.getTime())) return 'No dates';
  return date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function formatMonthLabel(value: string) {
  if (!value) return 'Pick month';
  const date = new Date(`${value}-01T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
}

function toDateInput(dateValue: string | null) {
  return dateValue ? dateValue.slice(0, 10) : '';
}

function parseDayStart(value: string) {
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function parseDayEnd(value: string) {
  const date = new Date(`${value}T23:59:59.999Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function monthRange(value: string) {
  const start = parseDayStart(`${value}-01`);
  if (!start) return null;
  const end = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 0, 23, 59, 59, 999));
  return { start, end };
}

function proposalInterval(proposal: TripAvailabilityProposal) {
  const start = parseDayStart(proposal.startDate);
  const end = parseDayEnd(proposal.endDate);
  if (!start || !end || end < start) return null;
  return { start, end };
}

function mergeIntervals(intervals: { start: Date; end: Date }[]) {
  const sorted = [...intervals].sort((a, b) => a.start.getTime() - b.start.getTime());
  const merged: { start: Date; end: Date }[] = [];

  sorted.forEach(interval => {
    const last = merged[merged.length - 1];
    if (!last) {
      merged.push(interval);
      return;
    }

    if (interval.start.getTime() <= last.end.getTime()) {
      last.end = new Date(Math.max(last.end.getTime(), interval.end.getTime()));
      return;
    }

    merged.push(interval);
  });

  return merged;
}

function intersectIntervals(
  left: { start: Date; end: Date }[],
  right: { start: Date; end: Date }[]
) {
  const intersections: { start: Date; end: Date }[] = [];

  left.forEach(lhs => {
    right.forEach(rhs => {
      const start = new Date(Math.max(lhs.start.getTime(), rhs.start.getTime()));
      const end = new Date(Math.min(lhs.end.getTime(), rhs.end.getTime()));
      if (start.getTime() <= end.getTime()) {
        intersections.push({ start, end });
      }
    });
  });

  return mergeIntervals(intersections);
}

function computeAvailabilityOverlaps(
  availability: TripAvailabilityProposal[],
  travelers: Traveler[]
): AvailabilityOverlap[] {
  if (travelers.length < 2) return [];

  const grouped = travelers.map(traveler =>
    mergeIntervals(
      availability
        .filter(proposal => proposal.participantId === traveler.id)
        .map(proposalInterval)
        .filter((interval): interval is { start: Date; end: Date } => interval !== null)
    )
  );

  if (grouped.some(group => group.length === 0)) return [];

  let current = grouped[0];
  grouped.slice(1).forEach(group => {
    current = intersectIntervals(current, group);
  });

  const exactCounts = new Map(
    travelers.map(traveler => [
      traveler.id,
      availability.filter(
        proposal =>
          proposal.participantId === traveler.id && proposal.kind === 'exact_dates'
      ).length,
    ])
  );

  const overlaps = current.map(interval => {
    let exactParticipantCount = 0;
    travelers.forEach(traveler => {
      const matchesExact = availability.some(proposal => {
        if (proposal.participantId !== traveler.id || proposal.kind !== 'exact_dates') {
          return false;
        }

        const proposalMatch = proposalInterval(proposal);
        if (!proposalMatch) return false;

        return (
          proposalMatch.start.getTime() <= interval.end.getTime() &&
          proposalMatch.end.getTime() >= interval.start.getTime()
        );
      });

      if (matchesExact || (exactCounts.get(traveler.id) ?? 0) === 0) {
        exactParticipantCount += 1;
      }
    });

    return {
      startDate: interval.start.toISOString().slice(0, 10),
      endDate: interval.end.toISOString().slice(0, 10),
      exactParticipantCount,
      totalParticipantCount: travelers.length,
    };
  });

  return overlaps
    .filter(
      (overlap, index, array) =>
        array.findIndex(
          candidate =>
            candidate.startDate === overlap.startDate &&
            candidate.endDate === overlap.endDate &&
            candidate.exactParticipantCount === overlap.exactParticipantCount
        ) === index
    )
    .sort((a, b) => {
      if (a.exactParticipantCount === b.exactParticipantCount) {
        return a.startDate.localeCompare(b.startDate);
      }
      return b.exactParticipantCount - a.exactParticipantCount;
    });
}

function availabilityBadge(
  overlaps: AvailabilityOverlap[],
  proposals: TripAvailabilityProposal[],
  travelerCount: number
) {
  if (travelerCount < 2) return null;
  if (proposals.length === 0) return 'No group availability added yet';
  if (overlaps.length === 0) return 'No shared window yet';

  const best = overlaps[0];
  const range = `${formatDate(best.startDate)} - ${formatDate(best.endDate)}`;
  if (best.exactParticipantCount === best.totalParticipantCount) {
    return `Best shared window: ${range}`;
  }
  return `Best overlap: ${range} (${best.exactParticipantCount}/${best.totalParticipantCount} exact)`;
}

async function getDefaultCalendarSource() {
  const defaultCalendar = await Calendar.getDefaultCalendarAsync();
  if (defaultCalendar?.source) {
    return defaultCalendar.source;
  }

  const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);
  const editable = calendars.find(calendar => calendar.allowsModifications);
  return editable?.source;
}

export default function TripPlannerScreen() {
  const colors = useTheme();
  const insets = useSafeAreaInsets();
  const { bucketIsoCodes, visitedIsoCodes, profile, session } = useAuth();
  const { selectedMonth } = useScorePreferences();
  const { countries } = useCountries();
  const { friends } = useFriends();

  const [trips, setTrips] = useState<PlannedTrip[]>([]);
  const [draft, setDraft] = useState<TripDraft>(emptyDraft);
  const [modalVisible, setModalVisible] = useState(false);
  const [countryQuery, setCountryQuery] = useState('');
  const [expenseDraftTitle, setExpenseDraftTitle] = useState('');
  const [expenseDraftAmount, setExpenseDraftAmount] = useState('');
  const [expenseDraftPaidById, setExpenseDraftPaidById] = useState<string | null>(null);
  const [expenseDraftSplitWithIds, setExpenseDraftSplitWithIds] = useState<string[]>([]);
  const [availabilityDraft, setAvailabilityDraft] = useState<AvailabilityDraft>(
    emptyAvailabilityDraft
  );

  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY)
      .then(value => {
        if (!value) return;
        const parsed = JSON.parse(value) as PlannedTrip[];
        setTrips(
          parsed.map(trip => ({
            ...trip,
            availability: Array.isArray(trip.availability) ? trip.availability : [],
            expenses: Array.isArray(trip.expenses) ? trip.expenses : [],
          }))
        );
      })
      .catch(error => {
        console.error('Failed to load trips', error);
      });
  }, []);

  const countryNameByIso2 = useMemo(
    () => new Map(countries.map(country => [country.iso2, country.name] as const)),
    [countries]
  );

  const friendNameById = useMemo(
    () =>
      new Map(
        friends.map(friend => [
          friend.id,
          friend.full_name || friend.username || 'Friend',
        ])
      ),
    [friends]
  );

  const plannerCountries = useMemo(() => {
    const prioritized = countries.filter(
      country =>
        bucketIsoCodes.includes(country.iso2) || visitedIsoCodes.includes(country.iso2)
    );
    const fallback = countries.filter(
      country =>
        !bucketIsoCodes.includes(country.iso2) && !visitedIsoCodes.includes(country.iso2)
    );

    return [...prioritized, ...fallback];
  }, [bucketIsoCodes, countries, visitedIsoCodes]);

  const filteredCountries = useMemo(() => {
    const query = countryQuery.trim().toLowerCase();
    const source = plannerCountries.filter(country => {
      if (!query) return true;
      return (
        country.name.toLowerCase().includes(query) ||
        country.iso2.toLowerCase().includes(query)
      );
    });

    return source.slice(0, 16);
  }, [countryQuery, plannerCountries]);

  const currentTraveler = useMemo(
    () =>
      session?.user?.id
        ? {
            id: session.user.id,
            name: profile?.full_name || profile?.username || 'You',
          }
        : null,
    [profile?.full_name, profile?.username, session?.user?.id]
  );

  const draftTravelers = useMemo(
    () => [
      ...(currentTraveler ? [currentTraveler] : []),
      ...friends
        .filter(friend => draft.friendIds.includes(friend.id))
        .map(friend => ({
          id: friend.id,
          name: friend.full_name || friend.username || 'Friend',
        })),
    ],
    [currentTraveler, draft.friendIds, friends]
  );

  const draftOverlaps = useMemo(
    () => computeAvailabilityOverlaps(draft.availability, draftTravelers),
    [draft.availability, draftTravelers]
  );

  const monthOptions = useMemo(() => {
    const base = new Date();
    return Array.from({ length: 8 }, (_, index) => {
      const date = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth() + index, 1));
      return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
    });
  }, []);

  const persistTrips = async (nextTrips: PlannedTrip[]) => {
    setTrips(nextTrips);
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(nextTrips));
  };

  const resetDraftHelpers = () => {
    setCountryQuery('');
    setExpenseDraftTitle('');
    setExpenseDraftAmount('');
    setExpenseDraftPaidById(null);
    setExpenseDraftSplitWithIds([]);
    setAvailabilityDraft(emptyAvailabilityDraft());
  };

  const openNewTrip = () => {
    setDraft(emptyDraft());
    resetDraftHelpers();
    setModalVisible(true);
  };

  const openEditTrip = (trip: PlannedTrip) => {
    setDraft({
      id: trip.id,
      title: trip.title,
      notes: trip.notes,
      includeDates: !!trip.startDate || !!trip.endDate,
      startDate: toDateInput(trip.startDate),
      endDate: toDateInput(trip.endDate),
      countryIso2s: trip.countryIso2s,
      friendIds: trip.friendIds,
      availability: Array.isArray(trip.availability) ? trip.availability : [],
      expenses: Array.isArray(trip.expenses) ? trip.expenses : [],
    });
    resetDraftHelpers();
    setModalVisible(true);
  };

  const closeModal = () => {
    setModalVisible(false);
  };

  const toggleCountry = (iso2: string) => {
    setDraft(current => ({
      ...current,
      countryIso2s: current.countryIso2s.includes(iso2)
        ? current.countryIso2s.filter(code => code !== iso2)
        : [...current.countryIso2s, iso2],
    }));
  };

  const toggleFriend = (friendId: string) => {
    setDraft(current => {
      const nextFriendIds = current.friendIds.includes(friendId)
        ? current.friendIds.filter(id => id !== friendId)
        : [...current.friendIds, friendId];

      const allowedParticipantIds = new Set([
        ...(currentTraveler ? [currentTraveler.id] : []),
        ...nextFriendIds,
      ]);

      return {
        ...current,
        friendIds: nextFriendIds,
        availability: current.availability.filter(proposal =>
          allowedParticipantIds.has(proposal.participantId)
        ),
      };
    });
  };

  const saveTrip = async () => {
    const title = draft.title.trim();
    if (!title) return;

    const now = new Date().toISOString();
    const nextTrip: PlannedTrip = {
      id: draft.id ?? now,
      title,
      notes: draft.notes.trim(),
      startDate:
        draft.includeDates && draft.startDate.trim()
          ? new Date(`${draft.startDate}T00:00:00.000Z`).toISOString()
          : null,
      endDate:
        draft.includeDates && draft.endDate.trim()
          ? new Date(`${draft.endDate}T00:00:00.000Z`).toISOString()
          : null,
      countryIso2s: draft.countryIso2s,
      friendIds: draft.friendIds,
      availability: draft.availability,
      expenses: draft.expenses,
      createdAt: draft.id ? trips.find(trip => trip.id === draft.id)?.createdAt ?? now : now,
      updatedAt: now,
    };

    const nextTrips = draft.id
      ? trips.map(trip => (trip.id === draft.id ? nextTrip : trip))
      : [nextTrip, ...trips];

    await persistTrips(nextTrips);
    closeModal();
  };

  const deleteTrip = async (tripId: string) => {
    await persistTrips(trips.filter(trip => trip.id !== tripId));
  };

  const selectedCountryNames = draft.countryIso2s.map(
    iso2 => countryNameByIso2.get(iso2) ?? iso2
  );
  const selectedFriendNames = draft.friendIds.map(
    friendId => friendNameById.get(friendId) ?? 'Friend'
  );

  const expenseTotal = (trip: PlannedTrip | TripDraft) =>
    trip.expenses.reduce((sum, expense) => sum + expense.totalAmount, 0);

  const toggleExpenseSplit = (participantId: string) => {
    setExpenseDraftSplitWithIds(current =>
      current.includes(participantId)
        ? current.filter(id => id !== participantId)
        : [...current, participantId]
    );
  };

  const addExpenseToDraft = () => {
    const title = expenseDraftTitle.trim();
    const totalAmount = Number(expenseDraftAmount);
    if (
      !title ||
      !Number.isFinite(totalAmount) ||
      totalAmount <= 0 ||
      !expenseDraftPaidById
    ) {
      Alert.alert('Incomplete expense', 'Add a title, amount, and who paid.');
      return;
    }

    const splitWithIds = expenseDraftSplitWithIds.length
      ? expenseDraftSplitWithIds
      : draftTravelers.map(participant => participant.id);

    const payer = draftTravelers.find(participant => participant.id === expenseDraftPaidById);
    if (!payer || splitWithIds.length === 0) {
      Alert.alert('Incomplete expense', 'Choose at least one traveler for the split.');
      return;
    }

    setDraft(current => ({
      ...current,
      expenses: [
        ...current.expenses,
        {
          id: new Date().toISOString(),
          title,
          totalAmount,
          paidById: payer.id,
          paidByName: payer.name,
          splitWithIds,
        },
      ],
    }));

    setExpenseDraftTitle('');
    setExpenseDraftAmount('');
    setExpenseDraftPaidById(null);
    setExpenseDraftSplitWithIds([]);
  };

  const addAvailabilityToDraft = () => {
    if (!availabilityDraft.participantId) {
      Alert.alert('Choose traveler', 'Pick who this availability belongs to first.');
      return;
    }

    const participant = draftTravelers.find(
      traveler => traveler.id === availabilityDraft.participantId
    );
    if (!participant) {
      Alert.alert('Traveler missing', 'Add the traveler to this trip first.');
      return;
    }

    let startDate = availabilityDraft.startDate.trim();
    let endDate = availabilityDraft.endDate.trim();

    if (availabilityDraft.kind === 'flexible_month') {
      const range = monthRange(availabilityDraft.flexibleMonth);
      if (!range) {
        Alert.alert('Choose month', 'Pick a flexible month before saving this window.');
        return;
      }
      startDate = range.start.toISOString().slice(0, 10);
      endDate = range.end.toISOString().slice(0, 10);
    }

    const start = parseDayStart(startDate);
    const end = parseDayEnd(endDate);
    if (!start || !end || end.getTime() < start.getTime()) {
      Alert.alert('Invalid dates', 'Availability needs a valid start and end date.');
      return;
    }

    setDraft(current => ({
      ...current,
      availability: [
        ...current.availability,
        {
          id: new Date().toISOString(),
          participantId: participant.id,
          participantName: participant.name,
          kind: availabilityDraft.kind,
          startDate,
          endDate,
        },
      ],
    }));

    setAvailabilityDraft(current => ({
      ...emptyAvailabilityDraft(),
      participantId: current.participantId,
    }));
  };

  const tripSummary = (trip: PlannedTrip) => {
    const tripCountries = countries.filter(country => trip.countryIso2s.includes(country.iso2));

    if (!tripCountries.length) {
      return null;
    }

    const average = (values: number[]) =>
      Math.round(values.reduce((sum, value) => sum + value, 0) / values.length);

    const overall = average(
      tripCountries.map(country => country.scoreTotal ?? 0).filter(value => Number.isFinite(value))
    );
    const affordability = average(
      tripCountries
        .map(country => country.facts?.affordability)
        .filter((value): value is number => typeof value === 'number')
    );
    const seasonality = average(
      tripCountries.map(country => seasonalityScoreForMonth(country, selectedMonth))
    );

    return { overall, affordability, seasonality };
  };

  const travelersForTrip = (trip: PlannedTrip) => {
    const currentName = currentTraveler?.name ?? profile?.full_name ?? profile?.username ?? 'You';

    return [
      ...(session?.user?.id ? [{ id: session.user.id, name: currentName }] : []),
      ...trip.friendIds.map(friendId => ({
        id: friendId,
        name: friendNameById.get(friendId) ?? 'Friend',
      })),
    ];
  };

  const addTripToCalendar = async (trip: PlannedTrip) => {
    if (!trip.startDate || !trip.endDate) {
      Alert.alert('Missing dates', 'Add trip dates before sending this to your calendar.');
      return;
    }

    try {
      const { status } = await Calendar.requestCalendarPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert(
          'Calendar access needed',
          'Allow calendar access to create an event from this trip.'
        );
        return;
      }

      const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);
      let writableCalendar = calendars.find(calendar => calendar.allowsModifications);

      if (!writableCalendar) {
        const sourceMaybe =
          Platform.OS === 'ios'
            ? await getDefaultCalendarSource()
            : {
                isLocalAccount: true,
                name: 'Travel AF',
                type: Calendar.SourceType.LOCAL,
              };

        if (!sourceMaybe) {
          Alert.alert('No calendar found', 'No writable calendar is available on this device.');
          return;
        }

        const source: Calendar.Source = sourceMaybe;

        const calendarId = await Calendar.createCalendarAsync({
          title: 'Travel AF Trips',
          color: '#065F46',
          entityType: Calendar.EntityTypes.EVENT,
          sourceId: source.id,
          source,
          name: 'Travel AF Trips',
          ownerAccount: 'personal',
          accessLevel: Calendar.CalendarAccessLevel.OWNER,
        });

        writableCalendar = { id: calendarId } as Calendar.Calendar;
      }

      if (!writableCalendar) {
        Alert.alert('No calendar found', 'Unable to find a writable calendar.');
        return;
      }

      const countrySummary = trip.countryIso2s
        .map(iso2 => countryNameByIso2.get(iso2) ?? iso2)
        .join(', ');
      const friendSummary = trip.friendIds
        .map(friendId => friendNameById.get(friendId) ?? 'Friend')
        .join(', ');
      const tripTravelers = travelersForTrip(trip);
      const overlaps = computeAvailabilityOverlaps(trip.availability, tripTravelers);
      const availabilitySummary = availabilityBadge(
        overlaps,
        trip.availability,
        tripTravelers.length
      );

      const notes = [
        trip.notes || null,
        countrySummary ? `Countries: ${countrySummary}` : null,
        friendSummary ? `Friends: ${friendSummary}` : null,
        availabilitySummary ? `Availability: ${availabilitySummary}` : null,
      ]
        .filter(Boolean)
        .join('\n');

      await Calendar.createEventAsync(writableCalendar.id, {
        title: trip.title,
        startDate: new Date(trip.startDate),
        endDate: new Date(trip.endDate),
        allDay: true,
        notes,
      });

      Alert.alert('Added to calendar', 'Your trip has been added to the device calendar.');
    } catch (error) {
      console.error('Calendar create error', error);
      Alert.alert('Calendar error', 'Unable to create the calendar event right now.');
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      <ScrollView
        contentContainerStyle={{
          paddingTop: insets.top + 18,
          paddingHorizontal: 20,
          paddingBottom: insets.bottom + 40,
        }}
        showsVerticalScrollIndicator={false}
      >
        <Pressable onPress={() => router.back()} style={styles.backButton}>
          <Text style={[styles.backText, { color: colors.textPrimary }]}>Back</Text>
        </Pressable>

        <View style={styles.headerRow}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.title, { color: colors.textPrimary }]}>Trip Planner</Text>
            <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
              Save trip ideas with destinations, dates, travelers, and the best
              shared windows you can actually make work.
            </Text>
          </View>

          <Pressable
            onPress={openNewTrip}
            style={[styles.addButton, { backgroundColor: colors.primary }]}
          >
            <Ionicons name="add" size={18} color={colors.primaryText} />
          </Pressable>
        </View>

        {trips.length === 0 ? (
          <Pressable
            onPress={openNewTrip}
            style={[
              styles.emptyCard,
              { backgroundColor: colors.card, borderColor: colors.border },
            ]}
          >
            <Ionicons name="airplane-outline" size={28} color={colors.textPrimary} />
            <Text style={[styles.emptyTitle, { color: colors.textPrimary }]}>
              Start your first trip plan
            </Text>
            <Text style={[styles.emptySubtitle, { color: colors.textSecondary }]}>
              Add dates, destinations, shared availability, and expense splits before
              anything gets booked.
            </Text>
          </Pressable>
        ) : (
          <View style={styles.tripStack}>
            {trips.map(trip => {
              const countrySummary = trip.countryIso2s
                .map(iso2 => countryNameByIso2.get(iso2) ?? iso2)
                .join(', ');
              const friendSummary = trip.friendIds
                .map(friendId => friendNameById.get(friendId) ?? 'Friend')
                .join(', ');
              const summary = tripSummary(trip);
              const totalExpenses = expenseTotal(trip);
              const tripTravelers = travelersForTrip(trip);
              const overlaps = computeAvailabilityOverlaps(trip.availability, tripTravelers);
              const availabilitySummary = availabilityBadge(
                overlaps,
                trip.availability,
                tripTravelers.length
              );

              return (
                <View
                  key={trip.id}
                  style={[
                    styles.tripCard,
                    { backgroundColor: colors.card, borderColor: colors.border },
                  ]}
                >
                  <View style={styles.tripCardHeader}>
                    <View style={{ flex: 1, marginRight: 12 }}>
                      <Text style={[styles.tripTitle, { color: colors.textPrimary }]}>
                        {trip.title}
                      </Text>
                      <Text style={[styles.tripMeta, { color: colors.textSecondary }]}>
                        {trip.startDate
                          ? `${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}`
                          : 'Dates not set'}
                      </Text>
                    </View>

                    <View style={styles.tripActions}>
                      <Pressable
                        onPress={() => addTripToCalendar(trip)}
                        disabled={!trip.startDate || !trip.endDate}
                      >
                        <Text
                          style={[
                            styles.tripActionText,
                            {
                              color:
                                trip.startDate && trip.endDate
                                  ? colors.primary
                                  : colors.textMuted,
                            },
                          ]}
                        >
                          Calendar
                        </Text>
                      </Pressable>
                      <Pressable onPress={() => openEditTrip(trip)}>
                        <Text style={[styles.tripActionText, { color: colors.primary }]}>
                          Edit
                        </Text>
                      </Pressable>
                      <Pressable onPress={() => deleteTrip(trip.id)}>
                        <Text style={[styles.tripActionText, { color: '#DC2626' }]}>
                          Delete
                        </Text>
                      </Pressable>
                    </View>
                  </View>

                  {countrySummary ? (
                    <Text style={[styles.tripDetail, { color: colors.textPrimary }]}>
                      Countries: {countrySummary}
                    </Text>
                  ) : null}

                  {friendSummary ? (
                    <Text style={[styles.tripDetail, { color: colors.textPrimary }]}>
                      Friends: {friendSummary}
                    </Text>
                  ) : null}

                  {availabilitySummary ? (
                    <View
                      style={[
                        styles.infoPanel,
                        { backgroundColor: colors.greenBg, borderColor: colors.greenBorder },
                      ]}
                    >
                      <Text style={[styles.infoText, { color: colors.greenText }]}>
                        {availabilitySummary}
                      </Text>
                      {overlaps.slice(0, 2).map(overlap => (
                        <Text key={`${overlap.startDate}-${overlap.endDate}`} style={[styles.infoSubtext, { color: colors.greenText }]}>
                          {formatDate(overlap.startDate)} - {formatDate(overlap.endDate)}
                        </Text>
                      ))}
                    </View>
                  ) : null}

                  {summary ? (
                    <View style={styles.statRow}>
                      <View
                        style={[
                          styles.statPill,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
                          Overall
                        </Text>
                        <Text style={[styles.statValue, { color: colors.textPrimary }]}>
                          {summary.overall}
                        </Text>
                      </View>

                      <View
                        style={[
                          styles.statPill,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
                          Budget
                        </Text>
                        <Text style={[styles.statValue, { color: colors.textPrimary }]}>
                          {summary.affordability}
                        </Text>
                      </View>

                      <View
                        style={[
                          styles.statPill,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
                          Season
                        </Text>
                        <Text style={[styles.statValue, { color: colors.textPrimary }]}>
                          {summary.seasonality}
                        </Text>
                      </View>
                    </View>
                  ) : null}

                  {trip.expenses.length ? (
                    <View style={styles.expenseCard}>
                      <Text style={[styles.expenseTitle, { color: colors.textPrimary }]}>
                        Expenses
                      </Text>
                      <Text style={[styles.tripDetail, { color: colors.textPrimary }]}>
                        Total tracked: ${totalExpenses.toFixed(2)}
                      </Text>
                      {trip.expenses.slice(0, 3).map(expense => (
                        <Text
                          key={expense.id}
                          style={[styles.tripNotes, { color: colors.textSecondary }]}
                        >
                          {expense.title}: ${expense.totalAmount.toFixed(2)} paid by{' '}
                          {expense.paidByName}
                        </Text>
                      ))}
                    </View>
                  ) : null}

                  {trip.notes ? (
                    <Text style={[styles.tripNotes, { color: colors.textSecondary }]}>
                      {trip.notes}
                    </Text>
                  ) : null}
                </View>
              );
            })}
          </View>
        )}
      </ScrollView>

      <Modal animationType="slide" visible={modalVisible} onRequestClose={closeModal}>
        <View style={{ flex: 1, backgroundColor: colors.background }}>
          <ScrollView
            contentContainerStyle={{
              paddingTop: insets.top + 18,
              paddingHorizontal: 20,
              paddingBottom: insets.bottom + 40,
            }}
            keyboardShouldPersistTaps="handled"
          >
            <View style={styles.modalHeader}>
              <Pressable onPress={closeModal}>
                <Text style={[styles.backText, { color: colors.textPrimary }]}>Cancel</Text>
              </Pressable>
              <Pressable onPress={saveTrip} disabled={!draft.title.trim()}>
                <Text
                  style={[
                    styles.saveText,
                    {
                      color: draft.title.trim() ? colors.primary : colors.textMuted,
                    },
                  ]}
                >
                  Save
                </Text>
              </Pressable>
            </View>

            <Text style={[styles.modalTitle, { color: colors.textPrimary }]}>
              {draft.id ? 'Edit Trip' : 'New Trip'}
            </Text>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Title</Text>
              <TextInput
                value={draft.title}
                onChangeText={value => setDraft(current => ({ ...current, title: value }))}
                placeholder="Summer in Portugal"
                placeholderTextColor={colors.textMuted}
                style={[
                  styles.textInput,
                  {
                    color: colors.textPrimary,
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                  },
                ]}
              />

              <Text
                style={[styles.sectionTitle, styles.sectionTopGap, { color: colors.textPrimary }]}
              >
                Notes
              </Text>
              <TextInput
                multiline
                value={draft.notes}
                onChangeText={value => setDraft(current => ({ ...current, notes: value }))}
                placeholder="Flights, timing, neighborhood ideas..."
                placeholderTextColor={colors.textMuted}
                style={[
                  styles.notesInput,
                  {
                    color: colors.textPrimary,
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                  },
                ]}
                textAlignVertical="top"
              />
            </View>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Pressable
                onPress={() =>
                  setDraft(current => ({
                    ...current,
                    includeDates: !current.includeDates,
                  }))
                }
                style={styles.switchRow}
              >
                <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                  Include dates
                </Text>
                <Text style={{ color: colors.primary, fontWeight: '700' }}>
                  {draft.includeDates ? 'On' : 'Off'}
                </Text>
              </Pressable>

              {draft.includeDates ? (
                <View style={styles.dateRow}>
                  <View
                    style={[
                      styles.dateButton,
                      { backgroundColor: colors.surface, borderColor: colors.border },
                    ]}
                  >
                    <Text style={[styles.dateLabel, { color: colors.textSecondary }]}>
                      Start
                    </Text>
                    <TextInput
                      value={draft.startDate}
                      onChangeText={value => setDraft(current => ({ ...current, startDate: value }))}
                      placeholder="YYYY-MM-DD"
                      placeholderTextColor={colors.textMuted}
                      style={[styles.dateInput, { color: colors.textPrimary }]}
                    />
                  </View>

                  <View
                    style={[
                      styles.dateButton,
                      { backgroundColor: colors.surface, borderColor: colors.border },
                    ]}
                  >
                    <Text style={[styles.dateLabel, { color: colors.textSecondary }]}>
                      End
                    </Text>
                    <TextInput
                      value={draft.endDate}
                      onChangeText={value => setDraft(current => ({ ...current, endDate: value }))}
                      placeholder="YYYY-MM-DD"
                      placeholderTextColor={colors.textMuted}
                      style={[styles.dateInput, { color: colors.textPrimary }]}
                    />
                  </View>
                </View>
              ) : null}
            </View>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Countries</Text>
              <TextInput
                value={countryQuery}
                onChangeText={setCountryQuery}
                placeholder="Search countries"
                placeholderTextColor={colors.textMuted}
                style={[
                  styles.textInput,
                  {
                    color: colors.textPrimary,
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                  },
                ]}
              />

              {selectedCountryNames.length ? (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Selected: {selectedCountryNames.join(', ')}
                </Text>
              ) : null}

              {draft.countryIso2s.length ? (
                <View style={styles.statRow}>
                  {countries
                    .filter(country => draft.countryIso2s.includes(country.iso2))
                    .slice(0, 3)
                    .map(country => (
                      <View
                        key={country.iso2}
                        style={[
                          styles.statPill,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
                          {country.flagEmoji ? `${country.flagEmoji} ` : ''}
                          {country.iso2}
                        </Text>
                        <Text style={[styles.statValue, { color: colors.textPrimary }]}>
                          {country.scoreTotal ?? 0}
                        </Text>
                      </View>
                    ))}
                </View>
              ) : null}

              <View style={styles.chipWrap}>
                {filteredCountries.map(country => {
                  const selected = draft.countryIso2s.includes(country.iso2);
                  return (
                    <Pressable
                      key={country.iso2}
                      onPress={() => toggleCountry(country.iso2)}
                      style={[
                        styles.chip,
                        {
                          backgroundColor: selected ? colors.primary : colors.surface,
                          borderColor: selected ? colors.primary : colors.border,
                        },
                      ]}
                    >
                      <Text
                        style={{
                          color: selected ? colors.primaryText : colors.textPrimary,
                          fontWeight: '600',
                        }}
                      >
                        {country.flagEmoji ? `${country.flagEmoji} ` : ''}
                        {country.name}
                      </Text>
                    </Pressable>
                  );
                })}
              </View>
            </View>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Friends</Text>

              {friends.length === 0 ? (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Add friends in the Friends tab to include them in a plan.
                </Text>
              ) : (
                <>
                  {selectedFriendNames.length ? (
                    <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                      Selected: {selectedFriendNames.join(', ')}
                    </Text>
                  ) : null}

                  <View style={styles.chipWrap}>
                    {friends.map(friend => {
                      const selected = draft.friendIds.includes(friend.id);
                      const label = friend.full_name || friend.username || 'Friend';
                      return (
                        <Pressable
                          key={friend.id}
                          onPress={() => toggleFriend(friend.id)}
                          style={[
                            styles.chip,
                            {
                              backgroundColor: selected ? colors.primary : colors.surface,
                              borderColor: selected ? colors.primary : colors.border,
                            },
                          ]}
                        >
                          <Text
                            style={{
                              color: selected ? colors.primaryText : colors.textPrimary,
                              fontWeight: '600',
                            }}
                          >
                            {label}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </View>
                </>
              )}
            </View>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                Availability
              </Text>
              <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                Add exact dates or flexible months for each traveler to spot real overlap.
              </Text>

              {draftTravelers.length === 0 ? (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Add yourself or friends to the trip before tracking shared availability.
                </Text>
              ) : (
                <>
                  <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                    Traveler
                  </Text>
                  <View style={styles.chipWrap}>
                    {draftTravelers.map(traveler => {
                      const selected = availabilityDraft.participantId === traveler.id;
                      return (
                        <Pressable
                          key={traveler.id}
                          onPress={() =>
                            setAvailabilityDraft(current => ({
                              ...current,
                              participantId: traveler.id,
                            }))
                          }
                          style={[
                            styles.chip,
                            {
                              backgroundColor: selected ? colors.primary : colors.surface,
                              borderColor: selected ? colors.primary : colors.border,
                            },
                          ]}
                        >
                          <Text
                            style={{
                              color: selected ? colors.primaryText : colors.textPrimary,
                              fontWeight: '600',
                            }}
                          >
                            {traveler.name}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </View>

                  <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                    Availability type
                  </Text>
                  <View style={styles.inlineRow}>
                    {[
                      { label: 'Exact dates', value: 'exact_dates' as const },
                      { label: 'Flexible month', value: 'flexible_month' as const },
                    ].map(option => {
                      const selected = availabilityDraft.kind === option.value;
                      return (
                        <Pressable
                          key={option.value}
                          onPress={() =>
                            setAvailabilityDraft(current => ({ ...current, kind: option.value }))
                          }
                          style={[
                            styles.segmentButton,
                            {
                              backgroundColor: selected ? colors.primary : colors.surface,
                              borderColor: selected ? colors.primary : colors.border,
                            },
                          ]}
                        >
                          <Text
                            style={{
                              color: selected ? colors.primaryText : colors.textPrimary,
                              fontWeight: '700',
                            }}
                          >
                            {option.label}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </View>

                  {availabilityDraft.kind === 'exact_dates' ? (
                    <View style={styles.dateRow}>
                      <View
                        style={[
                          styles.dateButton,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.dateLabel, { color: colors.textSecondary }]}>
                          Start
                        </Text>
                        <TextInput
                          value={availabilityDraft.startDate}
                          onChangeText={value =>
                            setAvailabilityDraft(current => ({ ...current, startDate: value }))
                          }
                          placeholder="YYYY-MM-DD"
                          placeholderTextColor={colors.textMuted}
                          style={[styles.dateInput, { color: colors.textPrimary }]}
                        />
                      </View>

                      <View
                        style={[
                          styles.dateButton,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.dateLabel, { color: colors.textSecondary }]}>
                          End
                        </Text>
                        <TextInput
                          value={availabilityDraft.endDate}
                          onChangeText={value =>
                            setAvailabilityDraft(current => ({ ...current, endDate: value }))
                          }
                          placeholder="YYYY-MM-DD"
                          placeholderTextColor={colors.textMuted}
                          style={[styles.dateInput, { color: colors.textPrimary }]}
                        />
                      </View>
                    </View>
                  ) : (
                    <View style={styles.chipWrap}>
                      {monthOptions.map(option => {
                        const selected = availabilityDraft.flexibleMonth === option;
                        return (
                          <Pressable
                            key={option}
                            onPress={() =>
                              setAvailabilityDraft(current => ({
                                ...current,
                                flexibleMonth: option,
                              }))
                            }
                            style={[
                              styles.chip,
                              {
                                backgroundColor: selected ? colors.primary : colors.surface,
                                borderColor: selected ? colors.primary : colors.border,
                              },
                            ]}
                          >
                            <Text
                              style={{
                                color: selected ? colors.primaryText : colors.textPrimary,
                                fontWeight: '600',
                              }}
                            >
                              {formatMonthLabel(option)}
                            </Text>
                          </Pressable>
                        );
                      })}
                    </View>
                  )}

                  <Pressable
                    onPress={addAvailabilityToDraft}
                    style={[styles.addExpenseButton, { backgroundColor: colors.primary }]}
                  >
                    <Text style={[styles.submitText, { color: colors.primaryText }]}>
                      Add Availability
                    </Text>
                  </Pressable>

                  {draftOverlaps.length ? (
                    <View
                      style={[
                        styles.infoPanel,
                        { backgroundColor: colors.greenBg, borderColor: colors.greenBorder },
                      ]}
                    >
                      <Text style={[styles.infoText, { color: colors.greenText }]}>
                        {availabilityBadge(
                          draftOverlaps,
                          draft.availability,
                          draftTravelers.length
                        )}
                      </Text>
                      {draftOverlaps.slice(0, 3).map(overlap => (
                        <Text
                          key={`${overlap.startDate}-${overlap.endDate}`}
                          style={[styles.infoSubtext, { color: colors.greenText }]}
                        >
                          {formatDate(overlap.startDate)} - {formatDate(overlap.endDate)}
                        </Text>
                      ))}
                    </View>
                  ) : null}

                  {draft.availability.length ? (
                    <View style={styles.availabilityList}>
                      {draftTravelers.map(traveler => {
                        const travelerProposals = draft.availability.filter(
                          proposal => proposal.participantId === traveler.id
                        );
                        if (travelerProposals.length === 0) return null;

                        return (
                          <View
                            key={traveler.id}
                            style={[
                              styles.availabilityGroup,
                              {
                                backgroundColor: colors.surface,
                                borderColor: colors.border,
                              },
                            ]}
                          >
                            <Text style={[styles.expenseTitle, { color: colors.textPrimary }]}>
                              {traveler.name}
                            </Text>
                            {travelerProposals.map(proposal => (
                              <View key={proposal.id} style={styles.availabilityRow}>
                                <View style={{ flex: 1, marginRight: 12 }}>
                                  <Text
                                    style={[styles.tripDetail, { color: colors.textPrimary }]}
                                  >
                                    {proposal.kind === 'exact_dates'
                                      ? `${formatDate(proposal.startDate)} - ${formatDate(proposal.endDate)}`
                                      : `Flexible ${formatMonthLabel(proposal.startDate.slice(0, 7))}`}
                                  </Text>
                                  <Text
                                    style={[styles.infoSubtext, { color: colors.textSecondary }]}
                                  >
                                    {proposal.kind === 'exact_dates'
                                      ? 'Exact dates'
                                      : 'Flexible month'}
                                  </Text>
                                </View>
                                <Pressable
                                  onPress={() =>
                                    setDraft(current => ({
                                      ...current,
                                      availability: current.availability.filter(
                                        item => item.id !== proposal.id
                                      ),
                                    }))
                                  }
                                >
                                  <Text style={[styles.tripActionText, { color: '#DC2626' }]}>
                                    Remove
                                  </Text>
                                </Pressable>
                              </View>
                            ))}
                          </View>
                        );
                      })}
                    </View>
                  ) : null}
                </>
              )}
            </View>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Expenses</Text>

              <TextInput
                value={expenseDraftTitle}
                onChangeText={setExpenseDraftTitle}
                placeholder="Expense title"
                placeholderTextColor={colors.textMuted}
                style={[
                  styles.textInput,
                  {
                    color: colors.textPrimary,
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                  },
                ]}
              />

              <TextInput
                value={expenseDraftAmount}
                onChangeText={setExpenseDraftAmount}
                placeholder="Amount in USD"
                placeholderTextColor={colors.textMuted}
                keyboardType="decimal-pad"
                style={[
                  styles.textInput,
                  {
                    color: colors.textPrimary,
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                    marginTop: 10,
                  },
                ]}
              />

              {draftTravelers.length ? (
                <>
                  <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                    Who paid?
                  </Text>
                  <View style={styles.chipWrap}>
                    {draftTravelers.map(participant => {
                      const selected = expenseDraftPaidById === participant.id;
                      return (
                        <Pressable
                          key={participant.id}
                          onPress={() => setExpenseDraftPaidById(participant.id)}
                          style={[
                            styles.chip,
                            {
                              backgroundColor: selected ? colors.primary : colors.surface,
                              borderColor: selected ? colors.primary : colors.border,
                            },
                          ]}
                        >
                          <Text
                            style={{
                              color: selected ? colors.primaryText : colors.textPrimary,
                              fontWeight: '600',
                            }}
                          >
                            {participant.name}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </View>

                  <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                    Split with
                  </Text>
                  <View style={styles.chipWrap}>
                    {draftTravelers.map(participant => {
                      const selected = expenseDraftSplitWithIds.includes(participant.id);
                      return (
                        <Pressable
                          key={`split-${participant.id}`}
                          onPress={() => toggleExpenseSplit(participant.id)}
                          style={[
                            styles.chip,
                            {
                              backgroundColor: selected ? colors.primary : colors.surface,
                              borderColor: selected ? colors.primary : colors.border,
                            },
                          ]}
                        >
                          <Text
                            style={{
                              color: selected ? colors.primaryText : colors.textPrimary,
                              fontWeight: '600',
                            }}
                          >
                            {participant.name}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </View>
                </>
              ) : (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Add yourself or friends to the trip before splitting expenses.
                </Text>
              )}

              <Pressable
                onPress={addExpenseToDraft}
                style={[styles.addExpenseButton, { backgroundColor: colors.primary }]}
              >
                <Text style={[styles.submitText, { color: colors.primaryText }]}>
                  Add Expense
                </Text>
              </Pressable>

              {draft.expenses.length ? (
                <View style={styles.expenseList}>
                  {draft.expenses.map(expense => (
                    <View
                      key={expense.id}
                      style={[
                        styles.expenseItem,
                        { backgroundColor: colors.surface, borderColor: colors.border },
                      ]}
                    >
                      <View style={{ flex: 1, marginRight: 12 }}>
                        <Text style={[styles.expenseTitle, { color: colors.textPrimary }]}>
                          {expense.title}
                        </Text>
                        <Text style={[styles.tripNotes, { color: colors.textSecondary }]}>
                          ${expense.totalAmount.toFixed(2)} paid by {expense.paidByName}
                        </Text>
                      </View>
                      <Pressable
                        onPress={() =>
                          setDraft(current => ({
                            ...current,
                            expenses: current.expenses.filter(item => item.id !== expense.id),
                          }))
                        }
                      >
                        <Text style={[styles.tripActionText, { color: '#DC2626' }]}>
                          Remove
                        </Text>
                      </Pressable>
                    </View>
                  ))}
                </View>
              ) : null}
            </View>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  backButton: {
    alignSelf: 'flex-start',
    marginBottom: 16,
  },
  backText: {
    fontSize: 15,
    fontWeight: '600',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 24,
  },
  title: {
    fontSize: 28,
    fontWeight: '800',
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 8,
    paddingRight: 12,
  },
  addButton: {
    width: 44,
    height: 44,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  emptyCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 22,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '700',
    marginTop: 12,
  },
  emptySubtitle: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: 8,
  },
  tripStack: {
    gap: 14,
  },
  tripCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 18,
  },
  tripCardHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  tripTitle: {
    fontSize: 18,
    fontWeight: '700',
  },
  tripMeta: {
    fontSize: 13,
    marginTop: 4,
  },
  tripActions: {
    flexDirection: 'row',
    gap: 14,
  },
  tripActionText: {
    fontSize: 14,
    fontWeight: '700',
  },
  tripDetail: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: 4,
  },
  tripNotes: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: 10,
  },
  expenseCard: {
    marginTop: 12,
  },
  expenseTitle: {
    fontSize: 15,
    fontWeight: '700',
    marginBottom: 4,
  },
  statRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 12,
  },
  statPill: {
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 10,
    minWidth: 84,
  },
  statLabel: {
    fontSize: 11,
    fontWeight: '700',
    marginBottom: 4,
  },
  statValue: {
    fontSize: 16,
    fontWeight: '800',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 18,
  },
  saveText: {
    fontSize: 15,
    fontWeight: '700',
  },
  submitText: {
    fontSize: 15,
    fontWeight: '700',
  },
  modalTitle: {
    fontSize: 28,
    fontWeight: '800',
    marginBottom: 20,
  },
  sectionCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 18,
    marginBottom: 14,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
  },
  sectionTopGap: {
    marginTop: 14,
  },
  textInput: {
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
    marginTop: 10,
  },
  notesInput: {
    minHeight: 110,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
    lineHeight: 21,
    marginTop: 10,
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dateRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 12,
  },
  dateButton: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 16,
    padding: 14,
  },
  dateLabel: {
    fontSize: 13,
    marginBottom: 4,
  },
  dateInput: {
    fontSize: 15,
    fontWeight: '600',
    paddingVertical: 0,
  },
  selectionSummary: {
    fontSize: 13,
    lineHeight: 18,
    marginTop: 10,
  },
  chipWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 12,
  },
  chip: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  inlineRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 12,
  },
  segmentButton: {
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  addExpenseButton: {
    minHeight: 44,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 14,
  },
  expenseList: {
    gap: 10,
    marginTop: 14,
  },
  expenseItem: {
    borderWidth: 1,
    borderRadius: 16,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
  },
  infoPanel: {
    borderWidth: 1,
    borderRadius: 18,
    padding: 14,
    marginTop: 12,
  },
  infoText: {
    fontSize: 14,
    fontWeight: '700',
    lineHeight: 20,
  },
  infoSubtext: {
    fontSize: 13,
    lineHeight: 18,
    marginTop: 4,
  },
  availabilityList: {
    gap: 10,
    marginTop: 14,
  },
  availabilityGroup: {
    borderWidth: 1,
    borderRadius: 18,
    padding: 12,
  },
  availabilityRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
});
