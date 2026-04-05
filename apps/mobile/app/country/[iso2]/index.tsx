import {
  ScrollView,
  View,
  ActivityIndicator,
  Pressable,
  Text,
  StyleSheet,
} from 'react-native';
import { router, useLocalSearchParams, useNavigation } from 'expo-router';
import { useEffect, useState } from 'react';
import { Ionicons } from '@expo/vector-icons';
import HeaderCard from './components/HeaderCard';
import AdvisoryCard from './components/AdvisoryCard';
import SeasonalityCard from './components/SeasonalityCard';
import VisaCard from './components/VisaCard';
import AffordabilityCard from './components/AffordabilityCard';
import LanguageCompatibilityCard from './components/LanguageCompatibilityCard';
import FriendEngagementCard from './components/FriendEngagementCard';
import { useScorePreferences } from '../../../context/ScorePreferencesContext';
import { scoreCountry, seasonalityScoreForMonth } from '../../../utils/scoring';
import { useCountryFriendEngagement } from '../../../hooks/useCountryFriendEngagement';
import { useTheme } from '../../../hooks/useTheme';
import ScrapbookBackground from '../../../components/theme/ScrapbookBackground';
import TitleBanner from '../../../components/theme/TitleBanner';
import ScrapbookCard from '../../../components/theme/ScrapbookCard';

export default function CountryDetailScreen() {
  const { iso2, name } = useLocalSearchParams<{ iso2: string; name?: string }>();
  const navigation = useNavigation();
  const { weights, selectedMonth } = useScorePreferences();

  const colors = useTheme();

  const [country, setCountry] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const { engagement, loading: engagementLoading } = useCountryFriendEngagement(
    typeof iso2 === 'string' ? iso2 : undefined
  );

  useEffect(() => {
    if (name) {
      navigation.setOptions({
        title: name,
      });
    }
  }, [navigation, name]);

  useEffect(() => {
    if (!iso2) return;

    const fetchCountry = async () => {
      try {
        setLoading(true);
        const res = await fetch(
          `https://travel-scorer.vercel.app/api/country/${iso2}`
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
  }, [iso2]);

  useEffect(() => {
    if (!country?.name) return;

    navigation.setOptions({
      title: country.name,
    });
  }, [navigation, country?.name]);

  if (loading || !country) {
    return (
      <ScrapbookBackground>
        <View style={styles.loadingShell}>
          <TitleBanner title={typeof name === 'string' ? name : 'Country'} />
          <ScrapbookCard innerStyle={styles.loadingCard}>
            <ActivityIndicator size="large" color={colors.primary} />
            <Text
              style={[
                styles.loadingText,
                { color: colors.textSecondary },
              ]}
            >
              Loading country details...
            </Text>
          </ScrapbookCard>
        </View>
      </ScrapbookBackground>
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

  return (
    <ScrapbookBackground>
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
        </View>

        <TitleBanner title={`${country.name} ${country.flagEmoji ?? ''}`.trim()} />

        <ScrapbookCard style={styles.introShell} innerStyle={styles.introCard}>
          <Text style={[styles.introEyebrow, { color: colors.textSecondary }]}>
            Travel dossier
          </Text>
          <Text style={[styles.introTitle, { color: colors.textPrimary }]}>
            A quick read before you plan
          </Text>
          <Text style={[styles.introBody, { color: colors.textSecondary }]}>
            Score, advisories, seasonality, visa context, costs, languages, and social signals all live together here.
          </Text>
        </ScrapbookCard>

        <HeaderCard
          name={country.name}
          subregion={(country as any).subregion}
          region={country.region}
          score={score}
          flagEmoji={(country as any).flagEmoji}
        />

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

        <FriendEngagementCard
          totalFriends={engagement.totalFriends}
          visited={engagement.visited}
          bucketList={engagement.bucketList}
          fromHere={engagement.fromHere}
          loading={engagementLoading}
          onSelectProfile={userId => router.push(`/profile/${userId}`)}
        />
      </ScrollView>
    </ScrapbookBackground>
  );
}

const styles = StyleSheet.create({
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
  },
  loadingText: {
    marginTop: 14,
    fontSize: 15,
    textAlign: 'center',
  },
  content: {
    paddingTop: 18,
    paddingHorizontal: 16,
    paddingBottom: 36,
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 2,
  },
  introShell: {
    marginTop: 10,
    marginBottom: 4,
  },
  introCard: {
    paddingHorizontal: 18,
    paddingVertical: 18,
  },
  introEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  introTitle: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 8,
  },
  introBody: {
    fontSize: 15,
    lineHeight: 22,
  },
  backButton: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
