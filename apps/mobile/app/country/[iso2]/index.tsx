import {
  ScrollView,
  View,
  ActivityIndicator,
  Pressable,
  Text,
  StyleSheet,
  ImageBackground,
} from 'react-native';
import { router, useLocalSearchParams, useNavigation } from 'expo-router';
import { useEffect, useState } from 'react';
import { Ionicons } from '@expo/vector-icons';
import HeaderCard from './components/HeaderCard';
import OverviewCard from './components/OverviewCard';
import AdvisoryCard from './components/AdvisoryCard';
import SeasonalityCard from './components/SeasonalityCard';
import VisaCard from './components/VisaCard';
import AffordabilityCard from './components/AffordabilityCard';
import LanguageCompatibilityCard from './components/LanguageCompatibilityCard';
import FriendEngagementCard from './components/FriendEngagementCard';
import { useAuth } from '../../../context/AuthContext';
import { useScorePreferences } from '../../../context/ScorePreferencesContext';
import { scoreCountry, seasonalityScoreForMonth } from '../../../utils/scoring';
import { useCountryFriendEngagement } from '../../../hooks/useCountryFriendEngagement';
import { useTheme } from '../../../hooks/useTheme';

function flagEmojiFromIso2(iso2: string) {
  const code = iso2.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(code)) return undefined;
  return String.fromCodePoint(
    ...code.split('').map(char => 127397 + char.charCodeAt(0))
  );
}

export default function CountryDetailScreen() {
  const { iso2, name } = useLocalSearchParams<{ iso2: string; name?: string }>();
  const navigation = useNavigation();
  const { weights, selectedMonth } = useScorePreferences();
  const { session, toggleBucket, toggleVisited, isBucketed, isVisited } = useAuth();

  const colors = useTheme();
  const normalizedIso2 = typeof iso2 === 'string' ? iso2.toUpperCase() : '';
  const bucketed = normalizedIso2 ? isBucketed(normalizedIso2) : false;
  const visited = normalizedIso2 ? isVisited(normalizedIso2) : false;

  const [country, setCountry] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const { engagement, loading: engagementLoading } = useCountryFriendEngagement(
    normalizedIso2 || undefined
  );

  useEffect(() => {
    navigation.setOptions({
      headerShown: false,
      title: typeof name === 'string' ? name : 'Country',
    });
  }, [navigation, name]);

  useEffect(() => {
    if (!normalizedIso2) return;

    const fetchCountry = async () => {
      try {
        setLoading(true);
        const res = await fetch(
          `https://travel-scorer.vercel.app/api/country/${normalizedIso2}`
        );
        const data = await res.json();
        setCountry(data);
      } catch (e) {
        console.log('Country detail fetch error:', e);
      } finally {
        setLoading(false);
      }
    };

    fetchCountry();
  }, [normalizedIso2]);

  useEffect(() => {
    if (!country?.name) return;

    navigation.setOptions({
      headerShown: false,
      title: country.name,
    });
  }, [navigation, country?.name]);

  if (loading || !country) {
    return (
      <ImageBackground
        source={require('../../../assets/scrapbook/travel5.png')}
        style={styles.background}
        imageStyle={styles.backgroundImage}
      >
        <View style={styles.overlay} />
        <View style={styles.loadingShell}>
          <View
            style={[
              styles.loadingCard,
              {
                backgroundColor: colors.card,
                borderColor: colors.cardBorderStrong,
                shadowColor: colors.shadow,
              },
            ]}
          >
            <ActivityIndicator size="large" color={colors.primary} />
            <Text
              style={[
                styles.loadingText,
                { color: colors.textSecondary },
              ]}
            >
              Loading country details...
            </Text>
          </View>
        </View>
      </ImageBackground>
    );
  }

  const score =
    scoreCountry(country, weights, selectedMonth) ??
    country.scoreTotal ??
    country.facts?.scoreTotal ??
    0;
  const advisoryLevel = country.facts?.advisoryLevel ?? '—';

  const advisoryScore =
    country.facts?.advisoryScore ??
    country.facts?.advisoryNormalized ??
    country.facts?.advisoryWeighted ??
    0;
  const flagEmoji =
    (country as any).flagEmoji ?? flagEmojiFromIso2(normalizedIso2);

  return (
    <ImageBackground
      source={require('../../../assets/scrapbook/travel5.png')}
      style={styles.background}
      imageStyle={styles.backgroundImage}
    >
      <View style={styles.overlay} />
      <ScrollView
        style={{ flex: 1, backgroundColor: 'transparent' }}
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.topBar}>
          <Pressable
            onPress={() => router.back()}
            style={[
              styles.backButton,
              { borderColor: colors.border, backgroundColor: colors.paperAlt },
            ]}
          >
            <Ionicons name="chevron-back" size={20} color={colors.textPrimary} />
          </Pressable>

          {session && normalizedIso2 ? (
            <View style={styles.actionStack}>
              <Pressable
                onPress={() => toggleBucket(normalizedIso2)}
                style={[
                  styles.actionButton,
                  {
                    backgroundColor: bucketed ? colors.greenBg : colors.paperAlt,
                    borderColor: bucketed ? colors.greenBorder : colors.border,
                  },
                ]}
              >
                <Ionicons
                  name={bucketed ? 'bookmark' : 'bookmark-outline'}
                  size={20}
                  color={bucketed ? colors.greenText : colors.textPrimary}
                />
              </Pressable>
              <Pressable
                onPress={() => toggleVisited(normalizedIso2)}
                style={[
                  styles.actionButton,
                  {
                    backgroundColor: visited ? colors.greenBg : colors.paperAlt,
                    borderColor: visited ? colors.greenBorder : colors.border,
                  },
                ]}
              >
                <Ionicons
                  name={visited ? 'checkmark-circle' : 'checkmark-circle-outline'}
                  size={21}
                  color={visited ? colors.greenText : colors.textPrimary}
                />
              </Pressable>
            </View>
          ) : null}
        </View>

        <HeaderCard
          name={country.name}
          subregion={(country as any).subregion}
          region={country.region}
          score={score}
          flagEmoji={flagEmoji}
        />

        <OverviewCard country={country} iso2={normalizedIso2} />

        {session ? (
          <FriendEngagementCard
            totalFriends={engagement.totalFriends}
            visited={engagement.visited}
            bucketList={engagement.bucketList}
            fromHere={engagement.fromHere}
            loading={engagementLoading}
            onSelectProfile={userId => router.push(`/profile/${userId}`)}
          />
        ) : null}

        <AdvisoryCard
          score={advisoryScore}
          level={advisoryLevel}
          summary={country.facts?.advisorySummary}
          url={country.facts?.advisoryUrl}
          updatedAtLabel={
            (country as any).advisory?.updatedAt
              ? `Last updated: ${(country as any).advisory.updatedAt}`
              : undefined
          }
          normalizedLabel={`Normalized: ${advisoryScore}`}
          weightOnlyLabel={'Weight: 10%'}
        />

        <SeasonalityCard
          score={seasonalityScoreForMonth(country, selectedMonth)}
          bestMonths={country.facts?.fmSeasonalityBestMonths ?? []}
          description={country.facts?.fmSeasonalityNotes}
          normalizedLabel={`Normalized: ${seasonalityScoreForMonth(country, selectedMonth)}`}
          weightOnlyLabel={'Weight: 5%'}
          weightLabel={`${new Date(2026, selectedMonth - 1, 1).toLocaleString('en-US', { month: 'short' })} · 5%`}
        />

        <VisaCard
          score={country.facts?.visaEase ?? 0}
          visaType={country.facts?.visaType}
          allowedDays={country.facts?.visaAllowedDays}
          notes={country.facts?.visaNotes}
          sourceUrl={country.facts?.visaSource}
          normalizedLabel={`Normalized: ${country.facts?.visaEase ?? 0}`}
          weightOnlyLabel={'Weight: 5%'}
        />

        <AffordabilityCard
          score={country.facts?.affordability ?? 0}
          category={country.facts?.affordabilityCategory}
          averageDailyCost={country.facts?.averageDailyCostUsd}
          explanation={country.facts?.affordabilityExplanation}
          normalizedLabel={`Normalized: ${country.facts?.affordability ?? 0}`}
          weightOnlyLabel={'Weight: 15%'}
        />

        {typeof country.facts?.languageCompatibilityScore === 'number' ? (
          <LanguageCompatibilityCard
            score={country.facts.languageCompatibilityScore}
            weightLabel={`Your languages · ${Math.round(weights.language * 100)}%`}
          />
        ) : null}
      </ScrollView>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
  },
  backgroundImage: {
    resizeMode: 'cover',
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(255, 248, 236, 0.56)',
  },
  loadingShell: {
    flex: 1,
    paddingTop: 22,
    paddingHorizontal: 20,
    justifyContent: 'center',
  },
  loadingCard: {
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 180,
    paddingHorizontal: 24,
    paddingVertical: 28,
    borderRadius: 14,
    borderWidth: 1,
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 8 },
    elevation: 3,
  },
  loadingText: {
    marginTop: 14,
    fontSize: 15,
    textAlign: 'center',
  },
  content: {
    paddingTop: 20,
    paddingHorizontal: 16,
    paddingBottom: 36,
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 14,
  },
  backButton: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionStack: {
    flexDirection: 'row',
    gap: 10,
  },
  actionButton: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
