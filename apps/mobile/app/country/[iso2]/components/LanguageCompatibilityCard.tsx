import { StyleSheet, Text, useColorScheme, View } from 'react-native';
import ScorePill from '../../../../components/ScorePill';
import { darkColors, lightColors } from '../../../../theme/colors';

type Props = {
  score: number;
  weightLabel?: string;
};

function buildHeadline(score: number) {
  if (score >= 85) {
    return 'You should be able to get around comfortably.';
  }
  if (score >= 65) {
    return 'You will likely be okay in most tourist situations.';
  }
  if (score >= 40) {
    return 'Some language friction is likely.';
  }
  return 'Expect meaningful language barriers.';
}

function buildDetail(score: number) {
  if (score >= 85) {
    return 'Your saved languages line up well with the country language profile.';
  }
  if (score >= 65) {
    return 'Common travel interactions should be manageable, but coverage may vary outside major hubs.';
  }
  if (score >= 40) {
    return 'You may want translation help for transport, admin, or local-only settings.';
  }
  return 'Plan for translation apps and more preparation before arrival.';
}

export default function LanguageCompatibilityCard({
  score,
  weightLabel = 'Your languages',
}: Props) {
  const scheme = useColorScheme();
  const theme = scheme === 'dark' ? darkColors : lightColors;

  return (
    <View style={[styles.card, { backgroundColor: theme.card }]}>
      <View style={styles.headerRow}>
        <Text style={[styles.cardTitle, { color: theme.textPrimary }]}>
          Language Compatibility
        </Text>
        <Text style={[styles.weightText, { color: theme.textSecondary }]}>
          {weightLabel}
        </Text>
      </View>

      <View style={styles.metricRow}>
        <ScorePill score={Math.round(score)} size="lg" />

        <View style={{ flex: 1 }}>
          <Text style={[styles.metricTitle, { color: theme.textPrimary }]}>
            {buildHeadline(score)}
          </Text>
          <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>
            {buildDetail(score)}
          </Text>

          <Text style={[styles.footerText, { color: theme.textMuted }]}>
            Based on the languages saved in your profile and the country language profile.
          </Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 22,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOpacity: 0.04,
    shadowRadius: 10,
    elevation: 2,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 14,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '800',
  },
  weightText: {
    fontSize: 13,
    fontWeight: '600',
  },
  metricRow: {
    flexDirection: 'row',
    gap: 16,
  },
  metricTitle: {
    fontSize: 16,
    fontWeight: '800',
    marginBottom: 6,
  },
  metricDescription: {
    fontSize: 14,
    lineHeight: 20,
  },
  footerText: {
    marginTop: 12,
    fontSize: 12,
    fontWeight: '600',
  },
});
