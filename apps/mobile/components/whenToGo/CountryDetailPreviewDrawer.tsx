import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  Pressable,
  TouchableOpacity,
  ScrollView,
  useWindowDimensions,
  ImageBackground,
} from 'react-native';
import { router } from 'expo-router';
import { getScoreColor } from '../../utils/seasonColor';
import { useTheme } from '../../hooks/useTheme';
import ScrapbookCard from '../theme/ScrapbookCard';
import { WhenToGoItem } from '../../utils/whenToGoLogic';

type Props = {
  visible: boolean;
  onClose: () => void;
  country: WhenToGoItem | null;
  selectedMonth: number;
};

export default function CountryDetailPreviewDrawer({
  visible,
  onClose,
  country,
  selectedMonth,
}: Props) {
  const colors = useTheme();
  const { height } = useWindowDimensions();
  const resolvedCountry = country?.country;

  const score = resolvedCountry?.facts?.scoreTotal ?? resolvedCountry?.score ?? 0;
  const seasonality = resolvedCountry?.facts?.seasonality ?? 0;
  const bestMonths =
    resolvedCountry?.facts?.fmSeasonalityBestMonths ??
    resolvedCountry?.seasonalityBestMonths ??
    [];
  const seasonalityNotes =
    resolvedCountry?.facts?.fmSeasonalityNotes ??
    resolvedCountry?.seasonalityNotes ??
    'Monthly conditions, weather rhythm, and crowd levels all shape the best timing for this stop.';
  const monthName = new Date(2026, Math.max(selectedMonth - 1, 0), 1).toLocaleString('en-US', {
    month: 'long',
  });

  const scoreColors = getScoreColor(score);
  const seasonalityColors = getScoreColor(seasonality);

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

        <ScrapbookCard
          style={styles.drawerShell}
          innerStyle={[
            styles.drawer,
            {
              backgroundColor: colors.card,
              maxHeight: height * 0.82,
            },
          ]}
        >
          <View style={styles.dragIndicator} />
          <ImageBackground
            source={require('../../assets/scrapbook/travel5.png')}
            style={styles.background}
            imageStyle={styles.backgroundImage}
          >
          <View style={styles.backgroundTint} />
          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.contentWrap}
            showsVerticalScrollIndicator={false}
          >
              <ScrapbookCard
                innerStyle={[
                  styles.headerCard,
                  { backgroundColor: `${colors.paperAlt}F2`, borderColor: colors.border },
                ]}
              >
                <View style={styles.headerRow}>
                  <View style={styles.headerTextWrap}>
                    <Text style={[styles.countryName, { color: colors.textPrimary }]}>
                      {resolvedCountry?.name} {resolvedCountry?.flagEmoji}
                    </Text>
                    {!!resolvedCountry?.region && (
                      <Text style={[styles.region, { color: colors.textMuted }]}>
                        {resolvedCountry?.region}
                      </Text>
                    )}
                  </View>

                  <View style={styles.overallWrap}>
                    <View
                      style={[
                        styles.scorePill,
                        {
                          backgroundColor: scoreColors.background,
                          borderColor: colors.border,
                        },
                      ]}
                    >
                      <Text style={[styles.scoreText, { color: scoreColors.text }]}>
                        {score}
                      </Text>
                    </View>
                    <Text style={[styles.overallLabel, { color: colors.textMuted }]}>
                      Overall
                    </Text>
                  </View>
                </View>
              </ScrapbookCard>

              <ScrapbookCard
                innerStyle={[
                  styles.insightCard,
                  { backgroundColor: `${colors.paperAlt}EE`, borderColor: colors.border },
                ]}
              >
                <View style={styles.insightHeader}>
                  <View style={styles.insightTitleWrap}>
                    <Text style={[styles.insightTitle, { color: colors.textPrimary }]}>
                      {monthName} conditions
                    </Text>
                    <Text style={[styles.insightSubtitle, { color: colors.textMuted }]}>
                      Monthly conditions
                    </Text>
                  </View>

                  <View
                    style={[
                      styles.scorePill,
                      {
                        backgroundColor: seasonalityColors.background,
                        borderColor: colors.border,
                      },
                    ]}
                  >
                    <Text
                      style={[
                        styles.scoreText,
                        { color: seasonalityColors.text },
                      ]}
                    >
                      {seasonality}
                    </Text>
                  </View>
                </View>

                <Text style={[styles.insightBody, { color: colors.textPrimary }]}>
                  {seasonalityNotes}
                </Text>

                {bestMonths.length ? (
                  <View style={styles.bestMonthsWrap}>
                    <Text style={[styles.bestMonthsLabel, { color: colors.textMuted }]}>
                      Best months
                    </Text>
                    <View style={styles.monthChipWrap}>
                      {bestMonths.map((month: string | number) => {
                        const numericMonth = Number(month);
                        const shortLabel = Number.isFinite(numericMonth)
                          ? new Date(2026, numericMonth - 1, 1).toLocaleString('en-US', { month: 'short' })
                          : String(month);
                        return (
                          <View
                            key={`${resolvedCountry?.iso2}-${month}`}
                            style={[
                              styles.monthChip,
                              { backgroundColor: colors.surface, borderColor: colors.border },
                            ]}
                          >
                            <Text style={[styles.monthChipText, { color: colors.textPrimary }]}>
                              {shortLabel}
                            </Text>
                          </View>
                        );
                      })}
                    </View>
                  </View>
                ) : null}
              </ScrapbookCard>

              <TouchableOpacity
                style={[styles.ctaButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
                onPress={handleNavigate}
              >
                <Text style={[styles.ctaText, { color: colors.textPrimary }]}>
                  View full country details
                </Text>
              </TouchableOpacity>
          </ScrollView>
          </ImageBackground>
        </ScrapbookCard>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalContainer: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(33,21,13,0.34)',
  },
  background: {
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    overflow: 'hidden',
  },
  backgroundImage: {
    resizeMode: 'cover',
  },
  backgroundTint: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(247, 242, 232, 0.18)',
  },
  scrollView: {
    flexGrow: 0,
  },
  drawer: {
    paddingTop: 14,
    paddingHorizontal: 0,
    paddingBottom: 18,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
  },
  drawerShell: {
    marginHorizontal: 12,
  },
  dragIndicator: {
    alignSelf: 'center',
    width: 40,
    height: 4,
    borderRadius: 2,
    backgroundColor: 'rgba(130, 111, 90, 0.28)',
    marginBottom: 8,
  },
  contentWrap: {
    paddingHorizontal: 14,
    paddingBottom: 10,
    gap: 12,
  },
  headerCard: {
    padding: 18,
    borderWidth: 1,
    borderRadius: 22,
  },
  headerTextWrap: {
    flex: 1,
    marginRight: 14,
  },
  overallWrap: {
    alignItems: 'center',
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  countryName: {
    fontSize: 20,
    fontWeight: '700',
  },
  scorePill: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
  },
  scoreText: {
    fontWeight: '700',
    fontSize: 16,
  },
  region: {
    marginTop: 4,
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.4,
  },
  overallLabel: {
    marginTop: 4,
    fontSize: 11,
    fontWeight: '600',
  },
  insightCard: {
    padding: 18,
    borderWidth: 1,
    borderRadius: 22,
  },
  insightHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12,
  },
  insightTitleWrap: {
    flex: 1,
  },
  insightTitle: {
    fontSize: 17,
    fontWeight: '700',
  },
  insightSubtitle: {
    marginTop: 3,
    fontSize: 12,
  },
  insightBody: {
    marginTop: 14,
    fontSize: 14,
    lineHeight: 20,
  },
  bestMonthsWrap: {
    marginTop: 16,
  },
  bestMonthsLabel: {
    fontSize: 12,
    marginBottom: 8,
  },
  monthChipWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  monthChip: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  monthChipText: {
    fontSize: 12,
    fontWeight: '600',
  },
  ctaButton: {
    paddingVertical: 16,
    borderRadius: 20,
    alignItems: 'center',
    borderWidth: 1,
  },
  ctaText: {
    fontWeight: '700',
    fontSize: 15,
  },
});
