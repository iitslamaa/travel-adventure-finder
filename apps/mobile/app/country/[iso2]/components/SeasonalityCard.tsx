import { View, Text, StyleSheet } from 'react-native';
import ScorePill from '../../../../components/ScorePill';
import ScrapbookCard from '../../../../components/theme/ScrapbookCard';
import { useTheme } from '../../../../hooks/useTheme';

type Props = {
  score: number;
  bestMonths?: (string | number)[];
  description?: string;
  normalizedLabel?: string;
  weightOnlyLabel?: string;
  weightLabel?: string;
};

const MONTHS = [
  'Jan','Feb','Mar','Apr','May','Jun',
  'Jul','Aug','Sep','Oct','Nov','Dec'
];

function toMonthLabel(m: string | number) {
  if (typeof m === 'number') return MONTHS[m - 1];
  if (/^\d+$/.test(m)) return MONTHS[parseInt(m) - 1];
  return m;
}

export default function SeasonalityCard({
  score,
  bestMonths = [],
  description,
  normalizedLabel,
  weightOnlyLabel,
  weightLabel = 'Today · 5%',
}: Props) {
  // SAFE: bestMonths may not be an array at runtime
  const safeMonths = Array.isArray(bestMonths) ? bestMonths : [];
  const labels = safeMonths.map(toMonthLabel);

  const theme = useTheme();

  return (
    <ScrapbookCard innerStyle={styles.card}>
      <Text style={[styles.eyebrow, { color: theme.textMuted }]}>Timing and weather</Text>
      <View style={styles.headerRow}>
        <Text style={[styles.cardTitle, { color: theme.textPrimary }]}>Seasonality</Text>
        <Text style={[styles.weightText, { color: theme.textSecondary }]}>{weightLabel}</Text>
      </View>

      <View style={styles.metricRow}>
        <ScorePill score={Math.round(score)} size="lg" />

        <View style={{ flex: 1 }}>
          <Text style={[styles.metricTitle, { color: theme.textPrimary }]}>
            {score >= 80 ? 'Peak time to go ✅' : 'Shoulder season'}
          </Text>
          <Text style={[styles.metricSubhead, { color: theme.textMuted }]}>
            Seasonal travel snapshot
          </Text>
          <View style={[styles.helperCard, { backgroundColor: theme.surface, borderColor: theme.border }]}>
            <Text style={[styles.helperLabel, { color: theme.textSecondary }]}>
              Monthly conditions
            </Text>
            {!!description && (
              <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>{description}</Text>
            )}
          </View>

          {labels.length > 0 && (
            <>
              <Text style={[styles.bestLabel, { color: theme.textMuted }]}>Best months:</Text>
              <View style={styles.chips}>
                {labels.map(m => (
                  <View key={m} style={[styles.chip, { backgroundColor: theme.paperAlt, borderColor: theme.border }]}>
                    <Text style={[styles.chipText, { color: theme.textPrimary }]}>{m}</Text>
                  </View>
                ))}
              </View>
            </>
          )}

          <Text style={[styles.disclaimer, { color: theme.textMuted }]}>
            Seasonality insights are based on historical climate averages and typical travel patterns. Timing may vary year to year.
          </Text>

          {(!!normalizedLabel || !!weightOnlyLabel) && (
            <View style={styles.footerRow}>
              {!!normalizedLabel && (
                <Text style={[styles.footerText, { color: theme.textMuted }]}>{normalizedLabel}</Text>
              )}
              {!!weightOnlyLabel && (
                <Text style={[styles.footerText, { color: theme.textMuted }]}>{weightOnlyLabel}</Text>
              )}
            </View>
          )}
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
    lineHeight: 19,
  },

  bestLabel: {
    marginTop: 12,
    fontSize: 13,
    fontWeight: '700',
  },

  chips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 8,
  },

  chip: {
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 999,
    borderWidth: 1,
  },

  chipText: {
    fontSize: 13,
    fontWeight: '800',
  },

  disclaimer: {
    marginTop: 12,
    fontSize: 13,
    lineHeight: 18,
  },

  footerRow: {
    marginTop: 12,
    flexDirection: 'row',
    gap: 16,
  },

  footerText: {
    fontSize: 12,
    fontWeight: '700',
  },
});
