import {
  ScrollView,
  useColorScheme,
  View,
  ActivityIndicator,
  Text,
} from 'react-native';
import { useLocalSearchParams, useNavigation } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import HeaderCard from './components/HeaderCard';
import AdvisoryCard from './components/AdvisoryCard';
import SeasonalityCard from './components/SeasonalityCard';
import VisaCard from './components/VisaCard';
import { lightColors, darkColors } from '../../../theme/colors';

export default function CountryDetailScreen() {
  const { iso2, name } = useLocalSearchParams<{ iso2: string; name?: string }>();
  const navigation = useNavigation();

  const scheme = useColorScheme();
  const colors = scheme === 'dark' ? darkColors : lightColors;

  const [country, setCountry] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

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
      <View
        style={{
          flex: 1,
          backgroundColor: colors.background,
          alignItems: 'center',
          justifyContent: 'center',
          padding: 24,
        }}
      >
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  const score = country.scoreTotal ?? country.facts?.scoreTotal ?? 0;
  const advisoryLevel = country.facts?.advisoryLevel ?? '—';

  const advisoryScore =
    country.facts?.advisoryScore ??
    country.facts?.advisoryNormalized ??
    country.facts?.advisoryWeighted ??
    0;

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.background }}
      contentContainerStyle={{ padding: 16 }}
    >
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
        score={country.facts?.seasonality ?? 50}
        bestMonths={country.facts?.fmSeasonalityBestMonths ?? []}
        description={country.facts?.fmSeasonalityNotes}
        normalizedLabel={`Normalized: ${country.facts?.seasonality ?? 50}`}
        weightOnlyLabel={'Weight: 5%'}
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
    </ScrollView>
  );
}