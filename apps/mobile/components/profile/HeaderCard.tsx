import React, { useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Animated,
  ImageBackground,
  Pressable,
} from 'react-native';
import { Image } from 'expo-image';
import CountryFlag from 'react-native-country-flag';
import { Ionicons } from '@expo/vector-icons';
import ScrapbookCard from '../theme/ScrapbookCard';
import { useTheme } from '../../hooks/useTheme';

type Props = {
  name: string;
  handle: string;
  avatarUrl?: string;
  flags?: string[];
  currentCountry?: string | null;
  currentCountryLabel?: string | null;
  nextDestination?: string | null;
  nextDestinationLabel?: string | null;
  favoriteCountries?: string[];
  friendCount?: number | null;
  ctaLabel?: string | null;
  ctaIcon?: keyof typeof Ionicons.glyphMap;
  ctaFilled?: boolean;
  onPressCta?: (() => void) | null;
};

export default function HeaderCard({
  name,
  handle,
  avatarUrl,
  flags = [],
  currentCountry,
  currentCountryLabel,
  nextDestination,
  nextDestinationLabel,
  favoriteCountries = [],
  friendCount,
  ctaLabel,
  ctaIcon = 'person-add-outline',
  ctaFilled = false,
  onPressCta,
}: Props) {
  const colors = useTheme();

  // Subtle fade‑in animation
  const fadeAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 400,
      useNativeDriver: true,
    }).start();
  }, []);

  const visibleFlags = flags.slice(0, 3);
  const visibleFavorites = favoriteCountries.slice(0, 4);
  const showIdentityCta = !!ctaLabel && !!onPressCta;

  return (
    <Animated.View style={[styles.wrapper, { opacity: fadeAnim }]}>
      <ScrapbookCard style={styles.cardStack} innerStyle={styles.card}>
        <ImageBackground
          source={require('../../assets/scrapbook/profile-header.png')}
          style={styles.background}
          imageStyle={styles.backgroundImage}
        >
          <View style={[styles.backgroundWash, { backgroundColor: `${colors.paper}D9` }]}>
            <View style={styles.row}>
              <View style={styles.identityColumn}>
                <View style={styles.avatarContainer}>
                  {avatarUrl ? (
                    <Image
                      source={avatarUrl}
                      style={styles.avatar}
                      contentFit="cover"
                      cachePolicy="memory-disk"
                    />
                  ) : (
                    <Ionicons
                      name="person-circle"
                      size={104}
                      color={colors.textMuted}
                    />
                  )}
                </View>

                <Text
                  style={[
                    styles.name,
                    { color: colors.textPrimary },
                  ]}
                >
                  {name}
                </Text>

                {!!handle && (
                  <Text
                    style={[
                      styles.handle,
                      { color: colors.textSecondary },
                    ]}
                  >
                    {handle}
                  </Text>
                )}

                {showIdentityCta ? (
                  <Pressable
                    onPress={onPressCta ?? undefined}
                    style={[
                      styles.ctaButton,
                      {
                        backgroundColor: ctaFilled ? colors.primary : colors.paperAlt,
                        borderColor: ctaFilled ? colors.primary : colors.border,
                      },
                    ]}
                  >
                    <Ionicons
                      name={ctaIcon}
                      size={14}
                      color={ctaFilled ? colors.primaryText : colors.textPrimary}
                    />
                    <Text
                      style={[
                        styles.ctaButtonText,
                        { color: ctaFilled ? colors.primaryText : colors.textPrimary },
                      ]}
                    >
                      {ctaLabel}
                    </Text>
                  </Pressable>
                ) : null}

                {typeof friendCount === 'number' && friendCount >= 0 && !showIdentityCta ? (
                  <View style={[styles.friendPill, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}>
                    <Ionicons name="people-outline" size={14} color={colors.textPrimary} />
                    <Text style={[styles.friendPillText, { color: colors.textPrimary }]}>
                      {friendCount} {friendCount === 1 ? 'friend' : 'friends'}
                    </Text>
                  </View>
                ) : null}

                {visibleFlags.length > 0 && (
                  <View style={styles.flagsRow}>
                    {visibleFlags.map(iso => (
                      <CountryFlag
                        key={iso}
                        isoCode={iso}
                        size={20}
                        style={{ marginRight: 8 }}
                      />
                    ))}
                    {flags.length > visibleFlags.length ? (
                      <Text style={[styles.moreCount, { color: colors.textPrimary }]}>+{flags.length - visibleFlags.length}</Text>
                    ) : null}
                  </View>
                )}
              </View>

              <View style={styles.detailsColumn}>
                <View style={styles.detailBlock}>
                  <Text style={[styles.detailLabel, { color: colors.textPrimary }]}>Current Country</Text>
                  {currentCountry ? (
                    <View style={styles.flagLine}>
                      <CountryFlag isoCode={currentCountry} size={18} style={styles.inlineFlag} />
                      <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                        {currentCountryLabel ?? currentCountry}
                      </Text>
                    </View>
                  ) : (
                    <Text style={[styles.detailFallback, { color: colors.textSecondary }]}>Not set</Text>
                  )}
                </View>

                <View style={styles.detailBlock}>
                  <Text style={[styles.detailLabel, { color: colors.textPrimary }]}>Next Destination</Text>
                  {nextDestination ? (
                    <View style={styles.flagLine}>
                      <CountryFlag isoCode={nextDestination} size={18} style={styles.inlineFlag} />
                      <Text style={[styles.detailValue, { color: colors.textPrimary }]}>
                        {nextDestinationLabel ?? nextDestination}
                      </Text>
                    </View>
                  ) : (
                    <Text style={[styles.detailFallback, { color: colors.textSecondary }]}>Not set</Text>
                  )}
                </View>

                <View style={styles.detailBlock}>
                  <Text style={[styles.detailLabel, { color: colors.textPrimary }]}>Favorite Trips</Text>
                  {visibleFavorites.length ? (
                    <View style={styles.favoriteFlagsRow}>
                      {visibleFavorites.map(iso => (
                        <CountryFlag
                          key={iso}
                          isoCode={iso}
                          size={18}
                          style={styles.inlineFlag}
                        />
                      ))}
                      {favoriteCountries.length > visibleFavorites.length ? (
                        <Text style={[styles.moreCount, { color: colors.textPrimary }]}>
                          +{favoriteCountries.length - visibleFavorites.length}
                        </Text>
                      ) : null}
                    </View>
                  ) : (
                    <Text style={[styles.detailFallback, { color: colors.textSecondary }]}>Not set</Text>
                  )}
                </View>
              </View>
            </View>
          </View>
        </ImageBackground>
      </ScrapbookCard>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    marginBottom: 32,
  },
  cardStack: {
    marginHorizontal: 2,
  },
  card: {
    overflow: 'hidden',
    padding: 0,
  },
  background: {
    width: '100%',
  },
  backgroundImage: {
    resizeMode: 'cover',
  },
  backgroundWash: {
    paddingHorizontal: 18,
    paddingVertical: 18,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    minHeight: 198,
  },
  identityColumn: {
    width: 128,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 22,
  },
  detailsColumn: {
    flex: 1,
    justifyContent: 'center',
    gap: 20,
  },
  detailBlock: {
    gap: 5,
  },
  detailLabel: {
    fontSize: 16,
    fontWeight: '600',
  },
  detailValue: {
    fontSize: 15,
    fontWeight: '600',
  },
  detailFallback: {
    fontSize: 14,
  },
  flagLine: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  favoriteFlagsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
  },
  inlineFlag: {
    marginRight: 8,
  },
  avatarContainer: {
    marginBottom: 10,
  },
  avatar: {
    width: 104,
    height: 104,
    borderRadius: 52,
  },
  name: {
    fontSize: 24,
    fontWeight: '700',
    letterSpacing: -0.3,
    textAlign: 'center',
  },
  handle: {
    marginTop: 4,
    fontSize: 15,
    textAlign: 'center',
  },
  ctaButton: {
    marginTop: 10,
    minHeight: 38,
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 9,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
  },
  ctaButtonText: {
    fontSize: 13,
    fontWeight: '700',
  },
  friendPill: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 7,
    marginTop: 10,
  },
  friendPillText: {
    marginLeft: 6,
    fontSize: 13,
    fontWeight: '700',
  },
  flagsRow: {
    marginTop: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    flexWrap: 'wrap',
  },
  moreCount: {
    fontSize: 12,
    fontWeight: '700',
  },
});
