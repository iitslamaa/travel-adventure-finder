import { View, Text, StyleSheet, Pressable, Linking } from 'react-native';
import ScorePill from '../../../../components/ScorePill';
import ScrapbookCard from '../../../../components/theme/ScrapbookCard';
import { useTheme } from '../../../../hooks/useTheme';

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

  const theme = useTheme();

  return (
    <ScrapbookCard innerStyle={styles.card}>
      <Text style={[styles.eyebrow, { color: theme.textMuted }]}>Passport context</Text>
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
          <Text style={[styles.metricSubhead, { color: theme.textMuted }]}>
            Passport and border snapshot
          </Text>

          <View style={[styles.helperCard, { backgroundColor: theme.surface, borderColor: theme.border }]}>
            <Text style={[styles.helperLabel, { color: theme.textSecondary }]}>
              Visa requirements
            </Text>
            <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>
              {notes ?? 'Visa requirements vary by nationality. Check official government sources before booking travel.'}
            </Text>
          </View>

          {!!sourceUrl && (
            <Pressable onPress={() => Linking.openURL(sourceUrl)} hitSlop={10} style={[styles.linkButton, { backgroundColor: theme.paperAlt, borderColor: theme.border }]}>
              <Text style={[styles.link, { color: theme.textPrimary }]}>View visa source</Text>
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
    </ScrapbookCard>
  );
}

const styles = StyleSheet.create({
  card: { padding: 18, marginBottom: 18 },
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
    alignItems: 'center',
    marginBottom: 14,
  },
  cardTitle: { fontSize: 18, fontWeight: '800' },
  weightText: { fontSize: 13, fontWeight: '600' },

  metricRow: { flexDirection: 'row', gap: 16 },

  metricTitle: { fontSize: 16, fontWeight: '800', marginBottom: 2 },
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
  metricDescription: { fontSize: 14, lineHeight: 20 },
  linkButton: {
    alignSelf: 'flex-start',
    marginTop: 10,
    borderWidth: 1,
    borderRadius: 14,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  link: { fontSize: 14, fontWeight: '800' },

  footerRow: { marginTop: 14, flexDirection: 'row', gap: 16 },
  footerText: { fontSize: 12.5, fontWeight: '700' },
});
