import React, { useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  useColorScheme,
  Animated,
} from 'react-native';
import { Image } from 'expo-image';
import CountryFlag from 'react-native-country-flag';
import { Ionicons } from '@expo/vector-icons';

type Props = {
  name: string;
  handle: string;
  avatarUrl?: string;
  flags?: string[];
};

export default function HeaderCard({
  name,
  handle,
  avatarUrl,
  flags = [],
}: Props) {
  const scheme = useColorScheme();
  const isDark = scheme === 'dark';

  // Subtle fade‑in animation
  const fadeAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 400,
      useNativeDriver: true,
    }).start();
  }, []);

  return (
    <Animated.View style={[styles.wrapper, { opacity: fadeAnim }]}>
      <View style={styles.row}>
        {/* Avatar */}
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
              size={118}
              color={isDark ? '#444' : '#D1D5DB'}
            />
          )}
        </View>

        {/* Text Meta */}
        <View style={styles.meta}>
          <Text
            style={[
              styles.name,
              isDark ? styles.nameDark : styles.nameLight,
            ]}
          >
            {name}
          </Text>

          {!!handle && (
            <Text
              style={[
                styles.handle,
                isDark ? styles.handleDark : styles.handleLight,
              ]}
            >
              {handle}
            </Text>
          )}

          {flags.length > 0 && (
            <View style={styles.flagsRow}>
              {flags.map((iso) => (
                <CountryFlag
                  key={iso}
                  isoCode={iso}
                  size={20}
                  style={{ marginRight: 8 }}
                />
              ))}
            </View>
          )}
        </View>
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    marginBottom: 32,
  },

  row: {
    flexDirection: 'row',
    alignItems: 'center',
  },

  avatarContainer: {
    marginRight: 20,
  },

  avatar: {
    width: 118,
    height: 118,
    borderRadius: 59,
  },

  avatarFallback: {
    width: 118,
    height: 118,
    borderRadius: 59,
  },

  avatarFallbackDark: {
    backgroundColor: '#2A2A2A',
  },

  avatarFallbackLight: {
    backgroundColor: '#E5E7EB',
  },

  meta: {
    flex: 1,
  },

  name: {
    fontSize: 28,
    fontWeight: '700',
    letterSpacing: -0.3,
  },

  nameDark: {
    color: '#FFFFFF',
  },

  nameLight: {
    color: '#111827',
  },

  handle: {
    marginTop: 6,
    fontSize: 16,
  },

  handleDark: {
    color: '#A1A1AA',
  },

  handleLight: {
    color: '#6B7280',
  },

  flagsRow: {
    marginTop: 10,
    flexDirection: 'row',
  },
});