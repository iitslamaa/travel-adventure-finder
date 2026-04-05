import { View, Text, StyleSheet, Pressable, Linking } from 'react-native';
import { useMemo, useState } from 'react';
import ScorePill from '../../../../components/ScorePill';
import ScrapbookCard from '../../../../components/theme/ScrapbookCard';
import { useTheme } from '../../../../hooks/useTheme';

type Props = {
  score: number;
  level: number | string;
  summary?: string;
  updatedAtLabel?: string;
  url?: string;
  normalizedLabel?: string;
  weightOnlyLabel?: string;
  weightLabel?: string;
};

export default function AdvisoryCard({
  score,
  level,
  summary,
  updatedAtLabel,
  url,
  normalizedLabel,
  weightOnlyLabel,
  weightLabel = 'U.S. Dept. of State · 10%',
}: Props) {
  const [expanded, setExpanded] = useState(false);

  const theme = useTheme();

  const { preview, canExpand } = useMemo(() => {
    const clean = (summary ?? '').trim();
    const max = 130;
    if (clean.length <= max) return { preview: clean, canExpand: false };
    return { preview: clean.slice(0, max).trim() + '…', canExpand: true };
  }, [summary]);

  const body = expanded ? summary : preview;

  return (
    <ScrapbookCard innerStyle={styles.card}>
      <Text style={[styles.eyebrow, { color: theme.textMuted }]}>Safety and entry</Text>
      <View style={styles.headerRow}>
        <Text style={[styles.cardTitle, { color: theme.textPrimary }]}>Travel advisory</Text>
        <Text style={[styles.weightText, { color: theme.textSecondary }]}>{weightLabel}</Text>
      </View>

      <View style={styles.metricRow}>
        <ScorePill score={Math.round(score)} size="lg" />

        <View style={{ flex: 1 }}>
          <Text style={[styles.metricTitle, { color: theme.textPrimary }]}>Level {level}</Text>
          <Text style={[styles.metricSubhead, { color: theme.textMuted }]}>
            Safety advisory snapshot
          </Text>

          <View style={[styles.helperCard, { backgroundColor: theme.surface, borderColor: theme.border }]}>
            <Text style={[styles.helperLabel, { color: theme.textSecondary }]}>
              Advisory snapshot
            </Text>

            {!!summary && (
              <Text style={[styles.metricDescription, { color: theme.textSecondary }]}>{body}</Text>
            )}
          </View>

          {canExpand && (
            <Pressable
              onPress={() => setExpanded(v => !v)}
              style={[styles.inlineButton, { backgroundColor: theme.paperAlt, borderColor: theme.border }]}
            >
              <Text style={[styles.showMore, { color: theme.textPrimary }]}>
                {expanded ? 'Show less' : 'Show more'}
              </Text>
            </Pressable>
          )}

          {!!updatedAtLabel && (
            <Text style={[styles.metaText, { color: theme.textMuted }]}>{updatedAtLabel}</Text>
          )}

          {!!url && (
            <Pressable
              onPress={() => Linking.openURL(url)}
              style={[styles.inlineButton, { backgroundColor: theme.paperAlt, borderColor: theme.border }]}
            >
              <Text style={[styles.link, { color: theme.textPrimary }]}>View official advisory</Text>
            </Pressable>
          )}

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

  showMore: {
    fontSize: 14,
    fontWeight: '700',
  },
  inlineButton: {
    alignSelf: 'flex-start',
    marginTop: 8,
    borderWidth: 1,
    borderRadius: 14,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },

  metaText: {
    marginTop: 8,
    fontSize: 12.5,
    fontWeight: '600',
  },

  link: {
    fontSize: 14,
    fontWeight: '800',
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
