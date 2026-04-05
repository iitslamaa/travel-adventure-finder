import React, { useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  UIManager,
  Platform,
  FlatList,
  ImageBackground,
} from 'react-native';
import CountryFlag from 'react-native-country-flag';
import { Ionicons } from '@expo/vector-icons';

import { WorldMap } from '../../src/features/map/components/WorldMap';
import { useTheme } from '../../hooks/useTheme';
import ScrapbookCard from '../theme/ScrapbookCard';

if (Platform.OS === 'android') {
  UIManager.setLayoutAnimationEnabledExperimental?.(true);
}

type Props = {
  title: string;
  countries: string[];
};

export default function CollapsibleCountrySection({
  title,
  countries = [],
}: Props) {
  const [expanded, setExpanded] = useState(false);
  const [selectedIso, setSelectedIso] = useState<string | null>(null);
  const colors = useTheme();

  const sortedCountries = useMemo(
    () =>
      Array.isArray(countries)
        ? [...countries].filter(Boolean).sort()
        : [],
    [countries]
  );

  const toggle = () => {
    setExpanded((prev) => !prev);
  };

  const selectedCountryName = selectedIso
    ? new Intl.DisplayNames(['en'], { type: 'region' }).of(selectedIso) ?? selectedIso
    : null;

  return (
    <ScrapbookCard innerStyle={styles.container}>
      <ImageBackground
        source={require('../../assets/scrapbook/profile-header.png')}
        style={styles.background}
        imageStyle={styles.backgroundImage}
      >
        <View style={[styles.backgroundWash, { backgroundColor: `${colors.paper}D4` }]}>
          <Pressable
            onPress={toggle}
            style={[
              styles.header,
              expanded && styles.headerExpanded,
            ]}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          >
            <View style={styles.headerLeft}>
              <Ionicons
                name={expanded ? 'chevron-down' : 'chevron-forward'}
                size={18}
                color={colors.textPrimary}
              />
              <Text style={[styles.title, { color: colors.textPrimary }]}>
                {title}
                <Text style={[styles.countInline, { color: colors.scoreGood }]}>
                  {`: ${sortedCountries.length}`}
                </Text>
              </Text>
            </View>
          </Pressable>

          {expanded && (
            <View style={styles.content}>
              {sortedCountries.length === 0 ? (
                <Text style={[styles.emptyText, { color: colors.textMuted }]}>
                  No countries yet
                </Text>
              ) : (
                <>
                  <FlatList
                    data={sortedCountries}
                    horizontal
                    keyExtractor={(item, index) => `${item}-${index}`}
                    showsHorizontalScrollIndicator={false}
                    contentContainerStyle={styles.flagsList}
                    renderItem={({ item }) => {
                      const isSelected = selectedIso === item;

                      return (
                        <Pressable
                          onPress={() => setSelectedIso(item)}
                          style={[
                            styles.flagWrapper,
                            {
                              backgroundColor: colors.paperAlt,
                              borderColor: isSelected ? colors.accentBlue : colors.border,
                            },
                            isSelected && {
                              backgroundColor: `${colors.accentBlue}22`,
                              shadowColor: colors.accentBlue,
                              shadowOpacity: 0.15,
                              shadowRadius: 6,
                              shadowOffset: { width: 0, height: 3 },
                              elevation: 3,
                            },
                          ]}
                        >
                          <CountryFlag isoCode={item} size={30} />
                        </Pressable>
                      );
                    }}
                  />

                  <View style={styles.mapContainer}>
                    <WorldMap
                      countries={sortedCountries}
                      selectedIso={selectedIso}
                      onSelect={(iso) => setSelectedIso(iso)}
                    />
                    {selectedIso && selectedCountryName ? (
                      <View style={styles.selectedCountryPillWrap}>
                        <View
                          style={[
                            styles.selectedCountryPill,
                            { backgroundColor: `${colors.paper}E8`, borderColor: colors.border },
                          ]}
                        >
                          <CountryFlag isoCode={selectedIso} size={16} style={styles.selectedPillFlag} />
                          <Text style={[styles.selectedCountryText, { color: colors.textPrimary }]}>
                            {selectedCountryName}
                          </Text>
                        </View>
                      </View>
                    ) : null}
                  </View>
                </>
              )}
            </View>
          )}
        </View>
      </ImageBackground>
    </ScrapbookCard>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: 18,
    paddingVertical: 0,
    paddingHorizontal: 0,
    overflow: 'hidden',
  },
  background: {
    width: '100%',
  },
  backgroundImage: {
    resizeMode: 'cover',
  },
  backgroundWash: {
    paddingVertical: 16,
    paddingHorizontal: 16,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerExpanded: {
    marginTop: -6,
    marginBottom: 6,
    paddingVertical: 6,
    borderRadius: 12,
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  title: {
    fontSize: 16,
    fontWeight: '700',
  },
  countInline: {
    fontSize: 14,
    fontWeight: '800',
  },
  content: {
    marginTop: 14,
  },
  emptyText: {
    fontSize: 14,
  },
  mapContainer: {
    width: '100%',
    aspectRatio: 1.6,
    minHeight: 200,
    maxHeight: 400,
    marginTop: 16,
    borderRadius: 16,
    overflow: 'hidden',
  },
  flagsList: {
    paddingVertical: 4,
  },
  flagWrapper: {
    marginRight: 12,
    paddingHorizontal: 8,
    paddingVertical: 7,
    borderRadius: 10,
    borderWidth: 2,
  },
  selectedCountryPillWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 12,
    alignItems: 'center',
  },
  selectedCountryPill: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  selectedPillFlag: {
    marginRight: 8,
  },
  selectedCountryText: {
    fontSize: 14,
    fontWeight: '700',
  },
});
