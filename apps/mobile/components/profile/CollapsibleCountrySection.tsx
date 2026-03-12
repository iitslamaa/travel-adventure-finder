import React, { useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  UIManager,
  Platform,
  useColorScheme,
  FlatList,
} from 'react-native';
import CountryFlag from 'react-native-country-flag';
import { Ionicons } from '@expo/vector-icons';

import { WorldMap } from '../../src/features/map/components/WorldMap';

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
  const scheme = useColorScheme();
  const isDark = scheme === 'dark';

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

  const backgroundColor = isDark ? '#18181B' : '#FFFFFF';
  const borderColor = isDark ? '#27272A' : '#E5E7EB';
  const titleColor = isDark ? '#FFFFFF' : '#111827';
  const mutedColor = isDark ? '#71717A' : '#9CA3AF';

  return (
    <View
      style={[
        styles.container,
        {
          backgroundColor,
          borderColor,
        },
      ]}
    >
      <TouchableOpacity
        activeOpacity={0.85}
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
            color={titleColor}
          />
          <Text style={[styles.title, { color: titleColor }]}>
            {title}
          </Text>
        </View>

        <Text style={[styles.count, { color: mutedColor }]}> 
          {sortedCountries.length}
        </Text>
      </TouchableOpacity>

      {expanded && (
        <View style={styles.content}>
          {sortedCountries.length === 0 ? (
            <Text style={[styles.emptyText, { color: mutedColor }]}> 
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
                    <TouchableOpacity
                      activeOpacity={0.85}
                      onPress={() => setSelectedIso(item)}
                      style={[
                        styles.flagWrapper,
                        isSelected && styles.flagSelected,
                      ]}
                    >
                      <CountryFlag isoCode={item} size={26} />
                    </TouchableOpacity>
                  );
                }}
              />

              <View style={styles.mapContainer}>
                <WorldMap
                  countries={sortedCountries}
                  selectedIso={selectedIso}
                  onSelect={(iso) => setSelectedIso(iso)}
                />
              </View>
            </>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: 18,
    paddingVertical: 16,
    paddingHorizontal: 16,
    borderRadius: 20,
    borderWidth: 1,
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
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 6,
  },
  count: {
    fontSize: 14,
    fontWeight: '500',
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
    padding: 6,
    borderRadius: 12,
  },
  flagSelected: {
    backgroundColor: '#FACC15',
  },
});