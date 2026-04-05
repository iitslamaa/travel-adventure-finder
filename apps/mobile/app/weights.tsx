import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  ImageBackground,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  DEFAULT_SCORE_WEIGHTS,
  useScorePreferences,
  WEIGHT_PRESETS,
  type ScoreWeights,
} from '../context/ScorePreferencesContext';
import { useTheme } from '../hooks/useTheme';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';

const MONTHS = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const WEIGHT_STEP = 0.05;

function normalize(weights: ScoreWeights): ScoreWeights {
  const sum = Object.values(weights).reduce((total, value) => total + value, 0);
  if (!sum) return DEFAULT_SCORE_WEIGHTS;
  return {
    advisory: weights.advisory / sum,
    seasonality: weights.seasonality / sum,
    visa: weights.visa / sum,
    affordability: weights.affordability / sum,
    language: weights.language / sum,
  };
}

function WeightStepper({
  label,
  value,
  colors,
  onChange,
  children,
}: {
  label: string;
  value: number;
  colors: ReturnType<typeof useTheme>;
  onChange: (value: number) => void;
  children?: React.ReactNode;
}) {
  const percentage = Math.round(value * 100);
  const decreaseDisabled = value <= 0;
  const increaseDisabled = value >= 1;

  return (
    <View style={styles.sliderBlock}>
      <View style={styles.sliderHeader}>
        <Text style={[styles.sliderTitle, { color: colors.textPrimary }]}>
          {label}
        </Text>
        <Text style={[styles.sliderValue, { color: colors.textSecondary }]}>
          {percentage}%
        </Text>
      </View>

      <View style={styles.adjustRow}>
        <Pressable
          onPress={() => onChange(value - WEIGHT_STEP)}
          disabled={decreaseDisabled}
          style={[
            styles.adjustButton,
            {
              backgroundColor: decreaseDisabled ? colors.surface : colors.primary,
              borderColor: colors.border,
            },
          ]}
        >
          <Text
            style={[
              styles.adjustButtonText,
              {
                color: decreaseDisabled ? colors.textSecondary : colors.primaryText,
              },
            ]}
          >
            -
          </Text>
        </Pressable>

        <View
          style={[
            styles.progressTrack,
            { backgroundColor: colors.surface, borderColor: colors.border },
          ]}
        >
          <View
            style={[
              styles.progressFill,
              {
                backgroundColor: colors.primary,
                width: `${percentage}%`,
              },
            ]}
          />
        </View>

        <Pressable
          onPress={() => onChange(value + WEIGHT_STEP)}
          disabled={increaseDisabled}
          style={[
            styles.adjustButton,
            {
              backgroundColor: increaseDisabled ? colors.surface : colors.primary,
              borderColor: colors.border,
            },
          ]}
        >
          <Text
            style={[
              styles.adjustButtonText,
              {
                color: increaseDisabled ? colors.textSecondary : colors.primaryText,
              },
            ]}
          >
            +
          </Text>
        </Pressable>
      </View>

      {children ? <View style={styles.stepperExtra}>{children}</View> : null}
    </View>
  );
}

export default function WeightsScreen() {
  const colors = useTheme();
  const insets = useSafeAreaInsets();
  const {
    weights,
    selectedMonth,
    loading,
    savePreferences,
  } = useScorePreferences();
  const [draftWeights, setDraftWeights] = useState<ScoreWeights>(weights);
  const [draftMonth, setDraftMonth] = useState(selectedMonth);
  const [saving, setSaving] = useState(false);
  const [hasSaved, setHasSaved] = useState(false);

  const normalizedDraft = useMemo(() => normalize(draftWeights), [draftWeights]);
  const isDirty =
    JSON.stringify(normalizedDraft) !== JSON.stringify(weights) ||
    draftMonth !== selectedMonth;

  const applyPreset = (presetWeights: ScoreWeights) => {
    setDraftWeights(presetWeights);
  };

  const updateWeight = (key: keyof ScoreWeights, value: number) => {
    setDraftWeights(current => ({
      ...current,
      [key]: Math.min(Math.max(value, 0), 1),
    }));
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      await savePreferences({
        weights: normalizedDraft,
        selectedMonth: draftMonth,
      });
      setHasSaved(true);
      setTimeout(() => setHasSaved(false), 1500);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <View
        style={{
          flex: 1,
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: colors.background,
        }}
      >
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  return (
    <ScrapbookBackground>
      <ImageBackground
        source={require('../assets/scrapbook/travel1.png')}
        style={styles.background}
        imageStyle={styles.backgroundImage}
      >
        <View style={styles.backgroundTint} />
        <ScrollView
          style={{ flex: 1, backgroundColor: 'transparent' }}
          contentContainerStyle={{
            paddingTop: insets.top + 18,
            paddingHorizontal: 20,
            paddingBottom: insets.bottom + 32,
          }}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.headerRow}>
            <View />
            <Pressable onPress={() => router.back()} style={styles.closeButton}>
              <Text style={[styles.closeText, { color: colors.textPrimary }]}>
                ×
              </Text>
            </Pressable>
          </View>

          <View
            style={[
              styles.bannerCard,
              styles.simpleCard,
              { backgroundColor: colors.card, borderColor: colors.border },
            ]}
          >
            <Text style={[styles.bannerTitle, { color: '#111111' }]}>
              Custom Weights
            </Text>
            <Text style={[styles.bannerSubtitle, { color: 'rgba(17,17,17,0.58)' }]}>
              Tune your discovery score blend with presets, manual weights, and a seasonality month.
            </Text>
          </View>

          <View
            style={[
              styles.sectionCard,
              styles.simpleCard,
              { backgroundColor: colors.card, borderColor: colors.border },
            ]}
          >
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              Quick Presets
            </Text>
            <View style={styles.presetGrid}>
              {WEIGHT_PRESETS.map(preset => (
                <Pressable
                  key={preset.id}
                  onPress={() => applyPreset(preset.weights)}
                  style={[
                    styles.presetCard,
                    { backgroundColor: colors.surface, borderColor: colors.border },
                  ]}
                >
                  <Text style={[styles.presetTitle, { color: colors.textPrimary }]}>
                    {preset.title}
                  </Text>
                </Pressable>
              ))}
            </View>
          </View>

          <View
            style={[
              styles.sectionCard,
              { backgroundColor: colors.card, borderColor: colors.border },
            ]}
          >
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              Weights
            </Text>

            {(
              [
                ['affordability', 'Affordability'],
                ['visa', 'Visa Ease'],
                ['advisory', 'Travel Advisory'],
                ['language', 'Language'],
                ['seasonality', 'Seasonality'],
              ] as const
            ).map(([key, label]) => (
              <WeightStepper
                key={key}
                label={label}
                value={draftWeights[key]}
                colors={colors}
                onChange={value => updateWeight(key, value)}
              >
                {key === 'seasonality' ? (
                  <>
                    <ScrollView
                      horizontal
                      showsHorizontalScrollIndicator={false}
                      contentContainerStyle={styles.monthRow}
                    >
                      {MONTHS.map((month, index) => {
                        const monthNumber = index + 1;
                        const selected = draftMonth === monthNumber;
                        return (
                          <Pressable
                            key={month}
                            onPress={() => setDraftMonth(monthNumber)}
                            style={[
                              styles.monthChip,
                              {
                                backgroundColor: selected ? 'rgba(255,255,255,0.78)' : 'transparent',
                                borderColor: selected ? 'rgba(0,0,0,0.06)' : 'transparent',
                              },
                            ]}
                          >
                            <Text
                              style={{
                                color: colors.textPrimary,
                                fontWeight: '700',
                              }}
                            >
                              {month}
                            </Text>
                          </Pressable>
                        );
                      })}
                    </ScrollView>
                    <Text style={[styles.helperText, { color: colors.textSecondary }]}>
                      Pick the month you want discovery and seasonality results to optimize around.
                    </Text>
                  </>
                ) : null}
              </WeightStepper>
            ))}

            <Text style={[styles.helperText, { color: colors.textSecondary }]}>
              Percentages auto-normalize so the final blend always sums to 100%.
            </Text>
          </View>

          <View
            style={[
              styles.sectionCard,
              { backgroundColor: colors.card, borderColor: colors.border },
            ]}
          >
            <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
              Actions
            </Text>
            <View style={styles.actionStack}>
              <Pressable
                onPress={handleSave}
                disabled={!isDirty || saving}
                style={[
                  styles.primaryAction,
                  {
                    backgroundColor: isDirty ? colors.primary : 'rgba(0,0,0,0.18)',
                  },
                ]}
              >
                {saving ? (
                  <ActivityIndicator color={colors.primaryText} />
                ) : (
                  <Text style={[styles.primaryActionText, { color: colors.primaryText }]}>
                    {hasSaved ? 'Saved' : 'Save Preferences'}
                  </Text>
                )}
              </Pressable>

              <Pressable
                onPress={() => {
                  setDraftWeights(DEFAULT_SCORE_WEIGHTS);
                  setDraftMonth(selectedMonth);
                }}
                style={[styles.secondaryAction, { backgroundColor: 'rgba(0,0,0,0.06)' }]}
              >
                <Text style={[styles.secondaryActionText, { color: colors.textPrimary }]}>
                  Reset to Default
                </Text>
              </Pressable>
            </View>
          </View>
        </ScrollView>
      </ImageBackground>
    </ScrapbookBackground>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
  },
  backgroundImage: {
    resizeMode: 'cover',
  },
  backgroundTint: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.12)',
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  closeButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(245,238,226,0.96)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.06)',
  },
  closeText: {
    fontSize: 24,
    lineHeight: 24,
    fontWeight: '500',
    marginTop: -2,
  },
  bannerCard: {
    padding: 22,
    marginBottom: 20,
  },
  simpleCard: {
    borderWidth: 1,
    borderRadius: 24,
    shadowColor: '#000000',
    shadowOpacity: 0.08,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
    elevation: 3,
  },
  bannerTitle: {
    fontSize: 32,
    fontWeight: '700',
    marginBottom: 10,
  },
  bannerSubtitle: {
    fontSize: 15,
    lineHeight: 21,
  },
  sectionCard: {
    padding: 20,
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 14,
  },
  presetGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  presetCard: {
    borderWidth: 1,
    borderRadius: 16,
    padding: 14,
    width: '48%',
  },
  presetTitle: {
    fontSize: 15,
    fontWeight: '600',
    textAlign: 'center',
  },
  sliderBlock: {
    marginBottom: 18,
  },
  adjustRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  adjustButton: {
    width: 42,
    height: 42,
    borderRadius: 14,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  adjustButtonText: {
    fontSize: 22,
    fontWeight: '700',
    lineHeight: 24,
  },
  progressTrack: {
    flex: 1,
    height: 12,
    borderRadius: 999,
    borderWidth: 1,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 999,
  },
  sliderHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sliderTitle: {
    fontSize: 15,
    fontWeight: '700',
  },
  sliderValue: {
    fontSize: 14,
    fontWeight: '600',
  },
  helperText: {
    fontSize: 13,
    lineHeight: 18,
  },
  monthRow: {
    flexDirection: 'row',
    gap: 10,
    paddingTop: 6,
  },
  monthChip: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  stepperExtra: {
    marginTop: 12,
  },
  actionStack: {
    gap: 12,
  },
  primaryAction: {
    minHeight: 54,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  primaryActionText: {
    fontSize: 17,
    fontWeight: '700',
  },
  secondaryAction: {
    minHeight: 54,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  secondaryActionText: {
    fontSize: 17,
    fontWeight: '700',
  },
});
