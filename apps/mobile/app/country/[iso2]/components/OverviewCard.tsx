import { StyleSheet, Text, View } from 'react-native';
import { useTheme } from '../../../../hooks/useTheme';
import { WorldMap } from '../../../../src/features/map/components/WorldMap';
import { countryOverviewDescription } from '../../../../utils/countryOverviewDescriptions';

type Props = {
  country: any;
  iso2: string;
};

export default function OverviewCard({ country, iso2 }: Props) {
  const colors = useTheme();
  const normalizedIso = iso2.trim().toUpperCase();

  return (
    <View
      style={[
        styles.card,
        {
          backgroundColor: colors.card,
          borderColor: colors.cardBorderStrong,
          shadowColor: colors.shadow,
        },
      ]}
    >
      <Text style={[styles.body, { color: colors.textPrimary }]}>
        {countryOverviewDescription({ ...country, iso2: normalizedIso })}
      </Text>
      <View style={[styles.map, { borderColor: colors.border }]}>
        <WorldMap
          countries={[normalizedIso]}
          selectedIso={normalizedIso}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 14,
    borderWidth: 1,
    padding: 16,
    marginBottom: 16,
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 8 },
    elevation: 3,
  },
  body: {
    fontSize: 15,
    lineHeight: 21,
    fontWeight: '600',
    marginBottom: 16,
  },
  map: {
    height: 220,
    borderRadius: 16,
    borderWidth: 1,
    overflow: 'hidden',
  },
});
