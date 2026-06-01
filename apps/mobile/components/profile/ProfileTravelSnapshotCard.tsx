import { Pressable, StyleSheet, Text, View } from 'react-native';
import CountryFlag from 'react-native-country-flag';
import { countryName, flagEmoji, normalizeCountryCode, uniqueCountryCodes } from '../../utils/countries';
import { useTheme } from '../../hooks/useTheme';

function SnapshotRow({
  title,
  code,
  emptyText,
  onOpenCountry,
}: {
  title: string;
  code?: string | null;
  emptyText: string;
  onOpenCountry?: (code: string) => void;
}) {
  const colors = useTheme();
  const normalized = normalizeCountryCode(code);

  return (
    <View style={styles.snapshotRow}>
      <Text style={[styles.snapshotLabel, { color: colors.textPrimary }]}>{title}:</Text>
      <Pressable
        disabled={!normalized}
        onPress={() => normalized && onOpenCountry?.(normalized)}
        style={[styles.snapshotValueBox, { backgroundColor: `${colors.card}8F` }]}
      >
        {normalized ? (
          <>
            <CountryFlag isoCode={normalized} size={24} style={styles.snapshotFlag} />
            <Text style={[styles.snapshotValue, { color: colors.textPrimary }]} numberOfLines={2}>
              {countryName(normalized)}
            </Text>
          </>
        ) : (
          <Text style={[styles.snapshotEmpty, { color: colors.textSecondary }]}>{emptyText}</Text>
        )}
      </Pressable>
    </View>
  );
}

export default function ProfileTravelSnapshotCard({
  currentCountry,
  nextDestination,
  favoriteCountries,
  onOpenCountry,
}: {
  currentCountry?: string | null;
  nextDestination?: string | null;
  favoriteCountries?: string[];
  onOpenCountry?: (code: string) => void;
}) {
  const colors = useTheme();
  const favorites = uniqueCountryCodes(favoriteCountries ?? []).sort();

  return (
    <View style={styles.wrap}>
      <SnapshotRow
        title="Currently in"
        code={currentCountry}
        emptyText="No current country yet"
        onOpenCountry={onOpenCountry}
      />
      <SnapshotRow
        title="Next stop"
        code={nextDestination}
        emptyText="No next destination yet"
        onOpenCountry={onOpenCountry}
      />

      <View style={styles.favoritesBlock}>
        <Text style={[styles.favoritesTitle, { color: colors.textPrimary }]}>Favorite trips:</Text>
        {favorites.length ? (
          <View style={styles.favoriteGrid}>
            {favorites.map(code => (
              <Pressable
                key={code}
                onPress={() => onOpenCountry?.(code)}
                style={styles.favoriteFlagBox}
              >
                <Text style={styles.favoriteFlag}>{flagEmoji(code)}</Text>
              </Pressable>
            ))}
          </View>
        ) : (
          <Text style={[styles.favoriteEmpty, { color: colors.textSecondary }]}>
            No favorites picked yet
          </Text>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    gap: 14,
  },
  snapshotRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  snapshotLabel: {
    width: 122,
    fontSize: 16,
    fontWeight: '800',
  },
  snapshotValueBox: {
    flex: 1,
    minHeight: 40,
    borderRadius: 12,
    paddingHorizontal: 8,
    paddingVertical: 6,
    flexDirection: 'row',
    alignItems: 'center',
  },
  snapshotFlag: {
    marginRight: 7,
  },
  snapshotValue: {
    flex: 1,
    fontSize: 14,
    fontWeight: '800',
  },
  snapshotEmpty: {
    fontSize: 13,
    fontWeight: '600',
  },
  favoritesBlock: {
    gap: 8,
  },
  favoritesTitle: {
    fontSize: 16,
    fontWeight: '800',
  },
  favoriteGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 4,
  },
  favoriteFlagBox: {
    width: 48,
    height: 46,
    alignItems: 'center',
    justifyContent: 'center',
  },
  favoriteFlag: {
    fontSize: 34,
    lineHeight: 42,
    includeFontPadding: true,
  },
  favoriteEmpty: {
    fontSize: 13,
    fontWeight: '600',
  },
});
