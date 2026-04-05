import { View, Text, StyleSheet } from 'react-native';
import ScorePill from '../../../../components/ScorePill';
import ScrapbookCard from '../../../../components/theme/ScrapbookCard';
import { useTheme } from '../../../../hooks/useTheme';

type Props = {
  name: string;
  subregion?: string;
  region?: string;
  score: number;
  flagEmoji?: string;
};

export default function HeaderCard({
  name,
  subregion,
  region,
  score,
  flagEmoji,
}: Props) {
  const theme = useTheme();

  const locationLine =
    subregion && region ? `${subregion}, ${region}` : (region ?? subregion ?? '');

  return (
    <ScrapbookCard innerStyle={styles.card}>
      <Text style={[styles.sectionTag, { color: theme.textSecondary }]}>
        Travel dossier
      </Text>
      <View style={styles.topRow}>
        <View style={styles.left}>
          <Text style={[styles.eyebrow, { color: theme.textMuted }]}>
            Country snapshot
          </Text>
          <View style={styles.titleRow}>
            {!!flagEmoji && <Text style={styles.flag}>{flagEmoji}</Text>}
            <Text style={[styles.title, { color: theme.textPrimary }]}>
              {name}
            </Text>
          </View>

          {!!locationLine && (
            <Text style={[styles.subtitle, { color: theme.textSecondary }]}>
              {locationLine}
            </Text>
          )}
        </View>

        <View style={styles.scoreWrap}>
          <ScorePill score={Math.round(score)} size="lg" />
          <Text style={[styles.scoreLabel, { color: theme.textMuted }]}>
            Overall score
          </Text>
        </View>
      </View>
    </ScrapbookCard>
  );
}

const styles = StyleSheet.create({
  card: {
    paddingVertical: 18,
    paddingHorizontal: 18,
    marginBottom: 16,
  },
  sectionTag: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },

  left: {
    flex: 1,
    paddingRight: 14,
  },

  eyebrow: {
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginBottom: 10,
  },

  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },

  flag: {
    fontSize: 28,
    marginRight: 8,
  },

  title: {
    fontSize: 22,
    fontWeight: '800',
  },

  subtitle: {
    fontSize: 15,
    fontWeight: '600',
  },
  scoreWrap: {
    alignItems: 'center',
  },
  scoreLabel: {
    marginTop: 8,
    fontSize: 12,
    fontWeight: '700',
  },
});
