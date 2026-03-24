import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import { useAuth } from './AuthContext';
import { supabase } from '../lib/supabase';

export type ScoreWeights = {
  advisory: number;
  seasonality: number;
  visa: number;
  affordability: number;
  language: number;
};

export type WeightPreset = {
  id: string;
  title: string;
  description: string;
  weights: ScoreWeights;
};

const STORAGE_KEY = 'travelaf-score-preferences-v1';
export const DEFAULT_SCORE_WEIGHTS: ScoreWeights = {
  advisory: 0.2,
  seasonality: 0.2,
  visa: 0.2,
  affordability: 0.2,
  language: 0.2,
};

export const WEIGHT_PRESETS: WeightPreset[] = [
  {
    id: 'balanced',
    title: 'Balanced',
    description: 'Keeps all five travel signals equally weighted.',
    weights: DEFAULT_SCORE_WEIGHTS,
  },
  {
    id: 'budget',
    title: 'Budget',
    description: 'Pushes cheaper destinations higher without ignoring basics.',
    weights: {
      affordability: 0.45,
      visa: 0.1,
      advisory: 0.15,
      seasonality: 0.1,
      language: 0.2,
    },
  },
  {
    id: 'easy-travel',
    title: 'Easy Travel',
    description: 'Prioritizes language and visa simplicity.',
    weights: {
      affordability: 0.1,
      visa: 0.3,
      advisory: 0.2,
      seasonality: 0.1,
      language: 0.3,
    },
  },
  {
    id: 'safety-first',
    title: 'Safety First',
    description: 'Heavily favors lower advisory risk.',
    weights: {
      affordability: 0.1,
      visa: 0.15,
      advisory: 0.5,
      seasonality: 0.1,
      language: 0.15,
    },
  },
];

type ScorePreferencesContextValue = {
  weights: ScoreWeights;
  selectedMonth: number;
  loading: boolean;
  setSelectedMonth: (month: number) => void;
  savePreferences: (input: {
    weights: ScoreWeights;
    selectedMonth: number;
  }) => Promise<void>;
  resetToDefault: () => Promise<void>;
};

const ScorePreferencesContext = createContext<
  ScorePreferencesContextValue | undefined
>(undefined);

function normalizeWeights(weights: ScoreWeights): ScoreWeights {
  const sum = Object.values(weights).reduce((total, value) => {
    const safeValue = Number.isFinite(value) ? Math.max(value, 0) : 0;
    return total + safeValue;
  }, 0);

  if (sum <= 0) {
    return DEFAULT_SCORE_WEIGHTS;
  }

  return {
    advisory: weights.advisory / sum,
    seasonality: weights.seasonality / sum,
    visa: weights.visa / sum,
    affordability: weights.affordability / sum,
    language: weights.language / sum,
  };
}

export function ScorePreferencesProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const { session } = useAuth();
  const [weights, setWeights] = useState<ScoreWeights>(DEFAULT_SCORE_WEIGHTS);
  const [selectedMonth, setSelectedMonthState] = useState(new Date().getMonth());
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      setLoading(true);

      try {
        const localValue = await AsyncStorage.getItem(STORAGE_KEY);
        if (localValue && !cancelled) {
          const parsed = JSON.parse(localValue) as {
            weights?: Partial<ScoreWeights>;
            selectedMonth?: number;
          };

          if (parsed.weights) {
            setWeights(
              normalizeWeights({
                advisory: parsed.weights.advisory ?? DEFAULT_SCORE_WEIGHTS.advisory,
                seasonality:
                  parsed.weights.seasonality ?? DEFAULT_SCORE_WEIGHTS.seasonality,
                visa: parsed.weights.visa ?? DEFAULT_SCORE_WEIGHTS.visa,
                affordability:
                  parsed.weights.affordability ?? DEFAULT_SCORE_WEIGHTS.affordability,
                language: parsed.weights.language ?? DEFAULT_SCORE_WEIGHTS.language,
              })
            );
          }

          if (typeof parsed.selectedMonth === 'number') {
            setSelectedMonthState(Math.min(Math.max(parsed.selectedMonth, 0), 11));
          }
        }

        if (session?.user?.id) {
          const { data } = await supabase
            .from('user_score_preferences')
            .select('advisory, seasonality, visa, affordability, language')
            .eq('user_id', session.user.id)
            .maybeSingle();

          if (data && !cancelled) {
            setWeights(
              normalizeWeights({
                advisory: data.advisory ?? DEFAULT_SCORE_WEIGHTS.advisory,
                seasonality: data.seasonality ?? DEFAULT_SCORE_WEIGHTS.seasonality,
                visa: data.visa ?? DEFAULT_SCORE_WEIGHTS.visa,
                affordability:
                  data.affordability ?? DEFAULT_SCORE_WEIGHTS.affordability,
                language: data.language ?? DEFAULT_SCORE_WEIGHTS.language,
              })
            );
          }
        }
      } catch (error) {
        console.error('Failed to load score preferences', error);
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    load();

    return () => {
      cancelled = true;
    };
  }, [session?.user?.id]);

  const persistLocal = useCallback(
    async (nextWeights: ScoreWeights, nextMonth: number) => {
      await AsyncStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          weights: nextWeights,
          selectedMonth: nextMonth,
        })
      );
    },
    []
  );

  const savePreferences = useCallback(
    async ({
      weights: draftWeights,
      selectedMonth: draftMonth,
    }: {
      weights: ScoreWeights;
      selectedMonth: number;
    }) => {
      const normalized = normalizeWeights(draftWeights);
      const clampedMonth = Math.min(Math.max(draftMonth, 0), 11);

      setWeights(normalized);
      setSelectedMonthState(clampedMonth);
      await persistLocal(normalized, clampedMonth);

      if (!session?.user?.id) {
        return;
      }

      const { error } = await supabase.from('user_score_preferences').upsert({
        user_id: session.user.id,
        advisory: normalized.advisory,
        seasonality: normalized.seasonality,
        visa: normalized.visa,
        affordability: normalized.affordability,
        language: normalized.language,
      });

      if (error) {
        console.error('Failed to save remote score preferences', error);
      }
    },
    [persistLocal, session?.user?.id]
  );

  const resetToDefault = useCallback(async () => {
    await savePreferences({
      weights: DEFAULT_SCORE_WEIGHTS,
      selectedMonth,
    });
  }, [savePreferences, selectedMonth]);

  const setSelectedMonth = useCallback((month: number) => {
    setSelectedMonthState(Math.min(Math.max(month, 0), 11));
  }, []);

  const value = useMemo(
    () => ({
      weights,
      selectedMonth,
      loading,
      setSelectedMonth,
      savePreferences,
      resetToDefault,
    }),
    [loading, resetToDefault, savePreferences, selectedMonth, setSelectedMonth, weights]
  );

  return (
    <ScorePreferencesContext.Provider value={value}>
      {children}
    </ScorePreferencesContext.Provider>
  );
}

export function useScorePreferences() {
  const context = useContext(ScorePreferencesContext);
  if (!context) {
    throw new Error('useScorePreferences must be used within ScorePreferencesProvider');
  }
  return context;
}

