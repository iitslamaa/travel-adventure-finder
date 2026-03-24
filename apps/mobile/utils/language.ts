export function formatLanguageName(value: unknown) {
  if (typeof value !== 'string') return null;

  const trimmed = value.trim();
  if (!trimmed) return null;

  return trimmed
    .split(/\s+/)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

export function formatLanguageList(languages: unknown) {
  if (!Array.isArray(languages) || languages.length === 0) return '—';

  const formatted = languages
    .map((language: any) =>
      formatLanguageName(typeof language === 'string' ? language : language?.name)
    )
    .filter(Boolean);

  return formatted.length ? formatted.join(' · ') : '—';
}

export function normalizeLanguageDraft(languages: unknown) {
  if (!Array.isArray(languages)) return [];

  return languages
    .map(language => {
      if (typeof language === 'string') {
        return formatLanguageName(language);
      }

      if (language && typeof language === 'object') {
        const formattedName = formatLanguageName((language as any).name);
        if (!formattedName) return null;
        return {
          ...(language as Record<string, unknown>),
          name: formattedName,
        };
      }

      return null;
    })
    .filter(Boolean);
}
