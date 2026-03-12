import React, { useEffect, useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  View,
  Text,
  Pressable,
  RefreshControl,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useAuth } from '../../context/AuthContext';
import { useCountries } from '../../hooks/useCountries';
import CountryFlag from 'react-native-country-flag';

import HeaderCard from '../../components/profile/HeaderCard';
import InfoCard from '../../components/profile/InfoCard';
import DisclosureRow from '../../components/profile/DisclosureRow';
import CollapsibleCountrySection from '../../components/profile/CollapsibleCountrySection';
import { useNavigation } from '@react-navigation/native';
import { useTheme } from '../../hooks/useTheme';

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
  } = useAuth();
  const { countries } = useCountries();
  const colors = useTheme();

  const user = session?.user ?? null;

  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = async () => {
    setRefreshing(true);

    try {
      // Small delay to allow auth/profile context to re-sync if updated elsewhere
      await new Promise(resolve => setTimeout(resolve, 500));
    } catch (err) {
      console.error('Profile refresh error:', err);
    }

    setRefreshing(false);
  };

  if (!user) {
    return (
      <View
        style={{
          flex: 1,
          paddingHorizontal: 20,
          paddingTop: 60,
          paddingBottom: 120,
          justifyContent: 'center',
          backgroundColor: colors.background,
        }}
      >
        <Text
          style={{
            fontSize: 34,
            fontWeight: '700',
            color: colors.textPrimary,
          }}
        >
          Login to customize your profile
        </Text>

        <Text
          style={{
            marginTop: 16,
            fontSize: 16,
            color: colors.textMuted,
            lineHeight: 22,
            maxWidth: 320,
          }}
        >
          Sign in to set your languages, travel style, and destinations.
        </Text>

        <Pressable
          onPress={() => router.push('/login')}
          style={{ marginTop: 24 }}
        >
          <Text
            style={{
              fontSize: 18,
              fontWeight: '600',
              color: '#3B82F6',
            }}
          >
            Go to Login →
          </Text>
        </Pressable>
      </View>
    );
  }

  const languages =
    Array.isArray(profile?.languages) && profile.languages.length
      ? profile.languages
          .map((l: any) => (typeof l === 'string' ? l : l?.name))
          .filter(Boolean)
          .join(' · ')
      : '—';

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

  const displayName =
    profile?.full_name ??
    profile?.username ??
    'Your Profile';

  return (
    <ScrollView
      style={{ backgroundColor: colors.background }}
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
        <Text style={[styles.title, { color: colors.textPrimary }]}>
          Profile
        </Text>

        <Pressable
          onPress={() => router.push('/profile-settings')}
          style={styles.settingsIcon}
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
      />

      <View style={styles.section}>
        <InfoCard title="Languages" value={languages} />

        <InfoCard
          title="Travel Mode"
          value={travelMode}
        />

        <InfoCard
          title="Travel Style"
          value={travelStyle}
        />

        <InfoCard
          title="Next Destination"
          value={
            nextDestinationCountry ? (
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Text
                  style={{
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: '600',
                  }}
                >
                  {nextDestinationCountry.name}
                </Text>
                <CountryFlag
                  isoCode={nextDestinationCountry.iso2}
                  size={18}
                  style={{ marginLeft: 8 }}
                />
              </View>
            ) : '—'
          }
        />

        <CollapsibleCountrySection
          title="Countries Traveled"
          countries={visitedIsoCodes}
        />

        <CollapsibleCountrySection
          title="Bucket List"
          countries={bucketIsoCodes}
        />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 22,
    paddingTop: 60,
  },

  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 14,
    marginBottom: 20,
  },

  settingsIcon: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },

  title: {
    fontSize: 30,
    fontWeight: '700',
    letterSpacing: -0.5,
  },

  subtitle: {
    marginTop: 12,
    fontSize: 15,
    textAlign: 'center',
    paddingHorizontal: 24,
  },

  loginButton: {
    marginTop: 24,
  },

  loginButtonText: {
    fontSize: 17,
    fontWeight: '600',
    color: '#3B82F6',
  },

  section: {
    marginTop: 18,
    gap: 18,
  },
});