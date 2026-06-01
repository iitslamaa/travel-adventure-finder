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
import ProfileBadgeShowcase from './ProfileBadgeShowcase';

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
  visitedCountryCodes?: string[];
  friendCount?: number | null;
  ctaLabel?: string | null;
  ctaIcon?: keyof typeof Ionicons.glyphMap;
  ctaFilled?: boolean;
  onPressCta?: (() => void) | null;
  onOpenCountry?: (code: string) => void;
};

export default function HeaderCard({
  name,
  handle,
  avatarUrl,
  flags = [],
  visitedCountryCodes = [],
  ctaLabel,
  ctaIcon = 'person-add-outline',
  ctaFilled = false,
  onPressCta,
  onOpenCountry,
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
  }, [fadeAnim]);

  const visibleFlags = flags.slice(0, 3);
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
                    <View style={[styles.avatarFallback, { backgroundColor: colors.paperAlt, borderColor: `${colors.card}CC` }]}>
                      <Ionicons
                        name="person-circle"
                        size={96}
                        color={colors.textPrimary}
                      />
                    </View>
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

                {!!handle && !showIdentityCta && (
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
                      numberOfLines={1}
                      ellipsizeMode="tail"
                      adjustsFontSizeToFit
                      minimumFontScale={0.8}
                    >
                      {ctaLabel}
                    </Text>
                  </Pressable>
                ) : null}

                {visibleFlags.length > 0 && (
                  <View style={styles.flagsRow}>
                    {visibleFlags.map(iso => (
                      <Pressable
                        key={iso}
                        onPress={() => onOpenCountry?.(iso)}
                        style={styles.headerFlagButton}
                      >
                        <CountryFlag
                          isoCode={iso}
                          size={20}
                        />
                      </Pressable>
                    ))}
                    {flags.length > visibleFlags.length ? (
                      <Text style={[styles.moreCount, { color: colors.textPrimary }]}>+{flags.length - visibleFlags.length}</Text>
                    ) : null}
                  </View>
                )}
              </View>

              <View style={styles.badgesColumn}>
                <ProfileBadgeShowcase visitedCountryCodes={visitedCountryCodes} />
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
    alignItems: 'flex-start',
    minHeight: 198,
  },
  identityColumn: {
    width: 116,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  badgesColumn: {
    flex: 1,
    justifyContent: 'center',
  },
  avatarContainer: {
    marginBottom: 10,
  },
  avatar: {
    width: 104,
    height: 104,
    borderRadius: 52,
  },
  avatarFallback: {
    width: 104,
    height: 104,
    borderRadius: 52,
    borderWidth: 3,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    shadowOpacity: 0.18,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 3 },
    elevation: 3,
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
    paddingHorizontal: 18,
    paddingVertical: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    alignSelf: 'stretch',
    maxWidth: 116,
  },
  ctaButtonText: {
    fontSize: 13,
    fontWeight: '700',
    flexShrink: 1,
    textAlign: 'center',
  },
  flagsRow: {
    marginTop: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    flexWrap: 'wrap',
  },
  headerFlagButton: {
    marginRight: 8,
    paddingVertical: 2,
  },
  moreCount: {
    fontSize: 12,
    fontWeight: '700',
  },
});
