import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  Modal,
  RefreshControl,
} from 'react-native';
import { Image } from 'expo-image';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useNavigation } from '@react-navigation/native';
import { useEffect, useState } from 'react';
import { Ionicons } from '@expo/vector-icons';
import CountryFlag from 'react-native-country-flag';
import { useProfileById } from '../../hooks/useProfileById';
import { useFriendshipStatus } from '../../hooks/useFriendshipStatus';
import { useFriendCount } from '../../hooks/useFriendCount';
import { useUserCounts } from '../../hooks/useUserCounts';
import CollapsibleCountrySection from '../../components/profile/CollapsibleCountrySection';
import { useCountries } from '../../hooks/useCountries';
import { useTheme } from '../../hooks/useTheme';
import { useAuth } from '../../context/AuthContext';
import { supabase } from '../../lib/supabase';

export default function FriendProfileScreen() {
  const router = useRouter();
  const navigation = useNavigation();

  useEffect(() => {
    navigation.setOptions({
      title: 'Profile',
    });
  }, [navigation]);
  const { userId } = useLocalSearchParams();
  if (typeof userId !== 'string') return null;
  const colors = useTheme();

  const { session } = useAuth();
  const isOwnProfile = session?.user?.id === userId;

  const [ctaOpen, setCtaOpen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const { isFriend, isPending, refresh: refreshFriendship } = useFriendshipStatus(userId);
  const { refresh: refreshFriendCount } = useFriendCount(userId);

  const handleUnfriend = async () => {
    if (!session?.user?.id) return;

    setCtaOpen(false); // optimistic UI

    await supabase
      .from('friends')
      .delete()
      .or(
        `and(user_id.eq.${session.user.id},friend_id.eq.${userId}),and(user_id.eq.${userId},friend_id.eq.${session.user.id})`
      );

    await refreshFriendship();
    await refreshFriendCount();
  };

  const handleAddFriend = async () => {
    if (!session?.user?.id) return;

    await supabase.from('friend_requests').insert({
      sender_id: session.user.id,
      receiver_id: userId,
      status: 'pending',
    });

    refreshFriendship(); // optimistic refresh
  };

  const handleCancelRequest = async () => {
    if (!session?.user?.id) return;

    await supabase
      .from('friend_requests')
      .delete()
      .eq('sender_id', session.user.id)
      .eq('receiver_id', userId);

    refreshFriendship(); // optimistic refresh
  };

  const handleRefresh = async () => {
    setRefreshing(true);

    try {
      await Promise.all([
        refreshFriendship?.(),
        refreshFriendCount?.(),
      ]);
    } catch (err) {
      console.error('Profile refresh error:', err);
    }

    setRefreshing(false);
  };

  const { profile, loading } = useProfileById(userId);
  const { count: friendCount } = useFriendCount(userId);
  const { traveledCount, traveledIsoCodes } = useUserCounts(userId);

  const { countries } = useCountries();

  const nextDestinationIso =
    typeof profile?.next_destination === 'string'
      ? profile.next_destination
      : null;

  const nextDestinationCountry = countries?.find(
    c => c.iso2 === nextDestinationIso
  );

  if (loading || !profile) {
    return (
      <View style={[styles.container, { backgroundColor: colors.background }]}>
        <Text style={{ color: colors.textMuted }}>Loading...</Text>
      </View>
    );
  }



  const languagesText =
    Array.isArray(profile.languages) && profile.languages.length > 0
      ? profile.languages
          .map((l: any) => (typeof l === 'string' ? l : l?.name))
          .filter(Boolean)
          .join(' · ')
      : '—';

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {/* Top back */}
      <Pressable onPress={() => router.back()} style={styles.backBtn}>
        <Ionicons name="arrow-back" size={22} color={colors.textPrimary} />
      </Pressable>

      <ScrollView
        contentContainerStyle={{ paddingBottom: 40 }}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={handleRefresh}
            tintColor={colors.textPrimary}
          />
        }
      >
        <Text style={[styles.title, { color: colors.textPrimary }]}>
          Profile
        </Text>

        {/* Header block */}
        <View style={styles.headerRow}>
          <View style={styles.avatarWrap}>
            {profile.avatar_url ? (
              <Image
                source={profile.avatar_url}
                style={styles.avatar}
                contentFit="cover"
                cachePolicy="memory-disk"
              />
            ) : (
              <Ionicons
                name="person-circle"
                size={150}
                color={colors.textMuted}
              />
            )}
          </View>

          <View style={{ flex: 1, marginLeft: 18 }}>
            <Text style={[styles.name, { color: colors.textPrimary }]}>
              {profile.full_name}
            </Text>
            <Text style={[styles.username, { color: colors.textMuted }]}>
              @{profile.username}
            </Text>

            {Array.isArray(profile.lived_countries) &&
              profile.lived_countries.length > 0 && (
                <View style={styles.homeRow}>
                  {profile.lived_countries.map((iso: string) => (
                    <CountryFlag
                      key={iso}
                      isoCode={iso}
                      size={24}
                      style={{ marginRight: 8 }}
                    />
                  ))}
                </View>
              )}

            {/* Friend button */}
            {!isOwnProfile && (
              <Pressable
                onPress={() => {
                  if (isFriend) setCtaOpen(true);
                  else if (isPending) handleCancelRequest();
                  else handleAddFriend();
                }}
                style={[
                  styles.friendBtn,
                  { borderColor: colors.primary },
                ]}
              >
                <Ionicons
                  name={
                    isFriend
                      ? 'checkmark'
                      : isPending
                      ? 'time-outline'
                      : 'person-add-outline'
                  }
                  size={18}
                  color={colors.primary}
                />

                <Text style={[styles.friendBtnText, { color: colors.primary }]}>
                  {isFriend
                    ? `${friendCount} Friend${friendCount === 1 ? '' : 's'}`
                    : isPending
                    ? 'Requested'
                    : 'Add Friend'}
                </Text>
              </Pressable>
            )}
          </View>
        </View>

        {(isOwnProfile || isFriend) ? (
        <>
        {/* Cards - (we’ll fill these from profile fields next) */}
        <View style={[styles.card, { backgroundColor: colors.card }]}>
          <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
            Languages
          </Text>
          <Text style={[styles.cardValue, { color: colors.textMuted }]}> 
            {languagesText}
          </Text>
        </View>

        <View style={[styles.card, { backgroundColor: colors.card }]}>
          <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
            Travel Mode: Solo or Group?
          </Text>
          <Text style={[styles.cardValue, { color: colors.textMuted }]}>
            {profile.travel_mode ?? '—'}
          </Text>
        </View>

        <View style={[styles.card, { backgroundColor: colors.card }]}>
          <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
            Travel Style: Budget, Comfortable, or In Between?
          </Text>
          <Text style={[styles.cardValue, { color: colors.textMuted }]}>
            {profile.travel_style ?? '—'}
          </Text>
        </View>

        <View style={[styles.card, { backgroundColor: colors.card }]}>
          <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
            Next Destination
          </Text>
          {nextDestinationCountry ? (
            <View style={styles.inlineRow}>
              <CountryFlag
                isoCode={nextDestinationCountry.iso2}
                size={18}
                style={{ marginRight: 6 }}
              />
              <Text style={[styles.cardValue, { color: colors.textPrimary, marginTop: 0 }]}>
                {nextDestinationCountry.name}
              </Text>
            </View>
          ) : (
            <Text style={[styles.cardValue, { color: colors.textMuted }]}>—</Text>
          )}
        </View>

        <CollapsibleCountrySection
          title="Countries Traveled"
          countries={traveledIsoCodes}
        />
        </>
        ) : (
          <View style={[styles.lockedCard, { backgroundColor: colors.card }]}>
            <Text style={[styles.lockedText, { color: colors.textMuted }]}>
              Learn more about this user by adding them as a friend!
            </Text>
          </View>
        )}
      </ScrollView>
      <Modal visible={ctaOpen} transparent animationType="slide">
        <Pressable
          style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' }}
          onPress={() => setCtaOpen(false)}
        >
          <View
            style={{
              backgroundColor: colors.card,
              padding: 20,
              borderTopLeftRadius: 24,
              borderTopRightRadius: 24,
            }}
          >
            <Pressable
              android_ripple={{ color: '#00000022' }}
              onPress={() => {
                setCtaOpen(false);
                router.push(`/profile/${userId}/friends`);
              }}
              style={{ paddingVertical: 16 }}
            >
              <Text style={{ fontSize: 16, fontWeight: '600', color: colors.textPrimary }}>
                View Friends
              </Text>
            </Pressable>

            <Pressable
              android_ripple={{ color: '#ef444422' }}
              onPress={() => {
                setCtaOpen(false); // optimistic close
                handleUnfriend();
              }}
              style={{ paddingVertical: 16 }}
            >
              <Text style={{ fontSize: 16, fontWeight: '600', color: '#ef4444' }}>
                Unfriend
              </Text>
            </Pressable>
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, paddingHorizontal: 20 },
  backBtn: { marginBottom: 14 },
  title: { fontSize: 30, fontWeight: '700', letterSpacing: -0.5, marginBottom: 20 },
  headerRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 22 },
  avatarWrap: { width: 150, height: 150, borderRadius: 75, overflow: 'hidden' },
  avatar: { width: 150, height: 150, borderRadius: 75 },
  name: { fontSize: 28, fontWeight: '800', marginTop: 6 },
  username: { fontSize: 18, marginTop: 4 },
  homeRow: {
    flexDirection: 'row',
    marginTop: 10,
    alignItems: 'center',
  },
  inlineRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  friendBtn: {
    marginTop: 14,
    alignSelf: 'flex-start',
    paddingVertical: 12,
    paddingHorizontal: 18,
    borderRadius: 26,
    borderWidth: 2,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  friendBtnText: { fontSize: 16, fontWeight: '700' },
  card: { borderRadius: 24, padding: 18, marginTop: 16 },
  cardTitle: { fontSize: 18, fontWeight: '800' },
  cardValue: { fontSize: 16, marginTop: 8 },
  lockedCard: {
    borderRadius: 24,
    padding: 24,
    marginTop: 24,
    alignItems: 'center',
  },
  lockedText: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 22,
  },
  linkRow: {
    marginTop: 18,
    borderRadius: 24,
    paddingVertical: 18,
    paddingHorizontal: 18,
    flexDirection: 'row',
    alignItems: 'center',
  },
  linkText: { fontSize: 18, fontWeight: '800', marginLeft: 10 },
});