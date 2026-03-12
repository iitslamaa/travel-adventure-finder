import { View, Text, StyleSheet, Pressable, Linking, useColorScheme } from 'react-native';
import { lightColors, darkColors } from '../../../../theme/colors';
import ScorePill from '../../../../components/ScorePill';

type Props = {
  score: number;
  weightLabel?: string;
  visaType?: string;
  allowedDays?: number;
  notes?: string;
  sourceUrl?: string;
  normalizedLabel?: string;
  weightOnlyLabel?: string;
};

function prettyVisaType(t?: string) {
  if (!t) return 'Visa';
  const map: Record<string, string> = {
    freedom_of_movement: 'Freedom of movement',
    visa_free: 'Visa-free',
    visa_required: 'Visa required',
    evisa: 'eVisa',
    voa: 'Visa on arrival',
    eta: 'ETA required',
    unknown: 'Visa',
  };
  return map[t] ?? t.replace(/_/g, ' ');
}

export default function VisaCard({
  score,
  weightLabel = 'US passport · 5%',
  visaType,
  allowedDays,
  notes,
  sourceUrl,
  normalizedLabel,
  weightOnlyLabel,
}: Props) {
  const title = prettyVisaType(visaType);

  const scheme = useColorScheme();
  const theme = scheme === 'dark' ? darkColors : lightColors;

  return (
    <View style={[styles.card, { backgroundColor: theme.card }]}>
      <View style={styles.headerRow}>
        <Text style={[styles.cardTitle, { color: theme.textPrimary }]}>Visa</Text>
        <Text style={[styles.weightText, { color: theme.textSecondary }]}>{weightLabel}</Text>
      </View>

      <View style={styles.metricRow}>
        <ScorePill score={Math.round(score)} size="lg" />

        <View style={{ flex: 1 }}>
          <Text style={[styles.metricTitle, { color: theme.textPrimary }]}>
            {title}{allowedDays ? ` · ${allowedDays} days` : ''}
          </Text>

          <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>
            {notes ?? 'Visa requirements vary by nationality. Check official government sources before booking travel.'}
          </Text>

          {!!sourceUrl && (
            <Pressable onPress={() => Linking.openURL(sourceUrl)} hitSlop={10}>
              <Text style={styles.link}>View visa source</Text>
            </Pressable>
          )}

          {(!!normalizedLabel || !!weightOnlyLabel) && (
            <View style={styles.footerRow}>
              {!!normalizedLabel && (
                <Text style={[styles.footerText, { color: theme.textMuted }]}>
                  {normalizedLabel}
                </Text>
              )}
              {!!weightOnlyLabel && (
                <Text style={[styles.footerText, { color: theme.textMuted }]}>
                  {weightOnlyLabel}
                </Text>
              )}
            </View>
          )}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { borderRadius: 22, padding: 18, marginBottom: 18 },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 14,
  },
  cardTitle: { fontSize: 18, fontWeight: '800' },
  weightText: { fontSize: 13, fontWeight: '600' },

  metricRow: { flexDirection: 'row', gap: 16 },

  metricTitle: { fontSize: 16, fontWeight: '800', marginBottom: 6 },
  metricDescription: { fontSize: 14, lineHeight: 20 },
  link: { marginTop: 10, fontSize: 14, color: '#2563EB', fontWeight: '800' },

  footerRow: { marginTop: 14, flexDirection: 'row', gap: 16 },
  footerText: { fontSize: 12.5, fontWeight: '700' },
});
