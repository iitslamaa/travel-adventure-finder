import {
  View,
  FlatList,
  ActivityIndicator,
  TextInput,
  Pressable,
  Text,
  KeyboardAvoidingView,
  Platform,
  Keyboard,
} from 'react-native';
import { router } from 'expo-router';
import { useState, useMemo } from 'react';
import AuthGate from '../../components/AuthGate';
import { useCountries } from '../../hooks/useCountries';
import CountryRow from '../../components/CountryRow';
import { useAuth } from '../../context/AuthContext';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';

export default function DiscoveryScreen() {
  const { countries, loading } = useCountries();
  const insets = useSafeAreaInsets();

  const colors = useTheme();

  const [sortBy, setSortBy] = useState<'name' | 'score'>('score');
  const [ascending, setAscending] = useState(false);
  const [search, setSearch] = useState('');
  const [searchActive, setSearchActive] = useState(false);

  const { toggleBucket, toggleVisited, isBucketed, isVisited } = useAuth();

  const filteredCountries = useMemo(() => {
    let data = [...countries];

    // Search filter
    if (search) {
      data = data.filter(c =>
        c.name.toLowerCase().includes(search.toLowerCase()) ||
        c.iso2.toLowerCase().includes(search.toLowerCase())
      );
    }

    // Sorting
    data.sort((a, b) => {
      if (sortBy === 'name') {
        const result = a.name.localeCompare(b.name);
        return ascending ? result : -result;
      } else {
        const aScore = a.scoreTotal ?? 0;
        const bScore = b.scoreTotal ?? 0;
        const result = aScore - bScore;
        return ascending ? result : -result;
      }
    });

    return data;
  }, [countries, sortBy, ascending, search]);

  const toggleSort = (type: 'name' | 'score') => {
    if (sortBy === type) {
      setAscending(prev => !prev);
    } else {
      setSortBy(type);
      setAscending(false);
    }
  };

  return (
    <AuthGate>
      <View style={{ flex: 1, backgroundColor: colors.background }}>
        {loading ? (
          <ActivityIndicator
            style={{ marginTop: 40 }}
            size="large"
            color={colors.primary}
          />
        ) : (
          <FlatList
            contentContainerStyle={{
              paddingHorizontal: 16,
              paddingBottom: 140,
            }}
            data={filteredCountries}
            extraData={`${sortBy}-${ascending}-${search}`}
            keyExtractor={item => item.iso2}
            stickyHeaderIndices={[0]}
            ListHeaderComponent={
              <View
                style={{
                  paddingTop: insets.top + 12,
                  paddingBottom: 20,
                  borderBottomWidth: 1,
                  backgroundColor: colors.background,
                  borderBottomColor: colors.border,
                }}
              >
                <View
                  style={{
                    flexDirection: 'row',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    paddingHorizontal: 16,
                  }}
                >
                  {/* Segmented Control */}
                  <View
                    style={{
                      flexDirection: 'row',
                      backgroundColor: colors.segmentBg,
                      borderRadius: 24,
                      flex: 1,
                      padding: 4,
                      marginRight: 12,
                    }}
                  >
                    <Pressable
                      onPress={() => toggleSort('name')}
                      android_ripple={{ color: '#E0E0E0', borderless: false }}
                      hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
                      pressRetentionOffset={{ top: 10, bottom: 10, left: 10, right: 10 }}
                      style={{
                        flex: 1,
                        paddingVertical: 14,
                        alignItems: 'center',
                        borderRadius: 20,
                        backgroundColor:
                          sortBy === 'name' ? colors.segmentActive : 'transparent',
                      }}
                    >
                      <Text
                        style={{
                          fontWeight: sortBy === 'name' ? '600' : '500',
                          color: colors.textPrimary,
                        }}
                      >
                        Name {sortBy === 'name' ? (ascending ? '↓' : '↑') : ''}
                      </Text>
                    </Pressable>

                    <Pressable
                      onPress={() => toggleSort('score')}
                      android_ripple={{ color: '#E0E0E0', borderless: false }}
                      hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
                      pressRetentionOffset={{ top: 10, bottom: 10, left: 10, right: 10 }}
                      style={{
                        flex: 1,
                        paddingVertical: 14,
                        alignItems: 'center',
                        borderRadius: 20,
                        backgroundColor:
                          sortBy === 'score' ? colors.segmentActive : 'transparent',
                      }}
                    >
                      <Text
                        style={{
                          fontWeight: sortBy === 'score' ? '600' : '500',
                          color: colors.textPrimary,
                        }}
                      >
                        Score {sortBy === 'score' ? (ascending ? '↓' : '↑') : ''}
                      </Text>
                    </Pressable>
                  </View>

                  {/* World Map Button */}
                  <Pressable
                    onPress={() => router.push('/score-map')}
                    android_ripple={{ color: '#E5E7EB', borderless: false }}
                    style={{
                      width: 48,
                      height: 48,
                      borderRadius: 24,
                      backgroundColor: colors.segmentBg,
                      borderWidth: 1,
                      borderColor: colors.border,
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <Ionicons
                      name="map-outline"
                      size={20}
                      color={colors.textPrimary}
                    />
                  </Pressable>
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
        )}

        {/* Floating Bottom Search */}
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <View
            style={{
              position: 'absolute',
              bottom: insets.bottom + 16,
              width: '100%',
              maxWidth: 720,
              alignSelf: 'center',
              paddingHorizontal: 16,
            }}
          >
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                backgroundColor: colors.segmentBg,
                borderRadius: 26,
                paddingHorizontal: 18,
                paddingVertical: 14,
                shadowColor: '#000',
                shadowOpacity: 0.15,
                shadowRadius: 14,
                elevation: 8,
              }}
            >
              <TextInput
                placeholder="Search destinations by country or code"
                placeholderTextColor={colors.textMuted}
                value={search}
                onFocus={() => setSearchActive(true)}
                onChangeText={setSearch}
                style={{ flex: 1, color: colors.textPrimary }}
              />

              {searchActive && (
                <Pressable
                  onPress={() => {
                    Keyboard.dismiss();
                    setSearchActive(false);
                  }}
                >
                  <Text style={{ fontSize: 18, color: colors.textPrimary }}>↓</Text>
                </Pressable>
              )}
            </View>
          </View>
        </KeyboardAvoidingView>
      </View>
    </AuthGate>
  );
}