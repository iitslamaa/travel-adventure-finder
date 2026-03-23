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
];

export const machineTranslationLocales = [
  "nl",
  "ar",
  "ja",
  "ko",
  "zh-Hans",
];

const machineTranslationLocaleSet = new Set(machineTranslationLocales);

export function localizedStringState(locale) {
  return machineTranslationLocaleSet.has(locale) ? "needs_review" : "translated";
}
