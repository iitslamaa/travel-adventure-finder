import { nameToIso2 } from '@/lib/countryMatch';
const WP_URL = 'https://en.wikipedia.org/wiki/Visa_requirements_for_United_States_citizens';
// --- Types & helpers for visa parsing --------------------------------------
export type VisaType =
  | 'visa_free'
  | 'voa'
  | 'evisa'
  | 'visa_required'
  | 'entry_permit'
  | 'ban';

export interface VisaRow {
  visaType: VisaType;
  allowedDays?: number;
  feeUsd?: number;
  notes?: string;
  visaRequirementText?: string;
  allowedStayText?: string;
  sourceUrl: string;
  visaEase: number | null; // 0..100 or null if unknown
}

// Parse durations like "90 days", "3 months", "1 year", "2 weeks" into days
function parseDays(text?: string | null): number | undefined {
  const s = (text || '').toLowerCase();
  if (!s) return undefined;

  // days
  let m = s.match(/(\d{1,4})\s*day/);
  if (m) return Number(m[1]);

  // weeks
  m = s.match(/(\d{1,3})\s*week/);
  if (m) return Number(m[1]) * 7;

  // months (approx)
  m = s.match(/(\d{1,2})\s*month/);
  if (m) return Number(m[1]) * 30;

  // years
  m = s.match(/(\d{1,2})\s*year/);
  if (m) return Number(m[1]) * 365;

  return undefined;
}

// Score mapping for visa ease (0..100) with simple fee-aware adjustments
function scoreFor(visaType: VisaType, feeUsd?: number): number | null {
  switch (visaType) {
    case 'visa_free':
      return 100;
    case 'voa':
      return feeUsd && feeUsd > 0 ? 75 : 90;
    case 'evisa':
      // If no reliable fee info, treat as unknown instead of neutral 50
      if (feeUsd == null) return null;
      return feeUsd > 0 ? 35 : 90;
    case 'visa_required':
      return 30;
    case 'ban':
      return 0;
    default:
      return null;
  }
}

function splitList(input: string): string[] {
  return input
    .split(/,| and |\//i)
    .map(s => s.trim())
    .filter(Boolean);
}

function resolveIso2Targets(name: string): string[] {
  // 1) exact match first
  const exact = nameToIso2(name);
  if (exact) return [exact.toUpperCase()];

  const results: string[] = [];

  // 2) parentheses expansion
  const paren = name.match(/\(([^)]+)\)/)?.[1];
  if (paren) {
    for (const token of splitList(paren)) {
      const iso = nameToIso2(token);
      if (iso) results.push(iso.toUpperCase());
    }
    if (results.length > 0) return [...new Set(results)];
  }

  // 3) hyphen handling (X - Y)
  const dashParts = name.split(/\s+-\s+/);
  if (dashParts.length > 1) {
    const rhs = dashParts.slice(1).join(' - ');
    for (const token of splitList(rhs)) {
      const iso = nameToIso2(token);
      if (iso) results.push(iso.toUpperCase());
    }
    // safety: if RHS resolves to none, do not map to LHS
    if (results.length > 0) return [...new Set(results)];
    return [];
  }

  // 4) token-safe contains fallback
  for (const token of splitList(name)) {
    const iso = nameToIso2(token);
    if (iso) results.push(iso.toUpperCase());
  }

  return [...new Set(results)];
}

/**
 * Parse the Wikipedia page table into a Map<ISO2, VisaRow>.
 * Target the US-citizen visa requirements wikitable and map columns accurately:
 * [0] Country | [1] Requirement | [2] Allowed stay | [3] Notes
 */
async function fetchVisaFromWikipedia(): Promise<Map<string, VisaRow>> {
  const res = await fetch(WP_URL, {
    cache: 'no-store',
  });
  if (!res.ok) throw new Error(`Visa WP fetch failed: ${res.status}`);
  const html = await res.text();

  // Select the main wikitable that contains Country + Requirement columns
  const tableMatches = [...html.matchAll(/<table[^>]*class="[^"]*wikitable[^"]*"[^>]*>([\s\S]*?)<\/table>/gi)];
  let tableHtml = '';
  for (const t of tableMatches) {
    const inner = t[1];
    const hasCountry = /<th[^>]*>\s*(Country|Territory)/i.test(inner) || /<th[^>]*>\s*Country\/?Territory/i.test(inner);
    const hasReq = /<th[^>]*>\s*(Visa requirement|Visa)/i.test(inner) || /Visa (not required|on arrival)|e-?visa|electronic travel authorization|ETA/i.test(inner);
    if (hasCountry && hasReq) { tableHtml = inner; break; }
  }

  const byIso2 = new Map<string, VisaRow>();
  if (!tableHtml) return byIso2; // structure changed – fail safe

  const rowMatches = [...tableHtml.matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/gi)];

  const clean = (s: string) => (s || '')
    .replace(/<sup[\s\S]*?<\/sup>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  for (const m of rowMatches) {
    const rowHtml = m[1];

    // Skip pure header rows
    const isHeaderRow = /<th[\s\S]*<\/th>/i.test(rowHtml) && !/<td/i.test(rowHtml);
    if (isHeaderRow) continue;

    const thName = rowHtml.match(/<th[^>]*>([\s\S]*?)<\/th>/i)?.[1] ?? '';
    const tdCells = [...rowHtml.matchAll(/<td[^>]*>([\s\S]*?)<\/td>/gi)].map(x => x[1]);

    // Expect at least 3 data cells when <th> is present; else 4 when the name is in the first <td>
    if (!thName && tdCells.length < 3) continue;

    const nameCell = thName || tdCells[0] || '';
    const name = clean(nameCell);
    if (!name) continue;

    const isoTargets = resolveIso2Targets(name);
    if (isoTargets.length === 0) continue;

    const requirementTextRaw = clean(tdCells[thName ? 0 : 1] || '');
    const requirement = requirementTextRaw.toLowerCase();
    const stayTextRaw = clean(tdCells[thName ? 1 : 2] || '');
    const notes = clean(tdCells[thName ? 2 : 3] || '');

    let visaType: VisaType = 'visa_required';
    if (/visa[- ]?free|not required/i.test(requirement)) visaType = 'visa_free';
    else if (/visa on arrival|\bvoa\b/i.test(requirement)) visaType = 'voa';
    else if (/(^|\b)e-?visa\b|electronic travel authorization|\beta\b/i.test(requirement)) visaType = 'evisa';
    else if (/entry permit|required permit/i.test(requirement)) visaType = 'entry_permit';
    else if (/not allowed|prohibit|ban/i.test(requirement)) visaType = 'ban';

    const allowedDays = parseDays(stayTextRaw) ?? parseDays(requirementTextRaw);

    const feeMatch = notes.match(/(?:US?\$|\$|€|£)\s?(\d{1,4})/);
    const feeUsd = feeMatch ? parseInt(feeMatch[1], 10) : undefined;

    const visaEase = scoreFor(visaType, feeUsd);

    for (const iso2 of isoTargets) {
      byIso2.set(iso2, {
        visaType,
        allowedDays,
        feeUsd,
        notes: notes || undefined,
        visaRequirementText: requirementTextRaw || undefined,
        allowedStayText: stayTextRaw || undefined,
        sourceUrl: WP_URL,
        visaEase,
      });
    }
  }

  // Merge manual overrides if present (typed, no `any`)
  try {
    const mod = await import('@/data/sources/visa_overrides.json');
    const ovUnknown: unknown = (mod as { default?: unknown }).default ?? mod;

    if (ovUnknown && typeof ovUnknown === 'object' && !Array.isArray(ovUnknown)) {
      const ov = ovUnknown as Record<string, Partial<VisaRow>>;
      for (const [k, v] of Object.entries(ov)) {
        const base = byIso2.get(k);
        if (!base && !v) continue;

        const merged: VisaRow = {
          visaType: v.visaType ?? base?.visaType ?? 'visa_required',
          allowedDays: v.allowedDays ?? base?.allowedDays,
          feeUsd: v.feeUsd ?? base?.feeUsd,
          notes: v.notes ?? base?.notes,
          visaRequirementText: v.visaRequirementText ?? base?.visaRequirementText,
          allowedStayText: v.allowedStayText ?? base?.allowedStayText,
          sourceUrl: v.sourceUrl ?? base?.sourceUrl ?? WP_URL,
          visaEase: v.visaEase ?? scoreFor(v.visaType ?? base?.visaType ?? 'visa_required', v.feeUsd ?? base?.feeUsd),
        };

        byIso2.set(k.toUpperCase(), merged);
      }
    }
  } catch {
    // optional file, ignore if missing
  }

  return byIso2;
}

import { createClient } from '@supabase/supabase-js';

let _visaCache: Map<string, VisaRow> | null = null;
let _visaCacheExpiresAt = 0;
const VISA_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export async function buildVisaIndex(): Promise<Map<string, VisaRow>> {
  const now = Date.now();
  if (_visaCache && now < _visaCacheExpiresAt) {
    return _visaCache;
  }

  const map = new Map<string, VisaRow>();

  const supabaseUrl = process.env.SUPABASE_URL!;
  const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY!;
  const supabase = createClient(supabaseUrl, serviceRole);

  // Get latest version
  const { data: latestRun } = await supabase
    .from('visa_sync_runs')
    .select('version')
    .order('version', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!latestRun?.version) return map;

  const { data: rows } = await supabase
    .from('visa_requirements')
    .select('*')
    .eq('version', latestRun.version);

  if (!rows) return map;

  // Helper normalize (must match ingestion normalize behavior)
  const normalize = (text: string) =>
    text
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/&/g, 'and')
      .replace(/[^\w\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

  for (const seedName of Object.keys(require('@/lib/seed').byIso2)) {
    const iso2 = seedName.toUpperCase();
    const seed = require('@/lib/seed').byIso2.get(iso2);
    if (!seed) continue;

    const countryNorm = normalize(seed.name);

    let matchedRow: any | null = null;

    // 1️⃣ Exact match
    matchedRow = rows.find(r => r.visitor_to_norm === countryNorm) ?? null;

    // 2️⃣ Alias match
    if (!matchedRow) {
      matchedRow = rows.find(r =>
        Array.isArray(r.aliases_norm) &&
        r.aliases_norm.includes(countryNorm)
      ) ?? null;
    }

    // 3️⃣ Safe contains (only non-special rows, and not parent bleed)
    if (!matchedRow) {
      matchedRow = rows.find(r => {
        if (r.is_special_subregion) return false;
        if (r.parent_norm && r.parent_norm === countryNorm) return false;
        return r.visitor_to_norm.includes(countryNorm);
      }) ?? null;
    }

    if (!matchedRow) continue;

    const visaType: VisaType = (() => {
      const r = (matchedRow.requirement || '').toLowerCase();
      if (/visa[- ]?free|not required/i.test(r)) return 'visa_free';
      if (/visa on arrival|\bvoa\b/i.test(r)) return 'voa';
      if (/(^|\b)e-?visa\b|electronic travel authorization|\beta\b/i.test(r)) return 'evisa';
      if (/entry permit|required permit/i.test(r)) return 'entry_permit';
      if (/not allowed|prohibit|ban/i.test(r)) return 'ban';
      return 'visa_required';
    })();

    const allowedDays = parseDays(matchedRow.allowed_stay) ?? parseDays(matchedRow.requirement);
    const visaEase = scoreFor(visaType);

    map.set(iso2, {
      visaType,
      allowedDays,
      feeUsd: undefined,
      notes: matchedRow.notes || undefined,
      visaRequirementText: matchedRow.requirement || undefined,
      allowedStayText: matchedRow.allowed_stay || undefined,
      sourceUrl: 'wikipedia',
      visaEase,
    });
  }

  _visaCache = map;
  _visaCacheExpiresAt = Date.now() + VISA_CACHE_TTL_MS;
  return map;
}

// Debug-only export for snapshot scripts (never used at runtime)
export { fetchVisaFromWikipedia };