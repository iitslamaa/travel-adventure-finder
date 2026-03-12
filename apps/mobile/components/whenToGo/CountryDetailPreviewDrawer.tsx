import React, { useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  Pressable,
  TouchableOpacity,
  useColorScheme,
  useWindowDimensions,
} from 'react-native';
import { router } from 'expo-router';
import { lightColors, darkColors } from '../../theme/colors';
import { getScoreColor } from '../../utils/seasonColor';
import { useCountries } from '../../hooks/useCountries';

type Props = {
  visible: boolean;
  onClose: () => void;
  country: any;
  selectedMonth: number;
};

export default function CountryDetailPreviewDrawer({
  visible,
  onClose,
  country,
  selectedMonth,
}: Props) {
  const scheme = useColorScheme();
  const colors = scheme === 'dark' ? darkColors : lightColors;
  const { height } = useWindowDimensions();
  const { countries } = useCountries();

  const resolvedCountry = useMemo(() => {
    const iso2 = country?.iso2;
    if (!iso2) return country;
    const full = countries?.find?.((c: any) => c.iso2 === iso2);
    return full ?? country;
  }, [countries, country]);

  const score = resolvedCountry?.facts?.scoreTotal ?? resolvedCountry?.score ?? 0;
  const advisory =
    resolvedCountry?.facts?.advisoryScore ??
    resolvedCountry?.facts?.advisoryNormalized ??
    resolvedCountry?.facts?.advisoryWeighted ??
    0;
  const affordability = resolvedCountry?.facts?.affordability ?? 0;
  const visaEase = resolvedCountry?.facts?.visaEase ?? 0;
  const seasonality = resolvedCountry?.facts?.seasonality ?? 0;

  const scoreColors = getScoreColor(score);

  const handleNavigate = () => {
    onClose();
    router.push({
      pathname: '/country/[iso2]',
      params: {
        iso2: resolvedCountry?.iso2,
        name: resolvedCountry?.name,
      },
    });
  };

  if (!country) return null;

  return (
    <Modal visible={visible} animationType="fade" transparent>
      <View style={styles.modalContainer}>
        <Pressable style={styles.overlay} onPress={onClose} />

        <View
          style={[
            styles.drawer,
            {
              backgroundColor: colors.card,
              maxHeight: height * 0.75,
            },
          ]}
        >
          <View style={styles.dragIndicator} />

          <View style={styles.headerRow}>
            <View>
              <Text style={[styles.countryName, { color: colors.textPrimary }]}> 
                {resolvedCountry?.flagEmoji} {resolvedCountry?.name}
              </Text>
              <Text style={[styles.region, { color: colors.textMuted }]}> 
                {resolvedCountry?.region}
              </Text>
            </View>

            <View
              style={[
                styles.scorePill,
                { backgroundColor: scoreColors.background },
              ]}
            >
              <Text
                style={[styles.scoreText, { color: scoreColors.text }]}
              >
                {score}
              </Text>
            </View>
          </View>

          <View style={styles.section}>
            <LabelRow label="Advisory" value={advisory} colors={colors} />
            <LabelRow label="Affordability" value={affordability} colors={colors} />
            <LabelRow label="Visa Ease" value={visaEase} colors={colors} />
            <LabelRow label="Seasonality" value={seasonality} colors={colors} />
          </View>

          <TouchableOpacity
            style={[styles.ctaButton, { backgroundColor: colors.primary }]}
            onPress={handleNavigate}
          >
            <Text style={[styles.ctaText, { color: colors.primaryText }]}>
              See Full Country Details
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

function LabelRow({
  label,
  value,
  colors,
}: {
  label: string;
  value: number;
  colors: any;
}) {
  return (
    <View style={styles.labelRow}>
      <Text style={[styles.label, { color: colors.textPrimary }]}>{label}</Text>
      <Text style={[styles.value, { color: colors.textPrimary }]}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  modalContainer: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  drawer: {
    padding: 20,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
  },
  dragIndicator: {
    alignSelf: 'center',
    width: 40,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#ccc',
    marginBottom: 16,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  countryName: {
    fontSize: 22,
    fontWeight: '700',
  },
  scorePill: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
  },
  scoreText: {
    fontWeight: '700',
  },
  region: {
    marginTop: 4,
  },
  section: {
    marginTop: 24,
    gap: 14,
  },
  labelRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  label: {
    fontWeight: '600',
  },
  value: {
    fontWeight: '700',
  },
  ctaButton: {
    marginTop: 28,
    paddingVertical: 16,
    borderRadius: 16,
    alignItems: 'center',
  },
  ctaText: {
    color: 'white',
    fontWeight: '700',
    fontSize: 15,
  },
});