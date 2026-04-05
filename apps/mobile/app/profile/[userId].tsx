import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  Modal,
  RefreshControl,
  ImageBackground,
} from 'react-native';
import { Image } from 'expo-image';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useNavigation } from '@react-navigation/native';
import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { Ionicons } from '@expo/vector-icons';
import CountryFlag from 'react-native-country-flag';
import { useProfileById } from '../../hooks/useProfileById';
import { useFriendshipStatus } from '../../hooks/useFriendshipStatus';
import { useFriendCount } from '../../hooks/useFriendCount';
import { useUserCounts } from '../../hooks/useUserCounts';
import CollapsibleCountrySection from '../../components/profile/CollapsibleCountrySection';
import HeaderCard from '../../components/profile/HeaderCard';
import { useCountries } from '../../hooks/useCountries';
import { useTheme } from '../../hooks/useTheme';
import { useAuth } from '../../context/AuthContext';
import { supabase } from '../../lib/supabase';
import { formatLanguageList } from '../../utils/language';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../components/theme/ScrapbookCard';
import TitleBanner from '../../components/theme/TitleBanner';

export default function FriendProfileScreen() {
  const router = useRouter();
  const navigation = useNavigation();
  const { userId } = useLocalSearchParams();
  const targetUserId = typeof userId === 'string' ? userId : undefined;
  const colors = useTheme();
  const { session } = useAuth();
  const [ctaOpen, setCtaOpen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const { profile, loading, refresh: refreshProfile } = useProfileById(targetUserId);
  const { isFriend, isPending, refresh: refreshFriendship } =
    useFriendshipStatus(targetUserId);
  const {
    count: friendCount,
    refresh: refreshFriendCount,
  } = useFriendCount(targetUserId);
  const {
    traveledIsoCodes,
    bucketIsoCodes,
    refresh: refreshUserCounts,
  } = useUserCounts(targetUserId);
  const { countries } = useCountries();

  const isOwnProfile = session?.user?.id === targetUserId;

  useEffect(() => {
    navigation.setOptions({
      title: 'Profile',
    });
  }, [navigation]);

  const handleUnfriend = async () => {
    if (!session?.user?.id || !targetUserId) return;

    setCtaOpen(false);

    await supabase
      .from('friends')
      .delete()
      .or(
        `and(user_id.eq.${session.user.id},friend_id.eq.${targetUserId}),and(user_id.eq.${targetUserId},friend_id.eq.${session.user.id})`
      );

    await refreshFriendship();
    await refreshFriendCount();
  };

  const handleAddFriend = async () => {
    if (!session?.user?.id || !targetUserId) return;

    await supabase.from('friend_requests').insert({
      sender_id: session.user.id,
      receiver_id: targetUserId,
      status: 'pending',
    });

    await refreshFriendship();
  };

  const handleCancelRequest = async () => {
    if (!session?.user?.id || !targetUserId) return;

    await supabase
      .from('friend_requests')
      .delete()
      .eq('sender_id', session.user.id)
      .eq('receiver_id', targetUserId);

    await refreshFriendship();
  };

  const handleRefresh = async () => {
    setRefreshing(true);

    try {
      await Promise.all([
        refreshFriendship(),
        refreshFriendCount(),
        refreshProfile(),
        refreshUserCounts(),
      ]);
    } catch (err) {
      console.error('Profile refresh error:', err);
    }

    setRefreshing(false);
  };

  const nextDestinationIso =
    typeof profile?.next_destination === 'string'
      ? profile.next_destination
      : null;

  const nextDestinationCountry = countries.find(c => c.iso2 === nextDestinationIso);

  if (!targetUserId) {
    return null;
  }

  if (loading || !profile) {
    return (
      <ScrapbookBackground>
        <View style={[styles.container, styles.loadingContainer, { backgroundColor: 'transparent' }]}>
          <TitleBanner title="Profile" />
          <ScrapbookCard innerStyle={styles.loadingCard}>
            <Text style={[styles.loadingEyebrow, { color: colors.textSecondary }]}>
              Social notebook
            </Text>
            <Text style={[styles.loadingTitle, { color: colors.textPrimary }]}>
              Loading profile
            </Text>
            <Text style={[styles.loadingBody, { color: colors.textSecondary }]}>
              Pulling together their travel profile, countries, and friendship details.
            </Text>
          </ScrapbookCard>
        </View>
      </ScrapbookBackground>
    );
  }

  const languagesText = formatLanguageList(profile.languages);
  const favoriteCountryCodes = Array.isArray(profile.favorite_countries)
    ? profile.favorite_countries.map((code: string) => String(code).toUpperCase()).filter(Boolean)
    : [];
  const currentCountryIso =
    typeof profile.current_country === 'string' ? profile.current_country.toUpperCase() : null;
  const friendCtaLabel = isFriend
    ? profile.username ? `@${profile.username}` : `${friendCount} Friend${friendCount === 1 ? '' : 's'}`
    : isPending
      ? profile.username ? `@${profile.username}` : 'Requested'
      : profile.username ? `@${profile.username}` : 'Add Friend';
  const friendCtaIcon = isFriend
    ? 'checkmark'
    : isPending
      ? 'time-outline'
      : 'person-add-outline';

  return (
    <ScrapbookBackground>
    <ImageBackground
      source={require('../../assets/scrapbook/travel4.png')}
      style={styles.pageBackground}
      imageStyle={styles.pageBackgroundImage}
    >
    <View style={styles.pageWash} />
    <View style={[styles.container, { backgroundColor: 'transparent' }]}>
      <Pressable
        onPress={() => router.back()}
        style={[styles.backBtn, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
      >
        <Ionicons name="chevron-back" size={20} color={colors.textPrimary} />
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
        <TitleBanner title="Profile" />

        <HeaderCard
          name={profile.full_name}
          handle={profile.username ? `@${profile.username}` : ''}
          avatarUrl={profile.avatar_url ?? undefined}
          flags={Array.isArray(profile.lived_countries) ? profile.lived_countries : []}
          currentCountry={currentCountryIso}
          currentCountryLabel={countries.find(c => c.iso2 === currentCountryIso)?.name ?? null}
          nextDestination={nextDestinationIso}
          nextDestinationLabel={nextDestinationCountry?.name ?? null}
          favoriteCountries={favoriteCountryCodes}
          friendCount={friendCount}
          ctaLabel={!isOwnProfile ? friendCtaLabel : null}
          ctaIcon={friendCtaIcon}
          ctaFilled={!isFriend && !isPending}
          onPressCta={
            !isOwnProfile
              ? () => {
                  if (isFriend) setCtaOpen(true);
                  else if (isPending) handleCancelRequest();
                  else handleAddFriend();
                }
              : null
          }
        />

        {isOwnProfile || isFriend ? (
          <>
            <ImageBackground
              source={require('../../assets/scrapbook/profile-info.png')}
              style={styles.infoNotebook}
              imageStyle={styles.infoNotebookImage}
            >
              <View style={[styles.infoNotebookWash, { backgroundColor: `${colors.paper}54`, borderColor: `${colors.card}66` }]}>
                <ImageBackground
                  source={require('../../assets/scrapbook/profile-header.png')}
                  style={styles.infoGroupBackground}
                  imageStyle={styles.infoGroupBackgroundImage}
                >
                  <View
                    style={[
                      styles.infoGroupWash,
                      {
                        backgroundColor: `${colors.paper}D9`,
                        borderColor: `${colors.card}66`,
                      },
                    ]}
                  >
                    <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
                      Languages
                    </Text>
                    <Text style={[styles.cardValue, { color: colors.textPrimary }]}>
                      {languagesText}
                    </Text>
                  </View>
                </ImageBackground>

                <ImageBackground
                  source={require('../../assets/scrapbook/profile-header.png')}
                  style={styles.infoGroupBackground}
                  imageStyle={styles.infoGroupBackgroundImage}
                >
                  <View
                    style={[
                      styles.infoGroupWash,
                      {
                        backgroundColor: `${colors.paper}D9`,
                        borderColor: `${colors.card}66`,
                      },
                    ]}
                  >
                    <View style={styles.preferenceRow}>
                      <View style={[styles.preferenceColumn, { backgroundColor: `${colors.card}D8` }]}>
                        <Text style={[styles.preferenceLabel, { color: colors.textSecondary }]}>
                          Travel Mode
                        </Text>
                        <Text style={[styles.preferenceValue, { color: colors.textPrimary }]}>
                          {profile.travel_mode ?? '—'}
                        </Text>
                      </View>
                      <View style={[styles.preferenceColumn, { backgroundColor: `${colors.card}D8` }]}>
                        <Text style={[styles.preferenceLabel, { color: colors.textSecondary }]}>
                          Travel Style
                        </Text>
                        <Text style={[styles.preferenceValue, { color: colors.textPrimary }]}>
                          {profile.travel_style ?? '—'}
                        </Text>
                      </View>
                    </View>
                  </View>
                </ImageBackground>

                <ImageBackground
                  source={require('../../assets/scrapbook/profile-header.png')}
                  style={styles.infoGroupBackground}
                  imageStyle={styles.infoGroupBackgroundImage}
                >
                  <View
                    style={[
                      styles.infoGroupWash,
                      {
                        backgroundColor: `${colors.paper}D9`,
                        borderColor: `${colors.card}66`,
                      },
                    ]}
                  >
                    <ProfileDetailRow
                      label="Next Destination"
                      value={nextDestinationCountry?.name ?? 'Not set'}
                      colors={colors}
                      trailing={
                        nextDestinationCountry ? (
                          <CountryFlag isoCode={nextDestinationCountry.iso2} size={16} />
                        ) : undefined
                      }
                    />
                  </View>
                </ImageBackground>

                <CollapsibleCountrySection
                  title="Countries Traveled"
                  countries={traveledIsoCodes}
                />

                <CollapsibleCountrySection
                  title="Bucket List"
                  countries={bucketIsoCodes}
                />
              </View>
            </ImageBackground>

          </>
        ) : (
          <ScrapbookCard innerStyle={styles.lockedCard}>
            <Ionicons name="lock-closed" size={28} color={colors.textPrimary} />
            <Text style={[styles.lockedEyebrow, { color: colors.textSecondary }]}>
              Friends only
            </Text>
            <Text style={[styles.lockedText, { color: colors.textPrimary }]}>
              Learn more about this traveler by adding them as a friend.
            </Text>
          </ScrapbookCard>
        )}
      </ScrollView>

      <Modal visible={ctaOpen} transparent animationType="slide">
        <Pressable
          style={styles.sheetBackdrop}
          onPress={() => setCtaOpen(false)}
        >
          <ScrapbookCard
            style={styles.sheetShell}
            innerStyle={{
              backgroundColor: colors.card,
              padding: 20,
              borderTopLeftRadius: 24,
              borderTopRightRadius: 24,
            }}
          >
            <Pressable
              android_ripple={{ color: 'rgba(107,79,51,0.08)' }}
              onPress={() => {
                setCtaOpen(false);
                router.push(`/profile/${targetUserId}/friends`);
              }}
              style={[styles.sheetAction, { borderColor: colors.border }]}
            >
              <Text
                style={{
                  fontSize: 16,
                  fontWeight: '600',
                  color: colors.textPrimary,
                }}
              >
                View Friends
              </Text>
            </Pressable>

            <Pressable
              android_ripple={{ color: 'rgba(122,62,52,0.12)' }}
              onPress={() => {
                setCtaOpen(false);
                handleUnfriend();
              }}
              style={[styles.sheetAction, { borderColor: colors.redBorder }]}
            >
              <Text style={{ fontSize: 16, fontWeight: '600', color: colors.redText }}>
                Unfriend
              </Text>
            </Pressable>
          </ScrapbookCard>
        </Pressable>
      </Modal>
    </View>
    </ImageBackground>
    </ScrapbookBackground>
  );
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
  container: { flex: 1, paddingHorizontal: 20 },
  loadingContainer: {
    paddingTop: 18,
  },
  loadingCard: {
    marginTop: 10,
    paddingHorizontal: 20,
    paddingVertical: 22,
  },
  loadingEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  loadingTitle: {
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 8,
  },
  loadingBody: {
    fontSize: 15,
    lineHeight: 22,
  },
  backBtn: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 8,
    marginBottom: 10,
  },
  infoNotebook: {
    marginTop: 8,
    borderRadius: 24,
    overflow: 'hidden',
  },
  infoNotebookImage: {
    resizeMode: 'cover',
  },
  infoNotebookWash: {
    padding: 16,
    borderRadius: 24,
    borderWidth: 1,
    gap: 14,
  },
  infoGroupBackground: {
    width: '100%',
    overflow: 'hidden',
    borderRadius: 24,
  },
  infoGroupBackgroundImage: {
    resizeMode: 'cover',
  },
  infoGroupWash: {
    paddingVertical: 20,
    paddingHorizontal: 20,
    borderRadius: 24,
    borderWidth: 1,
  },
  infoShell: {
    padding: 18,
    marginTop: 8,
  },
  infoSection: {
    gap: 10,
  },
  dividerWrap: {
    paddingVertical: 4,
  },
  softDivider: {
    height: 1,
    opacity: 0.75,
  },
  cardTitle: { fontSize: 18, fontWeight: '800' },
  cardValue: { fontSize: 16, marginTop: 2 },
  preferenceRow: {
    flexDirection: 'row',
    gap: 18,
    marginTop: 2,
  },
  preferenceColumn: {
    flex: 1,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 14,
  },
  preferenceLabel: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.9,
    textTransform: 'uppercase',
  },
  preferenceValue: {
    fontSize: 16,
    fontWeight: '700',
    marginTop: 6,
  },
  lockedCard: {
    padding: 24,
    marginTop: 24,
    alignItems: 'center',
  },
  lockedEyebrow: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
    marginTop: 12,
    marginBottom: 6,
  },
  lockedText: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 22,
    marginTop: 14,
  },
  sheetBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(33,21,13,0.34)',
    justifyContent: 'flex-end',
  },
  sheetShell: {
    marginHorizontal: 12,
  },
  sheetAction: {
    paddingVertical: 14,
    borderWidth: 1,
    borderRadius: 16,
    alignItems: 'center',
    marginBottom: 10,
  },
});

function ProfileDetailRow({
  label,
  value,
  colors,
  trailing,
}: {
  label: string;
  value: string;
  colors: ReturnType<typeof useTheme>;
  trailing?: ReactNode;
}) {
  return (
    <View style={stylesDetail.detailRow}>
      <Text style={[stylesDetail.detailLabel, { color: colors.textSecondary }]}>
        {label}
      </Text>
      <View style={stylesDetail.detailValueWrap}>
        {trailing}
        <Text style={[stylesDetail.detailValue, { color: colors.textPrimary }]}>
          {value}
        </Text>
      </View>
    </View>
  );
}

const stylesDetail = StyleSheet.create({
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 16,
    paddingTop: 4,
  },
  detailLabel: {
    fontSize: 15,
    fontWeight: '600',
    flex: 1,
  },
  detailValueWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    maxWidth: '58%',
  },
  detailValue: {
    fontSize: 15,
    fontWeight: '600',
    textAlign: 'right',
  },
});
