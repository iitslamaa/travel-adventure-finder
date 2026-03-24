export const requiredLocales = [
  "en",
  "es",
  "fr",
  "de",
  "it",
  "pt-BR",
  "ru",
  "nl",
  "ar",
  "ja",
  "ko",
  "zh-Hans",
  "hi",
  "tr",
  "pl",
  "he",
  "sv",
  "fi",
  "da",
  "el",
  "id",
  "uk",
  "zh-Hant",
  "ms",
  "ro",
  "th",
  "vi",
  "cs",
  "hu",
  "nb",
  "ca",
  "hr",
  "sk",
];

export const machineTranslationLocales = [
];

const machineTranslationLocaleSet = new Set(machineTranslationLocales);

export function localizedStringState(locale) {
  return machineTranslationLocaleSet.has(locale) ? "needs_review" : "translated";
}
