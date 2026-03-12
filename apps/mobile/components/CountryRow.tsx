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

function getScoreColor(score: number) {
  if (score >= 80) return '#4CAF50';
  if (score >= 60) return '#FBC02D';
  return '#E57373';
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
  const color = getScoreColor(score);

  return (
    <Pressable
      onPress={onPress}
      style={[styles.container, { borderColor: colors.border }]}
    >
      <View style={styles.left}>
        <Text style={styles.flag}>{isoToFlag(country.iso2)}</Text>

        <View>
          <Text style={[styles.name, { color: colors.textPrimary }]}>
            {country.name}
          </Text>
          {advisoryLevel !== undefined && (
            <Text style={[styles.level, { color: colors.textSecondary }]}>
              Level {advisoryLevel}
            </Text>
          )}
        </View>
      </View>

      <View style={styles.rightSection}>
        <View style={[styles.scorePill, { backgroundColor: `${color}20` }]}> 
          <Text style={[styles.scoreText, { color }]}>{score}</Text>
        </View>

        {/* Bucket Toggle */}
        <Pressable
          onPress={(e) => {
            e.stopPropagation();
            onToggleBucket();
          }}
          hitSlop={10}
          style={styles.iconButton}
        >
          <Ionicons
            name={isBucketed ? 'bookmark' : 'bookmark-outline'}
            size={22}
            color={isBucketed ? colors.primary : colors.textMuted}
          />
        </Pressable>

        {/* Visited Toggle */}
        <Pressable
          onPress={(e) => {
            e.stopPropagation();
            onToggleVisited();
          }}
          hitSlop={10}
          style={styles.iconButton}
        >
          <Ionicons
            name={isVisited ? 'checkmark-circle' : 'checkmark-circle-outline'}
            size={22}
            color={isVisited ? colors.primary : colors.textMuted}
          />
        </Pressable>

        <Text style={[styles.chevron, { color: colors.textMuted }]}>›</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 18,
  },
  left: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  rightSection: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  flag: {
    fontSize: 28,
    marginRight: 14,
  },
  name: {
    fontSize: 16,
    fontWeight: '600',
  },
  level: {
    fontSize: 13,
    marginTop: 2,
  },
  scorePill: {
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 6,
    marginRight: 10,
  },
  scoreText: {
    fontWeight: '600',
    fontSize: 14,
  },
  iconButton: {
    marginRight: 10,
  },
  chevron: {
    fontSize: 20,
  },
});