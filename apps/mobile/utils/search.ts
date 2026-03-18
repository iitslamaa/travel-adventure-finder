const SEARCH_CHAR_REPLACEMENTS: Record<string, string> = {
  ae: 'ae',
  oe: 'oe',
  ss: 'ss',
  o: 'o',
  d: 'd',
  l: 'l',
  i: 'i',
};

const SEARCH_CHAR_VARIANTS: Record<string, string> = {
  æ: SEARCH_CHAR_REPLACEMENTS.ae,
  œ: SEARCH_CHAR_REPLACEMENTS.oe,
  ß: SEARCH_CHAR_REPLACEMENTS.ss,
  ø: SEARCH_CHAR_REPLACEMENTS.o,
  đ: SEARCH_CHAR_REPLACEMENTS.d,
  ł: SEARCH_CHAR_REPLACEMENTS.l,
  ı: SEARCH_CHAR_REPLACEMENTS.i,
};

export function normalizeForSearch(value: string): string {
  return Array.from(value.toLowerCase())
    .map((char) => SEARCH_CHAR_VARIANTS[char] ?? char)
    .join('')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]/g, '');
}
