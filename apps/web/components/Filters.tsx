'use client';
import { useState, useEffect } from 'react';
import { DEFAULT_WEIGHTS } from '@travel-af/domain';
import type { ScoreWeights } from '@travel-af/domain/src/scoring';

// Derive a safe key type from DEFAULT_WEIGHTS so our slider keys are checked
type WeightMap = typeof DEFAULT_WEIGHTS;
type WeightKey = Extract<keyof WeightMap, string>;

type Props = { onChange: (w: ScoreWeights, month: number, tags: string[]) => void };

export default function Filters({ onChange }: Props) {
  const [w, setW] = useState<WeightMap>({ ...DEFAULT_WEIGHTS });
  const [month, setMonth] = useState<number>(new Date().getMonth() + 1);
  const [tags, setTags] = useState<string[]>([]);

  // Kick an initial compute on mount
  useEffect(() => {
    onChange(w as ScoreWeights, month, tags);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const updateWeight = (k: WeightKey, v: number) => {
    const next = { ...w, [k]: v } as WeightMap;
    setW(next);
    onChange(next as ScoreWeights, month, tags);
  };

  const updateMonth = (v: number) => {
    setMonth(v);
    onChange(w as ScoreWeights, v, tags);
  };

  const toggleTag = (t: string) => {
    const next = tags.includes(t) ? tags.filter((x) => x !== t) : [...tags, t];
    setTags(next);
    onChange(w as ScoreWeights, month, next);
  };

  const slider = (label: string, key: WeightKey) => (
    <div className="mb-3">
      <label className="block text-sm font-medium mb-1">
        {label}: {(w[key] * 100).toFixed(0)}%
      </label>
      <input
        type="range"
        min={0}
        max={0.4}
        step={0.01}
        value={w[key]}
        onChange={(e) => updateWeight(key, Number(e.target.value))}
        className="w-full"
      />
    </div>
  );

  const TAGS = ['food', 'nature', 'activities', 'architecture', 'history'];

  return (
    <div className="p-4 bg-white/60 dark:bg-zinc-900/60 rounded-lg border border-zinc-200 dark:border-zinc-800">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          {slider('Travel.gov advisory', 'travelGov' as WeightKey)}
          {slider('Seasonality', 'seasonality' as WeightKey)}
        </div>
        <div>
          {slider('Visa', 'visa' as WeightKey)}
          {slider('Affordability', 'affordability' as WeightKey)}
          <div className="mt-4">
            <label className="block text-sm font-medium mb-1">Target Month</label>
            <input
              type="number"
              min={1}
              max={12}
              value={month}
              onChange={(e) => updateMonth(Number(e.target.value))}
              className="w-24 rounded border px-2 py-1 bg-white dark:bg-zinc-900"
            />
          </div>
        </div>
      </div>

      <div className="mt-4">
        <div className="text-sm font-medium mb-2">Filter by tags</div>
        <div className="flex flex-wrap gap-2">
          {TAGS.map((t) => (
            <button
              key={t}
              onClick={() => toggleTag(t)}
              className={`px-3 py-1 rounded-full border text-sm ${
                tags.includes(t)
                  ? 'bg-zinc-900 text-white dark:bg-white dark:text-black'
                  : 'bg-white dark:bg-zinc-900'
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
