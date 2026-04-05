import React, { useEffect, useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  View,
  Text,
  Pressable,
  RefreshControl,
  ImageBackground,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useAuth } from '../../context/AuthContext';
import { useCountries } from '../../hooks/useCountries';
import CountryFlag from 'react-native-country-flag';

import HeaderCard from '../../components/profile/HeaderCard';
import CollapsibleCountrySection from '../../components/profile/CollapsibleCountrySection';
import { useNavigation } from '@react-navigation/native';
import { useTheme } from '../../hooks/useTheme';
import { formatLanguageList } from '../../utils/language';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import TitleBanner from '../../components/theme/TitleBanner';

export default function ProfileScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const navigation = useNavigation();

  useEffect(() => {
    navigation.setOptions({
      title: 'Profile',
    });
  }, [navigation]);

  const {
    session,
    profile,
    exitGuest,
    bucketIsoCodes,
    visitedIsoCodes,
    refreshProfile,
  } = useAuth();
  const { countries } = useCountries();
  const colors = useTheme();

  const user = session?.user ?? null;

  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = async () => {
    setRefreshing(true);

    try {
      await refreshProfile();
    } catch (err) {
      console.error('Profile refresh error:', err);
    }

    setRefreshing(false);
  };

  if (!user) {
    return (
      <ScrapbookBackground>
        <View style={styles.guestContainer}>
          <View style={styles.guestTitleWrap}>
            <TitleBanner title="Profile" />
          </View>

          <View style={styles.guestCenter}>
            <ScrapbookCard innerStyle={styles.guestFeatureCard}>
              <View style={styles.guestFeatureHeader}>
                <View
                  style={[
                    styles.guestFeatureIcon,
                    { backgroundColor: colors.paperAlt, borderColor: colors.border },
                  ]}
                >
                  <Ionicons
                    name="person-circle-outline"
                    size={28}
                    color={colors.textPrimary}
                  />
                </View>
              </View>

              <Text style={[styles.guestFeatureTitle, { color: colors.textPrimary }]}>
                Create an account to unlock your travel profile
              </Text>

              <Text style={[styles.guestFeatureBody, { color: colors.textSecondary }]}>
                Save your languages, travel style, favorite countries, and personalized profile details.
              </Text>
            </ScrapbookCard>

            <Pressable
              onPress={() => {
                exitGuest();
                router.push('/login');
              }}
              style={[
                styles.guestCTA,
                { backgroundColor: colors.paperAlt, borderColor: colors.cardBorderStrong },
              ]}
            >
              <Ionicons
                name="paper-plane"
                size={16}
                color={colors.textPrimary}
              />
              <Text style={[styles.guestCTAText, { color: colors.textPrimary }]}>
                Create Account or Log In
              </Text>
            </Pressable>
          </View>
        </View>
      </ScrapbookBackground>
    );
  }

  const languages = formatLanguageList(profile?.languages);
  const languageItems = languages
    ? languages
        .split(',')
        .map(item => item.trim())
        .filter(Boolean)
    : [];

  const travelMode =
    Array.isArray(profile?.travel_mode) && profile.travel_mode.length
      ? profile.travel_mode[0].charAt(0).toUpperCase() +
        profile.travel_mode[0].slice(1)
      : '—';

  const travelStyle =
    Array.isArray(profile?.travel_style) && profile.travel_style.length
      ? profile.travel_style[0].charAt(0).toUpperCase() +
        profile.travel_style[0].slice(1)
      : '—';

  const nextDestinationIso =
    typeof profile?.next_destination === 'string'
      ? profile.next_destination
      : null;

  const nextDestinationCountry = countries?.find(
    c => c.iso2 === nextDestinationIso
  );
  const currentCountryIso =
    typeof profile?.current_country === 'string'
      ? profile.current_country.toUpperCase()
      : null;
  const favoriteCountryCodes = Array.isArray(profile?.favorite_countries)
    ? profile.favorite_countries
        .map(code => String(code).toUpperCase())
        .filter(Boolean)
    : [];
  const currentCountry = countries?.find(c => c.iso2 === currentCountryIso);
  const favoriteCountries = favoriteCountryCodes
    .map(code => countries?.find(c => c.iso2 === code))
    .filter(Boolean);

  const fallbackFullName = [profile?.first_name, profile?.last_name]
    .filter(Boolean)
    .join(' ')
    .trim();
  const displayName =
    profile?.full_name ??
    (fallbackFullName || profile?.username) ??
    'Your Profile';

  const detailText = (value?: string | null) => value || 'Not set';

  return (
    <ScrapbookBackground>
      <ImageBackground
        source={require('../../assets/scrapbook/travel4.png')}
        style={styles.pageBackground}
        imageStyle={styles.pageBackgroundImage}
      >
      <View style={styles.pageWash} />
      <ScrollView
        style={{ backgroundColor: 'transparent' }}
        contentContainerStyle={[
          styles.container,
          { paddingBottom: insets.bottom + 80 },
        ]}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={handleRefresh}
            tintColor={colors.textPrimary}
          />
        }
      >
        <View style={styles.topRow}>
          <View style={styles.titleWrap}>
            <TitleBanner title="Profile" />
          </View>

          <Pressable
            onPress={() => router.push('/profile-settings')}
            style={[
              styles.settingsIcon,
              { backgroundColor: colors.card, borderColor: colors.border },
            ]}
          >
            <Ionicons
              name="settings-outline"
              size={20}
              color={colors.textPrimary}
            />
          </Pressable>
        </View>

        <HeaderCard
          name={displayName}
          handle={profile?.username ? `@${profile.username}` : ''}
          avatarUrl={profile?.avatar_url ?? undefined}
          flags={profile?.lived_countries ?? []}
          currentCountry={currentCountryIso}
          currentCountryLabel={currentCountry?.name ?? null}
          nextDestination={nextDestinationIso}
          nextDestinationLabel={nextDestinationCountry?.name ?? null}
          favoriteCountries={favoriteCountryCodes}
          friendCount={profile?.friend_count ?? 0}
        />

        <View style={styles.section}>
          <ImageBackground
            source={require('../../assets/scrapbook/profile-info.png')}
            style={styles.infoSectionBackground}
            imageStyle={styles.infoSectionBackgroundImage}
          >
            <View style={[styles.infoSectionWash, { backgroundColor: `${colors.paper}54`, borderColor: `${colors.card}66` }]}>

              <ImageBackground
                source={require('../../assets/scrapbook/profile-header.png')}
                style={styles.groupBackground}
                imageStyle={styles.groupBackgroundImage}
              >
                <View
                  style={[
                    styles.groupWash,
                    {
                      backgroundColor: `${colors.paper}D9`,
                      borderColor: `${colors.card}66`,
                    },
                  ]}
                >
                  <Text style={[styles.groupSectionTitle, { color: colors.textPrimary }]}>
                    Languages
                  </Text>
                  {languageItems.length ? (
                    <View style={styles.languageList}>
                      {languageItems.map((item, index) => (
                        <React.Fragment key={item}>
                          <ProfileDetailRow
                            label={item.split('—')[0]?.trim() || item}
                            value={item.split('—')[1]?.trim() || 'Added'}
                            colors={colors}
                          />
                          {index < languageItems.length - 1 ? (
                            <InlineDivider color={colors.border} />
                          ) : null}
                        </React.Fragment>
                      ))}
                    </View>
                  ) : (
                    <Text style={[styles.languageValue, { color: colors.textPrimary }]}>
                      Not set
                    </Text>
                  )}
                </View>
              </ImageBackground>

              <ImageBackground
                source={require('../../assets/scrapbook/profile-header.png')}
                style={styles.groupBackground}
                imageStyle={styles.groupBackgroundImage}
              >
                <View
                  style={[
                    styles.groupWash,
                    {
                      backgroundColor: `${colors.paper}D9`,
                      borderColor: `${colors.card}66`,
                    },
                  ]}
                >
                  <View style={styles.preferenceRow}>
                    <View style={styles.preferenceColumn}>
                      <Text style={[styles.preferenceLabel, { color: colors.textSecondary }]}>
                        Travel Mode
                      </Text>
                      <Text style={[styles.preferenceValue, { color: colors.textPrimary }]}>
                        {travelMode}
                      </Text>
                    </View>

                    <View style={styles.preferenceColumn}>
                      <Text style={[styles.preferenceLabel, { color: colors.textSecondary }]}>
                        Travel Style
                      </Text>
                      <Text style={[styles.preferenceValue, { color: colors.textPrimary }]}>
                        {travelStyle}
                      </Text>
                    </View>
                  </View>
                </View>
              </ImageBackground>

              <ImageBackground
                source={require('../../assets/scrapbook/profile-header.png')}
                style={styles.groupBackground}
                imageStyle={styles.groupBackgroundImage}
              >
                <View
                  style={[
                    styles.groupWash,
                    {
                      backgroundColor: `${colors.paper}D9`,
                      borderColor: `${colors.card}66`,
                    },
                  ]}
                >
                  <ProfileDetailRow
                    label="Current Country"
                    value={detailText(currentCountry?.name)}
                    trailing={
                      currentCountry ? (
                        <CountryFlag isoCode={currentCountry.iso2} size={16} />
                      ) : undefined
                    }
                    colors={colors}
                  />
                  <InlineDivider color={colors.border} />
                  <ProfileDetailRow
                    label="Next Destination"
                    value={detailText(nextDestinationCountry?.name)}
                    trailing={
                      nextDestinationCountry ? (
                        <CountryFlag isoCode={nextDestinationCountry.iso2} size={16} />
                      ) : undefined
                    }
                    colors={colors}
                  />
                  <InlineDivider color={colors.border} />
                  <ProfileDetailRow
                    label="Favorite Trips"
                    value={
                      favoriteCountries.length
                        ? favoriteCountries.map(country => country!.iso2).join(' ')
                        : 'Not set'
                    }
                    colors={colors}
                  />
                </View>
              </ImageBackground>

              <CollapsibleCountrySection
                title="Countries Traveled"
                countries={visitedIsoCodes}
              />

              <CollapsibleCountrySection
                title="Bucket List"
                countries={bucketIsoCodes}
              />
            </View>
          </ImageBackground>
        </View>
      </ScrollView>
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
  container: {
    paddingHorizontal: 22,
    paddingTop: 58,
  },

  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginTop: 6,
    marginBottom: 12,
  },
  titleWrap: {
    flex: 1,
    marginLeft: -20,
    marginTop: -8,
  },

  settingsIcon: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },

  subtitle: {
    marginTop: 12,
    fontSize: 15,
    textAlign: 'center',
    paddingHorizontal: 24,
  },

  loginButton: {
    marginTop: 24,
    alignSelf: 'flex-start',
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },

  loginButtonText: {
    fontSize: 17,
    fontWeight: '600',
  },
  guestContainer: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 46,
    paddingBottom: 120,
  },
  guestTitleWrap: {
    marginHorizontal: -20,
  },
  guestCenter: {
    flex: 1,
    justifyContent: 'center',
    gap: 24,
  },
  guestFeatureCard: {
    paddingHorizontal: 22,
    paddingVertical: 24,
    minHeight: 168,
  },
  guestFeatureHeader: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginBottom: 12,
  },
  guestFeatureIcon: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  guestFeatureTitle: {
    fontSize: 28,
    lineHeight: 34,
    fontWeight: '700',
  },
  guestFeatureBody: {
    marginTop: 14,
    fontSize: 16,
    lineHeight: 24,
  },
  guestCTA: {
    minHeight: 62,
    borderRadius: 24,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    paddingHorizontal: 18,
    shadowColor: '#000000',
    shadowOpacity: 0.14,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 6,
  },
  guestCTAText: {
    fontSize: 18,
    fontWeight: '700',
  },

  section: {
    marginTop: 14,
    gap: 18,
  },
  infoSectionBackground: {
    width: '100%',
    overflow: 'hidden',
    borderRadius: 24,
  },
  infoSectionBackgroundImage: {
    resizeMode: 'cover',
  },
  infoSectionWash: {
    paddingTop: 20,
    paddingBottom: 22,
    paddingHorizontal: 16,
    borderWidth: 1,
    borderRadius: 24,
    gap: 14,
  },
  groupBackground: {
    width: '100%',
    overflow: 'hidden',
    borderRadius: 24,
  },
  groupBackgroundImage: {
    resizeMode: 'cover',
  },
  groupWash: {
    paddingVertical: 20,
    paddingHorizontal: 20,
    borderRadius: 24,
    borderWidth: 1,
  },
  groupSectionTitle: {
    fontSize: 18,
    fontWeight: '800',
    marginBottom: 14,
  },
  languageList: {
    gap: 0,
  },
  languageValue: {
    fontSize: 16,
    lineHeight: 22,
    fontWeight: '600',
  },
  preferenceRow: {
    flexDirection: 'row',
    gap: 18,
    marginTop: 2,
  },
  preferenceColumn: {
    flex: 1,
    gap: 6,
    backgroundColor: 'rgba(255,250,244,0.62)',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 12,
  },
  preferenceLabel: {
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.3,
  },
  preferenceValue: {
    fontSize: 16,
    fontWeight: '700',
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 16,
    paddingVertical: 14,
  },
  detailLabel: {
    fontSize: 15,
    fontWeight: '600',
    flex: 1,
  },
  detailValueWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    maxWidth: '56%',
  },
  detailValue: {
    fontSize: 15,
    textAlign: 'right',
  },
  detailTrailing: {
    marginLeft: 8,
  },
  inlineDivider: {
    height: StyleSheet.hairlineWidth,
  },
});

function ProfileDetailRow({
  label,
  value,
  trailing,
  colors,
}: {
  label: string;
  value: string;
  trailing?: React.ReactNode;
  colors: ReturnType<typeof useTheme>;
}) {
  return (
    <View style={styles.detailRow}>
      <Text style={[styles.detailLabel, { color: colors.textPrimary }]}>{label}</Text>
      <View style={styles.detailValueWrap}>
        <Text style={[styles.detailValue, { color: colors.textSecondary }]}>{value}</Text>
        {trailing ? <View style={styles.detailTrailing}>{trailing}</View> : null}
      </View>
    </View>
  );
}

function InlineDivider({ color }: { color: string }) {
  return <View style={[styles.inlineDivider, { backgroundColor: color }]} />;
}
