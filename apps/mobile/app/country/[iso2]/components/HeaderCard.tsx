import { View, Text, StyleSheet } from 'react-native';
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
      <View style={styles.topRow}>
        {!!flagEmoji && <Text style={styles.flag}>{flagEmoji}</Text>}
        <View style={styles.left}>
          <Text style={[styles.title, { color: theme.textPrimary }]}>
            {name}
          </Text>

          {!!locationLine && (
            <Text style={[styles.subtitle, { color: theme.textSecondary }]}>
              {locationLine}
            </Text>
          )}
        </View>

        <View
          style={[
            styles.scorePill,
            { backgroundColor: theme.greenBg, borderColor: theme.greenBorder },
          ]}
        >
          <Text style={[styles.scoreText, { color: theme.greenText }]}>
            {Math.round(score)}
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
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },

  left: {
    flex: 1,
  },

  flag: {
    fontSize: 60,
    lineHeight: 68,
  },

  title: {
    fontSize: 22,
    fontWeight: '800',
  },

  subtitle: {
    fontSize: 15,
    fontWeight: '600',
    marginTop: 6,
  },
  scorePill: {
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 8,
    alignItems: 'center',
  },
  scoreText: {
    fontSize: 22,
    fontWeight: '800',
  },
});
