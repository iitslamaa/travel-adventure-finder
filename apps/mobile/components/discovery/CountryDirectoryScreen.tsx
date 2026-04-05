import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../../context/AuthContext';
import { useCountries } from '../../hooks/useCountries';
import { useTheme } from '../../hooks/useTheme';
import { normalizeForSearch } from '../../utils/search';
import CountryRow from '../CountryRow';
import ScrapbookBackground from '../theme/ScrapbookBackground';
import ScrapbookCard from '../theme/ScrapbookCard';
import TitleBanner from '../theme/TitleBanner';

export default function CountryDirectoryScreen() {
  const { countries, loading } = useCountries();
  const insets = useSafeAreaInsets();
  const colors = useTheme();
  const [sortBy, setSortBy] = useState<'name' | 'score'>('score');
  const [ascending, setAscending] = useState(false);
  const [search, setSearch] = useState('');
  const { toggleBucket, toggleVisited, isBucketed, isVisited } = useAuth();

  const filteredCountries = useMemo(() => {
    let data = [...countries];
    const normalizedSearch = normalizeForSearch(search);

    if (normalizedSearch) {
      data = data.filter(c => {
        const normalizedName = normalizeForSearch(c.name);
        const normalizedIso2 = normalizeForSearch(c.iso2);
        return (
          normalizedName.includes(normalizedSearch) ||
          normalizedIso2.includes(normalizedSearch)
        );
      });
    }

    data.sort((a, b) => {
      if (sortBy === 'name') {
        const result = a.name.localeCompare(b.name);
        return ascending ? result : -result;
      }

      const aScore = a.scoreTotal ?? 0;
      const bScore = b.scoreTotal ?? 0;
      const result = aScore - bScore;
      return ascending ? result : -result;
    });

    return data;
  }, [ascending, countries, search, sortBy]);

  const toggleSort = (type: 'name' | 'score') => {
    if (sortBy === type) {
      setAscending(prev => !prev);
      return;
    }

    setSortBy(type);
    setAscending(false);
  };

  return (
    <ScrapbookBackground>
      <View style={styles.screen}>
      {loading ? (
        <View style={[styles.loadingWrap, { paddingTop: insets.top + 16 }]}>
          <TitleBanner title="Countries" />
          <ScrapbookCard
            style={styles.loadingCardShell}
            innerStyle={styles.loadingCard}
          >
            <ActivityIndicator size="large" color={colors.primary} />
            <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
              Loading the country directory...
            </Text>
          </ScrapbookCard>
        </View>
      ) : (
        <View style={[styles.contentWrap, { paddingTop: insets.top + 8 }]}>
          <TitleBanner title="Countries" />

          <View
            style={[
              styles.directoryShell,
              {
                backgroundColor: colors.card,
                borderColor: colors.border,
              },
            ]}
          >
            <FlatList
              contentContainerStyle={styles.listContent}
              data={filteredCountries}
              extraData={`${sortBy}-${ascending}-${search}`}
              keyExtractor={item => item.iso2}
              stickyHeaderIndices={[0]}
              showsVerticalScrollIndicator={false}
              ListHeaderComponent={
                <View
                  style={{
                    paddingTop: 12,
                    paddingBottom: 12,
                    backgroundColor: colors.card,
                  }}
                >
                  <View
                    style={[
                      styles.searchShell,
                      {
                        backgroundColor: colors.segmentBg,
                        borderColor: colors.border,
                      },
                    ]}
                  >
                    <Ionicons name="search" size={18} color={colors.textMuted} />
                    <TextInput
                      placeholder="Search by country or code"
                      placeholderTextColor={colors.textMuted}
                      value={search}
                      onChangeText={setSearch}
                      style={[styles.searchInput, { color: colors.textPrimary }]}
                    />
                    {!!search && (
                      <Pressable
                        onPress={() => setSearch('')}
                        style={styles.clearButton}
                      >
                        <Ionicons name="close-circle" size={18} color={colors.textMuted} />
                      </Pressable>
                    )}
                  </View>

                  <View style={styles.controlsRow}>
                    <View
                      style={[
                        styles.segmented,
                        {
                          backgroundColor: colors.segmentBg,
                        },
                      ]}
                    >
                      <Pressable
                        onPress={() => toggleSort('name')}
                        style={[
                          styles.segmentButton,
                          {
                            backgroundColor:
                              sortBy === 'name' ? colors.segmentActive : 'transparent',
                          },
                        ]}
                      >
                        <Text
                          style={[
                            styles.segmentText,
                            { color: colors.textPrimary },
                          ]}
                        >
                          Name {sortBy === 'name' ? (ascending ? '↓' : '↑') : ''}
                        </Text>
                      </Pressable>

                      <Pressable
                        onPress={() => toggleSort('score')}
                        style={[
                          styles.segmentButton,
                          {
                            backgroundColor:
                              sortBy === 'score' ? colors.segmentActive : 'transparent',
                          },
                        ]}
                      >
                        <Text
                          style={[
                            styles.segmentText,
                            { color: colors.textPrimary },
                          ]}
                        >
                          Score {sortBy === 'score' ? (ascending ? '↓' : '↑') : ''}
                        </Text>
                      </Pressable>
                    </View>
                  </View>
                </View>
              }
              renderItem={({ item }) => (
                <CountryRow
                  country={item}
                  onPress={() =>
                    router.push({
                      pathname: '/country/[iso2]',
                      params: {
                        iso2: item.iso2,
                        name: item.name,
                      },
                    })
                  }
                  isBucketed={isBucketed(item.iso2)}
                  onToggleBucket={() => toggleBucket(item.iso2)}
                  isVisited={isVisited(item.iso2)}
                  onToggleVisited={() => toggleVisited(item.iso2)}
                />
              )}
            />
          </View>
        </View>
      )}
      </View>
    </ScrapbookBackground>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  loadingWrap: {
    paddingHorizontal: 16,
  },
  loadingCardShell: {
    marginTop: 18,
  },
  loadingCard: {
    paddingVertical: 24,
    paddingHorizontal: 20,
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 15,
    textAlign: 'center',
  },
  contentWrap: {
    flex: 1,
    paddingHorizontal: 16,
    paddingBottom: 112,
  },
  directoryShell: {
    flex: 1,
    marginTop: 8,
    borderRadius: 26,
    borderWidth: 1,
    overflow: 'hidden',
  },
  listContent: {
    paddingHorizontal: 12,
    paddingBottom: 28,
  },
  searchShell: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 16,
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 10,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
    marginLeft: 8,
  },
  clearButton: {
    marginLeft: 6,
  },
  controlsRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  segmented: {
    flex: 1,
    borderRadius: 18,
    padding: 4,
    flexDirection: 'row',
  },
  segmentButton: {
    flex: 1,
    paddingVertical: 11,
    alignItems: 'center',
    borderRadius: 14,
  },
  segmentText: {
    fontSize: 14,
    fontWeight: '600',
  },
});
