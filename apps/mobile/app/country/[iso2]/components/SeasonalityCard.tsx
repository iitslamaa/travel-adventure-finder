import { View, Text, StyleSheet, useColorScheme } from 'react-native';
import { lightColors, darkColors } from '../../../../theme/colors';
import ScorePill from '../../../../components/ScorePill';

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

  const scheme = useColorScheme();
  const theme = scheme === 'dark' ? darkColors : lightColors;

  return (
    <View style={[styles.card, { backgroundColor: theme.card }]}>
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
          {!!description && (
            <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>{description}</Text>
          )}

          {labels.length > 0 && (
            <>
              <Text style={[styles.bestLabel, { color: theme.textMuted }]}>Best months:</Text>
              <View style={styles.chips}>
                {labels.map(m => (
                  <View key={m} style={[styles.chip, { backgroundColor: scheme === 'dark' ? '#334155' : '#F3F4F6' }]}>
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
