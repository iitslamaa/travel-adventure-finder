import { StyleSheet, Text, View } from 'react-native';
import ScorePill from '../../../../components/ScorePill';
import ScrapbookCard from '../../../../components/theme/ScrapbookCard';
import { useTheme } from '../../../../hooks/useTheme';

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
  const theme = useTheme();

  return (
    <ScrapbookCard innerStyle={styles.card}>
      <Text style={[styles.eyebrow, { color: theme.textMuted }]}>Communication fit</Text>
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
          <Text style={[styles.metricSubhead, { color: theme.textMuted }]}>
            Communication snapshot
          </Text>
          <View style={[styles.helperCard, { backgroundColor: theme.surface, borderColor: theme.border }]}>
            <Text style={[styles.helperLabel, { color: theme.textSecondary }]}>
              Your language coverage
            </Text>
            <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>
              {buildDetail(score)}
            </Text>
          </View>

          <Text style={[styles.footerText, { color: theme.textMuted }]}>
            Based on the languages saved in your profile and the country language profile.
          </Text>
        </View>
      </View>
    </ScrapbookCard>
  );
}

const styles = StyleSheet.create({
  card: {
    padding: 16,
    marginBottom: 16,
  },
  eyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: 8,
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
    marginBottom: 2,
  },
  metricSubhead: {
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 8,
  },
  helperCard: {
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 11,
    marginTop: 2,
  },
  helperLabel: {
    fontSize: 12,
    fontWeight: '700',
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
