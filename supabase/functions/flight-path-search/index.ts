import "@supabase/functions-js/edge-runtime.d.ts";

type FlightLegRequest = {
  from: string;
  to: string;
  date: string;
};

type FlightPathRequest = {
  id: string;
  legs: FlightLegRequest[];
};

type SearchRequest = {
  market?: string;
  locale?: string;
  currency?: string;
  adults?: number;
  cabinClass?: string;
  paths: FlightPathRequest[];
};

type PricedLeg = FlightLegRequest & {
  price: number | null;
  currency: string;
  deepLink: string | null;
  provider: string | null;
};

type PricedPath = {
  id: string;
  totalPrice: number | null;
  currency: string;
  legs: PricedLeg[];
};

type DuffelOffer = {
  total_amount?: string;
  total_currency?: string;
  owner?: {
    name?: string;
  };
  slices?: Array<{
    segments?: Array<{
      marketing_carrier?: {
        name?: string;
      };
      operating_carrier?: {
        name?: string;
      };
    }>;
  }>;
};

const DUFFEL_BASE_URL =
  Deno.env.get("DUFFEL_API_BASE_URL") ??
  "https://api.duffel.com";

const DUFFEL_ACCESS_TOKEN = Deno.env.get("DUFFEL_ACCESS_TOKEN");
const DUFFEL_SUPPLIER_TIMEOUT_MS = Math.max(
  1000,
  Math.min(Number(Deno.env.get("DUFFEL_SUPPLIER_TIMEOUT_MS") ?? 5000), 10000),
);

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
    },
  });
}

function normalizeIata(value: unknown) {
  return typeof value === "string" ? value.trim().toUpperCase() : "";
}

function normalizeDate(value: unknown) {
  const raw = typeof value === "string" ? value.trim() : "";
  return /^\d{4}-\d{2}-\d{2}$/.test(raw) ? raw : "";
}

function legKey(leg: FlightLegRequest) {
  return `${normalizeIata(leg.from)}-${normalizeIata(leg.to)}-${normalizeDate(leg.date)}`;
}

function numericAmount(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function cabinClassForDuffel(value: string | undefined) {
  switch (value) {
  case "CABIN_CLASS_PREMIUM_ECONOMY":
    return "premium_economy";
  case "CABIN_CLASS_BUSINESS":
    return "business";
  case "CABIN_CLASS_FIRST":
    return "first";
  default:
    return "economy";
  }
}

function googleFlightsSearchURL(leg: FlightLegRequest) {
  const query = `${normalizeIata(leg.from)} to ${normalizeIata(leg.to)} ${normalizeDate(leg.date)} flights`;
  return `https://www.google.com/travel/flights?q=${encodeURIComponent(query)}`;
}

function unpricedLeg(leg: FlightLegRequest, currency: string): PricedLeg {
  return {
    from: normalizeIata(leg.from),
    to: normalizeIata(leg.to),
    date: normalizeDate(leg.date),
    price: null,
    currency,
    deepLink: googleFlightsSearchURL(leg),
    provider: "Duffel",
  };
}

async function mapWithConcurrency<T, U>(
  items: T[],
  limit: number,
  mapper: (item: T, index: number) => Promise<U>,
) {
  const results = new Array<U>(items.length);
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await mapper(items[index], index);
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(limit, Math.max(items.length, 1)) }, () => worker()),
  );
  return results;
}

function firstString(...values: Array<string | undefined>) {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function carrierName(offer: DuffelOffer) {
  for (const slice of offer.slices ?? []) {
    for (const segment of slice.segments ?? []) {
      const name = firstString(
        segment.marketing_carrier?.name,
        segment.operating_carrier?.name,
      );
      if (name) return name;
    }
  }
  return firstString(offer.owner?.name) ?? "Duffel";
}

function offerCandidates(raw: unknown): DuffelOffer[] {
  const root = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
  const data = root.data && typeof root.data === "object" ? root.data as Record<string, unknown> : {};
  return Array.isArray(data.offers) ? data.offers as DuffelOffer[] : [];
}

function parseCheapestOffer(raw: unknown, fallbackCurrency: string): Omit<PricedLeg, "from" | "to" | "date"> {
  let best: Omit<PricedLeg, "from" | "to" | "date"> | null = null;

  for (const offer of offerCandidates(raw)) {
    const price = numericAmount(offer.total_amount);
    if (price == null) continue;

    const candidate = {
      price,
      currency: offer.total_currency ?? fallbackCurrency,
      deepLink: null,
      provider: carrierName(offer),
    };

    if (!best || candidate.price < best.price!) best = candidate;
  }

  return best ?? {
    price: null,
    currency: fallbackCurrency,
    deepLink: null,
    provider: "Duffel",
  };
}

async function priceLeg(leg: FlightLegRequest, request: SearchRequest): Promise<PricedLeg> {
  const currency = request.currency ?? "USD";
  const passengerCount = Math.max(1, Math.min(request.adults ?? 1, 9));
  const body = {
    data: {
      slices: [
        {
          origin: normalizeIata(leg.from),
          destination: normalizeIata(leg.to),
          departure_date: normalizeDate(leg.date),
        },
      ],
      passengers: Array.from({ length: passengerCount }, () => ({ type: "adult" })),
      cabin_class: cabinClassForDuffel(request.cabinClass),
    },
  };

  const response = await fetch(`${DUFFEL_BASE_URL}/air/offer_requests?return_offers=true&supplier_timeout=${DUFFEL_SUPPLIER_TIMEOUT_MS}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${DUFFEL_ACCESS_TOKEN}`,
      "content-type": "application/json",
      "duffel-version": "v2",
    },
    body: JSON.stringify(body),
  });

  console.log(
    "[flight-path-search] duffel.offer_request",
    `${normalizeIata(leg.from)}-${normalizeIata(leg.to)}-${normalizeDate(leg.date)}`,
    response.status,
  );

  if (!response.ok) {
    throw new Error(`Duffel offer request failed ${response.status}: ${await response.text()}`);
  }

  const priced = parseCheapestOffer(await response.json(), currency);

  return {
    from: normalizeIata(leg.from),
    to: normalizeIata(leg.to),
    date: normalizeDate(leg.date),
    ...priced,
    deepLink: googleFlightsSearchURL(leg),
  };
}

function pathCurrency(legs: PricedLeg[], fallbackCurrency: string) {
  return legs.find(leg => leg.currency)?.currency ?? fallbackCurrency;
}

Deno.serve(async req => {
  if (req.method === "OPTIONS") return jsonResponse({ ok: true });
  if (req.method !== "POST") return jsonResponse({ ok: false, error: "POST required" }, 405);

  try {
    if (!DUFFEL_ACCESS_TOKEN) {
      return jsonResponse({
        ok: false,
        error: "Missing Duffel access token. Add the DUFFEL_ACCESS_TOKEN Supabase secret.",
      }, 503);
    }

    const body = await req.json() as SearchRequest;
    const paths = Array.isArray(body.paths) ? body.paths.slice(0, 6) : [];
    console.log("[flight-path-search] request", `provider=duffel paths=${paths.length}`);
    if (!paths.length) return jsonResponse({ ok: false, error: "No paths provided." }, 400);

    const uniqueLegs = new Map<string, FlightLegRequest>();
    for (const path of paths) {
      for (const leg of path.legs ?? []) {
        const normalized = {
          from: normalizeIata(leg.from),
          to: normalizeIata(leg.to),
          date: normalizeDate(leg.date),
        };
        if (!normalized.from || !normalized.to || !normalized.date) continue;
        uniqueLegs.set(legKey(normalized), normalized);
      }
    }

    const pricedLegs = new Map<string, PricedLeg>();
    const uniqueLegList = Array.from(uniqueLegs.values());
    console.log("[flight-path-search] unique_legs", uniqueLegList.length, `supplier_timeout=${DUFFEL_SUPPLIER_TIMEOUT_MS}`);
    const pricedLegList = await mapWithConcurrency(uniqueLegList, 6, async leg => {
      try {
        return await priceLeg(leg, body);
      } catch (error) {
        console.error("[flight-path-search] duffel.leg_failed", legKey(leg), error);
        return unpricedLeg(leg, body.currency ?? "USD");
      }
    });
    for (const leg of pricedLegList) {
      pricedLegs.set(legKey(leg), leg);
    }

    const pricedPaths: PricedPath[] = paths.map(path => {
      const legs = (path.legs ?? [])
        .map(leg => pricedLegs.get(legKey(leg)))
        .filter((leg): leg is PricedLeg => Boolean(leg));
      const currency = pathCurrency(legs, body.currency ?? "USD");
      const prices = legs
        .filter(leg => leg.currency === currency)
        .map(leg => leg.price)
        .filter((price): price is number => price != null);
      const allLegsPriced = legs.length === path.legs.length && prices.length === legs.length;

      return {
        id: path.id,
        currency,
        totalPrice: allLegsPriced ? Number(prices.reduce((sum, price) => sum + price, 0).toFixed(2)) : null,
        legs,
      };
    }).sort((a, b) => {
      if (a.totalPrice == null) return 1;
      if (b.totalPrice == null) return -1;
      return a.totalPrice - b.totalPrice;
    });

    console.log("[flight-path-search] response", `provider=duffel pricedPaths=${pricedPaths.length}`);
    return jsonResponse({
      ok: true,
      pricedAt: new Date().toISOString(),
      currency: body.currency ?? "USD",
      paths: pricedPaths,
    });
  } catch (error) {
    console.error("[flight-path-search]", error);
    return jsonResponse({ ok: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
