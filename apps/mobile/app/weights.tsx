import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import Slider from '@react-native-community/slider';
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
      Alert.alert('Saved', 'Your score preferences are now active.');
      router.back();
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
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.background }}
      contentContainerStyle={{
        paddingTop: insets.top + 18,
        paddingHorizontal: 20,
        paddingBottom: insets.bottom + 32,
      }}
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.headerRow}>
        <Pressable onPress={() => router.back()}>
          <Text style={[styles.backText, { color: colors.textPrimary }]}>
            Back
          </Text>
        </Pressable>
        <Pressable
          onPress={handleSave}
          disabled={!isDirty || saving}
          style={[
            styles.saveButton,
            {
              backgroundColor: isDirty ? colors.primary : colors.border,
            },
          ]}
        >
          {saving ? (
            <ActivityIndicator color={colors.primaryText} />
          ) : (
            <Text style={[styles.saveText, { color: colors.primaryText }]}>
              Save
            </Text>
          )}
        </Pressable>
      </View>

      <Text style={[styles.title, { color: colors.textPrimary }]}>
        Custom Weights
      </Text>
      <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
        Tune discovery scores the same way the Swift app does: presets, manual
        sliders, and a seasonality month.
      </Text>

      <View
        style={[
          styles.sectionCard,
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
              <Text
                style={[styles.presetDescription, { color: colors.textSecondary }]}
              >
                {preset.description}
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
          <View key={key} style={styles.sliderBlock}>
            <View style={styles.sliderHeader}>
              <Text style={[styles.sliderTitle, { color: colors.textPrimary }]}>
                {label}
              </Text>
              <Text style={[styles.sliderValue, { color: colors.textSecondary }]}>
                {Math.round(normalizedDraft[key] * 100)}%
              </Text>
            </View>

            <Slider
              minimumValue={0}
              maximumValue={1}
              step={0.05}
              value={draftWeights[key]}
              minimumTrackTintColor={colors.primary}
              maximumTrackTintColor={colors.border}
              thumbTintColor={colors.primary}
              onValueChange={value => updateWeight(key, value)}
            />
          </View>
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
          Seasonality Month
        </Text>
        <View style={styles.monthWrap}>
          {MONTHS.map((month, index) => {
            const selected = draftMonth === index;
            return (
              <Pressable
                key={month}
                onPress={() => setDraftMonth(index)}
                style={[
                  styles.monthChip,
                  {
                    backgroundColor: selected ? colors.primary : colors.surface,
                    borderColor: selected ? colors.primary : colors.border,
                  },
                ]}
              >
                <Text
                  style={{
                    color: selected ? colors.primaryText : colors.textPrimary,
                    fontWeight: '700',
                  }}
                >
                  {month}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 18,
  },
  backText: {
    fontSize: 15,
    fontWeight: '600',
  },
  saveButton: {
    minWidth: 76,
    minHeight: 40,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 14,
  },
  saveText: {
    fontSize: 14,
    fontWeight: '700',
  },
  title: {
    fontSize: 28,
    fontWeight: '800',
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 8,
    marginBottom: 24,
  },
  sectionCard: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 18,
    marginBottom: 14,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '800',
    marginBottom: 14,
  },
  presetGrid: {
    gap: 10,
  },
  presetCard: {
    borderWidth: 1,
    borderRadius: 16,
    padding: 14,
  },
  presetTitle: {
    fontSize: 15,
    fontWeight: '700',
    marginBottom: 4,
  },
  presetDescription: {
    fontSize: 13,
    lineHeight: 18,
  },
  sliderBlock: {
    marginBottom: 16,
  },
  sliderHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
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
  monthWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  monthChip: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
});
