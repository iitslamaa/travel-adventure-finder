// lib/countryMatch.ts
import { byNameKey, COUNTRY_SEEDS } from './seed';

// Manual overrides for tricky names
const OVERRIDES: Record<string, string> = {
  // Korea / Côte d’Ivoire
  koreasouth: 'KR',
  republicofkorea: 'KR',
  ivorycoast: 'CI',
  ctedivoire: 'CI',
  coteivoire: 'CI',

  // UK and variants
  uk: 'GB',
  unitedkingdom: 'GB',

  // Bahamas / Gambia (definite articles matter)
  thebahamas: 'BS',
  bahamas: 'BS',
  thegambia: 'GM',
  gambia: 'GM',

  // Myanmar / Burma
  myanmar: 'MM',
  burma: 'MM',

  // Laos / Lao PDR
  laopeoplesdemocraticrepublic: 'LA',
  lao: 'LA',
  laos: 'LA',

  // Vatican / Holy See
  holysee: 'VA',
  vaticancity: 'VA',
  vatican: 'VA',

  // Caribbean & territories with real advisories
  belize: 'BZ',
  turksandcaicos: 'TC',
  turksandcaicosislands: 'TC',
  turkey: 'TR',

  // Eastern Europe & Balkans
  bosniaandherzegovina: 'BA',

  // Caucasus / Central Asia
  azerbaijan: 'AZ',
  kyrgyzstan: 'KG',
  kyrgyzrepublic: 'KG',

  // Middle East
  palestine: 'PS',
  palestinianterritories: 'PS',

  // Africa
  rwanda: 'RW',
  burundi: 'BI',

  // Europe microstates
  monaco: 'MC',
  sanmarino: 'SM',

  // Pacific
  solomonislands: 'SB',

  // Curaçao (diacritics often dropped)
  curacao: 'CW',

  // Åland Islands
  alandislands: 'AX',

  // US territories / abbreviations
  usvirginislands: 'VI',
  virginislandsus: 'VI',
  unitedstatesvirginislands: 'VI',
};

export function normalizeName(raw: string) {
  return raw.toLowerCase().replace(/[^a-z]/g, '');
}

function soften(raw: string) {
  // remove frequent long prefixes that appear in formal names (e.g., "Islamic Republic of Iran")
  const replacements = [
    'the',
    'republicof',
    'democraticrepublicof',
    'islamicrepublicof',
    'bolivarianrepublicof',
    'kingdomof',
    'stateof',
    'peoplesrepublicof',
    'federationof',
    'plurinationalstateof',
  ];
  let k = normalizeName(raw);
  for (const r of replacements) {
    k = k.replace(new RegExp('^' + r), ''); // drop only if it is leading
  }
  return k;
}

export function nameToIso2(raw: string): string | null {
  const key = normalizeName(raw);
  if (OVERRIDES[key]) return OVERRIDES[key];

  // direct hit on normalized name / aliases
  const hit = byNameKey.get(key);
  if (hit?.iso2) return hit.iso2;

  // try a softened form (drop leading government words)
  const soft = soften(raw);
  if (OVERRIDES[soft]) return OVERRIDES[soft];
  const softHit = byNameKey.get(soft);
  if (softHit?.iso2) return softHit.iso2;

  // last resort: STRICT substring match (guard against short-name collisions)
  for (const c of COUNTRY_SEEDS) {
    const keys = [c.name, ...(c.aliases ?? [])].map(normalizeName);

    // avoid substring matching on very short names (prevents Rwanda/Burundi bleed)
    if (key.length < 5 || soft.length < 5) continue;

    if (keys.some(k => k === key || k === soft)) {
      return c.iso2;
    }
  }

  return null;
}
