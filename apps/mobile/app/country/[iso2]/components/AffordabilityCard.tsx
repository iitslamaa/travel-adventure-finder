import { StyleSheet, Text, View } from 'react-native';
import { useTheme } from '../../../../hooks/useTheme';
import MetricPill from './MetricPill';

type Props = {
  score: number;
  band?: string;
  averageDailyCost?: number;
  normalizedLabel?: string;
  weightOnlyLabel?: string;
};

export default function AffordabilityCard({
  score,
  band,
  averageDailyCost,
  normalizedLabel,
  weightOnlyLabel,
}: Props) {
  const theme = useTheme();
  const tier = affordabilityTier({ band, averageDailyCost, score });
  const formattedCost =
    typeof averageDailyCost === 'number' ? `$${Math.round(averageDailyCost)}` : undefined;
  const headline = affordabilityHeadline(tier, formattedCost);
  const body = affordabilityBody(tier);

  return (
    <View
      style={[
        styles.card,
        {
          backgroundColor: theme.card,
          borderColor: theme.cardBorderStrong,
          shadowColor: theme.shadow,
        },
      ]}
    >
      <Text style={[styles.eyebrow, { color: theme.textMuted }]}>Budget and daily spend</Text>
      <View style={styles.headerRow}>
        <Text style={[styles.cardTitle, { color: theme.textPrimary }]}>
          Affordability
        </Text>
        <Text style={[styles.weightText, { color: theme.textSecondary }]}>
          Cost snapshot · 15%
        </Text>
      </View>

      <View style={styles.metricRow}>
        <MetricPill score={score} />

        <View style={{ flex: 1 }}>
          <Text style={[styles.metricTitle, { color: theme.textPrimary }]}>
            {headline}
          </Text>
          <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>
            {body}
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

          <Text style={[styles.disclaimer, { color: theme.textMuted }]}>
            Costs are estimates and can vary by city, season, and travel style.
          </Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    padding: 16,
    marginBottom: 16,
    borderRadius: 14,
    borderWidth: 1,
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 8 },
    elevation: 3,
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
  metricDescription: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: 4,
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
  disclaimer: {
    marginTop: 12,
    fontSize: 11.5,
    lineHeight: 16,
    fontWeight: '600',
  },
});

type AffordabilityTier = 'veryLow' | 'low' | 'moderate' | 'high' | 'veryHigh';

function affordabilityTier({
  band,
  averageDailyCost,
  score,
}: {
  band?: string;
  averageDailyCost?: number;
  score: number;
}): AffordabilityTier {
  const normalizedBand = band?.toLowerCase();
  if (normalizedBand?.includes('very low')) return 'veryLow';
  if (normalizedBand?.includes('low')) return 'low';
  if (normalizedBand?.includes('moderate') || normalizedBand?.includes('mid')) return 'moderate';
  if (normalizedBand?.includes('very high')) return 'veryHigh';
  if (normalizedBand?.includes('high') || normalizedBand?.includes('expensive')) return 'high';

  if (typeof averageDailyCost === 'number') {
    if (averageDailyCost < 65) return 'veryLow';
    if (averageDailyCost < 120) return 'low';
    if (averageDailyCost < 220) return 'moderate';
    if (averageDailyCost < 350) return 'high';
    return 'veryHigh';
  }

  if (score >= 85) return 'veryLow';
  if (score >= 70) return 'low';
  if (score >= 45) return 'moderate';
  if (score >= 20) return 'high';
  return 'veryHigh';
}

function affordabilityHeadline(tier: AffordabilityTier, formattedCost?: string) {
  const suffix = formattedCost ? ` (~ ${formattedCost}/day)` : '';
  switch (tier) {
    case 'veryLow':
      return `Very low daily costs${suffix}`;
    case 'low':
      return `Low daily costs${suffix}`;
    case 'moderate':
      return `Moderate daily costs${suffix}`;
    case 'high':
      return `High daily costs${suffix}`;
    case 'veryHigh':
      return `Very high daily costs${suffix}`;
  }
}

function affordabilityBody(tier: AffordabilityTier) {
  switch (tier) {
    case 'veryLow':
      return 'Strong value for accommodation, food, and transport compared to global averages.';
    case 'low':
      return 'Relatively affordable for most travelers, with room to stay comfortable.';
    case 'moderate':
      return 'Mid-range travel costs compared with global averages.';
    case 'high':
      return 'Daily costs run above global averages, especially for accommodation.';
    case 'veryHigh':
      return 'Premium destination with consistently high travel costs.';
  }
}
