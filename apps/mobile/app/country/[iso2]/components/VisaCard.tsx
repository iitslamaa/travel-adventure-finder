import { View, Text, StyleSheet, Pressable, Linking } from 'react-native';
import { useTheme } from '../../../../hooks/useTheme';
import MetricPill from './MetricPill';

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

function visaHeadline(type?: string) {
  switch (type) {
    case 'own_passport':
      return 'Own passport for your home country';
    case 'freedom_of_movement':
      return 'Freedom of movement with US passport';
    case 'visa_free':
      return 'Visa-free entry with US passport';
    case 'voa':
      return 'Visa on arrival';
    case 'evisa':
      return 'eVisa available';
    case 'entry_permit':
      return 'Entry permit required';
    case 'visa_required':
      return 'Visa required';
    case 'ban':
      return 'Entry restrictions apply';
    case undefined:
      return 'Visa information is limited';
    default:
      return 'Visa rules vary';
  }
}

function visaBody(type?: string, notes?: string) {
  const trimmedNotes = notes?.trim();
  if (trimmedNotes) return trimmedNotes;

  switch (type) {
    case 'own_passport':
      return 'You are entering on your own passport for your own country.';
    case 'freedom_of_movement':
      return 'This destination is part of a territorial arrangement where US passport holders can move freely without visa restrictions.';
    case 'visa_free':
      return 'You can typically enter without arranging a visa in advance, but check stay limits and entry conditions.';
    case 'voa':
      return 'You can typically obtain a visa on arrival, but confirm fees, documents, and airport eligibility before travel.';
    case 'evisa':
      return 'You can typically apply online before travel; check processing time and validity before booking.';
    case 'entry_permit':
      return 'Entry may require a permit or authorization beyond a standard passport check.';
    case 'visa_required':
      return 'Plan to arrange a visa before travel and confirm processing requirements with official sources.';
    case 'ban':
      return 'Entry may be restricted for this passport; confirm with official government sources before making plans.';
    case undefined:
      return 'Check official sources for the latest entry requirements.';
    default:
      return 'Entry rules may depend on your trip details; confirm with official government sources.';
  }
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
  const headline = visaHeadline(visaType);
  const body = visaBody(visaType, notes);

  const theme = useTheme();

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
      <Text style={[styles.eyebrow, { color: theme.textMuted }]}>Passport context</Text>
      <View style={styles.headerRow}>
        <Text style={[styles.cardTitle, { color: theme.textPrimary }]}>Visa</Text>
        <Text style={[styles.weightText, { color: theme.textSecondary }]}>{weightLabel}</Text>
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

          {!!visaType && (
            <Text style={[styles.detailText, { color: theme.textMuted }]}>
              Type: {title}{allowedDays ? ` · Allowed stay: ${allowedDays} days` : ''}
            </Text>
          )}

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
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    padding: 18,
    marginBottom: 18,
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
    alignItems: 'center',
    marginBottom: 14,
  },
  cardTitle: { fontSize: 18, fontWeight: '800' },
  weightText: { fontSize: 13, fontWeight: '600' },

  metricRow: { flexDirection: 'row', gap: 16 },

  metricTitle: { fontSize: 16, fontWeight: '800', marginBottom: 2 },
  metricDescription: { fontSize: 14, lineHeight: 20, marginTop: 4 },
  detailText: {
    marginTop: 10,
    fontSize: 12.5,
    fontWeight: '600',
  },
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
