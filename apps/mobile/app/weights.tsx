import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
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
  percentage,
  colors,
  onChange,
  children,
}: {
  label: string;
  value: number;
  percentage: number;
  colors: ReturnType<typeof useTheme>;
  onChange: (value: number) => void;
  children?: React.ReactNode;
}) {
  const decreaseDisabled = value <= 0;
  const increaseDisabled = value >= 1;

  return (
    <View style={styles.sliderBlock}>
      <View style={styles.sliderHeader}>
        <Text style={styles.sliderTitle}>
          {label}
        </Text>
        <Text style={styles.sliderValue}>
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
    excludeVisitedCountries,
    loading,
    savePreferences,
  } = useScorePreferences();
  const [draftWeights, setDraftWeights] = useState<ScoreWeights>(weights);
  const [draftMonth, setDraftMonth] = useState(selectedMonth);
  const [draftExcludeVisitedCountries, setDraftExcludeVisitedCountries] =
    useState(excludeVisitedCountries);
  const [saving, setSaving] = useState(false);
  const [hasSaved, setHasSaved] = useState(false);

  const normalizedDraft = useMemo(() => normalize(draftWeights), [draftWeights]);
  const totalWeight = useMemo(
    () => Object.values(draftWeights).reduce((total, value) => total + value, 0),
    [draftWeights]
  );
  const isZeroSum = totalWeight <= 0.0001;
  const isDirty =
    JSON.stringify(normalizedDraft) !== JSON.stringify(weights) ||
    draftMonth !== selectedMonth ||
    draftExcludeVisitedCountries !== excludeVisitedCountries;

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
        excludeVisitedCountries: draftExcludeVisitedCountries,
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
    <ImageBackground
      source={require('../assets/scrapbook/travel1.png')}
      style={styles.background}
      imageStyle={styles.backgroundImage}
    >
      <View style={styles.backgroundTint} />
      <Pressable
        onPress={() => router.back()}
        style={[
          styles.closeButton,
          {
            top: insets.top + 12,
          },
        ]}
      >
        <Text style={styles.closeText}>×</Text>
      </Pressable>
      <ScrollView
        style={{ flex: 1, backgroundColor: 'transparent' }}
        contentContainerStyle={{
          paddingTop: insets.top + 18,
          paddingHorizontal: 20,
          paddingBottom: insets.bottom + 36,
        }}
        showsVerticalScrollIndicator={false}
      >
          <View
            style={[
              styles.bannerCard,
              styles.simpleCard,
            ]}
          >
            <Text style={styles.bannerTitle}>
              Travel Preferences
            </Text>
            <Text style={styles.bannerSubtitle}>
              Your selected weights determine how Travelability Scores are calculated throughout the app. Rankings update after you save.
            </Text>
          </View>

          <View
            style={[
              styles.sectionCard,
              styles.simpleCard,
            ]}
          >
            <Text style={styles.sectionTitle}>
              Quick Presets
            </Text>
            <View style={styles.presetGrid}>
              {WEIGHT_PRESETS.map(preset => (
                <Pressable
                  key={preset.id}
                  onPress={() => applyPreset(preset.weights)}
                  style={[styles.presetCard]}
                >
                  <Text style={styles.presetTitle}>
                    {preset.title}
                  </Text>
                </Pressable>
              ))}
            </View>
          </View>

          <View
            style={[
              styles.sectionCard,
              styles.simpleCard,
            ]}
          >
            <Text style={styles.sectionTitle}>
              Weights
            </Text>

            {isZeroSum ? (
              <Text style={styles.errorText}>
                At least one category must have weight.
              </Text>
            ) : null}

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
                percentage={
                  totalWeight > 0
                    ? Math.round((draftWeights[key] / totalWeight) * 100)
                    : 0
                }
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
                    <Text style={styles.helperText}>
                      Uses your selected travel month. Changing it here also updates When To Go.
                    </Text>
                  </>
                ) : null}
              </WeightStepper>
            ))}
          </View>

          <View
            style={[
              styles.sectionCard,
              styles.simpleCard,
            ]}
          >
            <Text style={styles.sectionTitle}>
              Discovery Mode
            </Text>
            <View
              style={[
                styles.discoveryModeButton,
                draftExcludeVisitedCountries && styles.discoveryModeButtonSelected,
              ]}
            >
              <Pressable
                onPress={() =>
                  setDraftExcludeVisitedCountries(current => !current)
                }
                style={styles.discoveryModeCopy}
              >
                <Text style={styles.discoveryModeTitle}>Go someplace new!</Text>
                <Text style={styles.discoveryModeSubtitle}>
                  Hide countries you&apos;ve already visited across Discovery so the list, map, and seasonality views focus on new places.
                </Text>
              </Pressable>
              <Switch
                value={draftExcludeVisitedCountries}
                onValueChange={setDraftExcludeVisitedCountries}
                trackColor={{
                  false: 'rgba(0,0,0,0.16)',
                  true: 'rgba(194,122,79,0.42)',
                }}
                thumbColor={draftExcludeVisitedCountries ? colors.primary : '#f7f0e5'}
              />
            </View>
          </View>

          <View
            style={[
              styles.sectionCard,
              styles.simpleCard,
            ]}
          >
            <Text style={styles.sectionTitle}>
              Actions
            </Text>
            <View style={styles.actionStack}>
              <Pressable
                onPress={handleSave}
                disabled={!isDirty || saving || isZeroSum}
                style={[
                  styles.primaryAction,
                  {
                    backgroundColor:
                      isDirty && !isZeroSum
                        ? colors.primary
                        : 'rgba(0,0,0,0.18)',
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
                  setDraftMonth(new Date().getMonth() + 1);
                  setDraftExcludeVisitedCountries(false);
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
  closeButton: {
    position: 'absolute',
    right: 20,
    zIndex: 4,
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
    backgroundColor: 'rgba(242, 237, 224, 0.97)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.5)',
    borderRadius: 24,
    shadowColor: '#000000',
    shadowOpacity: 0.12,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 4,
  },
  bannerTitle: {
    fontSize: 32,
    fontWeight: '700',
    marginBottom: 10,
    color: '#111111',
  },
  bannerSubtitle: {
    fontSize: 15,
    lineHeight: 21,
    color: 'rgba(17,17,17,0.58)',
  },
  sectionCard: {
    padding: 20,
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 14,
    color: '#111111',
  },
  presetGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  presetCard: {
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.06)',
    borderRadius: 16,
    padding: 14,
    width: '48%',
    backgroundColor: 'rgba(245,240,224,0.96)',
  },
  presetTitle: {
    fontSize: 15,
    fontWeight: '600',
    textAlign: 'center',
    color: '#111111',
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
    color: '#111111',
  },
  sliderValue: {
    fontSize: 14,
    fontWeight: '600',
    color: 'rgba(0,0,0,0.55)',
  },
  helperText: {
    fontSize: 13,
    lineHeight: 18,
    color: 'rgba(0,0,0,0.52)',
  },
  errorText: {
    marginBottom: 12,
    fontSize: 13,
    lineHeight: 18,
    color: '#c62828',
  },
  monthRow: {
    flexDirection: 'row',
    gap: 10,
    paddingTop: 6,
  },
  monthChip: {
    borderWidth: 1,
    borderColor: 'transparent',
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
  discoveryModeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.05)',
    backgroundColor: 'rgba(0,0,0,0.04)',
    padding: 18,
  },
  discoveryModeButtonSelected: {
    borderColor: 'rgba(0,0,0,0.12)',
    backgroundColor: 'rgba(255,255,255,0.65)',
  },
  discoveryModeCopy: {
    flex: 1,
    gap: 6,
  },
  discoveryModeTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: '#111111',
  },
  discoveryModeSubtitle: {
    fontSize: 14,
    lineHeight: 20,
    color: 'rgba(0,0,0,0.6)',
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
