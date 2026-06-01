import languageCatalog from '../data/global_languages.json';

type LanguageCatalogEntry = {
  code?: string;
  base?: string;
  displayName?: string;
};

const languageEntries = languageCatalog as LanguageCatalogEntry[];

const languageByCode = new Map<string, LanguageCatalogEntry>();
const languageByTravelCode = new Map<string, LanguageCatalogEntry>();
const languageByDisplayName = new Map<string, LanguageCatalogEntry>();

function normalizeLanguageLookup(value: unknown) {
  return String(value ?? '')
    .trim()
    .replace(/_/g, ' ')
    .toLowerCase();
}

languageEntries.forEach(language => {
  const codeKey = normalizeLanguageLookup(language.code);
  if (codeKey) {
    languageByCode.set(codeKey, language);
  }

  const travelKey = normalizeLanguageLookup(language.base);
  if (travelKey && !languageByTravelCode.has(travelKey)) {
    languageByTravelCode.set(travelKey, language);
  }

  const displayKey = normalizeLanguageLookup(language.displayName);
  if (displayKey && !languageByDisplayName.has(displayKey)) {
    languageByDisplayName.set(displayKey, language);
  }
});

export function formatLanguageName(value: unknown) {
  if (typeof value !== 'string') return null;

  const trimmed = value.trim();
  if (!trimmed) return null;

  const normalized = normalizeLanguageLookup(trimmed);
  const catalogMatch =
    languageByCode.get(normalized) ??
    languageByTravelCode.get(normalized) ??
    languageByDisplayName.get(normalized);
  if (catalogMatch?.displayName) {
    return catalogMatch.displayName;
  }

  return trimmed
    .split(/\s+/)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

export function normalizeProficiency(value: unknown) {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (normalized === 'fluent' || normalized === 'native' || normalized === 'advanced') {
    return 'fluent';
  }
  if (normalized === 'conversational' || normalized === 'intermediate') {
    return 'conversational';
  }
  return 'beginner';
}

export function proficiencyLabel(value: unknown) {
  switch (normalizeProficiency(value)) {
    case 'fluent':
      return 'Fluent';
    case 'conversational':
      return 'Conversational';
    default:
      return 'Beginner';
  }
}

export function formatLanguageEntries(languages: unknown) {
  if (!Array.isArray(languages)) return [];

  return languages
    .map((language: any) => {
      if (typeof language === 'string') {
        const name = formatLanguageName(language);
        return name ? { name, proficiency: 'Fluent' } : null;
      }

      const name = formatLanguageName(language?.name ?? language?.code);
      if (!name) return null;

      return {
        name,
        proficiency: proficiencyLabel(language?.proficiency ?? 'fluent'),
      };
    })
    .filter((entry): entry is { name: string; proficiency: string } => Boolean(entry));
}

export function formatLanguageList(languages: unknown) {
  const entries = formatLanguageEntries(languages);
  if (entries.length === 0) return '—';

  return entries.map(entry => `${entry.name} — ${entry.proficiency}`).join(', ');
}

export function normalizeLanguageDraft(languages: unknown) {
  if (!Array.isArray(languages)) return [];

  return languages
    .map(language => {
      if (typeof language === 'string') {
        return formatLanguageName(language);
      }

      if (language && typeof language === 'object') {
        const formattedName = formatLanguageName((language as any).name ?? (language as any).code);
        if (!formattedName) return null;
        return {
          ...(language as Record<string, unknown>),
          name: formattedName,
          proficiency: normalizeProficiency((language as any).proficiency),
        };
      }

      return null;
    })
    .filter(Boolean);
}
