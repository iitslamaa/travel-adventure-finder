import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Country } from '../types/Country';
import { useTheme } from '../hooks/useTheme';

type Props = {
  country: Country;
  onPress: () => void;
  isBucketed: boolean;
  onToggleBucket: () => void;
  isVisited: boolean;
  onToggleVisited: () => void;
};

function getScoreTone(score: number) {
  if (score >= 80) {
    return {
      bg: 'rgba(86, 131, 93, 0.14)',
      text: '#436347',
    };
  }
  if (score >= 60) {
    return {
      bg: 'rgba(211, 177, 104, 0.18)',
      text: '#805B2F',
    };
  }
  return {
    bg: 'rgba(184, 112, 95, 0.16)',
    text: '#7C4B43',
  };
}

function isoToFlag(iso2: string) {
  return iso2
    .toUpperCase()
    .replace(/./g, char =>
      String.fromCodePoint(127397 + char.charCodeAt(0))
    );
}

export default function CountryRow({
  country,
  onPress,
  isBucketed,
  onToggleBucket,
  isVisited,
  onToggleVisited,
}: Props) {
  const colors = useTheme();
  const score = country.scoreTotal ?? 0;
  const advisoryLevel = country.advisory?.level;
  const scoreTone = getScoreTone(score);

  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.container,
        {
          backgroundColor: colors.card,
          borderColor: colors.cardBorderStrong,
          shadowColor: colors.shadow,
        },
      ]}
    >
      <View style={styles.mainRow}>
        <View style={styles.left}>
          <Text style={styles.flag}>{isoToFlag(country.iso2)}</Text>

          <View style={styles.textWrap}>
            <Text style={[styles.name, { color: colors.textPrimary }]}>
              {country.name}
            </Text>
            {advisoryLevel !== undefined && (
              <Text style={[styles.level, { color: colors.textSecondary }]}>
                Advisory level {advisoryLevel}
              </Text>
            )}
          </View>
        </View>

        <View style={styles.rightSection}>
          <View style={[styles.scorePill, { backgroundColor: scoreTone.bg }]}>
            <Text style={[styles.scoreText, { color: scoreTone.text }]}>{score}</Text>
          </View>

          <Text style={[styles.chevron, { color: colors.textMuted }]}>›</Text>
        </View>
      </View>

      <View style={styles.actionsRow}>
        <Pressable
          onPress={(e) => {
            e.stopPropagation();
            onToggleBucket();
          }}
          hitSlop={10}
          style={[
            styles.actionChip,
            {
              backgroundColor: colors.surface,
              borderColor: colors.border,
            },
          ]}
        >
          <Ionicons
            name={isBucketed ? 'bookmark' : 'bookmark-outline'}
            size={16}
            color={isBucketed ? colors.primary : colors.textMuted}
          />
          <Text
            style={[
              styles.actionText,
              { color: isBucketed ? colors.primary : colors.textPrimary },
            ]}
          >
            Bucket
          </Text>
        </Pressable>

        <Pressable
          onPress={(e) => {
            e.stopPropagation();
            onToggleVisited();
          }}
          hitSlop={10}
          style={[
            styles.actionChip,
            {
              backgroundColor: colors.surface,
              borderColor: colors.border,
            },
          ]}
        >
          <Ionicons
            name={isVisited ? 'checkmark-circle' : 'checkmark-circle-outline'}
            size={16}
            color={isVisited ? colors.primary : colors.textMuted}
          />
          <Text
            style={[
              styles.actionText,
              { color: isVisited ? colors.primary : colors.textPrimary },
            ]}
          >
            Visited
          </Text>
        </Pressable>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    borderWidth: 1,
    borderRadius: 24,
    paddingHorizontal: 16,
    paddingVertical: 15,
    marginBottom: 12,
    shadowOpacity: 0.08,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 3,
  },
  mainRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  left: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  textWrap: {
    flexShrink: 1,
  },
  rightSection: {
    flexDirection: 'row',
    alignItems: 'center',
    marginLeft: 10,
  },
  flag: {
    fontSize: 26,
    marginRight: 14,
  },
  name: {
    fontSize: 16,
    fontWeight: '700',
  },
  level: {
    fontSize: 12,
    marginTop: 4,
  },
  scorePill: {
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 6,
    marginRight: 10,
    minWidth: 54,
    alignItems: 'center',
  },
  scoreText: {
    fontWeight: '700',
    fontSize: 14,
  },
  actionsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 10,
    marginLeft: 40,
  },
  actionChip: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 11,
    paddingVertical: 6,
    gap: 6,
  },
  actionText: {
    fontSize: 12,
    fontWeight: '600',
  },
  chevron: {
    fontSize: 20,
  },
});
