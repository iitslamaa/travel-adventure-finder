import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import {
  Modal,
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

type PlannedTrip = {
  id: string;
  title: string;
  notes: string;
  startDate: string | null;
  endDate: string | null;
  countryIso2s: string[];
  friendIds: string[];
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

export default function TripPlannerScreen() {
  const colors = useTheme();
  const insets = useSafeAreaInsets();
  const { bucketIsoCodes, visitedIsoCodes } = useAuth();
  const { selectedMonth } = useScorePreferences();
  const { countries } = useCountries();
  const { friends } = useFriends();

  const [trips, setTrips] = useState<PlannedTrip[]>([]);
  const [draft, setDraft] = useState<TripDraft>(emptyDraft);
  const [modalVisible, setModalVisible] = useState(false);
  const [countryQuery, setCountryQuery] = useState('');

  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY)
      .then(value => {
        if (!value) return;
        const parsed = JSON.parse(value) as PlannedTrip[];
        setTrips(parsed);
      })
      .catch(error => {
        console.error('Failed to load trips', error);
      });
  }, []);

  const countryNameByIso2 = useMemo(
    () =>
      new Map(
        countries.map(country => [country.iso2, country.name] as const)
      ),
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

  const persistTrips = async (nextTrips: PlannedTrip[]) => {
    setTrips(nextTrips);
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(nextTrips));
  };

  const openNewTrip = () => {
    setDraft(emptyDraft());
    setCountryQuery('');
    setModalVisible(true);
  };

  const openEditTrip = (trip: PlannedTrip) => {
    setDraft({
      id: trip.id,
      title: trip.title,
      notes: trip.notes,
      includeDates: !!trip.startDate || !!trip.endDate,
      startDate: trip.startDate ? trip.startDate.slice(0, 10) : '',
      endDate: trip.endDate ? trip.endDate.slice(0, 10) : '',
      countryIso2s: trip.countryIso2s,
      friendIds: trip.friendIds,
    });
    setCountryQuery('');
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
    setDraft(current => ({
      ...current,
      friendIds: current.friendIds.includes(friendId)
        ? current.friendIds.filter(id => id !== friendId)
        : [...current.friendIds, friendId],
    }));
  };

  const saveTrip = async () => {
    const title = draft.title.trim();
    if (!title) return;

    const now = new Date().toISOString();
    const nextTrip: PlannedTrip = {
      id: draft.id ?? now,
      title,
      notes: draft.notes.trim(),
      startDate: draft.includeDates && draft.startDate.trim()
        ? new Date(`${draft.startDate}T00:00:00.000Z`).toISOString()
        : null,
      endDate: draft.includeDates && draft.endDate.trim()
        ? new Date(`${draft.endDate}T00:00:00.000Z`).toISOString()
        : null,
      countryIso2s: draft.countryIso2s,
      friendIds: draft.friendIds,
      createdAt: draft.id
        ? trips.find(trip => trip.id === draft.id)?.createdAt ?? now
        : now,
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

  const tripSummary = (trip: PlannedTrip) => {
    const tripCountries = countries.filter(country =>
      trip.countryIso2s.includes(country.iso2)
    );

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
          <Text style={[styles.backText, { color: colors.textPrimary }]}>
            Back
          </Text>
        </Pressable>

        <View style={styles.headerRow}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.title, { color: colors.textPrimary }]}>
              Trip Planner
            </Text>
            <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
              Save trip ideas with destinations, dates, and people you want to
              travel with.
            </Text>
          </View>

          <Pressable
            onPress={openNewTrip}
            style={[
              styles.addButton,
              { backgroundColor: colors.primary },
            ]}
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
            <Ionicons
              name="airplane-outline"
              size={28}
              color={colors.textPrimary}
            />
            <Text style={[styles.emptyTitle, { color: colors.textPrimary }]}>
              Start your first trip plan
            </Text>
            <Text style={[styles.emptySubtitle, { color: colors.textSecondary }]}>
              Add a title, save a few countries, and sketch the trip before you
              book anything.
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
                      <Text
                        style={[styles.tripTitle, { color: colors.textPrimary }]}
                      >
                        {trip.title}
                      </Text>
                      <Text
                        style={[
                          styles.tripMeta,
                          { color: colors.textSecondary },
                        ]}
                      >
                        {trip.startDate
                          ? `${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}`
                          : 'Dates not set'}
                      </Text>
                    </View>

                    <View style={styles.tripActions}>
                      <Pressable onPress={() => openEditTrip(trip)}>
                        <Text
                          style={[styles.tripActionText, { color: colors.primary }]}
                        >
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

      <Modal
        animationType="slide"
        visible={modalVisible}
        onRequestClose={closeModal}
      >
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
                <Text style={[styles.backText, { color: colors.textPrimary }]}>
                  Cancel
                </Text>
              </Pressable>
              <Pressable
                onPress={saveTrip}
                disabled={!draft.title.trim()}
              >
                <Text
                  style={[
                    styles.saveText,
                    {
                      color: draft.title.trim()
                        ? colors.primary
                        : colors.textMuted,
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
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                Title
              </Text>
              <TextInput
                value={draft.title}
                onChangeText={value =>
                  setDraft(current => ({ ...current, title: value }))
                }
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

              <Text style={[styles.sectionTitle, styles.sectionTopGap, { color: colors.textPrimary }]}>
                Notes
              </Text>
              <TextInput
                multiline
                value={draft.notes}
                onChangeText={value =>
                  setDraft(current => ({ ...current, notes: value }))
                }
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
                      {
                        backgroundColor: colors.surface,
                        borderColor: colors.border,
                      },
                    ]}
                  >
                    <Text style={[styles.dateLabel, { color: colors.textSecondary }]}>
                      Start
                    </Text>
                    <TextInput
                      value={draft.startDate}
                      onChangeText={value =>
                        setDraft(current => ({ ...current, startDate: value }))
                      }
                      placeholder="YYYY-MM-DD"
                      placeholderTextColor={colors.textMuted}
                      style={[styles.dateInput, { color: colors.textPrimary }]}
                    />
                  </View>

                  <View
                    style={[
                      styles.dateButton,
                      {
                        backgroundColor: colors.surface,
                        borderColor: colors.border,
                      },
                    ]}
                  >
                    <Text style={[styles.dateLabel, { color: colors.textSecondary }]}>
                      End
                    </Text>
                    <TextInput
                      value={draft.endDate}
                      onChangeText={value =>
                        setDraft(current => ({ ...current, endDate: value }))
                      }
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
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                Countries
              </Text>
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
                          backgroundColor: selected
                            ? colors.primary
                            : colors.surface,
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
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                Friends
              </Text>

              {friends.length === 0 ? (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Add friends in the Friends tab to include them in a plan.
                </Text>
              ) : (
                <>
                  {selectedFriendNames.length ? (
                    <Text
                      style={[
                        styles.selectionSummary,
                        { color: colors.textSecondary },
                      ]}
                    >
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
                              backgroundColor: selected
                                ? colors.primary
                                : colors.surface,
                              borderColor: selected ? colors.primary : colors.border,
                            },
                          ]}
                        >
                          <Text
                            style={{
                              color: selected
                                ? colors.primaryText
                                : colors.textPrimary,
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
  dateValue: {
    fontSize: 15,
    fontWeight: '600',
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
});
