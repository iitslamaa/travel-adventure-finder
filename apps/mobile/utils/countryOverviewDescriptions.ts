import localizable from '../../ios/TravelScoreriOS/App/Resources/Localizable.xcstrings';

type CountryDescriptionInput = {
  iso2?: string | null;
  name?: string | null;
  region?: string | null;
  subregion?: string | null;
};

function currentLocaleIdentifier() {
  const resolvedLocale =
    typeof Intl !== 'undefined'
      ? Intl.DateTimeFormat().resolvedOptions().locale
      : undefined;
  const navigatorLocale =
    typeof navigator !== 'undefined'
      ? (navigator.languages?.[0] ?? navigator.language)
      : undefined;

  return resolvedLocale ?? navigatorLocale ?? 'en';
}

function localizationCandidates(localeIdentifier: string) {
  const normalized = localeIdentifier.replace(/_/g, '-');
  const lower = normalized.toLowerCase();
  const candidates: string[] = [];

  const append = (candidate: string) => {
    if (!candidates.includes(candidate)) {
      candidates.push(candidate);
    }
  };

  if (lower.startsWith('pt')) append('pt-BR');
  if (lower.startsWith('fr')) append('fr');
  if (lower.startsWith('es')) append('es');
  if (lower.startsWith('de')) append('de');
  if (lower.startsWith('it')) append('it');
  if (lower.startsWith('nl')) append('nl');
  if (lower.startsWith('ar')) append('ar');
  if (lower.startsWith('ja')) append('ja');
  if (lower.startsWith('ko')) append('ko');
  if (
    lower.includes('hant') ||
    lower.startsWith('zh-tw') ||
    lower.startsWith('zh-hk') ||
    lower.startsWith('zh-mo')
  ) {
    append('zh-Hant');
  }
  if (lower.startsWith('zh')) append('zh-Hans');
  if (lower.startsWith('ru')) append('ru');
  if (lower.startsWith('hi')) append('hi');
  if (lower.startsWith('tr')) append('tr');
  if (lower.startsWith('pl')) append('pl');
  if (lower.startsWith('he') || lower.startsWith('iw')) append('he');
  if (lower.startsWith('sv')) append('sv');
  if (lower.startsWith('fi')) append('fi');
  if (lower.startsWith('da')) append('da');
  if (lower.startsWith('el')) append('el');
  if (lower.startsWith('id')) append('id');
  if (lower.startsWith('uk')) append('uk');
  if (lower.startsWith('ms')) append('ms');
  if (lower.startsWith('ro')) append('ro');
  if (lower.startsWith('th')) append('th');
  if (lower.startsWith('vi')) append('vi');
  if (lower.startsWith('cs')) append('cs');
  if (lower.startsWith('hu')) append('hu');
  if (lower.startsWith('nb') || lower.startsWith('no')) append('nb');
  if (lower.startsWith('ca')) append('ca');
  if (lower.startsWith('hr')) append('hr');
  if (lower.startsWith('sk')) append('sk');
  if (lower.startsWith('en')) append('en');

  const languagePart = normalized.split('-')[0];
  if (languagePart) append(languagePart);
  append(normalized);
  append('en');

  return candidates;
}

function localizedDescription(iso2: string, localeIdentifier: string) {
  const key = `country.description.${iso2.trim().toLowerCase()}`;
  const entry = localizable.strings?.[key];

  for (const locale of localizationCandidates(localeIdentifier)) {
    const value = entry?.localizations?.[locale]?.stringUnit?.value?.trim();
    if (value) return value;
  }

  return undefined;
}

function fallbackDescription(country: CountryDescriptionInput) {
  const name = country.name?.trim() || 'This destination';
  const label = [country.subregion, country.region].filter(Boolean).join(', ');

  if (label) {
    return `${name} is part of ${label}. This entry is missing its full custom description in the current app dataset, but the country detail view is still available while the description list is being completed.`;
  }

  return `${name} is included in the app's country dataset. This entry is missing its full custom description in the current app dataset, but the country detail view is still available while the description list is being completed.`;
}

export function countryOverviewDescription(
  country: CountryDescriptionInput,
  localeIdentifier = currentLocaleIdentifier()
) {
  const iso2 = country.iso2?.trim();
  if (!iso2) return fallbackDescription(country);

  return localizedDescription(iso2, localeIdentifier) ?? fallbackDescription(country);
}
