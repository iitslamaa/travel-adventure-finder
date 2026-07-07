import { Ionicons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import airportsJson from '../../../packages/data/seed/airports.json';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';
import ScrapbookCard from '../components/theme/ScrapbookCard';
import TitleBanner from '../components/theme/TitleBanner';
import { useTheme } from '../hooks/useTheme';
import { openExternalUrl } from '../utils/externalLinks';

type Airport = {
  iata: string;
  name: string;
  cityName: string;
  countryIso2: string;
  lat: number;
  lon: number;
};

type StopDraft = {
  id: string;
  query: string;
  minNights: string;
  maxNights: string;
  fixedDate: string;
};

type ResolvedStop = {
  id: string;
  airport: Airport;
  minNights: number;
  maxNights: number;
  fixedDate: string | null;
};

type FlightLeg = {
  from: Airport;
  to: Airport;
  date: string;
  distanceKm: number;
};

type CandidateStop = {
  stop: ResolvedStop;
  arrivalDate: string;
  departureDate: string;
  nights: number;
};

type RouteCandidate = {
  id: string;
  startDate: string;
  endDate: string;
  tripDays: number;
  routeDistanceKm: number;
  score: number;
  stops: CandidateStop[];
  legs: FlightLeg[];
};

const AIRPORTS = (airportsJson as Airport[]).map(airport => ({
  ...airport,
  iata: airport.iata.toUpperCase(),
  countryIso2: airport.countryIso2.toUpperCase(),
}));

const DEFAULT_STOPS: StopDraft[] = [
  { id: 'stop-1', query: 'CDG', minNights: '3', maxNights: '4', fixedDate: '' },
  { id: 'stop-2', query: 'BEY', minNights: '3', maxNights: '5', fixedDate: '' },
  { id: 'stop-3', query: 'DXB', minNights: '2', maxNights: '3', fixedDate: '' },
];

function createId() {
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function clampNumber(value: string, fallback: number, min: number, max: number) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(parsed, min), max);
}

function parseDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value.trim())) return null;
  const date = new Date(`${value.trim()}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function toIsoDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

function addDays(isoDate: string, days: number) {
  const date = parseDate(isoDate);
  if (!date) return isoDate;
  date.setUTCDate(date.getUTCDate() + days);
  return toIsoDate(date);
}

function diffDays(startDate: string, endDate: string) {
  const start = parseDate(startDate);
  const end = parseDate(endDate);
  if (!start || !end) return 0;
  return Math.round((end.getTime() - start.getTime()) / 86_400_000);
}

function isDateInStay(fixedDate: string | null, arrivalDate: string, departureDate: string) {
  if (!fixedDate) return true;
  return fixedDate >= arrivalDate && fixedDate < departureDate;
}

function airportLabel(airport: Airport) {
  return `${airport.iata} - ${airport.cityName}`;
}

function findAirport(query: string) {
  const normalized = query.trim().toUpperCase();
  if (!normalized) return null;

  return (
    AIRPORTS.find(airport => airport.iata === normalized) ??
    AIRPORTS.find(airport => airport.cityName.toUpperCase() === normalized) ??
    AIRPORTS.find(airport => airport.cityName.toUpperCase().includes(normalized)) ??
    AIRPORTS.find(airport => airport.name.toUpperCase().includes(normalized)) ??
    null
  );
}

function airportSuggestions(query: string) {
  const normalized = query.trim().toUpperCase();
  if (!normalized) return AIRPORTS.slice(0, 5);

  return AIRPORTS.filter(airport => {
    return (
      airport.iata.includes(normalized) ||
      airport.cityName.toUpperCase().includes(normalized) ||
      airport.name.toUpperCase().includes(normalized)
    );
  }).slice(0, 5);
}

function distanceKm(a: Airport, b: Airport) {
  const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
  const radiusKm = 6371;
  const dLat = toRadians(b.lat - a.lat);
  const dLon = toRadians(b.lon - a.lon);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);
  const sinLat = Math.sin(dLat / 2);
  const sinLon = Math.sin(dLon / 2);
  const h = sinLat * sinLat + Math.cos(lat1) * Math.cos(lat2) * sinLon * sinLon;
  return Math.round(radiusKm * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h)));
}

function permutations<T>(items: T[], limit = 240): T[][] {
  const results: T[][] = [];
  const used = new Set<number>();

  function walk(path: T[]) {
    if (results.length >= limit) return;
    if (path.length === items.length) {
      results.push(path);
      return;
    }

    items.forEach((item, index) => {
      if (used.has(index)) return;
      used.add(index);
      walk([...path, item]);
      used.delete(index);
    });
  }

  walk([]);
  return results;
}

function nightCombinations(stops: ResolvedStop[], limit = 400) {
  const results: number[][] = [];

  function walk(index: number, path: number[]) {
    if (results.length >= limit) return;
    if (index === stops.length) {
      results.push(path);
      return;
    }

    const stop = stops[index];
    for (let nights = stop.minNights; nights <= stop.maxNights; nights += 1) {
      walk(index + 1, [...path, nights]);
    }
  }

  walk(0, []);
  return results;
}

function resolveStops(stops: StopDraft[]) {
  return stops
    .map(stop => {
      const airport = findAirport(stop.query);
      if (!airport) return null;
      const minNights = clampNumber(stop.minNights, 2, 1, 30);
      const maxNights = Math.max(minNights, clampNumber(stop.maxNights, minNights, 1, 30));
      const fixedDate = parseDate(stop.fixedDate) ? stop.fixedDate.trim() : null;

      return {
        id: stop.id,
        airport,
        minNights,
        maxNights,
        fixedDate,
      };
    })
    .filter((stop): stop is ResolvedStop => stop !== null);
}

function buildCandidates({
  origin,
  stops,
  startDate,
  targetDays,
  dayFlex,
  startFlex,
  returnHome,
}: {
  origin: Airport | null;
  stops: ResolvedStop[];
  startDate: string;
  targetDays: number;
  dayFlex: number;
  startFlex: number;
  returnHome: boolean;
}) {
  if (!origin || stops.length < 2 || !parseDate(startDate)) return [];

  const routes = permutations(stops);
  const startDates = Array.from({ length: startFlex * 2 + 1 }, (_, index) =>
    addDays(startDate, index - startFlex)
  );
  const minTripDays = Math.max(1, targetDays - dayFlex);
  const maxTripDays = targetDays + dayFlex;
  const candidates: RouteCandidate[] = [];

  for (const route of routes) {
    const combos = nightCombinations(route);

    for (const candidateStart of startDates) {
      for (const nightsByStop of combos) {
        const candidateStops: CandidateStop[] = [];
        const legs: FlightLeg[] = [];
        let currentAirport = origin;
        let currentDate = candidateStart;
        let routeDistanceKm = 0;
        let fixedPenalty = 0;

        route.forEach((stop, index) => {
          const legDistance = distanceKm(currentAirport, stop.airport);
          legs.push({
            from: currentAirport,
            to: stop.airport,
            date: currentDate,
            distanceKm: legDistance,
          });
          routeDistanceKm += legDistance;

          const arrivalDate = currentDate;
          const departureDate = addDays(arrivalDate, nightsByStop[index]);
          if (!isDateInStay(stop.fixedDate, arrivalDate, departureDate)) {
            fixedPenalty += 80_000;
          }

          candidateStops.push({
            stop,
            arrivalDate,
            departureDate,
            nights: nightsByStop[index],
          });

          currentAirport = stop.airport;
          currentDate = departureDate;
        });

        if (returnHome) {
          const returnDistance = distanceKm(currentAirport, origin);
          legs.push({
            from: currentAirport,
            to: origin,
            date: currentDate,
            distanceKm: returnDistance,
          });
          routeDistanceKm += returnDistance;
        }

        const endDate = currentDate;
        const tripDays = Math.max(1, diffDays(candidateStart, endDate));
        if (tripDays < minTripDays || tripDays > maxTripDays) continue;

        const durationPenalty = Math.abs(tripDays - targetDays) * 1200;
        const longLegPenalty = legs.filter(leg => leg.distanceKm > 7000).length * 900;
        const backtrackPenalty = routeDistanceKm / Math.max(1, route.length) > 5500 ? 700 : 0;

        candidates.push({
          id: `${candidateStart}-${route.map(stop => stop.airport.iata).join('-')}-${nightsByStop.join('-')}`,
          startDate: candidateStart,
          endDate,
          tripDays,
          routeDistanceKm,
          score: routeDistanceKm + durationPenalty + longLegPenalty + backtrackPenalty + fixedPenalty,
          stops: candidateStops,
          legs,
        });
      }
    }
  }

  return candidates
    .sort((a, b) => a.score - b.score || a.routeDistanceKm - b.routeDistanceKm)
    .slice(0, 8);
}

function googleFlightsUrl(leg: FlightLeg) {
  const query = encodeURIComponent(`Flights ${leg.from.iata} to ${leg.to.iata} on ${leg.date}`);
  return `https://www.google.com/travel/flights?q=${query}`;
}

export default function FlightPathToolScreen() {
  const params = useLocalSearchParams<{
    startDate?: string;
    endDate?: string;
    destinations?: string;
  }>();
  const colors = useTheme();
  const insets = useSafeAreaInsets();
  const initialStops = useMemo(() => {
    const destinationCodes = typeof params.destinations === 'string'
      ? params.destinations.split(',').map(value => value.trim()).filter(Boolean)
      : [];
    if (destinationCodes.length === 0) return DEFAULT_STOPS;

    return destinationCodes.slice(0, 5).map((code, index) => ({
      id: `param-stop-${index}`,
      query: code,
      minNights: '2',
      maxNights: '4',
      fixedDate: '',
    }));
  }, [params.destinations]);
  const initialTargetDays = useMemo(() => {
    if (typeof params.startDate !== 'string' || typeof params.endDate !== 'string') return '12';
    const days = diffDays(params.startDate, params.endDate);
    return days > 0 ? String(days) : '12';
  }, [params.endDate, params.startDate]);

  const [originQuery, setOriginQuery] = useState('JFK');
  const [startDate, setStartDate] = useState(
    typeof params.startDate === 'string' && parseDate(params.startDate) ? params.startDate : '2026-09-01'
  );
  const [targetDays, setTargetDays] = useState(initialTargetDays);
  const [dayFlex, setDayFlex] = useState('2');
  const [startFlex, setStartFlex] = useState('3');
  const [returnHome, setReturnHome] = useState(true);
  const [stops, setStops] = useState<StopDraft[]>(initialStops);

  const originAirport = useMemo(() => findAirport(originQuery), [originQuery]);
  const resolvedStops = useMemo(() => resolveStops(stops), [stops]);
  const candidates = useMemo(
    () =>
      buildCandidates({
        origin: originAirport,
        stops: resolvedStops,
        startDate,
        targetDays: clampNumber(targetDays, 10, 2, 90),
        dayFlex: clampNumber(dayFlex, 0, 0, 30),
        startFlex: clampNumber(startFlex, 0, 0, 30),
        returnHome,
      }),
    [dayFlex, originAirport, resolvedStops, returnHome, startDate, startFlex, targetDays]
  );

  const updateStop = (id: string, patch: Partial<StopDraft>) => {
    setStops(current =>
      current.map(stop => (stop.id === id ? { ...stop, ...patch } : stop))
    );
  };

  const addStop = () => {
    if (stops.length >= 5) {
      Alert.alert('Stop limit', 'Add up to five destination cities for this search.');
      return;
    }
    setStops(current => [
      ...current,
      { id: createId(), query: '', minNights: '2', maxNights: '4', fixedDate: '' },
    ]);
  };

  const removeStop = (id: string) => {
    setStops(current => current.filter(stop => stop.id !== id));
  };

  const openCandidateSearch = async (candidate: RouteCandidate) => {
    const firstLeg = candidate.legs[0];
    if (!firstLeg) return;
    await openExternalUrl(googleFlightsUrl(firstLeg));
  };

  return (
    <ScrapbookBackground>
      <View style={{ flex: 1, backgroundColor: 'transparent' }}>
        <ScrollView
          contentContainerStyle={{
            paddingTop: insets.top + 18,
            paddingHorizontal: 20,
            paddingBottom: insets.bottom + 42,
          }}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <Pressable
            onPress={() => router.back()}
            style={[styles.backButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
          >
            <Ionicons name="chevron-back" size={18} color={colors.textPrimary} />
          </Pressable>

          <TitleBanner title="Flight Paths" />

          <ScrapbookCard
            style={styles.introShell}
            innerStyle={[styles.introCard, { backgroundColor: `${colors.card}F2` }]}
          >
            <Text style={[styles.eyebrow, { color: colors.textSecondary }]}>
              Trip Planner
            </Text>
            <Text style={[styles.introTitle, { color: colors.textPrimary }]}>
              Compare flexible multi-city routes
            </Text>
            <View style={styles.statRow}>
              <View style={[styles.statPill, { backgroundColor: colors.surface, borderColor: colors.border }]}>
                <Text style={[styles.statLabel, { color: colors.textSecondary }]}>Stops</Text>
                <Text style={[styles.statValue, { color: colors.textPrimary }]}>{resolvedStops.length}</Text>
              </View>
              <View style={[styles.statPill, { backgroundColor: colors.surface, borderColor: colors.border }]}>
                <Text style={[styles.statLabel, { color: colors.textSecondary }]}>Routes</Text>
                <Text style={[styles.statValue, { color: colors.textPrimary }]}>{candidates.length}</Text>
              </View>
              <View style={[styles.statPill, { backgroundColor: colors.surface, borderColor: colors.border }]}>
                <Text style={[styles.statLabel, { color: colors.textSecondary }]}>Source</Text>
                <Text style={[styles.statValueSmall, { color: colors.textPrimary }]}>Google</Text>
              </View>
            </View>
          </ScrapbookCard>

          <View style={[styles.sectionCard, { backgroundColor: colors.card, borderColor: colors.border }]}>
            <Text style={[styles.eyebrow, { color: colors.textSecondary }]}>Search window</Text>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Trip shape</Text>

            <Text style={[styles.inputLabel, { color: colors.textSecondary }]}>Origin airport or city</Text>
            <TextInput
              value={originQuery}
              onChangeText={setOriginQuery}
              placeholder="JFK, LAX, Paris..."
              placeholderTextColor={colors.textMuted}
              autoCapitalize="characters"
              style={[styles.textInput, { color: colors.textPrimary, backgroundColor: colors.surface, borderColor: colors.border }]}
            />
            {originAirport ? (
              <Text style={[styles.matchText, { color: colors.textSecondary }]}>
                {airportLabel(originAirport)}
              </Text>
            ) : null}

            <View style={styles.dateRow}>
              <View style={[styles.dateBox, { backgroundColor: colors.surface, borderColor: colors.border }]}>
                <Text style={[styles.inputLabel, { color: colors.textSecondary }]}>Start date</Text>
                <TextInput
                  value={startDate}
                  onChangeText={setStartDate}
                  placeholder="YYYY-MM-DD"
                  placeholderTextColor={colors.textMuted}
                  keyboardType="numbers-and-punctuation"
                  style={[styles.dateInput, { color: colors.textPrimary }]}
                />
              </View>
              <View style={[styles.dateBox, { backgroundColor: colors.surface, borderColor: colors.border }]}>
                <Text style={[styles.inputLabel, { color: colors.textSecondary }]}>+/- days</Text>
                <TextInput
                  value={startFlex}
                  onChangeText={setStartFlex}
                  placeholder="3"
                  placeholderTextColor={colors.textMuted}
                  keyboardType="number-pad"
                  style={[styles.dateInput, { color: colors.textPrimary }]}
                />
              </View>
            </View>

            <View style={styles.dateRow}>
              <View style={[styles.dateBox, { backgroundColor: colors.surface, borderColor: colors.border }]}>
                <Text style={[styles.inputLabel, { color: colors.textSecondary }]}>Trip days</Text>
                <TextInput
                  value={targetDays}
                  onChangeText={setTargetDays}
                  placeholder="12"
                  placeholderTextColor={colors.textMuted}
                  keyboardType="number-pad"
                  style={[styles.dateInput, { color: colors.textPrimary }]}
                />
              </View>
              <View style={[styles.dateBox, { backgroundColor: colors.surface, borderColor: colors.border }]}>
                <Text style={[styles.inputLabel, { color: colors.textSecondary }]}>+/- range</Text>
                <TextInput
                  value={dayFlex}
                  onChangeText={setDayFlex}
                  placeholder="2"
                  placeholderTextColor={colors.textMuted}
                  keyboardType="number-pad"
                  style={[styles.dateInput, { color: colors.textPrimary }]}
                />
              </View>
            </View>

            <Pressable
              onPress={() => setReturnHome(current => !current)}
              style={[styles.toggleRow, { backgroundColor: colors.surface, borderColor: colors.border }]}
            >
              <View>
                <Text style={[styles.toggleTitle, { color: colors.textPrimary }]}>Return home</Text>
                <Text style={[styles.matchText, { color: colors.textSecondary }]}>
                  {returnHome ? 'Round trip route' : 'Open jaw route'}
                </Text>
              </View>
              <Ionicons
                name={returnHome ? 'checkmark-circle' : 'ellipse-outline'}
                size={24}
                color={returnHome ? colors.scoreGood : colors.textMuted}
              />
            </Pressable>
          </View>

          <View style={[styles.sectionCard, { backgroundColor: colors.card, borderColor: colors.border }]}>
            <View style={styles.sectionHeaderRow}>
              <View style={{ flex: 1 }}>
                <Text style={[styles.eyebrow, { color: colors.textSecondary }]}>Destinations</Text>
                <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Cities</Text>
              </View>
              <Pressable
                onPress={addStop}
                style={[styles.iconButton, { backgroundColor: colors.surface, borderColor: colors.border }]}
              >
                <Ionicons name="add" size={18} color={colors.textPrimary} />
              </Pressable>
            </View>

            <View style={styles.stopList}>
              {stops.map((stop, index) => {
                const matchedAirport = findAirport(stop.query);
                const suggestions = airportSuggestions(stop.query);

                return (
                  <View
                    key={stop.id}
                    style={[styles.stopCard, { backgroundColor: colors.surface, borderColor: colors.border }]}
                  >
                    <View style={styles.stopHeader}>
                      <Text style={[styles.stopTitle, { color: colors.textPrimary }]}>
                        City {index + 1}
                      </Text>
                      {stops.length > 2 ? (
                        <Pressable onPress={() => removeStop(stop.id)}>
                          <Text style={[styles.removeText, { color: colors.redText }]}>Remove</Text>
                        </Pressable>
                      ) : null}
                    </View>

                    <TextInput
                      value={stop.query}
                      onChangeText={value => updateStop(stop.id, { query: value })}
                      placeholder="Airport or city"
                      placeholderTextColor={colors.textMuted}
                      autoCapitalize="characters"
                      style={[styles.textInput, { color: colors.textPrimary, backgroundColor: colors.card, borderColor: colors.border }]}
                    />
                    {matchedAirport ? (
                      <Text style={[styles.matchText, { color: colors.textSecondary }]}>
                        {airportLabel(matchedAirport)}
                      </Text>
                    ) : null}

                    <View style={styles.suggestionRow}>
                      {suggestions.map(suggestion => (
                        <Pressable
                          key={`${stop.id}-${suggestion.iata}`}
                          onPress={() => updateStop(stop.id, { query: suggestion.iata })}
                          style={[styles.suggestionChip, { backgroundColor: colors.card, borderColor: colors.border }]}
                        >
                          <Text style={[styles.suggestionText, { color: colors.textPrimary }]}>
                            {suggestion.iata}
                          </Text>
                        </Pressable>
                      ))}
                    </View>

                    <View style={styles.dateRow}>
                      <View style={[styles.compactBox, { backgroundColor: colors.card, borderColor: colors.border }]}>
                        <Text style={[styles.inputLabel, { color: colors.textSecondary }]}>Min nights</Text>
                        <TextInput
                          value={stop.minNights}
                          onChangeText={value => updateStop(stop.id, { minNights: value })}
                          keyboardType="number-pad"
                          style={[styles.dateInput, { color: colors.textPrimary }]}
                        />
                      </View>
                      <View style={[styles.compactBox, { backgroundColor: colors.card, borderColor: colors.border }]}>
                        <Text style={[styles.inputLabel, { color: colors.textSecondary }]}>Max nights</Text>
                        <TextInput
                          value={stop.maxNights}
                          onChangeText={value => updateStop(stop.id, { maxNights: value })}
                          keyboardType="number-pad"
                          style={[styles.dateInput, { color: colors.textPrimary }]}
                        />
                      </View>
                    </View>

                    <TextInput
                      value={stop.fixedDate}
                      onChangeText={value => updateStop(stop.id, { fixedDate: value })}
                      placeholder="Must be here on YYYY-MM-DD"
                      placeholderTextColor={colors.textMuted}
                      keyboardType="numbers-and-punctuation"
                      style={[styles.textInput, { color: colors.textPrimary, backgroundColor: colors.card, borderColor: colors.border }]}
                    />
                  </View>
                );
              })}
            </View>
          </View>

          <View style={[styles.sectionCard, { backgroundColor: colors.card, borderColor: colors.border }]}>
            <Text style={[styles.eyebrow, { color: colors.textSecondary }]}>Ranked routes</Text>
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Best flight paths</Text>

            {!originAirport || resolvedStops.length < 2 || !parseDate(startDate) ? (
              <View style={[styles.infoPanel, { backgroundColor: colors.yellowBg, borderColor: colors.yellowBorder }]}>
                <Text style={[styles.infoText, { color: colors.yellowText }]}>
                  Add a valid origin, date, and at least two destination airports.
                </Text>
              </View>
            ) : null}

            <View style={styles.candidateList}>
              {candidates.map((candidate, index) => (
                <View
                  key={candidate.id}
                  style={[styles.candidateCard, { backgroundColor: colors.surface, borderColor: colors.border }]}
                >
                  <View style={styles.candidateHeader}>
                    <View style={{ flex: 1, marginRight: 10 }}>
                      <Text style={[styles.candidateTitle, { color: colors.textPrimary }]}>
                        Option {index + 1}
                      </Text>
                      <Text style={[styles.matchText, { color: colors.textSecondary }]}>
                        {candidate.startDate} to {candidate.endDate} · {candidate.tripDays} days
                      </Text>
                    </View>
                    <View style={[styles.distancePill, { backgroundColor: colors.card, borderColor: colors.border }]}>
                      <Text style={[styles.distanceText, { color: colors.textPrimary }]}>
                        {Math.round(candidate.routeDistanceKm).toLocaleString()} km
                      </Text>
                    </View>
                  </View>

                  <View style={styles.routeLine}>
                    <Text style={[styles.routeText, { color: colors.textPrimary }]}>
                      {candidate.legs.map(leg => leg.from.iata).slice(0, 1).join('')}
                      {' -> '}
                      {candidate.stops.map(item => item.stop.airport.iata).join(' -> ')}
                      {returnHome && originAirport ? ` -> ${originAirport.iata}` : ''}
                    </Text>
                  </View>

                  {candidate.stops.map(item => (
                    <Text
                      key={`${candidate.id}-${item.stop.id}`}
                      style={[styles.itineraryText, { color: colors.textSecondary }]}
                    >
                      {item.stop.airport.cityName}: {item.arrivalDate} to {item.departureDate} · {item.nights} night{item.nights === 1 ? '' : 's'}
                    </Text>
                  ))}

                  <View style={styles.legList}>
                    {candidate.legs.map(leg => (
                      <Pressable
                        key={`${candidate.id}-${leg.from.iata}-${leg.to.iata}-${leg.date}`}
                        onPress={() => openExternalUrl(googleFlightsUrl(leg))}
                        style={[styles.legButton, { backgroundColor: colors.card, borderColor: colors.border }]}
                      >
                        <Ionicons name="airplane-outline" size={15} color={colors.textPrimary} />
                        <Text style={[styles.legText, { color: colors.textPrimary }]}>
                          {leg.from.iata} to {leg.to.iata} · {leg.date}
                        </Text>
                      </Pressable>
                    ))}
                  </View>

                  <Pressable
                    onPress={() => openCandidateSearch(candidate)}
                    style={[styles.primaryButton, { backgroundColor: colors.primary }]}
                  >
                    <Text style={[styles.primaryButtonText, { color: colors.primaryText }]}>
                      Search first leg
                    </Text>
                  </Pressable>
                </View>
              ))}
            </View>
          </View>
        </ScrollView>
      </View>
    </ScrapbookBackground>
  );
}

const styles = StyleSheet.create({
  backButton: {
    alignSelf: 'flex-start',
    marginBottom: 16,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  introShell: {
    marginTop: 12,
    marginBottom: 14,
  },
  introCard: {
    padding: 18,
  },
  eyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.6,
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  introTitle: {
    fontSize: 19,
    fontWeight: '800',
    lineHeight: 24,
  },
  statRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 14,
  },
  statPill: {
    flex: 1,
    minWidth: 86,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  statLabel: {
    fontSize: 11,
    fontWeight: '700',
    marginBottom: 4,
  },
  statValue: {
    fontSize: 18,
    fontWeight: '800',
  },
  statValueSmall: {
    fontSize: 15,
    fontWeight: '800',
  },
  sectionCard: {
    borderWidth: 1,
    borderRadius: 28,
    padding: 20,
    marginBottom: 16,
    shadowColor: '#8d7559',
    shadowOpacity: 0.12,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 9 },
    elevation: 5,
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '800',
  },
  inputLabel: {
    fontSize: 12,
    fontWeight: '800',
    marginTop: 12,
    marginBottom: 6,
  },
  textInput: {
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 15,
    paddingVertical: 13,
    fontSize: 15,
  },
  matchText: {
    fontSize: 12,
    lineHeight: 17,
    marginTop: 6,
    fontWeight: '600',
  },
  dateRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 10,
  },
  dateBox: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingBottom: 12,
  },
  compactBox: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 13,
    paddingBottom: 10,
  },
  dateInput: {
    fontSize: 15,
    fontWeight: '700',
    paddingVertical: 0,
  },
  toggleRow: {
    minHeight: 58,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginTop: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  toggleTitle: {
    fontSize: 15,
    fontWeight: '800',
  },
  iconButton: {
    width: 42,
    height: 42,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stopList: {
    gap: 12,
    marginTop: 14,
  },
  stopCard: {
    borderWidth: 1,
    borderRadius: 20,
    padding: 14,
  },
  stopHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  stopTitle: {
    fontSize: 15,
    fontWeight: '800',
  },
  removeText: {
    fontSize: 13,
    fontWeight: '700',
  },
  suggestionRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 10,
  },
  suggestionChip: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 11,
    paddingVertical: 8,
  },
  suggestionText: {
    fontSize: 12,
    fontWeight: '800',
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
  candidateList: {
    gap: 12,
    marginTop: 14,
  },
  candidateCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 15,
  },
  candidateHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
  },
  candidateTitle: {
    fontSize: 16,
    fontWeight: '800',
  },
  distancePill: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  distanceText: {
    fontSize: 12,
    fontWeight: '800',
  },
  routeLine: {
    marginTop: 12,
  },
  routeText: {
    fontSize: 14,
    fontWeight: '800',
    lineHeight: 20,
  },
  itineraryText: {
    fontSize: 13,
    lineHeight: 19,
    marginTop: 7,
    fontWeight: '600',
  },
  legList: {
    gap: 8,
    marginTop: 12,
  },
  legButton: {
    minHeight: 42,
    borderWidth: 1,
    borderRadius: 15,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  legText: {
    flex: 1,
    fontSize: 13,
    fontWeight: '700',
  },
  primaryButton: {
    minHeight: 46,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 12,
  },
  primaryButtonText: {
    fontSize: 15,
    fontWeight: '800',
  },
});
