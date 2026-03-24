type RawUserLanguage =
  | string
  | {
      code?: string | null;
      name?: string | null;
      proficiency?: string | null;
    };

type UserLanguage = {
  code: string;
  proficiency: 'beginner' | 'conversational' | 'fluent';
};

export type CountryLanguageCoverage = {
  code?: string | null;
  type?: string | null;
  coverage?: number | null;
};

const FLUENT_VALUES = new Set(['fluent', 'native', 'advanced']);
const CONVERSATIONAL_VALUES = new Set(['conversational', 'intermediate']);

function normalizeCode(value: string | null | undefined): string | null {
  const normalized = value?.trim().toLowerCase();
  return normalized ? normalized : null;
}

function normalizeProficiency(value: string | null | undefined): UserLanguage['proficiency'] {
  const normalized = value?.trim().toLowerCase() ?? '';
  if (FLUENT_VALUES.has(normalized)) return 'fluent';
  if (CONVERSATIONAL_VALUES.has(normalized)) return 'conversational';
  return 'beginner';
}

function compatibilityMultiplier(proficiency: UserLanguage['proficiency']): number {
  switch (proficiency) {
    case 'fluent':
      return 1;
    case 'conversational':
      return 0.5;
    case 'beginner':
    default:
      return 0;
  }
}

function normalizedScore(compatibility: number): number {
  if (compatibility >= 0.65) return 100;
  if (compatibility >= 0.3) return 50;
  return 0;
}

export function parseProfileLanguages(raw: unknown): UserLanguage[] {
  if (!Array.isArray(raw)) return [];

  return raw.flatMap((entry): UserLanguage[] => {
    if (typeof entry === 'string') {
      const code = normalizeCode(entry);
      return code ? [{ code, proficiency: 'fluent' }] : [];
    }

    if (!entry || typeof entry !== 'object') return [];

    const candidate = entry as Exclude<RawUserLanguage, string>;
    const code = normalizeCode(candidate.code ?? candidate.name);
    if (!code) return [];

    return [{
      code,
      proficiency: normalizeProficiency(candidate.proficiency),
    }];
  });
}

export function computeLanguageCompatibilityScore(
  userLanguages: UserLanguage[],
  countryLanguages: CountryLanguageCoverage[] | null | undefined
): number | undefined {
  if (!userLanguages.length) return undefined;
  if (!Array.isArray(countryLanguages) || !countryLanguages.length) return undefined;

  const userLanguageMap = new Map<string, UserLanguage>();
  for (const language of userLanguages) {
    userLanguageMap.set(language.code, language);
  }

  let strongestCompatibility: number | null = null;

  for (const countryLanguage of countryLanguages) {
    const code = normalizeCode(countryLanguage.code);
    if (!code) continue;

    const userLanguage = userLanguageMap.get(code);
    if (!userLanguage) continue;

    const coverage = Number(countryLanguage.coverage);
    if (!Number.isFinite(coverage)) continue;

    const compatibility = compatibilityMultiplier(userLanguage.proficiency) * coverage;
    strongestCompatibility = strongestCompatibility == null
      ? compatibility
      : Math.max(strongestCompatibility, compatibility);
  }

  if (strongestCompatibility == null) {
    return 0;
  }

  return normalizedScore(strongestCompatibility);
}
