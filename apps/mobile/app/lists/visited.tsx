import { ActivityIndicator, View, Text, StyleSheet, FlatList, Modal, Pressable, ScrollView, TextInput, ImageBackground } from 'react-native';
import { useMemo, useState } from 'react';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import AuthGate from '../../components/AuthGate';
import { useAuth } from '../../context/AuthContext';
import { useCountries } from '../../hooks/useCountries';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../components/theme/ScrapbookCard';
import TitleBanner from '../../components/theme/TitleBanner';
import { useTheme } from '../../hooks/useTheme';

function getScoreTone(score: number) {
  if (score >= 80) return { bg: 'rgba(78, 133, 92, 0.16)', text: '#355E3B' };
  if (score >= 60) return { bg: 'rgba(214, 170, 78, 0.18)', text: '#8A5B20' };
  return { bg: 'rgba(181, 92, 79, 0.16)', text: '#8B3E35' };
}

export default function VisitedListScreen() {
  const colors = useTheme();

  const { visitedIsoCodes, toggleVisited, loading: authLoading } = useAuth();
  const { countries, loading: countriesLoading } = useCountries();
  const [editorVisible, setEditorVisible] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const isLoading = authLoading || countriesLoading;

  const visitedCountries = useMemo(() => {
    return countries
      .filter((country) => visitedIsoCodes.includes(country.iso2))
      .map((country) => ({
        code: country.iso2,
        name: country.name,
        flagEmoji: country.flagEmoji,
        score: country.facts?.scoreTotal,
      }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [countries, visitedIsoCodes]);

  const filteredCountries = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    if (!query) return countries;

    return countries.filter(country =>
      country.name.toLowerCase().includes(query) || country.iso2.toLowerCase().includes(query)
    );
  }, [countries, searchQuery]);

  return (
    <AuthGate>
      <ScrapbookBackground overlay={0}>
      <ImageBackground
        source={require('../../assets/scrapbook/travel2.png')}
        style={styles.pageBackground}
        imageStyle={styles.pageBackgroundImage}
      >
      <View style={styles.pageWash} />
      <View style={[styles.container, { backgroundColor: 'transparent' }]}>
        <View style={styles.headerRow}>
          <View style={styles.headerTitleWrap}>
            <TitleBanner title="Visited" />
          </View>

          <Pressable
            onPress={() => setEditorVisible(true)}
            style={[styles.editButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
          >
            <Text style={[styles.editButtonText, { color: colors.textPrimary }]}>Edit</Text>
          </Pressable>
        </View>

        {isLoading ? (
          <View style={[styles.loadingCard, { backgroundColor: colors.paper, borderColor: colors.border }]}>
            <ActivityIndicator color={colors.primary} />
            <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
              Loading your visited countries...
            </Text>
          </View>
        ) : visitedCountries.length === 0 ? (
          <View style={[styles.emptyCard, { backgroundColor: colors.paper, borderColor: colors.border }]}>
            <Text style={[styles.emptyTitle, { color: colors.textPrimary }]}>
              No Visited Countries Yet
            </Text>
            <Text style={[styles.emptyText, { color: colors.textSecondary }]}>
              Tap the check icon on a country to add it here.
            </Text>
          </View>
        ) : (
          <ScrapbookCard style={styles.listShell} innerStyle={[styles.listInner, { backgroundColor: `${colors.card}F0` }]}>
            <FlatList
              data={visitedCountries}
              keyExtractor={(item) => item.code}
              ItemSeparatorComponent={() => <View style={{ height: 14 }} />}
              renderItem={({ item }) => {
                const score = item.score ?? 0;
                const tone = getScoreTone(score);

                return (
                  <Pressable
                    onPress={() =>
                      router.push({
                        pathname: '/country/[iso2]',
                        params: { iso2: item.code, name: item.name },
                      })
                    }
                    style={[styles.row, { backgroundColor: colors.paper, borderColor: colors.border }]}
                  >
                    <View style={styles.rowContent}>
                      <View style={styles.rowMain}>
                        <Text style={[styles.flag, { color: colors.textPrimary }]}>
                          {item.flagEmoji ?? '•'}
                        </Text>
                        <Text style={[styles.countryName, { color: colors.textPrimary }]}>
                          {item.name}
                        </Text>
                      </View>
                    </View>

                    <View style={styles.rowTail}>
                      <View style={[styles.scorePill, { backgroundColor: tone.bg }]}>
                        <Text style={[styles.scoreText, { color: tone.text }]}>{score}</Text>
                      </View>
                    </View>
                  </Pressable>
                );
              }}
              contentContainerStyle={{ paddingTop: 12, paddingBottom: 24, paddingHorizontal: 12 }}
              showsVerticalScrollIndicator={false}
            />
          </ScrapbookCard>
        )}
      </View>

      <Modal
        visible={editorVisible}
        animationType="slide"
        onRequestClose={() => setEditorVisible(false)}
      >
        <ScrapbookBackground overlay={0}>
          <ImageBackground
            source={require('../../assets/scrapbook/travel2.png')}
            style={styles.pageBackground}
            imageStyle={styles.pageBackgroundImage}
          >
          <View style={styles.pageWash} />
          <View style={[styles.modalScreen, { backgroundColor: 'transparent' }]}>
            <View style={styles.modalHeader}>
              <Pressable
                onPress={() => setEditorVisible(false)}
                style={[styles.modalButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
              >
                <Text style={[styles.modalButtonText, { color: colors.textPrimary }]}>Done</Text>
              </Pressable>
            </View>

            <TitleBanner title="Edit Visited" />

            <ScrapbookCard innerStyle={[styles.editorCard, { backgroundColor: `${colors.card}F2` }]}>
              <Text style={[styles.editorCopy, { color: colors.textSecondary }]}>
                Search and tap countries to add or remove them from your visited list.
              </Text>

              <TextInput
                value={searchQuery}
                onChangeText={setSearchQuery}
                placeholder="Search countries"
                placeholderTextColor={colors.textMuted}
                style={[
                  styles.searchInput,
                  {
                    color: colors.textPrimary,
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                  },
                ]}
              />

              <ScrollView
                style={styles.editorScroll}
                contentContainerStyle={styles.editorContent}
                showsVerticalScrollIndicator={false}
              >
                {filteredCountries.map(country => {
                  const selected = visitedIsoCodes.includes(country.iso2);
                  return (
                    <Pressable
                      key={country.iso2}
                      onPress={() => toggleVisited(country.iso2)}
                      style={[
                        styles.editorRow,
                        {
                          backgroundColor: selected ? colors.paperAlt : colors.paper,
                          borderColor: selected ? colors.primary : colors.border,
                        },
                      ]}
                    >
                      <View style={styles.rowMain}>
                        <Text style={[styles.flag, { color: colors.textPrimary }]}>
                          {country.flagEmoji ?? '•'}
                        </Text>
                        <View style={{ flex: 1 }}>
                          <Text style={[styles.countryName, { color: colors.textPrimary }]}>
                            {country.name}
                          </Text>
                          <Text style={[styles.editorIso, { color: colors.textSecondary }]}>
                            {country.iso2}
                          </Text>
                        </View>
                      </View>

                      <View
                        style={[
                          styles.editorCheck,
                          {
                            backgroundColor: selected ? colors.primary : colors.surface,
                            borderColor: selected ? colors.primary : colors.border,
                          },
                        ]}
                      >
                        <Ionicons
                          name={selected ? 'checkmark' : 'add'}
                          size={16}
                          color={selected ? colors.primaryText : colors.textPrimary}
                        />
                      </View>
                    </Pressable>
                  );
                })}
              </ScrollView>
            </ScrapbookCard>
          </View>
          </ImageBackground>
        </ScrapbookBackground>
      </Modal>
      </ImageBackground>
      </ScrapbookBackground>
    </AuthGate>
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
    backgroundColor: 'rgba(250,245,237,0.14)',
  },
  container: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 18,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  headerTitleWrap: {
    flex: 1,
  },
  editButton: {
    minWidth: 72,
    height: 44,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 12,
  },
  editButtonText: {
    fontSize: 15,
    fontWeight: '700',
  },
  emptyCard: {
    marginTop: 20,
    borderWidth: 1,
    borderRadius: 22,
    paddingHorizontal: 22,
    paddingVertical: 24,
  },
  loadingCard: {
    marginTop: 20,
    borderWidth: 1,
    borderRadius: 22,
    paddingHorizontal: 22,
    paddingVertical: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 12,
    textAlign: 'center',
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 8,
  },
  emptyText: {
    fontSize: 15,
    lineHeight: 22,
  },
  listShell: {
    flex: 1,
    marginTop: 18,
  },
  listInner: {
    flex: 1,
  },
  row: {
    paddingVertical: 16,
    paddingHorizontal: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: 22,
  },
  rowContent: {
    flex: 1,
    marginRight: 12,
  },
  rowMain: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  rowTail: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  flag: {
    fontSize: 24,
    marginRight: 12,
  },
  countryName: {
    fontSize: 16,
    fontWeight: '600',
    flexShrink: 1,
  },
  scorePill: {
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 6,
  },
  scoreText: {
    fontWeight: '600',
    fontSize: 14,
  },
  modalScreen: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 18,
    paddingBottom: 32,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginBottom: 8,
  },
  modalButton: {
    minWidth: 78,
    height: 44,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalButtonText: {
    fontSize: 15,
    fontWeight: '700',
  },
  editorCard: {
    padding: 18,
    flex: 1,
  },
  editorCopy: {
    fontSize: 14,
    lineHeight: 20,
  },
  searchInput: {
    marginTop: 14,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
  },
  editorScroll: {
    marginTop: 16,
    flex: 1,
  },
  editorContent: {
    paddingBottom: 12,
    gap: 12,
  },
  editorRow: {
    minHeight: 72,
    borderWidth: 1,
    borderRadius: 22,
    paddingHorizontal: 16,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  editorIso: {
    fontSize: 12,
    marginTop: 4,
    fontWeight: '600',
    letterSpacing: 0.5,
  },
  editorCheck: {
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 12,
  },
});
