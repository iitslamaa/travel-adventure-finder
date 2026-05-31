import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
  RefreshControl,
  ImageBackground,
  ScrollView,
} from 'react-native';
import { Image } from 'expo-image';
import { useRouter } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useIsFocused } from '@react-navigation/native';
import { supabase } from '../../lib/supabase';
import { Ionicons } from '@expo/vector-icons';
import AuthGate from '../../components/AuthGate';
import { FriendProfile, useFriends } from '../../hooks/useFriends';
import { useAuth } from '../../context/AuthContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../components/theme/ScrapbookCard';
import { useTheme } from '../../hooks/useTheme';

type SocialActivityEventType =
  | 'bucket_list_added'
  | 'country_visited'
  | 'next_destination_changed'
  | 'profile_photo_updated'
  | 'current_country_changed'
  | 'home_country_changed'
  | 'favorite_country_added';

type SocialActivityEvent = {
  id: string;
  actor_user_id: string;
  event_type: SocialActivityEventType;
  metadata: Record<string, unknown> | null;
  created_at: string;
  actorProfile?: FriendProfile | null;
};

const ACTIVITY_EMOJI: Record<SocialActivityEventType, string> = {
  bucket_list_added: '📝',
  country_visited: '✅',
  next_destination_changed: '✈️',
  profile_photo_updated: '📸',
  current_country_changed: '📍',
  home_country_changed: '🏠',
  favorite_country_added: '⭐️',
};

const displayNames =
  typeof Intl !== 'undefined' && 'DisplayNames' in Intl
    ? new Intl.DisplayNames(['en'], { type: 'region' })
    : null;

export default function FriendsScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const colors = useTheme();
  const isFocused = useIsFocused();

  const { isGuest, session, profile } = useAuth();
  const { friends, loading: friendsLoading, refresh } = useFriends();

  const [events, setEvents] = useState<SocialActivityEvent[]>([]);
  const [activityLoading, setActivityLoading] = useState(false);
  const [hasAttemptedLoad, setHasAttemptedLoad] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [pendingCount, setPendingCount] = useState(0);

  const currentUserId = session?.user?.id;

  const profileById = useMemo(() => {
    const map = new Map<string, FriendProfile>();

    friends.forEach(friend => {
      map.set(friend.id, friend);
    });

    if (profile?.id) {
      const profileName = [profile.first_name, profile.last_name].filter(Boolean).join(' ');

      map.set(profile.id, {
        id: profile.id,
        username: profile.username ?? '',
        full_name: profile.full_name?.trim() || profileName || profile.username || 'You',
        avatar_url: profile.avatar_url ?? null,
      });
    }

    return map;
  }, [friends, profile]);

  const fetchPendingCount = useCallback(async () => {
    if (!currentUserId) return;

    const { count, error } = await supabase
      .from('friend_requests')
      .select('*', { count: 'exact', head: true })
      .eq('receiver_id', currentUserId)
      .eq('status', 'pending');

    if (error) {
      console.error('Pending count error:', error);
      return;
    }

    setPendingCount(count ?? 0);
  }, [currentUserId]);

  const fetchActivity = useCallback(async () => {
    if (!currentUserId) return;

    setActivityLoading(true);
    setHasAttemptedLoad(true);

    const cutoff = new Date();
    cutoff.setMonth(cutoff.getMonth() - 1);

    const actorIds = Array.from(
      new Set([currentUserId, ...friends.map(friend => friend.id)].filter(Boolean))
    );

    const { data, error } = await supabase
      .from('activity_events')
      .select('id, actor_user_id, event_type, metadata, created_at')
      .in('actor_user_id', actorIds)
      .gte('created_at', cutoff.toISOString())
      .order('created_at', { ascending: false })
      .limit(20);

    if (error) {
      if (!String(error.message ?? '').toLowerCase().includes('activity_events')) {
        console.error('Activity feed error:', error);
      }
      setEvents([]);
      setActivityLoading(false);
      return;
    }

    const hydrated = ((data ?? []) as SocialActivityEvent[]).map(event => ({
      ...event,
      actorProfile: profileById.get(event.actor_user_id) ?? null,
    }));

    setEvents(hydrated);
    setActivityLoading(false);
  }, [currentUserId, friends, profileById]);

  useEffect(() => {
    if (!isFocused || !currentUserId) return;

    fetchPendingCount();
  }, [currentUserId, fetchPendingCount, isFocused]);

  useEffect(() => {
    if (!isFocused || !currentUserId || friendsLoading) return;

    fetchActivity();
  }, [currentUserId, fetchActivity, friendsLoading, isFocused]);

  const handleRefresh = async () => {
    if (!currentUserId) return;

    setRefreshing(true);
    await Promise.all([fetchPendingCount(), refresh()]);
    await fetchActivity();
    setRefreshing(false);
  };

  const openFriends = () => {
    if (!currentUserId) return;

    router.push({
      pathname: '/profile/[userId]/friends',
      params: { userId: currentUserId },
    });
  };

  const openRequests = () => {
    router.push('/friend-requests');
  };

  const openProfile = () => {
    if (!currentUserId) return;

    router.push({
      pathname: '/profile/[userId]',
      params: { userId: currentUserId },
    });
  };

  if (isGuest) {
    return (
      <ScrapbookBackground overlay={0}>
        <ImageBackground
          source={require('../../assets/scrapbook/travel3.png')}
          style={styles.pageBackground}
          imageStyle={styles.pageBackgroundImage}
        >
          <View style={styles.pageWash} />
          <View
            style={[
              styles.container,
              {
                paddingTop: insets.top + 16,
                paddingBottom: insets.bottom + 24,
              },
            ]}
          >
            <View style={styles.guestCenter}>
              <ScrapbookCard innerStyle={styles.guestFeatureCard}>
                <View style={styles.guestFeatureHeader}>
                  <View
                    style={[
                      styles.guestFeatureIcon,
                      { backgroundColor: colors.paperAlt, borderColor: colors.border },
                    ]}
                  >
                    <Ionicons name="people-outline" size={26} color={colors.textPrimary} />
                  </View>
                </View>

                <Text style={[styles.emptyHeadline, { color: colors.textPrimary }]}>
                  Create an account to build your travel circle
                </Text>
                <Text style={[styles.emptyBody, { color: colors.textSecondary }]}>
                  Add friends, review requests, and follow friend activity once you sign in.
                </Text>
              </ScrapbookCard>

              <Pressable
                onPress={() => router.push('/login')}
                style={[
                  styles.ctaButton,
                  { backgroundColor: colors.paperAlt, borderColor: colors.cardBorderStrong },
                ]}
              >
                <Ionicons name="paper-plane" size={16} color={colors.textPrimary} />
                <Text style={[styles.ctaText, { color: colors.textPrimary }]}>
                  Create Account or Log In
                </Text>
              </Pressable>
            </View>
          </View>
        </ImageBackground>
      </ScrapbookBackground>
    );
  }

  return (
    <AuthGate>
      <ScrapbookBackground overlay={0}>
        <ImageBackground
          source={require('../../assets/scrapbook/travel3.png')}
          style={styles.pageBackground}
          imageStyle={styles.pageBackgroundImage}
        >
          <View style={styles.pageWash} />
          <View style={[styles.container, { paddingTop: Math.max(insets.top - 12, 12) }]}>
            <View style={styles.actionRow}>
              <SocialAction
                icon="people"
                label="Friends"
                onPress={openFriends}
              />
              <SocialAction
                icon="person-add"
                label="Requests"
                badgeCount={pendingCount}
                onPress={openRequests}
              />
              <SocialAction
                icon="person-circle"
                label="Profile"
                onPress={openProfile}
              />
            </View>

            <ScrollView
              contentContainerStyle={[
                styles.scrollContent,
                { paddingBottom: Math.max(insets.bottom + 112, 132) },
              ]}
              refreshControl={
                <RefreshControl
                  refreshing={refreshing}
                  onRefresh={handleRefresh}
                  tintColor={colors.textPrimary}
                />
              }
              showsVerticalScrollIndicator={false}
            >
              <ScrapbookCard
                style={styles.activityShell}
                innerStyle={[styles.activityCard, { backgroundColor: `${colors.card}EB` }]}
              >
                <View style={styles.activityHeader}>
                  <View style={styles.activityTitleRow}>
                    <Ionicons name="sparkles" size={21} color={colors.textPrimary} />
                    <Text style={[styles.activityTitle, { color: colors.textPrimary }]}>
                      Activity
                    </Text>
                  </View>

                  {activityLoading && events.length > 0 && (
                    <ActivityIndicator size="small" color={colors.textPrimary} />
                  )}
                </View>

                {activityLoading && events.length === 0 ? (
                  <View style={[styles.loadingPanel, { backgroundColor: colors.paperAlt }]}>
                    <ActivityIndicator size="large" color={colors.textPrimary} />
                    <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
                      Loading friend activity
                    </Text>
                  </View>
                ) : events.length === 0 ? (
                  <View style={[styles.emptyActivity, { backgroundColor: colors.paperAlt }]}>
                    <Text style={[styles.emptyActivityTitle, { color: colors.textPrimary }]}>
                      {hasAttemptedLoad ? 'No recent friend activity yet' : 'Loading friend activity'}
                    </Text>
                    <Text style={[styles.emptyActivityBody, { color: colors.textSecondary }]}>
                      When friends update travel lists, favorite countries, destinations, or profile details, those updates will appear here.
                    </Text>
                  </View>
                ) : (
                  <View style={styles.eventList}>
                    {events.map(event => (
                      <ActivityRow key={event.id} event={event} />
                    ))}
                  </View>
                )}
              </ScrapbookCard>
            </ScrollView>
          </View>
        </ImageBackground>
      </ScrapbookBackground>
    </AuthGate>
  );

  function SocialAction({
    icon,
    label,
    badgeCount,
    onPress,
  }: {
    icon: keyof typeof Ionicons.glyphMap;
    label: string;
    badgeCount?: number;
    onPress: () => void;
  }) {
    return (
      <Pressable
        onPress={onPress}
        style={({ pressed }) => [
          styles.actionButton,
          {
            backgroundColor: colors.card,
            borderColor: colors.cardBorderStrong,
            opacity: pressed ? 0.76 : 1,
          },
        ]}
      >
        <View style={[styles.actionIconWrap, { backgroundColor: colors.paperAlt }]}>
          <Ionicons name={icon} size={28} color={colors.primary} />
          {!!badgeCount && badgeCount > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{badgeCount}</Text>
            </View>
          )}
        </View>
        <Text style={[styles.actionLabel, { color: colors.textPrimary }]} numberOfLines={1}>
          {label}
        </Text>
      </Pressable>
    );
  }

  function ActivityRow({ event }: { event: SocialActivityEvent }) {
    const actor = event.actorProfile;
    const username = actor?.username?.trim();

    return (
      <Pressable
        onPress={() =>
          router.push({
            pathname: '/profile/[userId]',
            params: { userId: event.actor_user_id },
          })
        }
        style={({ pressed }) => [styles.eventRow, { opacity: pressed ? 0.72 : 1 }]}
      >
        {actor?.avatar_url ? (
          <Image
            source={actor.avatar_url}
            style={styles.avatar}
            contentFit="cover"
            cachePolicy="memory-disk"
          />
        ) : (
          <Ionicons name="person-circle" size={46} color={colors.textMuted} />
        )}

        <View style={styles.eventCopy}>
          <Text style={[styles.eventEyebrow, { color: colors.textMuted }]} numberOfLines={1}>
            {activityEyebrow(event, username)}
          </Text>
          <Text style={[styles.eventText, { color: colors.textPrimary }]}>
            {activityText(event)}
          </Text>
          <Text style={[styles.eventTime, { color: colors.textSecondary }]}>
            {activityTimestamp(event.created_at)}
          </Text>
        </View>
      </Pressable>
    );
  }
}

function activityText(event: SocialActivityEvent) {
  const country = countryDisplayName(event);
  const destination = destinationDisplayName(event);
  const countries = countryDisplayTexts(event);
  const count = countryCount(event);
  const fallbackCountry = 'Somewhere new';
  const fallbackUpdated = 'Updated';

  switch (event.event_type) {
    case 'bucket_list_added':
      if (count > 3) return 'Added new countries to their bucket list';
      if (countries.length >= 2) return `Added ${countryListText(countries)} to their bucket list`;
      return `Added ${country ?? fallbackCountry}${flagSuffix(event)} to their bucket list`;
    case 'country_visited':
      if (count > 3) return 'Updated their visited countries';
      if (countries.length >= 2) return `Visited ${countryListText(countries)}`;
      return `Visited ${country ?? fallbackCountry}${flagSuffix(event)}`;
    case 'next_destination_changed':
      return `Going Next: ${destination ?? country ?? fallbackCountry}${flagSuffix(event)}`;
    case 'profile_photo_updated':
      return 'Updated their profile photo';
    case 'current_country_changed':
      return `Currently In: ${country ?? fallbackCountry}${flagSuffix(event)}`;
    case 'home_country_changed':
      if (count > 3) return 'Updated their home flags';
      if (countries.length > 0) {
        return `Updated home country flags to include ${countryListText(countries)}`;
      }
      return `Updated home country to ${country ?? fallbackUpdated}${flagSuffix(event)}`;
    case 'favorite_country_added':
      return `Added ${country ?? fallbackCountry}${flagSuffix(event)} to favorite countries`;
    default:
      return 'Updated their profile';
  }
}

function activityEyebrow(event: SocialActivityEvent, username?: string) {
  const emoji = ACTIVITY_EMOJI[event.event_type] ?? '✨';
  return username ? `${emoji} Update · @${username}` : `${emoji} Update`;
}

function activityTimestamp(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  const elapsed = Math.max(Date.now() - date.getTime(), 0);
  const day = 24 * 60 * 60 * 1000;

  if (elapsed < 7 * day) {
    const formatter = new Intl.RelativeTimeFormat('en', { numeric: 'auto', style: 'short' });
    if (elapsed < 60 * 1000) return formatter.format(0, 'second');
    if (elapsed < 60 * 60 * 1000) return formatter.format(-Math.round(elapsed / (60 * 1000)), 'minute');
    if (elapsed < day) return formatter.format(-Math.round(elapsed / (60 * 60 * 1000)), 'hour');
    return formatter.format(-Math.round(elapsed / day), 'day');
  }

  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

function countryDisplayName(event: SocialActivityEvent) {
  const metadata = event.metadata;
  const countryName = stringValue(metadata?.country_name);
  if (countryName) return countryName;

  const code = stringValue(metadata?.country_code) ?? stringValue(metadata?.country);
  if (!code) return null;

  return regionName(code);
}

function destinationDisplayName(event: SocialActivityEvent) {
  const metadata = event.metadata;
  const destinationName = stringValue(metadata?.destination_name);
  if (destinationName) return destinationName;

  const destination = stringValue(metadata?.destination);
  if (!destination) return countryDisplayName(event);

  return regionName(destination);
}

function countryDisplayTexts(event: SocialActivityEvent) {
  return countryCodes(event)
    .slice(0, 3)
    .map(code => {
      const name = regionName(code);
      const emoji = flag(code);
      return emoji ? `${name}\u00A0${emoji}` : name;
    });
}

function countryListText(countries: string[]) {
  if (countries.length === 0) return 'Somewhere new';
  if (countries.length === 1) return countries[0];
  if (countries.length === 2) return `${countries[0]} and ${countries[1]}`;
  return `${countries[0]}, ${countries[1]}, and ${countries[2]}`;
}

function countryCodes(event: SocialActivityEvent) {
  const metadata = event.metadata;
  const codes: string[] = [];

  codes.push(...stringArrayValue(metadata?.country_codes));

  const csvCodes = stringValue(metadata?.country_codes);
  if (csvCodes) {
    codes.push(...csvCodes.split(','));
  }

  const primary = stringValue(metadata?.country_code) ?? stringValue(metadata?.country);
  if (primary) codes.push(primary);

  const second = stringValue(metadata?.country_code_2);
  if (second) codes.push(second);

  const third = stringValue(metadata?.country_code_3);
  if (third) codes.push(third);

  const seen = new Set<string>();
  return codes
    .map(code => code.trim().toUpperCase())
    .filter(code => {
      if (!code || seen.has(code)) return false;
      seen.add(code);
      return true;
    });
}

function countryCount(event: SocialActivityEvent) {
  const metadataCount = intValue(event.metadata?.country_count);
  return metadataCount ?? countryCodes(event).length;
}

function flagSuffix(event: SocialActivityEvent) {
  const metadata = event.metadata;
  const code =
    stringValue(metadata?.country_code) ??
    stringValue(metadata?.country) ??
    stringValue(metadata?.destination);
  if (!code) return '';

  const emoji = flag(code);
  return emoji ? `\u00A0${emoji}` : '';
}

function regionName(code: string) {
  const normalized = code.trim().toUpperCase();
  return displayNames?.of(normalized) ?? normalized;
}

function flag(code: string) {
  const upper = code.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(upper)) return '';

  return upper
    .split('')
    .map(char => String.fromCodePoint(127397 + char.charCodeAt(0)))
    .join('');
}

function stringValue(value: unknown) {
  if (typeof value === 'string') return value.trim() || null;
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return null;
}

function intValue(value: unknown) {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function stringArrayValue(value: unknown) {
  if (!Array.isArray(value)) return [];

  return value
    .map(item => stringValue(item))
    .filter((item): item is string => Boolean(item));
}

const styles = StyleSheet.create({
  pageBackground: {
    flex: 1,
  },
  pageBackgroundImage: {
    resizeMode: 'cover',
  },
  pageWash: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(250,245,237,0.18)',
  },
  container: {
    flex: 1,
  },
  actionRow: {
    flexDirection: 'row',
    gap: 12,
    height: 118,
    paddingHorizontal: 14,
  },
  actionButton: {
    flex: 1,
    borderRadius: 24,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 12,
    shadowOpacity: 0.16,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 4,
  },
  actionIconWrap: {
    width: 52,
    height: 52,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  actionLabel: {
    fontSize: 15,
    fontWeight: '800',
  },
  scrollContent: {
    paddingTop: 16,
    paddingHorizontal: 14,
  },
  activityShell: {
    marginBottom: 16,
  },
  activityCard: {
    padding: 18,
  },
  activityHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  activityTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  activityTitle: {
    fontSize: 20,
    fontWeight: '800',
  },
  loadingPanel: {
    minHeight: 156,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  loadingText: {
    fontSize: 15,
    fontWeight: '700',
  },
  emptyActivity: {
    borderRadius: 20,
    padding: 16,
  },
  emptyActivityTitle: {
    fontSize: 16,
    fontWeight: '800',
  },
  emptyActivityBody: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '600',
  },
  eventList: {
    gap: 2,
  },
  eventRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 4,
    paddingVertical: 10,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
  },
  eventCopy: {
    flex: 1,
    gap: 4,
  },
  eventEyebrow: {
    fontSize: 11,
    fontWeight: '700',
  },
  eventText: {
    fontSize: 15,
    lineHeight: 20,
    fontWeight: '800',
  },
  eventTime: {
    fontSize: 12,
    fontWeight: '600',
  },
  badge: {
    position: 'absolute',
    top: -5,
    right: -5,
    minWidth: 17,
    height: 17,
    borderRadius: 9,
    backgroundColor: '#B07A6C',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
  },
  badgeText: {
    color: '#FFF8F0',
    fontSize: 10,
    fontWeight: '800',
  },
  emptyHeadline: {
    fontSize: 28,
    fontWeight: '700',
  },
  emptyBody: {
    marginTop: 12,
    fontSize: 16,
    lineHeight: 22,
  },
  guestCenter: {
    flex: 1,
    justifyContent: 'center',
    gap: 24,
    paddingHorizontal: 20,
  },
  guestFeatureCard: {
    padding: 22,
    minHeight: 168,
  },
  guestFeatureHeader: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginBottom: 12,
  },
  guestFeatureIcon: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ctaButton: {
    borderWidth: 1,
    borderRadius: 24,
    minHeight: 60,
    paddingHorizontal: 20,
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'center',
    flexDirection: 'row',
    gap: 10,
  },
  ctaText: {
    fontSize: 18,
    fontWeight: '700',
  },
});
