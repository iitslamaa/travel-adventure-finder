import { StyleSheet, Text, View } from 'react-native';
import { continentForCountry, totalCountryCount, uniqueCountryCodes } from '../../utils/countries';
import { useTheme } from '../../hooks/useTheme';

type Badge = {
  id: string;
  label: string;
  tint: string;
};

type TravelRank = {
  title: string;
  start: number;
  nextThreshold: number | null;
  tint: string;
};

const milestoneThresholds = [5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200];

const continentLabels: Record<string, string> = {
  Africa: 'AF',
  Antarctica: '❄',
  Asia: 'AS',
  Europe: 'EU',
  'North America': 'NA',
  Oceania: 'OC',
  'South America': 'SA',
};

const continentTints: Record<string, string> = {
  Africa: '#D17829',
  Antarctica: '#5796DB',
  Asia: '#C45770',
  Europe: '#456ED4',
  'North America': '#36916F',
  Oceania: '#2499C7',
  'South America': '#2EA07D',
};

function rankForCount(count: number): TravelRank {
  if (count < 5) {
    return { title: 'Travel Newbie', start: 0, nextThreshold: 5, tint: '#E38C42' };
  }
  if (count < 20) {
    return { title: 'Passport Starter', start: 5, nextThreshold: 20, tint: '#D6A143' };
  }
  if (count < 40) {
    return { title: 'Frequent Flyer', start: 20, nextThreshold: 40, tint: '#408CDD' };
  }
  if (count < 60) {
    return { title: 'World Hopper', start: 40, nextThreshold: 60, tint: '#369786' };
  }
  if (count < 100) {
    return { title: 'Global Explorer', start: 60, nextThreshold: 100, tint: '#7A63D6' };
  }
  return { title: '100 Club', start: 100, nextThreshold: null, tint: '#D6AB33' };
}

function badgesForCountries(codes: string[]): Badge[] {
  const badges: Badge[] = [];

  if (codes.length >= 2) {
    badges.push({ id: 'milestone-2-first', label: '👶', tint: '#E38C42' });
  }

  milestoneThresholds.forEach(threshold => {
    if (codes.length >= threshold) {
      badges.push({
        id: `milestone-${threshold}`,
        label: String(threshold),
        tint: threshold >= 100 ? '#2B966D' : threshold >= 50 ? '#8C5CD6' : '#3387DE',
      });
    }
  });

  Array.from(new Set(codes.map(continentForCountry).filter(Boolean) as string[]))
    .sort()
    .forEach(continent => {
      badges.push({
        id: `continent-${continent}`,
        label: continentLabels[continent] ?? continent.slice(0, 2).toUpperCase(),
        tint: continentTints[continent] ?? '#6B4F33',
      });
    });

  return badges.slice(0, 12);
}

export default function ProfileBadgeShowcase({
  visitedCountryCodes,
}: {
  visitedCountryCodes: string[];
}) {
  const colors = useTheme();
  const normalizedCodes = uniqueCountryCodes(visitedCountryCodes);
  const rank = rankForCount(normalizedCodes.length);
  const badges = badgesForCountries(normalizedCodes);
  const remaining = rank.nextThreshold == null ? null : Math.max(rank.nextThreshold - normalizedCodes.length, 0);
  const progress =
    rank.nextThreshold == null
      ? 1
      : Math.min(Math.max((normalizedCodes.length - rank.start) / Math.max(rank.nextThreshold - rank.start, 1), 0), 1);

  return (
    <View style={styles.wrap}>
      <Text style={[styles.rankTitle, { color: colors.textPrimary }]} numberOfLines={1}>
        {rank.title}
      </Text>

      {rank.nextThreshold != null ? (
        <View style={styles.progressGroup}>
          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                {
                  backgroundColor: rank.tint,
                  width: `${Math.max(progress * 100, 5)}%`,
                },
              ]}
            />
          </View>
          <Text style={[styles.nextRank, { color: colors.textSecondary }]}>
            {remaining} to next rank
          </Text>
        </View>
      ) : null}

      <View style={[styles.countPill, { backgroundColor: `${colors.card}A8` }]}>
        <Text style={[styles.countText, { color: colors.textPrimary }]}>
          {normalizedCodes.length}/{totalCountryCount}
        </Text>
      </View>

      <View style={styles.badgeGrid}>
        {badges.length ? (
          badges.map(badge => (
            <View
              key={badge.id}
              style={[
                styles.badge,
                {
                  backgroundColor: `${badge.tint}2E`,
                  borderColor: normalizedCodes.length >= 100 ? '#D6AB33' : `${colors.card}B8`,
                },
              ]}
            >
              <Text style={[styles.badgeText, { color: colors.textPrimary }]} numberOfLines={1}>
                {badge.label}
              </Text>
            </View>
          ))
        ) : (
          <View style={[styles.badge, { backgroundColor: `${colors.card}8F`, borderColor: `${colors.card}B8` }]}>
            <Text style={styles.emptyBadge}>✨</Text>
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    paddingTop: 6,
  },
  rankTitle: {
    fontSize: 13,
    fontWeight: '800',
  },
  progressGroup: {
    width: 132,
    gap: 4,
  },
  progressTrack: {
    height: 8,
    borderRadius: 999,
    overflow: 'hidden',
    backgroundColor: 'rgba(0,0,0,0.14)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.52)',
  },
  progressFill: {
    height: '100%',
    borderRadius: 999,
  },
  nextRank: {
    fontSize: 10,
    fontWeight: '700',
  },
  countPill: {
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  countText: {
    fontSize: 18,
    fontWeight: '900',
  },
  badgeGrid: {
    width: 168,
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 8,
  },
  badge: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: {
    fontSize: 13,
    fontWeight: '900',
  },
  emptyBadge: {
    fontSize: 22,
  },
});
