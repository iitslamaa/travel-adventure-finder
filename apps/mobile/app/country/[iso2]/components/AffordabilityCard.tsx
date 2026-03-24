import { StyleSheet, Text, useColorScheme, View } from 'react-native';
import ScorePill from '../../../../components/ScorePill';
import { darkColors, lightColors } from '../../../../theme/colors';

type Props = {
  score: number;
  category?: number;
  averageDailyCost?: number;
  explanation?: string;
  normalizedLabel?: string;
  weightOnlyLabel?: string;
};

export default function AffordabilityCard({
  score,
  category,
  averageDailyCost,
  explanation,
  normalizedLabel,
  weightOnlyLabel,
}: Props) {
  const scheme = useColorScheme();
  const theme = scheme === 'dark' ? darkColors : lightColors;

  return (
    <View style={[styles.card, { backgroundColor: theme.card }]}>
      <View style={styles.headerRow}>
        <Text style={[styles.cardTitle, { color: theme.textPrimary }]}>
          Affordability
        </Text>
        <Text style={[styles.weightText, { color: theme.textSecondary }]}>
          Cost snapshot · 15%
        </Text>
      </View>

      <View style={styles.metricRow}>
        <ScorePill score={Math.round(score)} size="lg" />

        <View style={{ flex: 1 }}>
          <Text style={[styles.metricTitle, { color: theme.textPrimary }]}>
            {category ? `Cost tier ${category}/10` : 'Budget snapshot'}
          </Text>

          <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>
            {explanation ??
              'Affordability blends average daily travel cost and local price signals. Higher scores mean cheaper trips.'}
          </Text>

          {typeof averageDailyCost === 'number' ? (
            <Text style={[styles.metaText, { color: theme.textMuted }]}>
              Avg. daily travel cost: ${Math.round(averageDailyCost)} USD
            </Text>
          ) : null}

          {(!!normalizedLabel || !!weightOnlyLabel) && (
            <View style={styles.footerRow}>
              {!!normalizedLabel ? (
                <Text style={[styles.footerText, { color: theme.textMuted }]}>
                  {normalizedLabel}
                </Text>
              ) : null}
              {!!weightOnlyLabel ? (
                <Text style={[styles.footerText, { color: theme.textMuted }]}>
                  {weightOnlyLabel}
                </Text>
              ) : null}
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
    lineHeight: 20,
  },
  metaText: {
    marginTop: 10,
    fontSize: 12.5,
    fontWeight: '600',
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
