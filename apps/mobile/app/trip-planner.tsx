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
import { useFriends, type FriendProfile } from '../hooks/useFriends';
import { useTheme } from '../hooks/useTheme';
import { supabase } from '../lib/supabase';
import { seasonalityScoreForMonth } from '../utils/scoring';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';
import ScrapbookCard from '../components/theme/ScrapbookCard';
import TitleBanner from '../components/theme/TitleBanner';

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

type DayPlanKind = 'country' | 'travel';

type TripDayPlan = {
  id: string;
  date: string;
  kind: DayPlanKind;
  countryIso2: string | null;
  countryName: string | null;
};

type TravelerPassportSelection = {
  travelerId: string;
  passportCountryCode: string;
};

type TripFriendSnapshot = {
  id: string;
  displayName: string;
  username: string;
  avatarURL: string | null;
};

type PlannedTrip = {
  id: string;
  title: string;
  notes: string;
  startDate: string | null;
  endDate: string | null;
  countryIso2s: string[];
  friendIds: string[];
  friendSnapshots: TripFriendSnapshot[];
  availability: TripAvailabilityProposal[];
  dayPlans: TripDayPlan[];
  travelerPassports: TravelerPassportSelection[];
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
  dayPlans: TripDayPlan[];
  travelerPassports: TravelerPassportSelection[];
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

type TripVisaSummary = {
  travelerId: string;
  travelerName: string;
  passportCountryCode: string;
  passportLabel: string;
  countryIso2: string;
  countryName: string;
  countryFlag: string;
  visaType: string | null;
  allowedDays: number | null;
  sourceUrl: string | null;
  notes: string | null;
  exceedsAllowedStay: boolean;
};

type PassportPreferences = {
  nationalityCountryCodes: string[];
  passportCountryCode: string | null;
};

type RemoteTripRow = {
  user_id: string;
  trip_id: string;
  trip_data: any;
};

type VisaSyncRunRow = {
  version: number;
  passport_from_raw: string | null;
  passport_from_iso2: string | null;
};

type VisaRequirementRow = {
  passport_from_raw: string;
  passport_from_norm: string;
  passport_from_iso2: string;
  visitor_to_raw: string;
  visitor_to_norm: string;
  parent_norm: string | null;
  is_special_subregion: boolean | null;
  aliases_norm: string[] | null;
  requirement: string | null;
  allowed_stay: string | null;
  notes: string | null;
  version: number;
  source: string | null;
  source_url: string | null;
  last_verified_at: string | null;
};

type AvailabilityDraft = {
  participantId: string | null;
  kind: AvailabilityKind;
  startDate: string;
  endDate: string;
  flexibleMonth: string;
};

const STORAGE_KEY = 'travelaf-trip-plans-v1';

function isUuidLike(value: string | null | undefined) {
  return !!value && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function createUuid() {
  return global.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function toIsoStringOrNull(value: unknown) {
  if (typeof value === 'string' && value.trim()) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : date.toISOString();
  }

  return null;
}

function normalizeTripPayload(raw: any): PlannedTrip | null {
  if (!raw || typeof raw !== 'object') return null;

  const id = typeof raw.id === 'string' ? raw.id : typeof raw.trip_id === 'string' ? raw.trip_id : null;
  if (!id) return null;

  const friendIds = Array.isArray(raw.friendIds)
    ? raw.friendIds.map(String)
    : Array.isArray(raw.friends)
      ? raw.friends.map((friend: any) => String(friend?.id)).filter(Boolean)
      : [];

  const friendSnapshots: TripFriendSnapshot[] = Array.isArray(raw.friends)
    ? raw.friends
        .map((friend: any) => {
          const id = String(friend?.id ?? '');
          if (!id) return null;
          const displayName = String(
            friend?.displayName ??
              friend?.participantName ??
              friend?.full_name ??
              friend?.fullName ??
              friend?.name ??
              'Friend'
          ).trim();
          const username = String(friend?.username ?? '').replace(/^@+/, '').trim();
          const avatarURL =
            typeof friend?.avatarURL === 'string'
              ? friend.avatarURL
              : typeof friend?.avatar_url === 'string'
                ? friend.avatar_url
                : null;

          return {
            id,
            displayName: displayName || username || 'Friend',
            username: username || displayName.replace(/\s+/g, '').toLowerCase() || 'friend',
            avatarURL,
          };
        })
        .filter((friend): friend is TripFriendSnapshot => friend !== null)
    : friendIds.map((friendId, index) => {
        const fallbackName =
          Array.isArray(raw.friendNames) && typeof raw.friendNames[index] === 'string'
            ? raw.friendNames[index]
            : 'Friend';
        return {
          id: friendId,
          displayName: fallbackName,
          username: fallbackName.replace(/\s+/g, '').toLowerCase() || 'friend',
          avatarURL: null,
        };
      });

  const availability = Array.isArray(raw.availability)
    ? raw.availability.map((proposal: any) => ({
        id: typeof proposal?.id === 'string' ? proposal.id : createUuid(),
        participantId: String(proposal?.participantId ?? proposal?.participant_id ?? ''),
        participantName:
          proposal?.participantName ??
          proposal?.participant_name ??
          proposal?.participantDisplayName ??
          'Traveler',
        kind: proposal?.kind === 'flexible_month' ? 'flexible_month' : 'exact_dates',
        startDate: String(proposal?.startDate ?? proposal?.start_date ?? '').slice(0, 10),
        endDate: String(proposal?.endDate ?? proposal?.end_date ?? '').slice(0, 10),
      }))
    : [];

  const dayPlans = Array.isArray(raw.dayPlans)
    ? raw.dayPlans.map((plan: any) => ({
        id: typeof plan?.id === 'string' ? plan.id : createUuid(),
        date: String(plan?.date ?? '').slice(0, 10),
        kind: plan?.kind === 'travel' ? 'travel' : 'country',
        countryIso2:
          typeof plan?.countryIso2 === 'string'
            ? plan.countryIso2
            : typeof plan?.countryId === 'string'
              ? plan.countryId
              : null,
        countryName:
          typeof plan?.countryName === 'string'
            ? plan.countryName
            : typeof plan?.country_name === 'string'
              ? plan.country_name
              : null,
      }))
    : [];

  const travelerPassports = Array.isArray(raw.travelerPassports)
    ? raw.travelerPassports.map((selection: any) => ({
        travelerId: String(selection?.travelerId ?? selection?.traveler_id ?? ''),
        passportCountryCode: String(
          selection?.passportCountryCode ?? selection?.passport_country_code ?? 'US'
        ).toUpperCase(),
      }))
    : [];

  const expenses = Array.isArray(raw.expenses)
    ? raw.expenses.map((expense: any) => ({
        id: typeof expense?.id === 'string' ? expense.id : createUuid(),
        title: String(expense?.title ?? ''),
        totalAmount: Number(expense?.totalAmount ?? expense?.amount ?? 0),
        paidById: String(expense?.paidById ?? expense?.paid_by_id ?? ''),
        paidByName: String(expense?.paidByName ?? expense?.paid_by_name ?? 'Traveler'),
        splitWithIds: Array.isArray(expense?.splitWithIds)
          ? expense.splitWithIds.map(String)
          : Array.isArray(expense?.split_with_ids)
            ? expense.split_with_ids.map(String)
            : [],
      }))
    : [];

  return {
    id,
    title: String(raw.title ?? ''),
    notes: String(raw.notes ?? ''),
    startDate: toIsoStringOrNull(raw.startDate),
    endDate: toIsoStringOrNull(raw.endDate),
    countryIso2s: Array.isArray(raw.countryIso2s)
      ? raw.countryIso2s.map(String)
      : Array.isArray(raw.countryIds)
        ? raw.countryIds.map(String)
        : [],
    friendIds,
    friendSnapshots,
    availability: availability.filter(item => item.participantId && item.startDate && item.endDate),
    dayPlans: dayPlans.filter(item => item.date),
    travelerPassports: travelerPassports.filter(item => item.travelerId),
    expenses: expenses.filter(item => item.title),
    createdAt: toIsoStringOrNull(raw.createdAt) ?? new Date().toISOString(),
    updatedAt: toIsoStringOrNull(raw.updatedAt) ?? toIsoStringOrNull(raw.createdAt) ?? new Date().toISOString(),
  };
}

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
    dayPlans: [],
    travelerPassports: [],
    expenses: [],
  };
}

function normalizeTripFriendSnapshot(
  value: FriendProfile | TripFriendSnapshot | null | undefined
): TripFriendSnapshot | null {
  if (!value?.id) return null;
  const displayName =
    'displayName' in value
      ? value.displayName
      : value.full_name || value.username || 'Friend';
  const username = value.username || displayName.replace(/\s+/g, '').toLowerCase() || 'friend';
  const avatarURL =
    'avatarURL' in value ? value.avatarURL : value.avatar_url ?? null;

  return {
    id: value.id,
    displayName: displayName || username || 'Friend',
    username,
    avatarURL,
  };
}

function buildTripFriendSnapshots(
  friendIds: string[],
  liveSnapshotById: Map<string, TripFriendSnapshot>,
  fallbackSnapshots: TripFriendSnapshot[] = []
) {
  const fallbackById = new Map(
    fallbackSnapshots.map((snapshot) => [snapshot.id, snapshot] as const)
  );

  return friendIds.map((friendId) => {
    return (
      liveSnapshotById.get(friendId) ??
      fallbackById.get(friendId) ?? {
        id: friendId,
        displayName: 'Friend',
        username: 'friend',
        avatarURL: null,
      }
    );
  });
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

function dateRange(startDate: string, endDate: string) {
  const start = parseDayStart(startDate);
  const end = parseDayStart(endDate);
  if (!start || !end || start.getTime() > end.getTime()) return [];

  const dates: string[] = [];
  const current = new Date(start);
  while (current.getTime() <= end.getTime()) {
    dates.push(current.toISOString().slice(0, 10));
    current.setUTCDate(current.getUTCDate() + 1);
  }

  return dates;
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

function syncDayPlans(
  existingPlans: TripDayPlan[],
  startDate: string,
  endDate: string,
  countriesForTrip: { iso2: string; name: string }[]
) {
  const dates = dateRange(startDate, endDate);
  if (!dates.length) return [];

  const existingByDate = new Map(existingPlans.map(plan => [plan.date, plan] as const));
  const validCountryIso2s = new Set(countriesForTrip.map(country => country.iso2));
  const firstCountry = countriesForTrip[0] ?? null;

  return dates.map(date => {
    const existing = existingByDate.get(date);
    if (existing?.kind === 'travel') {
      return {
        id: existing.id,
        date,
        kind: 'travel' as const,
        countryIso2: null,
        countryName: null,
      };
    }

    if (
      existing?.kind === 'country' &&
      existing.countryIso2 &&
      validCountryIso2s.has(existing.countryIso2)
    ) {
      const matchedCountry =
        countriesForTrip.find(country => country.iso2 === existing.countryIso2) ?? null;
      return {
        id: existing.id,
        date,
        kind: 'country' as const,
        countryIso2: existing.countryIso2,
        countryName: matchedCountry?.name ?? existing.countryName,
      };
    }

    if (firstCountry) {
      return {
        id: `${date}-${firstCountry.iso2}`,
        date,
        kind: 'country' as const,
        countryIso2: firstCountry.iso2,
        countryName: firstCountry.name,
      };
    }

    return {
      id: `${date}-travel`,
      date,
      kind: 'travel' as const,
      countryIso2: null,
      countryName: null,
    };
  });
}

function itineraryPreview(dayPlans: TripDayPlan[]) {
  if (!dayPlans.length) return [];
  return dayPlans.slice(0, 4).map(plan =>
    plan.kind === 'travel'
      ? `${formatDate(plan.date)}: Travel day`
      : `${formatDate(plan.date)}: ${plan.countryName ?? plan.countryIso2 ?? 'Country day'}`
  );
}

function normalizeVisaText(text: string) {
  const normalized = text
    .replace(/\[\d+\]/g, ' ')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  const tokens = normalized.split(' ').filter(Boolean);
  const collapsed: string[] = [];

  tokens.forEach(token => {
    const last = collapsed[collapsed.length - 1];
    if (token.length === 1 && last && last.length === 1) {
      collapsed[collapsed.length - 1] = `${last}${token}`;
      return;
    }
    collapsed.push(token);
  });

  return collapsed.join(' ');
}

function visaAliasesForISO2(iso2: string) {
  switch (iso2.toUpperCase()) {
    case 'AX': return ['aland islands', 'aland'];
    case 'BL': return ['saint barthelemy', 'st barthelemy'];
    case 'BS': return ['bahamas', 'the bahamas'];
    case 'CI': return ['cote d ivoire', 'cote ivoire', 'ivory coast'];
    case 'CW': return ['curacao', 'curaçao'];
    case 'GM': return ['gambia', 'the gambia'];
    case 'KR': return ['south korea', 'republic of korea', 'korea south'];
    case 'LA': return ['laos', 'lao', 'lao peoples democratic republic'];
    case 'MF': return ['saint martin', 'st martin', 'saint martin french part'];
    case 'MM': return ['myanmar', 'burma'];
    case 'PS': return ['palestine', 'palestinian territories', 'palestinian territory'];
    case 'RE': return ['reunion', 'réunion'];
    case 'SX': return ['sint maarten', 'saint maarten'];
    case 'TC': return ['turks and caicos', 'turks and caicos islands'];
    case 'TR': return ['turkey', 'turkiye', 'türkiye', 'republic of turkey', 'republic of türkiye'];
    case 'TW': return ['taiwan', 'republic of china taiwan', 'taiwan province of china'];
    case 'VA': return ['vatican', 'vatican city', 'holy see'];
    case 'VI': return ['u s virgin islands', 'us virgin islands', 'virgin islands u s', 'virgin islands us'];
    default: return [];
  }
}

function visaTypeFromRequirement(requirement?: string | null) {
  const value = (requirement ?? '').toLowerCase();
  if (!value) return null;
  if (/freedom of movement/.test(value)) return 'freedom_of_movement';
  if (/visa[- ]?free|not required/.test(value)) return 'visa_free';
  if (/visa on arrival|\bvoa\b/.test(value)) return 'voa';
  if (/(^|\b)e-?visa\b|electronic travel authorization|\beta\b/.test(value)) return 'evisa';
  if (/entry permit|required permit/.test(value)) return 'entry_permit';
  if (/not allowed|prohibit|ban/.test(value)) return 'ban';
  return 'visa_required';
}

function parseAllowedDays(text?: string | null) {
  const value = (text ?? '').toLowerCase();
  if (!value) return null;

  const dayMatch = value.match(/(\d{1,4})\s*day/);
  if (dayMatch) return Number(dayMatch[1]);
  const weekMatch = value.match(/(\d{1,3})\s*week/);
  if (weekMatch) return Number(weekMatch[1]) * 7;
  const monthMatch = value.match(/(\d{1,2})\s*month/);
  if (monthMatch) return Number(monthMatch[1]) * 30;
  const yearMatch = value.match(/(\d{1,2})\s*year/);
  if (yearMatch) return Number(yearMatch[1]) * 365;

  return null;
}

function countryLabelForPassport(code: string) {
  try {
    return new Intl.DisplayNames(undefined, { type: 'region' }).of(code.toUpperCase()) ?? code.toUpperCase();
  } catch {
    return code.toUpperCase();
  }
}

function matchVisaRow(
  country: { iso2: string; name: string },
  rows: VisaRequirementRow[]
) {
  const candidates = new Set(
    [country.name, ...visaAliasesForISO2(country.iso2)].map(normalizeVisaText)
  );
  const containsCandidates = [...candidates].filter(
    candidate => candidate.length >= 4 && !/^[a-z]{2,3}$/.test(candidate)
  );

  const exact = rows.find(row => candidates.has(row.visitor_to_norm));
  if (exact) return exact;

  const aliasMatch = rows.find(row =>
    (row.aliases_norm ?? []).some(alias => candidates.has(alias))
  );
  if (aliasMatch) return aliasMatch;

  return rows.find(row => {
    if (row.is_special_subregion) return false;
    if (row.parent_norm && candidates.has(row.parent_norm)) return false;
    return containsCandidates.some(
      candidate =>
        row.visitor_to_norm.includes(candidate) || candidate.includes(row.visitor_to_norm)
    );
  });
}

function prettyVisaType(visaType?: string | null) {
  if (!visaType) return 'Visa details unavailable';
  const labelMap: Record<string, string> = {
    own_passport: 'Own passport',
    freedom_of_movement: 'Freedom of movement',
    visa_free: 'Visa-free',
    voa: 'Visa on arrival',
    eta: 'ETA required',
    evisa: 'eVisa required',
    visa_required: 'Visa required',
    entry_permit: 'Entry permit required',
    ban: 'Travel restricted',
  };
  return labelMap[visaType] ?? visaType.replace(/_/g, ' ');
}

function tripLengthDays(startDate: string | null, endDate: string | null) {
  if (!startDate || !endDate) return null;
  const start = parseDayStart(startDate.slice(0, 10));
  const end = parseDayStart(endDate.slice(0, 10));
  if (!start || !end || end.getTime() < start.getTime()) return null;
  return Math.floor((end.getTime() - start.getTime()) / 86400000) + 1;
}

function computeTripVisaSummaries(
  tripCountries: {
    iso2: string;
    name: string;
    flagEmoji?: string;
    facts?: Record<string, any>;
  }[],
  travelers: Traveler[],
  travelerPassports: TravelerPassportSelection[],
  visaRowsByPassport: Record<string, VisaRequirementRow[]>,
  totalDays: number | null
) {
  return travelers.flatMap(traveler => {
    const passportCode =
      travelerPassports.find(item => item.travelerId === traveler.id)?.passportCountryCode ?? 'US';
    const rows = visaRowsByPassport[passportCode] ?? [];

    return tripCountries
      .map(country => {
        if (passportCode.toUpperCase() === country.iso2.toUpperCase()) {
          return {
            travelerId: traveler.id,
            travelerName: traveler.name,
            passportCountryCode: passportCode,
            passportLabel: countryLabelForPassport(passportCode),
            countryIso2: country.iso2,
            countryName: country.name,
            countryFlag: country.flagEmoji ?? '',
            visaType: 'own_passport',
            allowedDays: null,
            sourceUrl: null,
            notes: null,
            exceedsAllowedStay: false,
          };
        }

        const row = matchVisaRow(country, rows);
        const visaType = visaTypeFromRequirement(row?.requirement ?? country.facts?.visaType);
        const allowedDays =
          parseAllowedDays(row?.allowed_stay) ??
          parseAllowedDays(row?.requirement) ??
          (typeof country.facts?.visaAllowedDays === 'number' ? country.facts.visaAllowedDays : null);
        const exceedsAllowedStay =
          typeof totalDays === 'number' &&
          typeof allowedDays === 'number' &&
          totalDays > allowedDays;

        return {
          travelerId: traveler.id,
          travelerName: traveler.name,
          passportCountryCode: passportCode,
          passportLabel: row?.passport_from_raw ?? countryLabelForPassport(passportCode),
          countryIso2: country.iso2,
          countryName: country.name,
          countryFlag: country.flagEmoji ?? '',
          visaType,
          allowedDays,
          sourceUrl: row?.source_url ?? country.facts?.visaSource ?? null,
          notes: row?.notes ?? country.facts?.visaNotes ?? null,
          exceedsAllowedStay,
        };
      })
      .filter(
        summary =>
          summary.visaType &&
          !['own_passport', 'freedom_of_movement', 'visa_free', 'voa'].includes(summary.visaType)
      );
  });
}

function visaHeadline(
  summaries: TripVisaSummary[],
  travelerCount: number,
  totalDays: number | null
) {
  const overstayCount = summaries.filter(summary => summary.exceedsAllowedStay).length;
  if (overstayCount > 0) {
    return `${overstayCount} stop${overstayCount === 1 ? '' : 's'} may exceed the allowed stay${typeof totalDays === 'number' ? ` for ${totalDays} days` : ''}`;
  }
  if (summaries.length === 0) {
    return 'No advance visa prep flagged';
  }
  return `${summaries.length} stop${summaries.length === 1 ? '' : 's'} need visa prep for ${travelerCount} traveler${travelerCount === 1 ? '' : 's'}`;
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
  const [savedPassportPreferences, setSavedPassportPreferences] = useState<PassportPreferences>({
    nationalityCountryCodes: [],
    passportCountryCode: null,
  });
  const [visaRowsByPassport, setVisaRowsByPassport] = useState<Record<string, VisaRequirementRow[]>>(
    {}
  );

  useEffect(() => {
    const userId = session?.user?.id;
    if (!userId) return;

    supabase
      .from('user_passport_preferences')
      .select('nationality_country_codes,passport_country_code')
      .eq('user_id', userId)
      .limit(1)
      .maybeSingle()
      .then(({ data, error }) => {
        if (error) {
          console.error('Failed to load passport preferences', error);
          return;
        }

        setSavedPassportPreferences({
          nationalityCountryCodes: data?.nationality_country_codes ?? [],
          passportCountryCode: data?.passport_country_code ?? null,
        });
      });
  }, [session?.user?.id]);

  useEffect(() => {
    const loadTrips = async () => {
      try {
        const localValue = await AsyncStorage.getItem(STORAGE_KEY);
        const localTrips = localValue
          ? (JSON.parse(localValue) as PlannedTrip[])
              .map(normalizeTripPayload)
              .filter((trip): trip is PlannedTrip => trip !== null)
          : [];

        if (!session?.user?.id) {
          setTrips(localTrips);
          return;
        }

        const { data, error } = await supabase
          .from('user_trip_plans')
          .select('user_id,trip_id,trip_data')
          .eq('user_id', session.user.id);

        if (error) {
          console.error('Failed to load remote trips', error);
          setTrips(localTrips);
          return;
        }

        const remoteTrips = ((data ?? []) as RemoteTripRow[])
          .map(row => normalizeTripPayload(row.trip_data))
          .filter((trip): trip is PlannedTrip => trip !== null)
          .sort((lhs, rhs) => rhs.createdAt.localeCompare(lhs.createdAt));

        const mergedTrips = remoteTrips.length ? remoteTrips : localTrips;
        setTrips(mergedTrips);
        await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(mergedTrips));
      } catch (error) {
        console.error('Failed to load trips', error);
      }
    };

    loadTrips();
  }, [session?.user?.id]);

  const countryNameByIso2 = useMemo(
    () => new Map(countries.map(country => [country.iso2, country.name] as const)),
    [countries]
  );

  const friendSnapshotById = useMemo(
    () =>
      new Map(
        friends
          .map(friend => normalizeTripFriendSnapshot(friend))
          .filter((snapshot): snapshot is TripFriendSnapshot => snapshot !== null)
          .map(snapshot => [snapshot.id, snapshot] as const)
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

  const savedListSuggestions = useMemo(
    () =>
      plannerCountries.filter(
        country =>
          !draft.countryIso2s.includes(country.iso2) &&
          (bucketIsoCodes.includes(country.iso2) || visitedIsoCodes.includes(country.iso2))
      ),
    [bucketIsoCodes, draft.countryIso2s, plannerCountries, visitedIsoCodes]
  );

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

  const draftFriendSnapshots = useMemo(() => {
    const existingTrip = draft.id ? trips.find(trip => trip.id === draft.id) : null;
    return buildTripFriendSnapshots(
      draft.friendIds,
      friendSnapshotById,
      existingTrip?.friendSnapshots ?? []
    );
  }, [draft.friendIds, draft.id, friendSnapshotById, trips]);

  const serializeTripForRemote = (trip: PlannedTrip) => {
    const friendSnapshots = buildTripFriendSnapshots(
      trip.friendIds,
      friendSnapshotById,
      trip.friendSnapshots
    );

    return {
      id: trip.id,
      createdAt: trip.createdAt,
      updatedAt: trip.updatedAt,
      title: trip.title,
      notes: trip.notes,
      startDate: trip.startDate,
      endDate: trip.endDate,
      countryIds: trip.countryIso2s,
      countryNames: trip.countryIso2s.map(iso2 => countryNameByIso2.get(iso2) ?? iso2),
      friendIds: trip.friendIds,
      friendNames: friendSnapshots.map(friend => friend.displayName),
      friends: friendSnapshots,
      ownerId: session?.user?.id ?? null,
      availability: trip.availability,
      dayPlans: trip.dayPlans.map(plan => ({
        ...plan,
        countryId: plan.countryIso2,
      })),
      travelerPassports: trip.travelerPassports,
      overallChecklistItems: [],
      packingProgressEntries: [],
      expenses: trip.expenses,
    };
  };

  const saveTripRemote = async (trip: PlannedTrip) => {
    const userId = session?.user?.id;
    if (!userId || !isUuidLike(trip.id)) return;

    const tripPayload = serializeTripForRemote(trip);
    const participantIds = Array.from(new Set([userId, ...trip.friendIds])).filter(isUuidLike);

    if (participantIds.length > 1) {
      const { error } = await supabase.rpc('share_trip_plan', {
        p_target_user_ids: participantIds,
        p_trip_id: trip.id,
        p_trip_payload: JSON.stringify(tripPayload),
      });

      if (error) {
        console.error('Failed to share remote trip', error);
      }
      return;
    }

    await supabase.from('user_trip_plans').delete().eq('user_id', userId).eq('trip_id', trip.id);

    const { error } = await supabase.from('user_trip_plans').insert({
      user_id: userId,
      trip_id: trip.id,
      trip_data: tripPayload,
    });

    if (error) {
      console.error('Failed to save remote trip', error);
    }
  };

  const deleteTripRemote = async (trip: PlannedTrip) => {
    const userId = session?.user?.id;
    if (!userId || !isUuidLike(trip.id)) return;

    const participantIds = Array.from(new Set([userId, ...trip.friendIds])).filter(isUuidLike);

    if (participantIds.length > 1) {
      const { error } = await supabase.rpc('delete_shared_trip_plan', {
        p_target_user_ids: participantIds,
        p_trip_id: trip.id,
        p_trip_payload: JSON.stringify(serializeTripForRemote(trip)),
      });

      if (error) {
        console.error('Failed to delete shared remote trip', error);
      }
      return;
    }

    const { error } = await supabase
      .from('user_trip_plans')
      .delete()
      .eq('user_id', userId)
      .eq('trip_id', trip.id);

    if (error) {
      console.error('Failed to delete remote trip', error);
    }
  };

  const defaultPassportCode = useMemo(
    () =>
      savedPassportPreferences.passportCountryCode ||
      savedPassportPreferences.nationalityCountryCodes[0] ||
      'US',
    [
      savedPassportPreferences.nationalityCountryCodes,
      savedPassportPreferences.passportCountryCode,
    ]
  );

  const draftTravelers = useMemo(
    () => [
      ...(currentTraveler ? [currentTraveler] : []),
      ...draftFriendSnapshots.map(friend => ({
        id: friend.id,
        name: friend.displayName || friend.username || 'Friend',
      })),
    ],
    [currentTraveler, draftFriendSnapshots]
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

  useEffect(() => {
    setDraft(current => {
      const validTravelerIds = new Set(draftTravelers.map(traveler => traveler.id));
      const filtered = current.travelerPassports.filter(selection =>
        validTravelerIds.has(selection.travelerId)
      );
      const additions = draftTravelers
        .filter(traveler => !filtered.some(selection => selection.travelerId === traveler.id))
        .map(traveler => ({
          travelerId: traveler.id,
          passportCountryCode:
            traveler.id === currentTraveler?.id ? defaultPassportCode : 'US',
        }));
      const nextSelections = [...filtered, ...additions];

      if (nextSelections.length === current.travelerPassports.length) {
        const unchanged = nextSelections.every((selection, index) => {
          const original = current.travelerPassports[index];
          return (
            original?.travelerId === selection.travelerId &&
            original?.passportCountryCode === selection.passportCountryCode
          );
        });
        if (unchanged) return current;
      }

      return {
        ...current,
        travelerPassports: nextSelections,
      };
    });
  }, [currentTraveler?.id, defaultPassportCode, draftTravelers]);

  const activePassportCodes = useMemo(() => {
    const codes = [
      defaultPassportCode,
      ...draft.travelerPassports.map(item => item.passportCountryCode),
      ...trips.flatMap(trip => trip.travelerPassports.map(item => item.passportCountryCode)),
    ]
      .map(code => code.trim().toUpperCase())
      .filter(Boolean);

    return Array.from(new Set(codes));
  }, [defaultPassportCode, draft.travelerPassports, trips]);

  useEffect(() => {
    const missingCodes = activePassportCodes.filter(code => !visaRowsByPassport[code]);
    if (!missingCodes.length) return;

    missingCodes.forEach(code => {
      supabase
        .from('visa_sync_runs')
        .select('version,passport_from_raw,passport_from_iso2')
        .eq('passport_from_iso2', code)
        .order('version', { ascending: false })
        .limit(1)
        .maybeSingle()
        .then(async ({ data: versionRow, error: versionError }) => {
          if (versionError) {
            console.error('Failed to load visa version', code, versionError);
            return;
          }

          const typedVersionRow = versionRow as VisaSyncRunRow | null;
          if (!typedVersionRow?.version) {
            setVisaRowsByPassport(current => ({ ...current, [code]: [] }));
            return;
          }

          const { data: requirementRows, error: requirementsError } = await supabase
            .from('visa_requirements')
            .select(
              'passport_from_raw,passport_from_norm,passport_from_iso2,visitor_to_raw,visitor_to_norm,parent_norm,is_special_subregion,aliases_norm,requirement,allowed_stay,notes,version,source,source_url,last_verified_at'
            )
            .eq('passport_from_iso2', code)
            .eq('version', typedVersionRow.version);

          if (requirementsError) {
            console.error('Failed to load visa requirements', code, requirementsError);
            return;
          }

          setVisaRowsByPassport(current => ({
            ...current,
            [code]: (requirementRows as VisaRequirementRow[]) ?? [],
          }));
        });
    });
  }, [activePassportCodes, visaRowsByPassport]);

  const persistTrips = async (nextTrips: PlannedTrip[]) => {
    const sortedTrips = [...nextTrips].sort((lhs, rhs) => rhs.updatedAt.localeCompare(lhs.updatedAt));
    setTrips(sortedTrips);
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(sortedTrips));
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
    setDraft({
      ...emptyDraft(),
      travelerPassports: currentTraveler
        ? [{ travelerId: currentTraveler.id, passportCountryCode: defaultPassportCode }]
        : [],
    });
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
      dayPlans: Array.isArray(trip.dayPlans) ? trip.dayPlans : [],
      travelerPassports: Array.isArray(trip.travelerPassports)
        ? trip.travelerPassports
        : currentTraveler
          ? [{ travelerId: currentTraveler.id, passportCountryCode: defaultPassportCode }]
          : [],
      expenses: Array.isArray(trip.expenses) ? trip.expenses : [],
    });
    resetDraftHelpers();
    setModalVisible(true);
  };

  const closeModal = () => {
    setModalVisible(false);
  };

  const toggleCountry = (iso2: string) => {
    setDraft(current => {
      const nextCountryIso2s = current.countryIso2s.includes(iso2)
        ? current.countryIso2s.filter(code => code !== iso2)
        : [...current.countryIso2s, iso2];

      const shouldSync =
        current.includeDates && current.startDate.trim() && current.endDate.trim();
      const nextDayPlans = shouldSync
        ? syncDayPlans(
            current.dayPlans,
            current.startDate.trim(),
            current.endDate.trim(),
            nextCountryIso2s.map(code => ({
              iso2: code,
              name: countryNameByIso2.get(code) ?? code,
            }))
          )
        : [];

      return {
        ...current,
        countryIso2s: nextCountryIso2s,
        dayPlans: nextDayPlans,
      };
    });
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
        travelerPassports: [
          ...current.travelerPassports.filter(selection =>
            allowedParticipantIds.has(selection.travelerId)
          ),
          ...nextFriendIds
            .filter(
              id => !current.travelerPassports.some(selection => selection.travelerId === id)
            )
            .map(id => ({ travelerId: id, passportCountryCode: 'US' })),
          ...(currentTraveler &&
          !current.travelerPassports.some(
            selection => selection.travelerId === currentTraveler.id
          )
            ? [{ travelerId: currentTraveler.id, passportCountryCode: defaultPassportCode }]
            : []),
        ],
      };
    });
  };

  const saveTrip = async () => {
    const title = draft.title.trim();
    if (!title) return;

    const now = new Date().toISOString();
    const resolvedTripId =
      draft.id && isUuidLike(draft.id) ? draft.id : createUuid();
    const nextTrip: PlannedTrip = {
      id: resolvedTripId,
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
      friendSnapshots: draftFriendSnapshots,
      availability: draft.availability,
      dayPlans: draft.dayPlans,
      travelerPassports: draft.travelerPassports,
      expenses: draft.expenses,
      createdAt: draft.id ? trips.find(trip => trip.id === draft.id)?.createdAt ?? now : now,
      updatedAt: now,
    };

    const nextTrips = draft.id
      ? trips.map(trip => (trip.id === draft.id ? nextTrip : trip))
      : [nextTrip, ...trips];

    await persistTrips(nextTrips);
    await saveTripRemote(nextTrip);
    closeModal();
  };

  const deleteTrip = async (tripId: string) => {
    const tripToDelete = trips.find(trip => trip.id === tripId) ?? null;
    await persistTrips(trips.filter(trip => trip.id !== tripId));
    if (tripToDelete) {
      await deleteTripRemote(tripToDelete);
    }
  };

  const updateTripDateField = (field: 'startDate' | 'endDate', value: string) => {
    setDraft(current => {
      const nextDraft = { ...current, [field]: value };
      if (
        !nextDraft.includeDates ||
        !nextDraft.startDate.trim() ||
        !nextDraft.endDate.trim()
      ) {
        return {
          ...nextDraft,
          dayPlans: [],
        };
      }

      return {
        ...nextDraft,
        dayPlans: syncDayPlans(
          current.dayPlans,
          nextDraft.startDate.trim(),
          nextDraft.endDate.trim(),
          nextDraft.countryIso2s.map(iso2 => ({
            iso2,
            name: countryNameByIso2.get(iso2) ?? iso2,
          }))
        ),
      };
    });
  };

  const toggleIncludeDates = () => {
    setDraft(current => {
      const nextIncludeDates = !current.includeDates;
      if (!nextIncludeDates || !current.startDate.trim() || !current.endDate.trim()) {
        return {
          ...current,
          includeDates: nextIncludeDates,
          dayPlans: [],
        };
      }

      return {
        ...current,
        includeDates: nextIncludeDates,
        dayPlans: syncDayPlans(
          current.dayPlans,
          current.startDate.trim(),
          current.endDate.trim(),
          current.countryIso2s.map(iso2 => ({
            iso2,
            name: countryNameByIso2.get(iso2) ?? iso2,
          }))
        ),
      };
    });
  };

  const selectedCountryNames = draft.countryIso2s.map(
    iso2 => countryNameByIso2.get(iso2) ?? iso2
  );
  const selectedFriendNames = draftFriendSnapshots.map(
    friend => friend.displayName || friend.username || 'Friend'
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

  const draftTripDays = tripLengthDays(
    draft.includeDates && draft.startDate ? `${draft.startDate}T00:00:00.000Z` : null,
    draft.includeDates && draft.endDate ? `${draft.endDate}T00:00:00.000Z` : null
  );
  const draftVisaSummaries = computeTripVisaSummaries(
    countries.filter(country => draft.countryIso2s.includes(country.iso2)),
    draftTravelers,
    draft.travelerPassports,
    visaRowsByPassport,
    draftTripDays
  );
  const totalDraftExpenses = draft.expenses.reduce((sum, expense) => sum + expense.totalAmount, 0);

  const updateDayPlan = (
    dayPlanId: string,
    patch: Partial<Pick<TripDayPlan, 'kind' | 'countryIso2' | 'countryName'>>
  ) => {
    setDraft(current => ({
      ...current,
      dayPlans: current.dayPlans.map(plan => {
        if (plan.id !== dayPlanId) return plan;

        if (patch.kind === 'travel') {
          return {
            ...plan,
            kind: 'travel',
            countryIso2: null,
            countryName: null,
          };
        }

        const nextCountryIso2 = patch.countryIso2 ?? plan.countryIso2;
        return {
          ...plan,
          kind: patch.kind ?? plan.kind,
          countryIso2: nextCountryIso2,
          countryName:
            nextCountryIso2 ? countryNameByIso2.get(nextCountryIso2) ?? nextCountryIso2 : null,
        };
      }),
    }));
  };

  const updateTravelerPassport = (travelerId: string, passportCountryCode: string) => {
    setDraft(current => ({
      ...current,
      travelerPassports: current.travelerPassports.some(
        selection => selection.travelerId === travelerId
      )
        ? current.travelerPassports.map(selection =>
            selection.travelerId === travelerId
              ? { ...selection, passportCountryCode }
              : selection
          )
        : [...current.travelerPassports, { travelerId, passportCountryCode }],
    }));
  };

  const travelersForTrip = (trip: PlannedTrip) => {
    const currentName = currentTraveler?.name ?? profile?.full_name ?? profile?.username ?? 'You';
    const tripFriendSnapshots = buildTripFriendSnapshots(
      trip.friendIds,
      friendSnapshotById,
      trip.friendSnapshots
    );

    return [
      ...(session?.user?.id ? [{ id: session.user.id, name: currentName }] : []),
      ...tripFriendSnapshots.map(friend => ({
        id: friend.id,
        name: friend.displayName || friend.username || 'Friend',
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
          color: colors.primary,
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
      const friendSummary = buildTripFriendSnapshots(
        trip.friendIds,
        friendSnapshotById,
        trip.friendSnapshots
      )
        .map(friend => friend.displayName || friend.username || 'Friend')
        .join(', ');
      const tripTravelers = travelersForTrip(trip);
      const overlaps = computeAvailabilityOverlaps(trip.availability, tripTravelers);
      const availabilitySummary = availabilityBadge(
        overlaps,
        trip.availability,
        tripTravelers.length
      );
      const previewLines = itineraryPreview(trip.dayPlans);
      const totalDays = tripLengthDays(trip.startDate, trip.endDate);
      const visaSummaries = computeTripVisaSummaries(
        countries.filter(country => trip.countryIso2s.includes(country.iso2)),
        tripTravelers,
        trip.travelerPassports,
        visaRowsByPassport,
        totalDays
      );

      const notes = [
        trip.notes || null,
        countrySummary ? `Countries: ${countrySummary}` : null,
        friendSummary ? `Friends: ${friendSummary}` : null,
        availabilitySummary ? `Availability: ${availabilitySummary}` : null,
        previewLines.length ? `Itinerary:\n${previewLines.join('\n')}` : null,
        visaSummaries.length
          ? `Visa prep:\n${visaSummaries
              .slice(0, 3)
              .map(
                summary =>
                  `${summary.travelerName} (${summary.passportLabel}) · ${summary.countryName}: ${prettyVisaType(summary.visaType)}${
                    summary.allowedDays ? ` (${summary.allowedDays} days)` : ''
                  }${summary.exceedsAllowedStay ? ' - trip may exceed allowed stay' : ''}`
              )
              .join('\n')}`
          : null,
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
    <ScrapbookBackground>
    <View style={{ flex: 1, backgroundColor: 'transparent' }}>
      <ScrollView
        contentContainerStyle={{
          paddingTop: insets.top + 18,
          paddingHorizontal: 20,
          paddingBottom: insets.bottom + 40,
        }}
        showsVerticalScrollIndicator={false}
      >
        <Pressable
          onPress={() => router.back()}
          style={[styles.backButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
        >
          <Ionicons name="chevron-back" size={18} color={colors.textPrimary} />
        </Pressable>

        <View style={styles.headerRow}>
          <View style={{ flex: 1 }}>
            <TitleBanner title="Trip Planner" />
          </View>

          <Pressable
            onPress={openNewTrip}
            style={[styles.addButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
          >
            <Ionicons name="add" size={18} color={colors.textPrimary} />
          </Pressable>
        </View>

        {trips.length === 0 ? (
          <Pressable
            onPress={openNewTrip}
            style={styles.emptyCardPress}
          >
            <ScrapbookCard innerStyle={styles.emptyCard}>
              <Text style={[styles.emptyEyebrow, { color: colors.textSecondary }]}>
                Planner workspace
              </Text>
              <Ionicons name="airplane-outline" size={28} color={colors.textPrimary} />
              <Text style={[styles.emptyTitle, { color: colors.textPrimary }]}>
                Start your first trip plan
              </Text>
              <Text style={[styles.emptySubtitle, { color: colors.textSecondary }]}>
                Keep dates, destinations, and group planning details together before anything gets booked.
              </Text>
              <View style={styles.emptySummaryRow}>
                <View
                  style={[
                    styles.emptySummaryChip,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.emptySummaryLabel, { color: colors.textSecondary }]}>
                    Includes
                  </Text>
                  <Text style={[styles.emptySummaryValue, { color: colors.textPrimary }]}>
                    Dates + countries
                  </Text>
                </View>
                <View
                  style={[
                    styles.emptySummaryChip,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.emptySummaryLabel, { color: colors.textSecondary }]}>
                    Group tools
                  </Text>
                  <Text style={[styles.emptySummaryValue, { color: colors.textPrimary }]}>
                    Availability + split costs
                  </Text>
                </View>
              </View>
            </ScrapbookCard>
          </Pressable>
        ) : (
          <View style={styles.tripStack}>
            {trips.map(trip => {
              const countrySummary = trip.countryIso2s
                .map(iso2 => countryNameByIso2.get(iso2) ?? iso2)
                .join(', ');
              const friendSummary = buildTripFriendSnapshots(
                trip.friendIds,
                friendSnapshotById,
                trip.friendSnapshots
              )
                .map(friend => friend.displayName || friend.username || 'Friend')
                .join(', ');
              const summary = tripSummary(trip);
              const totalExpenses = expenseTotal(trip);
              const tripTravelers = travelersForTrip(trip);
              const overlaps = computeAvailabilityOverlaps(trip.availability, tripTravelers);
              const previewLines = itineraryPreview(trip.dayPlans);
              const totalDays = tripLengthDays(trip.startDate, trip.endDate);
              const visaSummaries = computeTripVisaSummaries(
                countries.filter(country => trip.countryIso2s.includes(country.iso2)),
                tripTravelers,
                trip.travelerPassports,
                visaRowsByPassport,
                totalDays
              );
              const availabilitySummary = availabilityBadge(
                overlaps,
                trip.availability,
                tripTravelers.length
              );

              return (
                <ScrapbookCard
                  key={trip.id}
                  style={styles.tripCardShell}
                  innerStyle={[styles.tripCard, { backgroundColor: `${colors.card}F4` }]}
                >
                  <Text style={[styles.tripCardEyebrow, { color: colors.textSecondary }]}>
                    Saved Trip
                  </Text>
                  <View style={styles.tripCardHeader}>
                    <View style={{ flex: 1, marginRight: 12 }}>
                      <View style={styles.tripBadgeRow}>
                        <View
                          style={[
                            styles.tripTypeBadge,
                            { backgroundColor: colors.surface, borderColor: colors.border },
                          ]}
                        >
                          <Text style={[styles.tripTypeBadgeText, { color: colors.textSecondary }]}>
                            {trip.friendIds.length ? 'Group trip' : 'Solo trip'}
                          </Text>
                        </View>

                        <View
                          style={[
                            styles.tripModeBadge,
                            { backgroundColor: colors.surface, borderColor: colors.border },
                          ]}
                        >
                          <Ionicons name="airplane" size={11} color={colors.textSecondary} />
                          <Text style={[styles.tripModeBadgeText, { color: colors.textSecondary }]}>
                            Planner
                          </Text>
                        </View>
                      </View>

                      <Text style={[styles.tripTitle, { color: colors.textPrimary }]}>
                        {trip.title}
                      </Text>
                      <View style={styles.tripMetaRow}>
                        <Ionicons name="calendar-outline" size={14} color={colors.textSecondary} />
                        <Text style={[styles.tripMeta, { color: colors.textSecondary }]}>
                          {trip.startDate
                            ? `${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}`
                            : 'Dates not set'}
                        </Text>
                      </View>
                    </View>

                    <View style={styles.tripActions}>
                      <Pressable
                        onPress={() => openEditTrip(trip)}
                        style={[
                          styles.tripHeaderAction,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.tripActionText, { color: colors.primary }]}>
                          Edit
                        </Text>
                      </Pressable>
                      <Pressable
                        onPress={() => deleteTrip(trip.id)}
                        style={[
                          styles.tripDeleteButton,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Ionicons name="trash-outline" size={14} color={colors.textPrimary} />
                      </Pressable>
                    </View>
                  </View>

                  {tripTravelers.length ? (
                    <View style={styles.tripTravelerRow}>
                      <View style={styles.tripAvatarStack}>
                        {tripTravelers.slice(0, 3).map((traveler, index) => (
                          <View
                            key={traveler.id}
                            style={[
                              styles.tripAvatarCircle,
                              {
                                backgroundColor: colors.paperAlt,
                                borderColor: colors.card,
                                marginLeft: index === 0 ? 0 : -10,
                              },
                            ]}
                          >
                            <Text style={[styles.tripAvatarText, { color: colors.textPrimary }]}>
                              {traveler.name.trim().charAt(0).toUpperCase()}
                            </Text>
                          </View>
                        ))}
                      </View>

                      <Text style={[styles.tripTravelerNames, { color: colors.textPrimary }]}>
                        {tripTravelers
                          .slice(0, 3)
                          .map(traveler => traveler.name)
                          .join(', ')}
                        {tripTravelers.length > 3 ? ` +${tripTravelers.length - 3}` : ''}
                      </Text>
                    </View>
                  ) : null}

                  {trip.countryIso2s.length ? (
                    <View style={styles.tripChipWrap}>
                      {trip.countryIso2s.slice(0, 6).map(iso2 => {
                        const country = countries.find(entry => entry.iso2 === iso2);
                        return (
                          <View
                            key={iso2}
                            style={[
                              styles.tripCountryChip,
                              { backgroundColor: colors.surface, borderColor: colors.border },
                            ]}
                          >
                            <Text style={[styles.tripCountryChipText, { color: colors.textPrimary }]}>
                              {country?.flagEmoji ? `${country.flagEmoji} ` : ''}
                              {countryNameByIso2.get(iso2) ?? iso2}
                            </Text>
                          </View>
                        );
                      })}
                    </View>
                  ) : null}

                  {!trip.countryIso2s.length && countrySummary ? (
                    <Text style={[styles.tripDetail, { color: colors.textPrimary }]}>
                      Countries: {countrySummary}
                    </Text>
                  ) : null}

                  {!trip.friendIds.length && friendSummary ? (
                    <Text style={[styles.tripDetail, { color: colors.textPrimary }]}>
                      Friends: {friendSummary}
                    </Text>
                  ) : null}

                  {trip.notes ? (
                    <View
                      style={[
                        styles.tripNotesCard,
                        { backgroundColor: colors.surface, borderColor: colors.border },
                      ]}
                    >
                      <Text style={[styles.expenseTitle, { color: colors.textPrimary }]}>
                        Notes
                      </Text>
                      <Text style={[styles.tripNotesInline, { color: colors.textSecondary }]}>
                        {trip.notes}
                      </Text>
                    </View>
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

                  {previewLines.length ? (
                    <View style={styles.expenseCard}>
                      <Text style={[styles.expenseTitle, { color: colors.textPrimary }]}>
                        Itinerary
                      </Text>
                      {previewLines.map(line => (
                        <Text key={line} style={[styles.tripNotes, { color: colors.textSecondary }]}>
                          {line}
                        </Text>
                      ))}
                    </View>
                  ) : null}

                  <View
                    style={[
                      styles.infoPanel,
                      {
                        backgroundColor:
                          visaSummaries.some(summary => summary.exceedsAllowedStay)
                            ? colors.yellowBg
                            : colors.surface,
                        borderColor:
                          visaSummaries.some(summary => summary.exceedsAllowedStay)
                            ? colors.yellowBorder
                            : colors.border,
                      },
                    ]}
                  >
                    <Text
                      style={[
                        styles.infoText,
                        {
                          color: visaSummaries.some(summary => summary.exceedsAllowedStay)
                            ? colors.yellowText
                            : colors.textPrimary,
                        },
                      ]}
                    >
                      {visaHeadline(visaSummaries, tripTravelers.length || 1, totalDays)}
                    </Text>
                    <Text style={[styles.infoSubtext, { color: colors.textSecondary }]}>
                      Assumes the app&apos;s default passport context for all travelers.
                    </Text>
                    {visaSummaries.slice(0, 3).map(summary => (
                      <Text
                        key={`${summary.travelerId}-${summary.countryIso2}`}
                        style={[
                          styles.infoSubtext,
                          {
                            color: summary.exceedsAllowedStay ? colors.yellowText : colors.textSecondary,
                          },
                        ]}
                      >
                        {summary.travelerName} · {summary.passportLabel}: {summary.countryFlag ? `${summary.countryFlag} ` : ''}
                        {summary.countryName} {prettyVisaType(summary.visaType)}
                        {summary.allowedDays ? ` · ${summary.allowedDays} days` : ''}
                        {summary.exceedsAllowedStay ? ' · trip may be too long' : ''}
                      </Text>
                    ))}
                  </View>

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

                  <View style={styles.tripFooterRow}>
                    <Pressable
                      onPress={() => openEditTrip(trip)}
                      style={[
                        styles.tripPrimaryButton,
                        { backgroundColor: colors.paperAlt, borderColor: colors.border },
                      ]}
                    >
                      <Text style={[styles.tripPrimaryButtonText, { color: colors.textPrimary }]}>
                        Open trip
                      </Text>
                    </Pressable>

                    {trip.startDate && trip.endDate ? (
                      <Pressable
                        onPress={() => addTripToCalendar(trip)}
                        style={[
                          styles.tripCalendarButton,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Ionicons name="calendar-outline" size={16} color={colors.textPrimary} />
                        <Text style={[styles.tripCalendarButtonText, { color: colors.textPrimary }]}>
                          Calendar
                        </Text>
                      </Pressable>
                    ) : null}
                  </View>
                </ScrapbookCard>
              );
            })}
          </View>
        )}
      </ScrollView>

      <Modal animationType="slide" visible={modalVisible} onRequestClose={closeModal}>
        <ScrapbookBackground>
        <View style={{ flex: 1, backgroundColor: 'transparent' }}>
          <ScrollView
            contentContainerStyle={{
              paddingTop: insets.top + 18,
              paddingHorizontal: 20,
              paddingBottom: insets.bottom + 40,
            }}
            keyboardShouldPersistTaps="handled"
          >
            <View style={styles.modalHeader}>
              <Pressable
                onPress={closeModal}
                style={[styles.modalHeaderButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
              >
                <Text style={[styles.backText, { color: colors.textPrimary }]}>Cancel</Text>
              </Pressable>
              <Pressable
                onPress={saveTrip}
                disabled={!draft.title.trim()}
                style={[
                  styles.modalHeaderButton,
                  {
                    backgroundColor: draft.title.trim() ? colors.paperAlt : colors.surface,
                    borderColor: colors.border,
                    opacity: draft.title.trim() ? 1 : 0.7,
                  },
                ]}
              >
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

            <TitleBanner title={draft.id ? 'Edit Trip' : 'New Trip'} />

            <ScrapbookCard
              style={styles.composerIntroShell}
              innerStyle={[styles.composerIntroCard, { backgroundColor: `${colors.card}F2` }]}
            >
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Trip Snapshot
              </Text>
              <Text style={[styles.composerIntroTitle, { color: colors.textPrimary }]}>
                Keep the full trip in one place
              </Text>

              <View style={styles.composerStatRow}>
                <View
                  style={[
                    styles.composerStatPill,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.composerStatLabel, { color: colors.textSecondary }]}>
                    Travelers
                  </Text>
                  <Text style={[styles.composerStatValue, { color: colors.textPrimary }]}>
                    {draftTravelers.length}
                  </Text>
                </View>

                <View
                  style={[
                    styles.composerStatPill,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.composerStatLabel, { color: colors.textSecondary }]}>
                    Countries
                  </Text>
                  <Text style={[styles.composerStatValue, { color: colors.textPrimary }]}>
                    {draft.countryIso2s.length}
                  </Text>
                </View>

                <View
                  style={[
                    styles.composerStatPill,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.composerStatLabel, { color: colors.textSecondary }]}>
                    Dates
                  </Text>
                  <Text style={[styles.composerStatValue, { color: colors.textPrimary }]}>
                    {draft.includeDates ? 'On' : 'Off'}
                  </Text>
                </View>
              </View>

              <View
                style={[
                  styles.composerSnapshotCard,
                  { backgroundColor: colors.surface, borderColor: colors.border },
                ]}
              >
                <View style={styles.snapshotRow}>
                  <View style={styles.snapshotLabelWrap}>
                    <Ionicons name="map-outline" size={14} color={colors.textSecondary} />
                    <Text style={[styles.snapshotLabel, { color: colors.textSecondary }]}>
                      Route
                    </Text>
                  </View>
                  <Text style={[styles.snapshotValue, { color: colors.textPrimary }]} numberOfLines={1}>
                    {selectedCountryNames.length ? selectedCountryNames.slice(0, 3).join(', ') : 'No countries yet'}
                  </Text>
                </View>
                <View style={[styles.snapshotDivider, { backgroundColor: colors.border }]} />
                <View style={styles.snapshotRow}>
                  <View style={styles.snapshotLabelWrap}>
                    <Ionicons name="people-outline" size={14} color={colors.textSecondary} />
                    <Text style={[styles.snapshotLabel, { color: colors.textSecondary }]}>
                      Travelers
                    </Text>
                  </View>
                  <Text style={[styles.snapshotValue, { color: colors.textPrimary }]} numberOfLines={1}>
                    {draftTravelers.length
                      ? draftTravelers.map(traveler => traveler.name).slice(0, 3).join(', ')
                      : 'Just you'}
                  </Text>
                </View>
                <View style={[styles.snapshotDivider, { backgroundColor: colors.border }]} />
                <View style={styles.snapshotRow}>
                  <View style={styles.snapshotLabelWrap}>
                    <Ionicons name="calendar-outline" size={14} color={colors.textSecondary} />
                    <Text style={[styles.snapshotLabel, { color: colors.textSecondary }]}>
                      Status
                    </Text>
                  </View>
                  <Text style={[styles.snapshotValue, { color: colors.textPrimary }]} numberOfLines={1}>
                    {draft.includeDates && draftTripDays
                      ? `${draftTripDays} day${draftTripDays === 1 ? '' : 's'} planned`
                      : 'Dates still flexible'}
                  </Text>
                </View>
              </View>
            </ScrapbookCard>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Trip basics
              </Text>
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
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Trip timing
              </Text>
              <Pressable
                onPress={toggleIncludeDates}
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
                      onChangeText={value => updateTripDateField('startDate', value)}
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
                      onChangeText={value => updateTripDateField('endDate', value)}
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
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Route planning
              </Text>
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Countries</Text>
              <View
                style={[
                  styles.helperCard,
                  { backgroundColor: colors.surface, borderColor: colors.border },
                ]}
              >
                <Text style={[styles.helperTitle, { color: colors.textPrimary }]}>
                  Route builder
                </Text>
                <Text style={[styles.helperCopy, { color: colors.textSecondary }]}>
                  Add the places this trip will actually cover, then use itinerary and visa tools against that same route.
                </Text>
              </View>

              <View style={styles.summaryStrip}>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Selected
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    {draft.countryIso2s.length}
                  </Text>
                </View>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Saved lists
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    {savedListSuggestions.length}
                  </Text>
                </View>
              </View>

              {draft.countryIso2s.length ? (
                <>
                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
                    Included in this trip
                  </Text>
                  <View style={styles.chipWrap}>
                    {countries
                      .filter(country => draft.countryIso2s.includes(country.iso2))
                      .map(country => (
                        <Pressable
                          key={`selected-${country.iso2}`}
                          onPress={() => toggleCountry(country.iso2)}
                          style={[
                            styles.chip,
                            { backgroundColor: colors.primary, borderColor: colors.primary },
                          ]}
                        >
                          <Text style={{ color: colors.primaryText, fontWeight: '700' }}>
                            {country.flagEmoji ? `${country.flagEmoji} ` : ''}
                            {country.name}
                          </Text>
                        </Pressable>
                      ))}
                  </View>
                </>
              ) : null}

              {savedListSuggestions.length ? (
                <>
                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
                    From your saved lists
                  </Text>
                  <View style={styles.chipWrap}>
                    {savedListSuggestions.slice(0, 8).map(country => (
                      <Pressable
                        key={`saved-${country.iso2}`}
                        onPress={() => toggleCountry(country.iso2)}
                        style={[
                          styles.chip,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={{ color: colors.textPrimary, fontWeight: '600' }}>
                          {country.flagEmoji ? `${country.flagEmoji} ` : ''}
                          {country.name}
                        </Text>
                      </Pressable>
                    ))}
                  </View>
                </>
              ) : null}

              <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
                Search countries
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

              <View style={styles.pickerList}>
                {filteredCountries.map(country => {
                  const selected = draft.countryIso2s.includes(country.iso2);
                  const inSavedList =
                    bucketIsoCodes.includes(country.iso2) || visitedIsoCodes.includes(country.iso2);

                  return (
                    <Pressable
                      key={country.iso2}
                      onPress={() => toggleCountry(country.iso2)}
                      style={[
                        styles.pickerRow,
                        {
                          backgroundColor: selected ? colors.paperAlt : colors.surface,
                          borderColor: selected ? colors.primary : colors.border,
                        },
                      ]}
                    >
                      <View style={styles.pickerRowMain}>
                        <Text style={[styles.flag, { color: colors.textPrimary }]}>
                          {country.flagEmoji ?? '•'}
                        </Text>

                        <View style={{ flex: 1 }}>
                          <Text style={[styles.countryName, { color: colors.textPrimary }]}>
                            {country.name}
                          </Text>
                          <Text style={[styles.pickerMeta, { color: colors.textSecondary }]}>
                            {country.iso2}
                            {inSavedList ? ' · saved in your lists' : ''}
                          </Text>
                        </View>
                      </View>

                      <View
                        style={[
                          styles.pickerCheck,
                          {
                            backgroundColor: selected ? colors.primary : colors.card,
                            borderColor: selected ? colors.primary : colors.border,
                          },
                        ]}
                      >
                        <Ionicons
                          name={selected ? 'checkmark' : 'add'}
                          size={16}
                          color={selected ? colors.primaryText : colors.textPrimary}
                        />
                      </View>
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
                Passports
              </Text>
              <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                Choose the passport to use for each traveler when calculating visa prep.
              </Text>

              {draftTravelers.length ? (
                <View style={styles.expenseList}>
                  {draftTravelers.map(traveler => {
                    const selectedPassport =
                      draft.travelerPassports.find(
                        selection => selection.travelerId === traveler.id
                      )?.passportCountryCode ??
                      (traveler.id === currentTraveler?.id ? defaultPassportCode : 'US');

                    return (
                      <View
                        key={`passport-${traveler.id}`}
                        style={[
                          styles.itineraryCard,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.expenseTitle, { color: colors.textPrimary }]}>
                          {traveler.name}
                        </Text>
                        <Text style={[styles.infoSubtext, { color: colors.textSecondary }]}>
                          Passport used for visa checks
                        </Text>
                        <View style={styles.chipWrap}>
                          {[
                            selectedPassport,
                            ...(traveler.id === currentTraveler?.id
                              ? savedPassportPreferences.nationalityCountryCodes
                              : []),
                            ...plannerCountries.slice(0, 12).map(country => country.iso2),
                          ]
                            .map(code => code.toUpperCase())
                            .filter((code, index, array) => array.indexOf(code) === index)
                            .slice(0, 12)
                            .map(code => {
                              const selected = selectedPassport === code;
                              return (
                                <Pressable
                                  key={`${traveler.id}-${code}`}
                                  onPress={() => updateTravelerPassport(traveler.id, code)}
                                  style={[
                                    styles.chip,
                                    {
                                      backgroundColor: selected ? colors.primary : colors.card,
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
                                    {countryLabelForPassport(code)}
                                  </Text>
                                </Pressable>
                              );
                            })}
                        </View>
                      </View>
                    );
                  })}
                </View>
              ) : (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Add travelers before setting passport context.
                </Text>
              )}
            </View>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Day planning
              </Text>
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Itinerary</Text>
              <View
                style={[
                  styles.helperCard,
                  { backgroundColor: colors.surface, borderColor: colors.border },
                ]}
              >
                <Text style={[styles.helperTitle, { color: colors.textPrimary }]}>
                  Day-by-day route
                </Text>
                <Text style={[styles.helperCopy, { color: colors.textSecondary }]}>
                  Shape each day as a country stop or a travel day so the trip timeline stays readable.
                </Text>
              </View>
              {draft.includeDates ? (
                <View style={styles.summaryStrip}>
                  <View
                    style={[
                      styles.summaryMiniCard,
                      { backgroundColor: colors.surface, borderColor: colors.border },
                    ]}
                  >
                    <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                      Days
                    </Text>
                    <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                      {draft.dayPlans.length}
                    </Text>
                  </View>
                  <View
                    style={[
                      styles.summaryMiniCard,
                      { backgroundColor: colors.surface, borderColor: colors.border },
                    ]}
                  >
                    <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                      Stops
                    </Text>
                    <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                      {new Set(draft.dayPlans.map(plan => plan.countryIso2).filter(Boolean)).size}
                    </Text>
                  </View>
                </View>
              ) : null}
              {draft.includeDates && draft.dayPlans.length ? (
                <>
                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
                    Current route
                  </Text>

                  <View style={styles.expenseList}>
                    {draft.dayPlans.map(plan => (
                      <View
                        key={plan.id}
                        style={[
                          styles.itineraryCard,
                          { backgroundColor: colors.surface, borderColor: colors.border },
                        ]}
                      >
                        <Text style={[styles.expenseTitle, { color: colors.textPrimary }]}>
                          {formatDate(plan.date)}
                        </Text>

                        <View style={styles.inlineRow}>
                          {[
                            { label: 'Country', value: 'country' as const },
                            { label: 'Travel', value: 'travel' as const },
                          ].map(option => {
                            const selected = plan.kind === option.value;
                            return (
                              <Pressable
                                key={`${plan.id}-${option.value}`}
                                onPress={() => updateDayPlan(plan.id, { kind: option.value })}
                                style={[
                                  styles.segmentButton,
                                  {
                                    backgroundColor: selected ? colors.primary : colors.card,
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

                        {plan.kind === 'country' ? (
                          <View style={styles.chipWrap}>
                            {draft.countryIso2s.map(iso2 => {
                              const selected = plan.countryIso2 === iso2;
                              const label = countryNameByIso2.get(iso2) ?? iso2;
                              return (
                                <Pressable
                                  key={`${plan.id}-${iso2}`}
                                  onPress={() =>
                                    updateDayPlan(plan.id, {
                                      kind: 'country',
                                      countryIso2: iso2,
                                      countryName: label,
                                    })
                                  }
                                  style={[
                                    styles.chip,
                                    {
                                      backgroundColor: selected ? colors.primary : colors.card,
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
                        ) : (
                          <Text style={[styles.infoSubtext, { color: colors.textSecondary }]}>
                            Travel day between stops
                          </Text>
                        )}
                      </View>
                    ))}
                  </View>
                </>
              ) : (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Add trip dates to generate a day-by-day itinerary.
                </Text>
              )}
            </View>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Travel crew
              </Text>
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Friends</Text>
              <View
                style={[
                  styles.helperCard,
                  { backgroundColor: colors.surface, borderColor: colors.border },
                ]}
              >
                <Text style={[styles.helperTitle, { color: colors.textPrimary }]}>
                  Travel crew
                </Text>
                <Text style={[styles.helperCopy, { color: colors.textSecondary }]}>
                  Pick the friends joining this trip so dates, visas, and expenses all stay attached to the same group.
                </Text>
              </View>

              {friends.length === 0 ? (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Add friends in the Friends tab to include them in a plan.
                </Text>
              ) : (
                <>
                  <View style={styles.summaryStrip}>
                    <View
                      style={[
                        styles.summaryMiniCard,
                        { backgroundColor: colors.surface, borderColor: colors.border },
                      ]}
                    >
                      <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                        Invited
                      </Text>
                      <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                        {draft.friendIds.length}
                      </Text>
                    </View>
                    <View
                      style={[
                        styles.summaryMiniCard,
                        { backgroundColor: colors.surface, borderColor: colors.border },
                      ]}
                    >
                      <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                        Total travelers
                      </Text>
                      <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                        {draftTravelers.length}
                      </Text>
                    </View>
                  </View>
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
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Group timing
              </Text>
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                Availability
              </Text>
              <View
                style={[
                  styles.helperCard,
                  { backgroundColor: colors.surface, borderColor: colors.border },
                ]}
              >
                <Text style={[styles.helperTitle, { color: colors.textPrimary }]}>
                  How this works
                </Text>
                <Text style={[styles.helperCopy, { color: colors.textSecondary }]}>
                  Add exact dates or flexible months for each traveler to find a real shared window.
                </Text>
              </View>
              <View style={styles.summaryStrip}>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Travelers
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    {draftTravelers.length}
                  </Text>
                </View>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Proposals
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    {draft.availability.length}
                  </Text>
                </View>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Shared windows
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    {draftOverlaps.length}
                  </Text>
                </View>
              </View>

              {draftTravelers.length === 0 ? (
                <Text style={[styles.selectionSummary, { color: colors.textSecondary }]}>
                  Add yourself or friends to the trip before tracking shared availability.
                </Text>
              ) : (
                <>
                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
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

                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
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
                    <>
                      <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
                        Current proposals
                      </Text>
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
                                  <Text style={[styles.tripActionText, { color: colors.redText }]}>
                                    Remove
                                  </Text>
                                </Pressable>
                              </View>
                            ))}
                          </View>
                        );
                      })}
                      </View>
                    </>
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
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Border prep
              </Text>
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
                Visa Summary
              </Text>
              <View
                style={[
                  styles.helperCard,
                  { backgroundColor: colors.surface, borderColor: colors.border },
                ]}
              >
                <Text style={[styles.helperTitle, { color: colors.textPrimary }]}>
                  Visa requirements
                </Text>
                <Text style={[styles.helperCopy, { color: colors.textSecondary }]}>
                  Check each traveler and country combination that may still need visa prep before booking.
                </Text>
              </View>
              <View style={styles.summaryStrip}>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Travelers
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    {draftTravelers.length}
                  </Text>
                </View>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Flagged
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    {draftVisaSummaries.length}
                  </Text>
                </View>
              </View>
              <View
                style={[
                  styles.infoPanel,
                  {
                    backgroundColor: draftVisaSummaries.some(summary => summary.exceedsAllowedStay)
                      ? colors.yellowBg
                      : colors.surface,
                    borderColor: draftVisaSummaries.some(summary => summary.exceedsAllowedStay)
                      ? colors.yellowBorder
                      : colors.border,
                  },
                ]}
              >
                <Text
                  style={[
                    styles.infoText,
                    {
                      color: draftVisaSummaries.some(summary => summary.exceedsAllowedStay)
                        ? colors.yellowText
                        : colors.textPrimary,
                    },
                  ]}
                >
                  {visaHeadline(draftVisaSummaries, draftTravelers.length || 1, draftTripDays)}
                </Text>
                {draftVisaSummaries.length ? (
                  draftVisaSummaries.map(summary => (
                    <Text
                      key={`draft-visa-${summary.travelerId}-${summary.countryIso2}`}
                      style={[
                        styles.infoSubtext,
                        {
                          color: summary.exceedsAllowedStay ? colors.yellowText : colors.textSecondary,
                        },
                      ]}
                    >
                      {summary.travelerName} · {summary.passportLabel}: {summary.countryFlag ? `${summary.countryFlag} ` : ''}
                      {summary.countryName} {prettyVisaType(summary.visaType)}
                      {summary.allowedDays ? ` · ${summary.allowedDays} days` : ''}
                      {summary.exceedsAllowedStay ? ' · trip may be too long' : ''}
                    </Text>
                  ))
                ) : (
                  <Text style={[styles.infoSubtext, { color: colors.textSecondary }]}>
                    No advance visa prep is currently flagged for the selected countries.
                  </Text>
                )}
              </View>
            </View>

            <View
              style={[
                styles.sectionCard,
                { backgroundColor: colors.card, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.sectionEyebrow, { color: colors.textSecondary }]}>
                Group budget
              </Text>
              <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>Expenses</Text>
              <View
                style={[
                  styles.helperCard,
                  { backgroundColor: colors.surface, borderColor: colors.border },
                ]}
              >
                <Text style={[styles.helperTitle, { color: colors.textPrimary }]}>
                  Expense split
                </Text>
                <Text style={[styles.helperCopy, { color: colors.textSecondary }]}>
                  Log who paid and who should share the cost so the group total stays easy to track.
                </Text>
              </View>
              <View style={styles.summaryStrip}>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Total
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    ${totalDraftExpenses.toFixed(0)}
                  </Text>
                </View>
                <View
                  style={[
                    styles.summaryMiniCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.summaryMiniLabel, { color: colors.textSecondary }]}>
                    Entries
                  </Text>
                  <Text style={[styles.summaryMiniValue, { color: colors.textPrimary }]}>
                    {draft.expenses.length}
                  </Text>
                </View>
              </View>

              {draft.expenses.length ? (
                <>
                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
                    Logged expenses
                  </Text>
                  <View style={styles.statRow}>
                    <View
                      style={[
                        styles.statPill,
                        { backgroundColor: colors.surface, borderColor: colors.border },
                      ]}
                    >
                      <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
                        Total
                      </Text>
                      <Text style={[styles.statValue, { color: colors.textPrimary }]}>
                        ${draft.expenses.reduce((sum, expense) => sum + expense.totalAmount, 0).toFixed(0)}
                      </Text>
                    </View>
                    <View
                      style={[
                        styles.statPill,
                        { backgroundColor: colors.surface, borderColor: colors.border },
                      ]}
                    >
                      <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
                        Entries
                      </Text>
                      <Text style={[styles.statValue, { color: colors.textPrimary }]}>
                        {draft.expenses.length}
                      </Text>
                    </View>
                  </View>
                </>
              ) : null}

              <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
                Add a new expense
              </Text>
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
                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
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

                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
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
                <>
                  <Text style={[styles.subsectionTitle, { color: colors.textPrimary }]}>
                    Current expenses
                  </Text>
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
                          <Text style={[styles.infoSubtext, { color: colors.textSecondary }]}>
                            Split with {expense.splitWithIds.length || 1} traveler{expense.splitWithIds.length === 1 ? '' : 's'}
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
                          <Text style={[styles.tripActionText, { color: colors.redText }]}>
                            Remove
                          </Text>
                        </Pressable>
                      </View>
                    ))}
                  </View>
                </>
              ) : null}
            </View>
          </ScrollView>
        </View>
        </ScrapbookBackground>
      </Modal>
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
    gap: 8,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 10,
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
    borderWidth: 1,
  },
  emptyCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 22,
  },
  emptyEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
    marginBottom: 10,
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
  emptySummaryRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 16,
  },
  emptySummaryChip: {
    flex: 1,
    minWidth: 132,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  emptySummaryLabel: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginBottom: 4,
  },
  emptySummaryValue: {
    fontSize: 14,
    fontWeight: '700',
    lineHeight: 18,
  },
  tripStack: {
    gap: 14,
  },
  tripCardShell: {
    width: '100%',
  },
  tripCard: {
    padding: 18,
  },
  tripCardEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 1.1,
    textTransform: 'uppercase',
    marginBottom: 10,
  },
  tripCardHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  tripBadgeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 8,
  },
  tripTypeBadge: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  tripTypeBadgeText: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.3,
  },
  tripModeBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  tripModeBadgeText: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.3,
  },
  tripTitle: {
    fontSize: 24,
    fontWeight: '800',
    lineHeight: 28,
  },
  tripMetaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 6,
  },
  tripMeta: {
    fontSize: 13,
    fontWeight: '600',
  },
  tripTravelerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
    marginBottom: 2,
  },
  tripAvatarStack: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 12,
  },
  tripAvatarCircle: {
    width: 30,
    height: 30,
    borderRadius: 15,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tripAvatarText: {
    fontSize: 12,
    fontWeight: '800',
  },
  tripTravelerNames: {
    flex: 1,
    fontSize: 14,
    fontWeight: '600',
  },
  tripChipWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 8,
  },
  tripCountryChip: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  tripCountryChipText: {
    fontSize: 13,
    fontWeight: '600',
  },
  tripActions: {
    flexDirection: 'row',
    gap: 8,
    alignItems: 'center',
  },
  tripHeaderAction: {
    minHeight: 36,
    paddingHorizontal: 14,
    borderRadius: 999,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tripDeleteButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tripActionText: {
    fontSize: 13,
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
  tripNotesCard: {
    marginTop: 12,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  tripNotesInline: {
    fontSize: 14,
    lineHeight: 20,
  },
  tripFooterRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 14,
  },
  tripPrimaryButton: {
    flex: 1,
    minHeight: 46,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tripPrimaryButtonText: {
    fontSize: 14,
    fontWeight: '800',
  },
  tripCalendarButton: {
    minHeight: 46,
    borderRadius: 18,
    borderWidth: 1,
    paddingHorizontal: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  tripCalendarButtonText: {
    fontSize: 14,
    fontWeight: '700',
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
  modalHeaderButton: {
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 10,
    minWidth: 82,
    alignItems: 'center',
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
  composerIntroShell: {
    marginBottom: 14,
  },
  composerIntroCard: {
    padding: 18,
  },
  composerIntroTitle: {
    fontSize: 18,
    fontWeight: '800',
  },
  composerIntroCopy: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: 8,
  },
  composerStatRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 14,
  },
  composerStatPill: {
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 10,
    minWidth: 86,
  },
  composerStatLabel: {
    fontSize: 11,
    fontWeight: '700',
    marginBottom: 4,
  },
  composerStatValue: {
    fontSize: 16,
    fontWeight: '800',
  },
  composerSnapshotCard: {
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 8,
    marginTop: 14,
  },
  snapshotRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
    paddingVertical: 10,
  },
  snapshotLabelWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    flexShrink: 1,
  },
  snapshotLabel: {
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 0.3,
    textTransform: 'uppercase',
  },
  snapshotValue: {
    flex: 1,
    textAlign: 'right',
    fontSize: 14,
    fontWeight: '700',
  },
  snapshotDivider: {
    height: StyleSheet.hairlineWidth,
  },
  sectionCard: {
    borderWidth: 1,
    borderRadius: 28,
    padding: 20,
    marginBottom: 16,
    backgroundColor: 'rgba(248, 241, 231, 0.94)',
    shadowColor: '#8d7559',
    shadowOpacity: 0.12,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 9 },
    elevation: 5,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '800',
  },
  sectionEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.6,
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  subsectionTitle: {
    fontSize: 15,
    fontWeight: '800',
    marginTop: 16,
    marginBottom: 4,
  },
  helperCard: {
    borderWidth: 1,
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 14,
    marginTop: 12,
    shadowColor: '#8d7559',
    shadowOpacity: 0.04,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
  },
  helperTitle: {
    fontSize: 14,
    fontWeight: '800',
  },
  helperCopy: {
    fontSize: 13,
    lineHeight: 18,
    marginTop: 6,
  },
  summaryStrip: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 12,
    marginBottom: 2,
  },
  summaryMiniCard: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 13,
    paddingVertical: 12,
  },
  summaryMiniLabel: {
    fontSize: 11,
    fontWeight: '800',
    marginBottom: 4,
  },
  summaryMiniValue: {
    fontSize: 16,
    fontWeight: '800',
  },
  sectionTopGap: {
    marginTop: 14,
  },
  textInput: {
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 15,
    paddingVertical: 13,
    fontSize: 15,
    marginTop: 10,
    backgroundColor: 'rgba(255,250,244,0.84)',
  },
  notesInput: {
    minHeight: 110,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 15,
    paddingVertical: 13,
    fontSize: 15,
    lineHeight: 21,
    marginTop: 10,
    backgroundColor: 'rgba(255,250,244,0.84)',
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    minHeight: 40,
  },
  dateRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 12,
  },
  dateButton: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 18,
    padding: 15,
    backgroundColor: 'rgba(255,248,241,0.84)',
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
  pickerList: {
    gap: 10,
    marginTop: 14,
  },
  pickerRow: {
    minHeight: 72,
    borderWidth: 1,
    borderRadius: 22,
    paddingHorizontal: 15,
    paddingVertical: 13,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  pickerRowMain: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
    marginRight: 12,
  },
  pickerMeta: {
    fontSize: 12,
    lineHeight: 16,
    marginTop: 4,
    fontWeight: '600',
    letterSpacing: 0.3,
  },
  pickerCheck: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  chip: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 13,
    paddingVertical: 10,
    shadowColor: '#8d7559',
    shadowOpacity: 0.06,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
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
    minWidth: 126,
    alignItems: 'center',
  },
  addExpenseButton: {
    minHeight: 46,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 14,
    shadowColor: '#8d7559',
    shadowOpacity: 0.12,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
  },
  expenseList: {
    gap: 10,
    marginTop: 14,
  },
  expenseItem: {
    borderWidth: 1,
    borderRadius: 18,
    padding: 14,
    flexDirection: 'row',
    alignItems: 'center',
  },
  itineraryCard: {
    borderWidth: 1,
    borderRadius: 18,
    padding: 14,
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
    padding: 14,
  },
  availabilityRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
});
