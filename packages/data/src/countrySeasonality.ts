// packages/data/src/countrySeasonality.ts

/**
 * Canonical TravelScorer seasonality dataset.
 *
 * Keys are ISO2 country/territory codes in UPPERCASE (e.g. "US", "JP", "EG").
 * Values are hand-curated "best time to visit" patterns.
 */

export type CountrySeasonalityDefinition = {
  /**
   * Best months to visit (1–12, where 1 = Jan, 12 = Dec).
   * Strongest "yes, go now" months.
   */
  best: number[];

  /**
   * Shoulder-season months (still good, slightly off-peak).
   */
  shoulder?: number[];

  /**
   * Solid but not quite peak (optional).
   */
  good?: number[];

  /**
   * Months that are usually less ideal (extreme heat, monsoon, etc.).
   */
  avoid?: number[];

  /**
   * Freeform notes you can surface in the UI later.
   */
  notes?: string;
};

export const COUNTRY_SEASONALITY_DEFINITIONS: Record<
  string,
  CountrySeasonalityDefinition
> = {
  // United States of America
  US: {
    best: [4, 5, 9, 10], // spring + fall
    shoulder: [3, 11],
    avoid: [7, 8],
    notes:
      "Generic mainland pattern: spring and fall are ideal; mid-summer can be hot, crowded, or stormy depending on region. Refine per-region later.",
  },

  // Japan
  JP: {
    best: [3, 4, 10, 11],
    shoulder: [5],
    avoid: [7, 8],
    notes:
      "Cherry blossom (Mar–Apr) and autumn foliage (Oct–Nov) are peak. Summer is hot/humid with typhoon risk.",
  },

  // Iceland
  IS: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [12, 1, 2],
    notes:
      "Summer has mild weather and long days. Shoulder seasons can be good for fewer crowds; deep winter is very cold and dark.",
  },

  // Egypt
  EG: {
    best: [11, 12, 1, 2, 3],
    shoulder: [10, 4],
    avoid: [6, 7, 8],
    notes:
      "Cooler months (Nov–Mar) are ideal for Cairo, Luxor, and Aswan. Summer is extremely hot, especially in Upper Egypt.",
  },

  // Argentina (Buenos Aires + Patagonia blend baseline)
  AR: {
    best: [3, 4, 10, 11],
    shoulder: [2, 5],
    avoid: [7, 8],
    notes:
      "Spring and fall work well across much of the country. For Patagonia specifically, late spring–early fall is best.",
  },

  // Canada
  CA: {
    best: [6, 7, 8, 9],
    shoulder: [5, 10],
    avoid: [1, 2, 3, 12],
    notes:
      "Summer and early fall are ideal across much of the country; winters are very cold in most regions.",
  },

  // Mexico
  MX: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 5, 10],
    avoid: [6, 7, 8, 9],
    notes:
      "Dry season (Nov–Mar) is best for most coasts and Mexico City; summer can be hot, humid, and stormy on the Caribbean and Pacific.",
  },

  // Brazil
  BR: {
    best: [4, 5, 6, 7, 8, 9],
    shoulder: [3, 10],
    avoid: [1, 2, 12],
    notes:
      "Best timing depends on region, but fall–winter (Apr–Sep) often brings more comfortable temperatures and less rain in many areas.",
  },

  // Chile
  CL: {
    best: [11, 12, 1, 2, 3],
    shoulder: [10, 4],
    avoid: [6, 7],
    notes:
      "Summer in the Southern Hemisphere (Nov–Mar) is ideal for Patagonia and most of Chile; mid-winter can be cold and stormy in the south.",
  },

  // Peru
  PE: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3],
    notes:
      "Dry season (May–Sep) is best for the Andes and Machu Picchu; early year can be wetter with occasional disruptions.",
  },

  // Colombia
  CO: {
    best: [12, 1, 2, 7, 8, 9],
    shoulder: [3, 4, 5, 6],
    avoid: [10, 11],
    notes:
      "Equatorial climate with micro-regions; many areas are pleasant most of the year, but late-year rains can be heavier on some coasts.",
  },

  // Costa Rica
  CR: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [9, 10],
    notes:
      "Dry season (Dec–Apr) is ideal for beaches and wildlife; Oct–Nov can bring heavy rains in many regions.",
  },

  // France
  FR: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes:
      "Late spring and early fall balance good weather with fewer crowds; mid-summer is busy but still enjoyable.",
  },

  // Italy
  IT: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes:
      "May–Jun and Sep–Oct offer great weather and lighter crowds; Jul–Aug can be very hot and packed in major cities.",
  },

  // Spain
  ES: {
    best: [4, 5, 10, 11],
    shoulder: [3, 6, 9],
    avoid: [7, 8],
    notes:
      "Spring and late fall are great for cities; summer is very hot inland but fine for beach-focused trips.",
  },

  // Portugal
  PT: {
    best: [4, 5, 6, 9, 10],
    shoulder: [3, 7, 8, 11],
    avoid: [1, 2],
    notes:
      "Mild spring and fall are ideal for exploring Lisbon, Porto, and the coast; winters are cool and damp.",
  },

  // Greece
  GR: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2, 3],
    notes:
      "Late spring and early fall are perfect for islands and ruins; peak summer is very hot and busy.",
  },

  // Switzerland
  CH: {
    best: [6, 7, 8, 9],
    shoulder: [5, 10],
    avoid: [11, 12, 1, 2],
    notes:
      "Summer and early fall are ideal for hiking and lakes; deep winter is cold but good for skiing.",
  },

  // Austria
  AT: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes:
      "Spring and fall are great for cities and Alps; summer is warm and busy but still pleasant.",
  },

  // Germany
  DE: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8, 12],
    avoid: [1, 2],
    notes:
      "Late spring and early fall are ideal for sightseeing; December is a special case for Christmas markets.",
  },

  // Netherlands
  NL: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes:
      "Late spring and early fall balance mild weather and fewer crowds; winters are grey and chilly.",
  },

  // United Kingdom
  GB: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes:
      "Weather is changeable year-round; late spring and early fall often feel nicest with longer days.",
  },

  // Ireland
  IE: {
    best: [5, 6, 7, 9],
    shoulder: [4, 8, 10],
    avoid: [1, 2],
    notes:
      "Expect some rain anytime, but late spring through early fall offer the best mix of daylight and temperatures.",
  },

  // Norway
  NO: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [11, 12, 1, 2],
    notes:
      "Summer has long days and accessible fjords; winter is dark and cold outside of winter-sports trips.",
  },

  // Sweden
  SE: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [11, 12, 1, 2],
    notes:
      "Summer is ideal for cities and lakes; winters are cold and dark at higher latitudes.",
  },

  // Finland
  FI: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [11, 12, 1, 2],
    notes:
      "Summer is perfect for lakes and forests; deep winter is harsh but interesting for northern-lights trips.",
  },

  // Denmark
  DK: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [1, 2],
    notes:
      "Short summers are pleasant and bright; winters are cold, windy, and dark.",
  },

  // Türkiye
  TR: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes:
      "Spring and fall are ideal for Istanbul and the coast; high summer can be very hot in many regions.",
  },

  // Morocco
  MA: {
    best: [3, 4, 10, 11],
    shoulder: [2, 5, 9],
    avoid: [7, 8],
    notes:
      "Spring and fall are best for cities and desert; midsummer heat can be intense inland.",
  },

  // South Africa
  ZA: {
    best: [9, 10, 11, 3, 4, 5],
    shoulder: [8, 6, 7],
    avoid: [1, 2],
    notes:
      "Best timing varies by region; spring and fall often balance safari conditions and city weather well.",
  },

  // Thailand
  TH: {
    best: [11, 12, 1, 2, 3],
    shoulder: [10, 4],
    avoid: [6, 7, 8, 9],
    notes:
      "Cooler, drier months (Nov–Mar) are best for most regions; monsoon seasons shift by coast.",
  },

  // Vietnam
  VN: {
    best: [12, 1, 2, 3, 11],
    shoulder: [4, 10],
    avoid: [6, 7, 8, 9],
    notes:
      "North, central, and south have different patterns; winter and early spring often work best overall for a north–south trip.",
  },

  // Indonesia
  ID: {
    best: [6, 7, 8, 9],
    shoulder: [5, 10],
    avoid: [12, 1, 2, 3],
    notes:
      "Dry season (roughly May–Sep) is best for Bali and many islands; rainy season peaks around Dec–Feb.",
  },

  // Malaysia
  MY: {
    best: [6, 7, 8, 9],
    shoulder: [2, 3, 4, 5, 10],
    avoid: [11, 12, 1],
    notes:
      "Seasonality shifts by coast, but mid-year is often friendlier for many coastal areas; some coasts see heavy rains in winter.",
  },

  // Singapore
  SG: {
    best: [2, 3, 4, 7, 8, 9],
    shoulder: [1, 5, 6, 10, 11, 12],
    notes:
      "Hot and humid year-round with showers; there is no truly bad time, but some months have slightly fewer storms.",
  },

  // Philippines
  PH: {
    best: [1, 2, 3, 4],
    shoulder: [12, 5],
    avoid: [7, 8, 9, 10],
    notes: "Dry season (Jan–Apr) is best for islands; late summer and fall can bring stronger typhoons.",
  },

  // Australia
  AU: {
    best: [3, 4, 5, 9, 10, 11],
    shoulder: [2, 6, 8, 12],
    avoid: [1, 7],
    notes: "Spring and fall are pleasant for many regions; far north and interior have strong wet/heat seasons.",
  },

  // New Zealand
  NZ: {
    best: [12, 1, 2, 3],
    shoulder: [11, 4],
    avoid: [6, 7],
    notes: "Southern Hemisphere summer (Dec–Mar) is ideal for hikes and road trips; winter is colder and wetter.",
  },

  // United Arab Emirates
  AE: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [6, 7, 8, 9],
    notes: "Cooler months are much more comfortable; summer heat is extreme.",
  },

  // Saudi Arabia
  SA: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [6, 7, 8, 9],
    notes: "Winter and early spring offer manageable heat; summers are extremely hot across much of the country.",
  },

  // Qatar
  QA: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [6, 7, 8, 9],
    notes: "Similar Gulf pattern: winter is pleasant, summer is intensely hot and humid.",
  },

  // Bahrain
  BH: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [6, 7, 8, 9],
    notes: "Best visited in the cooler months; summers are very hot and humid.",
  },

  // Oman
  OM: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [5, 6, 7, 8, 9],
    notes: "Winter and early spring are ideal for Muscat and the mountains; peak summer is very hot except for the Khareef season around Salalah.",
  },

  // Jordan
  JO: {
    best: [3, 4, 5, 10, 11],
    shoulder: [2, 9],
    avoid: [6, 7, 8],
    notes: "Spring and fall are perfect for Amman, Petra, and Wadi Rum; summer can be very hot at midday.",
  },

  // Lebanon
  LB: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes: "Late spring and early fall are ideal for the coast and mountains; winters are cool and wetter.",
  },

  // China (mainland)
  CN: {
    best: [4, 5, 9, 10],
    shoulder: [3, 11],
    avoid: [1, 2, 7, 8],
    notes: "Best windows for much of China are spring and fall; summers can be hot/humid and winters very cold in the north.",
  },

  // Hong Kong
  HK: {
    best: [11, 12, 1, 2, 3],
    shoulder: [10, 4],
    avoid: [6, 7, 8, 9],
    notes: "Cooler, drier months are most comfortable; late summer and early fall bring more typhoon risk.",
  },

  // South Korea
  KR: {
    best: [4, 5, 10, 11],
    shoulder: [3, 6, 9],
    avoid: [7, 8, 1, 2],
    notes: "Cherry-blossom spring and crisp autumn are ideal; summers are hot and humid, winters are cold.",
  },

  // Taiwan
  TW: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [6, 7, 8, 9],
    notes: "Cooler months are comfortable across many regions; late summer and early fall can see strong typhoons.",
  },

  // India
  IN: {
    best: [11, 12, 1, 2, 3],
    shoulder: [10, 4],
    avoid: [6, 7, 8, 9],
    notes: "Dry, cooler season (Nov–Mar) is best for most classic routes; monsoon and pre-monsoon heat vary by region.",
  },

  // Sri Lanka
  LK: {
    best: [12, 1, 2, 3, 7, 8, 9],
    shoulder: [4, 5, 10, 11],
    avoid: [6],
    notes: "Different coasts peak at different times; overall there are multiple good windows, but June can be particularly wet in some regions.",
  },

  // Nepal
  NP: {
    best: [3, 4, 5, 10, 11],
    shoulder: [2, 12],
    avoid: [6, 7, 8, 9],
    notes: "Pre-monsoon (Mar–May) and post-monsoon (Oct–Nov) are ideal for trekking and views.",
  },

  // Poland
  PL: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Late spring and early fall are ideal for cities and countryside; winters are cold and often grey.",
  },

  // Czechia
  CZ: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes: "Prague and other cities shine in late spring and early fall; winters are cold and can be foggy.",
  },

  // Hungary
  HU: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes: "Budapest is especially nice in May–Jun and Sep–Oct; mid-summer can be hot and crowded.",
  },

  // Croatia
  HR: {
    best: [6, 9],
    shoulder: [5, 7, 8, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Adriatic coast is great in early/late summer; peak July–Aug is busier and hotter but still workable.",
  },

  // Romania
  RO: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Late spring and early fall are best for cities and countryside; winters can be very cold inland.",
  },

  // Kosovo
  XK: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes:
      "Late spring and early fall are usually the most comfortable for cities and mountain trips, with warm days and fewer weather extremes than midsummer or winter.",
  },

  // Bulgaria
  BG: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Coast and mountains are pleasant in late spring and early fall; peak summer is hotter and busier.",
  },

  // Monaco
  MC: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8, 11],
    avoid: [1, 2],
    notes: "Shares a Riviera pattern: spring and fall feel best; summer is hot and crowded but fine if you want beach energy.",
  },

  // Liechtenstein
  LI: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [11, 12, 1, 2],
    notes: "Summer is ideal for hikes and alpine scenery; winters are cold but good if you are targeting skiing.",
  },

  // Puerto Rico (US territory)
  PR: {
    best: [1, 2, 3, 12],
    shoulder: [4, 11],
    avoid: [8, 9, 10],
    notes: "Dry season (Dec–Mar) is most reliable for beaches; late summer and early fall bring higher hurricane risk.",
  },

  // Syria (climate-based, security situation separate)
  SY: {
    best: [3, 4, 10, 11],
    shoulder: [2, 5],
    avoid: [6, 7, 8, 1],
    notes: "Based on historical climate only: spring and fall are generally most comfortable. Always verify current safety guidance separately.",
  },
  
  // Uzbekistan
  UZ: {
    best: [4, 5, 9, 10],
    shoulder: [3, 6, 8, 11],
    avoid: [1, 2, 7, 12],
    notes: "Spring and fall are ideal for Samarkand, Bukhara, and Tashkent; summers are very hot and winters can be quite cold.",
  },

  // Kazakhstan
  KZ: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2, 12],
    notes: "Late spring and early fall balance comfortable temperatures across the steppe and cities; winters are extremely cold.",
  },

  // Kyrgyzstan
  KG: {
    best: [6, 7, 8, 9],
    shoulder: [5, 10],
    avoid: [11, 12, 1, 2],
    notes: "Summer and early fall are best for trekking and lakes; winters are cold and mountain passes can be snowed in.",
  },

  // Tajikistan
  TJ: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [11, 12, 1, 2],
    notes: "Late spring and early fall are ideal for Pamir routes; winters are harsh at altitude.",
  },

  // Turkmenistan
  TM: {
    best: [4, 5, 10, 11],
    shoulder: [3, 6, 9],
    avoid: [7, 8],
    notes: "Spring and late fall are most comfortable; summers are extremely hot in the desert.",
  },

  // Georgia
  GE: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes: "Spring and fall are perfect for Tbilisi and wine regions; winters can be cold, especially in the mountains.",
  },

  // Armenia
  AM: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes: "Late spring and early fall are ideal for Yerevan and monasteries; summers are hot and winters can be snowy.",
  },

  // Azerbaijan
  AZ: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8, 11],
    avoid: [1, 2],
    notes: "Spring and fall are comfortable for Baku and the Caucasus; summers can be hot on the lowlands.",
  },

  // Ukraine
  UA: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes: "Climate-based only: late spring and early fall are most pleasant for cities and countryside; winters are cold. Always check current safety guidance separately.",
  },

  // Russia (climate only; safety handled separately)
  RU: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [11, 12, 1, 2, 3],
    notes: "Very broad climate pattern: short summers and early fall are most comfortable for many regions; winters are long and very cold in much of the country.",
  },

  // Tunisia
  TN: {
    best: [4, 5, 10, 11],
    shoulder: [3, 6, 9],
    avoid: [7, 8],
    notes: "Spring and late fall are ideal for coast and desert; mid-summer is hot and can be windy.",
  },

  // Algeria
  DZ: {
    best: [4, 5, 10, 11],
    shoulder: [3, 6, 9],
    avoid: [7, 8],
    notes: "Coastal areas feel best in spring and fall; Saharan regions are extremely hot in summer.",
  },

  // Kenya
  KE: {
    best: [7, 8, 9],
    shoulder: [1, 2, 6, 10],
    avoid: [3, 4, 5, 11, 12],
    notes: "Wildlife patterns vary, but the dry season around Jul–Sep is excellent for many safaris; March–May can be very wet.",
  },

  // Tanzania
  TZ: {
    best: [6, 7, 8, 9],
    shoulder: [1, 2, 10],
    avoid: [3, 4, 5, 11, 12],
    notes: "Dry months around Jun–Sep are strong for safaris and Kilimanjaro; long rains peak in Mar–May.",
  },

  // Ethiopia
  ET: {
    best: [10, 11, 12, 1, 2],
    shoulder: [3, 9],
    avoid: [6, 7, 8],
    notes: "Highlands are pleasant in the dry season (roughly Oct–Feb); Jun–Aug can be quite rainy in Addis and the north.",
  },

  // Namibia
  NA: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Dry winter months are ideal for wildlife viewing and desert landscapes; summer can be hotter with more storms.",
  },

  // Botswana
  BW: {
    best: [6, 7, 8, 9],
    shoulder: [5, 10],
    avoid: [1, 2, 3, 4, 11, 12],
    notes: "Dry season around Jun–Sep is peak for Okavango and safaris; wet season can make some areas harder to access.",
  },

  // Ecuador
  EC: {
    best: [6, 7, 8, 9],
    shoulder: [1, 2, 3, 4, 5, 10],
    avoid: [11, 12],
    notes: "Equatorial but with varied microclimates; mid-year is often drier and clearer in many Andean and highland areas.",
  },

  // Bolivia
  BO: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Dry season (May–Sep) is best for Altiplano and Uyuni; summer can be wet with some access issues.",
  },

  // Uruguay
  UY: {
    best: [12, 1, 2, 3],
    shoulder: [11, 4],
    avoid: [6, 7, 8],
    notes: "Southern Hemisphere summer is ideal for Montevideo and beach towns; winters are cooler and grayer.",
  },

  // Paraguay
  PY: {
    best: [5, 6, 7, 8],
    shoulder: [4, 9],
    avoid: [12, 1, 2, 3],
    notes: "Cooler, drier mid-year months are generally more comfortable; summer can be very hot and humid.",
  },

  // Venezuela (climate only; safety handled separately)
  VE: {
    best: [12, 1, 2, 3],
    shoulder: [11, 4],
    avoid: [5, 6, 7, 8, 9, 10],
    notes: "Based on historical climate: drier months at the start of the year tend to be better in many regions. Always verify current safety separately.",
  },

  // Guyana
  GY: {
    best: [9, 10, 11],
    shoulder: [1, 2, 3, 4, 8, 12],
    avoid: [5, 6, 7],
    notes: "Short dry season around Sep–Nov is often best; heavy rains peak mid-year.",
  },

  // Suriname
  SR: {
    best: [8, 9, 10],
    shoulder: [1, 2, 3, 4, 7, 11, 12],
    avoid: [5, 6],
    notes: "Late dry season around Aug–Oct tends to be pleasant; May–Jun are wetter.",
  },

  // Belize
  BZ: {
    best: [1, 2, 3, 4],
    shoulder: [11, 12, 5],
    avoid: [6, 7, 8, 9, 10],
    notes: "Dry season (roughly Jan–Apr) is ideal for reefs and ruins; late summer and fall have more rain and storm risk.",
  },

  // Panama
  PA: {
    best: [1, 2, 3, 4],
    shoulder: [12, 5],
    avoid: [6, 7, 8, 9, 10, 11],
    notes: "Dry months early in the year are best for the Pacific side and Panama City; many other months are wetter but still workable.",
  },

  // Guatemala
  GT: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [5, 6, 7, 8, 9],
    notes: "Dry season (Nov–Mar) is great for Antigua, highlands, and ruins; mid-year is rainier.",
  },

  // El Salvador
  SV: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [5, 6, 7, 8, 9],
    notes: "Dry season is more comfortable for beaches and volcano hikes; wet season can mean heavier afternoon storms.",
  },

  // Honduras
  HN: {
    best: [12, 1, 2, 3],
    shoulder: [11, 4],
    avoid: [5, 6, 7, 8, 9, 10],
    notes: "Early-year dry season is good for Bay Islands and inland areas; hurricane season peaks in late summer/fall.",
  },

  // Nicaragua
  NI: {
    best: [12, 1, 2, 3],
    shoulder: [11, 4],
    avoid: [5, 6, 7, 8, 9, 10],
    notes: "Dry season at the start of the year is best for most routes; later months are hotter and wetter.",
  },

  // Cuba
  CU: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Winter and early spring are pleasant and outside the main hurricane window; late summer and fall carry more storm risk.",
  },

  // Dominican Republic
  DO: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "High season in winter offers good weather; late summer and early fall are peak hurricane/storm months.",
  },

  // Haiti
  HT: {
    best: [12, 1, 2, 3],
    shoulder: [11, 4],
    avoid: [8, 9, 10],
    notes: "Cooler, drier months are generally better; late summer and fall carry higher hurricane risk.",
  },

  // Jamaica
  JM: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Winter and early spring bring pleasant beach weather; late summer/fall can be stormier.",
  },

  // Bahamas
  BS: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Typical Caribbean pattern: winter and early spring are driest; late summer/fall is peak hurricane season.",
  },

  // Barbados
  BB: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Dry season (Dec–Apr) is ideal for beach trips; hurricane season peaks in late summer and early fall.",
  },

  // Trinidad and Tobago
  TT: {
    best: [1, 2, 3, 4],
    shoulder: [11, 12, 5],
    avoid: [6, 7, 8, 9, 10],
    notes: "Drier months early in the year work best; mid-year is wetter and more humid.",
  },

  // Antigua and Barbuda
  AG: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Caribbean dry season is ideal; late summer and fall are more hurricane-prone.",
  },

  // Saint Lucia
  LC: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Dry season has sunnier skies and calmer seas; wet season peaks around late summer.",
  },

  // Saint Vincent and the Grenadines
  VC: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Dry season is favoured for sailing and island-hopping; later months see more tropical storms.",
  },

  // Grenada
  GD: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Similar to neighbours: winter and early spring are best; hurricane risk higher in late summer/fall.",
  },

  // Belgium
  BE: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Late spring and early fall are pleasant for cities; winters are cool and grey.",
  },

  // Luxembourg
  LU: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Shares a similar pattern to neighbouring Belgium and Germany: shoulder seasons are especially nice.",
  },

  // Slovakia
  SK: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Late spring and early fall suit both Bratislava and mountain areas; winters are cold.",
  },

  // Slovenia
  SI: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Great for lakes and Alps in late spring and early fall; summers are warmer and busier, winters are colder.",
  },

  // Latvia
  LV: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [11, 12, 1, 2],
    notes: "Short summers are the best window; shoulder months can be cool but still okay.",
  },

  // Lithuania
  LT: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [11, 12, 1, 2],
    notes: "Summer brings long days and milder temperatures; winters are cold and dark.",
  },

  // Estonia
  EE: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [11, 12, 1, 2],
    notes: "Tallinn and coastal areas are nicest in summer; winter is cold with short days.",
  },

  // Belarus (climate only; safety separate)
  BY: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [11, 12, 1, 2, 3],
    notes: "Continental climate with cold winters; late spring and early fall are most pleasant. Always check current safety guidance.",
  },

  // Serbia
  RS: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Spring and fall are comfortable for Belgrade and countryside; summers are warm, winters are cold.",
  },

  // Montenegro
  ME: {
    best: [6, 9],
    shoulder: [5, 7, 8, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Adriatic coast patterns: early and late summer are ideal; winters are cooler and quieter.",
  },

  // North Macedonia
  MK: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Late spring and early fall strike a good balance; summers can be hot inland.",
  },

  // Albania
  AL: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes: "Coastlines and mountains are lovely in late spring and early fall; peak summer is hotter but fine for the beaches.",
  },

  // Bosnia and Herzegovina
  BA: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Sarajevo and surrounding nature feel best in shoulder seasons; winters can be cold and snowy.",
  },

  // Moldova
  MD: {
    best: [5, 6, 9],
    shoulder: [4, 7, 8, 10],
    avoid: [1, 2],
    notes: "Spring and fall are pleasant for wine routes and countryside; winters are cold.",
  },

  // Nigeria
  NG: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Drier, slightly cooler months around Dec–Feb are easier for many regions; mid-year brings heavier rains in much of the country.",
  },

  // Ghana
  GH: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Coastal Ghana is most comfortable in the drier months around Dec–Feb; long rains peak mid-year.",
  },

  // Côte d'Ivoire (climate only; safety separate where applicable)
  CI: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Drier months around Dec–Feb are generally better; heavy rains arrive mid-year, especially along the coast.",
  },

  // Senegal
  SN: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [7, 8, 9],
    notes: "Cool, dry season (roughly Nov–Feb) is ideal for Dakar and the coast; summer is hotter and more humid.",
  },

  // Uganda
  UG: {
    best: [6, 7, 8, 12, 1, 2],
    shoulder: [3, 4, 5, 9],
    avoid: [10, 11],
    notes: "There are two dry-ish seasons (Dec–Feb and Jun–Aug) that work well for safaris and gorilla treks.",
  },

  // Rwanda
  RW: {
    best: [6, 7, 8, 12, 1, 2],
    shoulder: [3, 4, 5, 9],
    avoid: [10, 11],
    notes: "Similar to Uganda: two main drier seasons are best for trekking and wildlife.",
  },

  // Zambia
  ZM: {
    best: [6, 7, 8, 9],
    shoulder: [5, 10],
    avoid: [11, 12, 1, 2, 3, 4],
    notes: "Dry season (Jun–Sep) is prime for safaris; the wet season can limit accessibility in some parks.",
  },

  // Zimbabwe
  ZW: {
    best: [6, 7, 8, 9],
    shoulder: [5, 10],
    avoid: [11, 12, 1, 2, 3, 4],
    notes: "Similar to Zambia: dry winter months are best for wildlife and Victoria Falls views (timing varies with water levels).",
  },

  // Mozambique
  MZ: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Cooler, drier winter months suit beaches and coastal travel; summer is hotter and more cyclone-prone.",
  },

  // Madagascar
  MG: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Dry season is best for wildlife and road conditions; cyclone risk is higher in the first months of the year.",
  },

  // Mauritius
  MU: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3],
    notes: "Winter months (May–Sep) are less humid and still warm; cyclone season peaks in late summer.",
  },

  // Seychelles
  SC: {
    best: [4, 5, 10, 11],
    shoulder: [3, 6, 9],
    avoid: [1, 2, 7, 8],
    notes: "Transition months between trade winds often give calmer seas; some summer months can be windier or wetter.",
  },

  // Pakistan
  PK: {
    best: [10, 11, 2, 3, 4],
    shoulder: [1, 5],
    avoid: [6, 7, 8, 9],
    notes: "Cooler months are best for cities; high mountain regions have their own narrower trekking windows.",
  },

  // Bangladesh
  BD: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Cool, dry season is more comfortable; monsoon and heat dominate much of the rest of the year.",
  },

  // Myanmar (Burma)
  MM: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Classic pattern: cool, dry months are best; monsoon brings heavy rain and heat.",
  },

  // Cambodia
  KH: {
    best: [12, 1, 2, 3],
    shoulder: [11, 4],
    avoid: [5, 6, 7, 8, 9, 10],
    notes: "Dry season is perfect for Angkor and Phnom Penh; wet season is hotter and stickier with more downpours.",
  },

  // Laos
  LA: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [5, 6, 7, 8, 9],
    notes: "Cooler, drier months are nicer for Mekong towns and highlands; mid-year is wetter and more humid.",
  },

  // Maldives
  MV: {
    best: [1, 2, 3, 12],
    shoulder: [4, 11],
    avoid: [5, 6, 7, 8, 9, 10],
    notes: "Dry season (Dec–Mar) has the sunniest skies; wet season brings more showers and occasional storms.",
  },

  // Bhutan
  BT: {
    best: [3, 4, 5, 10, 11],
    shoulder: [2, 9],
    avoid: [6, 7, 8],
    notes: "Pre- and post-monsoon windows are ideal for views and hikes; monsoon months are wetter with clouds.",
  },

  // Mongolia
  MN: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4],
    notes: "Short summers are the main comfortable season; the rest of the year is very cold in much of the country.",
  },

  // Israel
  IL: {
    best: [3, 4, 5, 10, 11],
    shoulder: [2, 6],
    avoid: [7, 8],
    notes: "Spring and fall are ideal for cities and desert; summers are hot, especially inland and in the south.",
  },

  // Kuwait
  KW: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [5, 6, 7, 8, 9],
    notes: "Cooler months are much more comfortable; summers are extremely hot.",
  },

  // Yemen (climate only; safety separate)
  YE: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [5, 6, 7, 8, 9],
    notes: "Very rough climate baseline only; highland areas are more temperate. Always verify safety conditions separately.",
  },

  // Iraq (climate only; safety separate)
  IQ: {
    best: [10, 11, 2, 3, 4],
    shoulder: [1, 5],
    avoid: [6, 7, 8, 9],
    notes: "Cooler months are much more comfortable; summers are extremely hot, especially inland. Always check safety guidance.",
  },

  // Cyprus
  CY: {
    best: [4, 5, 6, 9, 10],
    shoulder: [3, 7, 8, 11],
    avoid: [1, 2, 12],
    notes: "Mediterranean pattern: spring and fall are ideal for coasts and cities; mid-summer is hot but good for pure beach trips.",
  },

  // Malta
  MT: {
    best: [4, 5, 6, 9, 10],
    shoulder: [3, 7, 8, 11],
    avoid: [1, 2, 12],
    notes: "Spring and fall balance warm seas with milder heat and fewer crowds; winters are cooler and windier.",
  },

  // Andorra
  AD: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [11, 12, 1, 2],
    notes: "Summer is ideal for hiking in the Pyrenees; winters are cold and focused on skiing rather than general sightseeing.",
  },

  // San Marino
  SM: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [1, 2],
    notes: "Shares central Italian seasonality: late spring and early fall are most comfortable for sightseeing.",
  },

  // Vatican City (climate only)
  VA: {
    best: [4, 5, 10, 11],
    shoulder: [3, 6, 9],
    avoid: [7, 8, 1, 2],
    notes: "Follows Rome’s pattern: spring and fall are best; peak summer is hot and crowded, winters are cooler and wetter.",
  },

  // Fiji
  FJ: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Dry season (May–Sep) is ideal for beaches and islands; cyclone risk is higher in the first months of the year.",
  },

  // Samoa
  WS: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Cooler, drier mid-year months are best; late summer and early year bring heavier rains and cyclone risk.",
  },

  // Tonga
  TO: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Dry, cooler season is best for beaches and whale watching; cyclone season clusters around the start of the year.",
  },

  // Vanuatu
  VU: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Mid-year is generally drier and more pleasant; cyclone risk increases from late summer into early autumn.",
  },

  // Papua New Guinea
  PG: {
    best: [6, 7, 8, 9],
    shoulder: [4, 5, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Equatorial and humid, but mid-year months often have slightly better trekking and visibility in many regions.",
  },

  // Solomon Islands
  SB: {
    best: [6, 7, 8, 9],
    shoulder: [4, 5, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Drier, cooler months mid-year typically work best for diving and island-hopping; earlier months are wetter with more storms.",
  },

  // Cape Verde
  CV: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [7, 8, 9],
    notes: "Winter and early spring have warm, dry weather and trade winds; late summer can be hotter and more humid.",
  },

  // Mauritius’s neighbour: Réunion (FR territory, but separate ISO code)
  RE: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Dry, cooler months are best for hiking and coasts; cyclone season peaks in the first months of the year.",
  },

  // Eswatini
  SZ: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [11, 12, 1, 2, 3],
    notes: "Dry winter months are best for wildlife and outdoor trips; summer is hotter and more humid with storms.",
  },

  // Cameroon
  CM: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Drier, slightly cooler months around Dec–Feb are easier in many regions; mid-year can be very wet, especially in the south.",
  },

  // Angola
  AO: {
    best: [5, 6, 7, 8],
    shoulder: [4, 9],
    avoid: [10, 11, 12, 1, 2, 3],
    notes: "Dry winter months are more comfortable for Luanda and safaris; summer can be hotter and wetter.",
  },

  // Sudan (climate only; safety separate)
  SD: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Based on climate alone: cooler, drier months around winter are more bearable; most of the year is extremely hot. Always check safety separately.",
  },

  // South Sudan (climate only; safety separate)
  SS: {
    best: [12, 1, 2],
    shoulder: [3, 11],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Very hot with pronounced wet seasons; the coolest, driest months around winter are generally most manageable. Always verify current safety.",
  },

  // Greenland
  GL: {
    best: [7, 8],
    shoulder: [6, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4, 5],
    notes: "Short Arctic summer is best for cruises and coastal visits; the rest of the year is very cold and dark, suited mainly to niche winter trips.",
  },

  // Iceland’s neighbour: Faroe Islands
  FO: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4],
    notes: "Summer has the mildest temperatures and longest days; the rest of the year is very windy, wet, and dark.",
  },

  // Canary Islands (Spain territory, but own ISO code)
  IC: {
    best: [3, 4, 5, 9, 10, 11],
    shoulder: [1, 2, 6, 7, 8, 12],
    notes: "Subtropical climate with few truly bad months; spring and fall often feel the nicest with warm, not-too-hot weather.",
  },

  // Hong Kong’s neighbour: Macao
  MO: {
    best: [11, 12, 1, 2, 3],
    shoulder: [4, 10],
    avoid: [6, 7, 8, 9],
    notes: "Similar to Hong Kong: cooler, drier months are most comfortable; late summer and early fall bring stronger typhoons and heat.",
  },

  // Palestine (climate only; safety separate)
  PS: {
    best: [3, 4, 5, 10, 11],
    shoulder: [2, 6],
    avoid: [7, 8],
    notes: "Follows a Levantine pattern: spring and fall are ideal; summers are hot and winters can be cool and wet. Always check current safety guidance.",
  },

  // Afghanistan
  AF: {
    best: [4, 5, 9, 10],
    shoulder: [3, 6, 8, 11],
    avoid: [1, 2, 7, 12],
    notes: "Climate baseline only: spring and fall are most comfortable in many regions; summers are very hot and winters can be harsh. Always check current safety guidance.",
  },

  // Iran (climate only; safety separate)
  IR: {
    best: [4, 5, 9, 10],
    shoulder: [3, 6, 8, 11],
    avoid: [1, 2, 7, 12],
    notes: "Very rough climate pattern: spring and fall are generally pleasant across much of the country; summers are hot in many areas and some winters can be cold. Always verify safety separately.",
  },

  // Sri Lanka’s neighbour: Maldives already defined; add Mauritius neighbour Seychelles done above.

  // Sierra Leone
  SL: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Cooler, drier months from roughly Nov–Feb are more comfortable; the rest of the year is hotter and wetter with heavier rains mid-year.",
  },

  // Liberia
  LR: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Shorter dry season around Dec–Feb is most comfortable; much of the year is hot, humid, and rainy.",
  },

  // Mali
  ML: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Cooler, drier winter months are most bearable; much of the year is extremely hot, especially in the north.",
  },

  // Niger
  NE: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Climate-only baseline: winter months are less extreme; most of the year is very hot with limited rainfall. Always confirm safety separately.",
  },

  // Chad
  TD: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Drier, cooler winter months are a bit easier; other months are hotter and, in the south, wetter. Always check safety guidance.",
  },

  // Burkina Faso
  BF: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Harmattan season can bring dust, but the hottest months are usually just before the rains; winter tends to feel more comfortable overall.",
  },

  // Mauritania
  MR: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Desert climate: cooler winter months are more bearable; other months can be extremely hot.",
  },

  // Benin
  BJ: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Coastal and southern areas are more comfortable in the cooler, drier months; mid-year is wetter and more humid.",
  },

  // Togo
  TG: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Drier and slightly cooler months feel better, especially along the coast; long rains fall mid-year.",
  },

  // Central African Republic
  CF: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Tropical interior climate with a somewhat cooler, drier window around winter; heavy rains and heat dominate other months.",
  },

  // Burundi
  BI: {
    best: [6, 7, 8],
    shoulder: [12, 1, 2, 3, 4, 5, 9],
    avoid: [10, 11],
    notes: "Equatorial highland climate: slightly drier mid-year months can be nicer, though temperatures are fairly mild year-round.",
  },

  // Malawi
  MW: {
    best: [5, 6, 7, 8],
    shoulder: [4, 9],
    avoid: [11, 12, 1, 2, 3, 10],
    notes: "Dry winter months are ideal for Lake Malawi and safaris; summer is wetter with heavier rains.",
  },

  // Lesotho
  LS: {
    best: [11, 12, 1, 2, 3],
    shoulder: [10, 4],
    avoid: [5, 6, 7, 8, 9],
    notes: "High-altitude kingdom: late spring to early autumn in the Southern Hemisphere is best; winters are cold with snow at higher elevations.",
  },

  // Swaziland alias Eswatini already defined as SZ; no extra needed.

  // Djibouti
  DJ: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Best visited in the cooler months; the rest of the year can be extremely hot, especially inland.",
  },

  // Eritrea
  ER: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Coastal and lowland areas are more comfortable in winter; summers can be very hot and, in some parts, humid.",
  },

  // Sao Tome and Principe
  ST: {
    best: [6, 7, 8],
    shoulder: [1, 2, 3, 4, 5, 9],
    avoid: [10, 11, 12],
    notes: "Equatorial island nation: slightly drier mid-year months work best, while some late-year months are wetter.",
  },

  // Cabo Verde already present above as CV.

  // Kiribati
  KI: {
    best: [6, 7, 8, 9],
    shoulder: [4, 5, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Pacific island climate with a somewhat drier, more settled mid-year period; earlier months can be wetter and more cyclone-prone depending on atoll.",
  },

  // Marshall Islands
  MH: {
    best: [1, 2, 3, 4],
    shoulder: [5, 6, 7],
    avoid: [8, 9, 10, 11, 12],
    notes: "Tropical Pacific with year-round warmth; later-year months can see more storms and rougher seas.",
  },

  // Micronesia (Federated States of)
  FM: {
    best: [1, 2, 3, 4],
    shoulder: [5, 6, 7],
    avoid: [8, 9, 10, 11, 12],
    notes: "Equatorial islands with frequent showers; early-year months are often a bit more settled for diving and boating.",
  },

  // Palau
  PW: {
    best: [2, 3, 4],
    shoulder: [1, 5, 6, 7],
    avoid: [8, 9, 10, 11, 12],
    notes: "Generally warm and humid year-round, but late winter and early spring can offer slightly clearer weather for diving.",
  },

  // Tuvalu
  TV: {
    best: [5, 6, 7, 8],
    shoulder: [4, 9],
    avoid: [1, 2, 3, 10, 11, 12],
    notes: "Small Pacific nation with limited weather variation; mid-year may be marginally less stormy.",
  },

  // New Caledonia (FR territory)
  NC: {
    best: [4, 5, 6, 9, 10],
    shoulder: [3, 7, 8, 11],
    avoid: [1, 2, 12],
    notes: "Subtropical South Pacific: spring and fall balance warm seas with milder humidity; cyclone risk peaks around summer.",
  },

  // French Polynesia (PF)
  PF: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Best for islands and lagoons in the drier, cooler mid-year months; summer can be more humid with heavier showers.",
  },

  // Cayman Islands
  KY: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Similar to many Caribbean neighbours: winter and early spring are ideal; late summer and fall bring more storm risk.",
  },

  // Turks and Caicos Islands
  TC: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Dry season is best for beaches; peak hurricane season runs from late summer into early fall.",
  },

  // British Virgin Islands
  VG: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Great for sailing and beaches in the dry season; late summer and fall can be stormier.",
  },

  // US Virgin Islands
  VI: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Follows a typical Lesser Antilles pattern: winter and early spring are sunnier and drier; late summer/fall has higher hurricane risk.",
  },

  // Saint Kitts and Nevis
  KN: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Dry season is prime time; later months see more tropical storms, similar to other nearby islands.",
  },

  // Dominica
  DM: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Hiking and nature trips are easier in the drier months; late summer/fall can be wetter with storm risk.",
  },

  // Bermuda
  BM: {
    best: [3, 4, 5, 9, 10],
    shoulder: [2, 6, 7, 8, 11],
    avoid: [1, 12],
    notes: "Subtropical Atlantic: spring and fall balance warm weather and lower storm risk; hurricane season peaks late summer into early fall.",
  },

  // Anguilla
  AI: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Typical Lesser Antilles pattern: winter and early spring are driest; late summer and fall carry higher hurricane risk.",
  },

  // Montserrat
  MS: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Best to visit in the dry season for clearer views and hiking; late summer and autumn are wetter and more storm-prone.",
  },

  // Saint Barthélemy
  BL: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "High season in winter has the most reliable beach weather; late summer and fall are peak hurricane months.",
  },

  // Saint Martin (French part)
  MF: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Dry, sunny months around winter are ideal; late summer and early fall can be stormy.",
  },

  // Guadeloupe
  GP: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Caribbean dry season offers calmer seas and more sun; hurricane risk rises later in the year.",
  },

  // Martinique
  MQ: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Winter and early spring are best for beach and hiking; late summer and fall are wetter with more storms.",
  },

  // Sint Maarten (Dutch part)
  SX: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Follows a similar pattern to neighbouring islands: dry, sunny winter; wetter, stormier late summer and fall.",
  },

  // Curaçao
  CW: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Outside of hurricane belt but still has a drier high season in winter and early spring; late summer can be hotter and more humid.",
  },

  // Aruba
  AW: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Dry, breezy conditions make winter and early spring ideal; late summer/fall is hotter and more humid, with some storm risk.",
  },

  // Bonaire, Sint Eustatius and Saba
  BQ: {
    best: [12, 1, 2, 3, 4],
    shoulder: [11, 5],
    avoid: [8, 9, 10],
    notes: "Divers love the generally stable conditions, but winter and early spring offer slightly drier, calmer weather overall.",
  },

  // Mayotte
  YT: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Dryer, cooler months mid-year are best for beaches and lagoons; cyclone season peaks around the start of the year.",
  },

  // French Guiana
  GF: {
    best: [8, 9, 10],
    shoulder: [1, 2, 3, 4, 7, 11, 12],
    avoid: [5, 6],
    notes: "Equatorial with long rainy seasons; a late dry-ish window around Aug–Oct is generally more comfortable for travel.",
  },

  // Gibraltar
  GI: {
    best: [4, 5, 6, 9, 10],
    shoulder: [3, 7, 8, 11],
    avoid: [1, 2, 12],
    notes: "Shares a Mediterranean pattern with southern Spain: spring and fall are most pleasant; midsummer is hotter but fine for sun-seekers.",
  },

  // Jersey
  JE: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4],
    notes: "Short, mild summers are the sweet spot for beaches and coastal walks; the rest of the year is cooler and often wetter.",
  },

  // Guernsey
  GG: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4],
    notes: "Similar to Jersey: summer brings the best mix of warmth and daylight; winter months are grey and damp.",
  },

  // Isle of Man
  IM: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4],
    notes: "Summer is most comfortable for coastal scenery and events like the TT; winters are cool and windy.",
  },

  // Åland Islands
  AX: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4],
    notes: "Baltic archipelago with very short summers; those months are best for ferries, cycling, and island-hopping.",
  },

  // Svalbard and Jan Mayen
  SJ: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4],
    notes: "Arctic environment: short summer is the main accessible window; the rest of the year is polar night or deep winter.",
  },

  // Northern Mariana Islands
  MP: {
    best: [1, 2, 3, 4],
    shoulder: [5, 6, 7],
    avoid: [8, 9, 10, 11, 12],
    notes: "Tropical Pacific pattern: early-year months are a bit drier and calmer; late summer and fall see more storms.",
  },

  // Guam
  GU: {
    best: [1, 2, 3, 4],
    shoulder: [5, 6, 7],
    avoid: [8, 9, 10, 11, 12],
    notes: "Warm year-round; early months are usually slightly less rainy, while late summer into fall has higher typhoon risk.",
  },

  // American Samoa
  AS: {
    best: [6, 7, 8, 9],
    shoulder: [4, 5, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Cooler, drier months mid-year are generally best for hiking and coastal trips; cyclone season clusters around the start of the year.",
  },

  // Cook Islands
  CK: {
    best: [6, 7, 8, 9],
    shoulder: [4, 5, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "South Pacific pattern: winter and early spring are less humid and stormy; early-year months carry more cyclone risk.",
  },

  // Niue
  NU: {
    best: [6, 7, 8, 9],
    shoulder: [4, 5, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Small Pacific island with a similar rhythm to nearby countries: mid-year is generally best for calmer seas and diving.",
  },

  // Wallis and Futuna
  WF: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Tropical, humid climate with a somewhat drier, calmer mid-year period; cyclone season clusters around the start of the year.",
  },
  // Democratic Republic of the Congo
  CD: {
    best: [6, 7, 8],
    shoulder: [12, 1, 2],
    avoid: [3, 4, 5, 9, 10, 11],
    notes: "Equatorial climate with pronounced wet seasons; drier, slightly cooler months around Jun–Aug and mid-winter are generally more comfortable for overland travel.",
  },

  // Republic of the Congo
  CG: {
    best: [6, 7, 8],
    shoulder: [12, 1, 2],
    avoid: [3, 4, 5, 9, 10, 11],
    notes: "Similar to its larger neighbour: mid-year and parts of winter tend to be less rainy and slightly cooler, making travel easier.",
  },

  // The Gambia
  GM: {
    best: [11, 12, 1, 2],
    shoulder: [3, 10],
    avoid: [4, 5, 6, 7, 8, 9],
    notes: "Dry season around Nov–Feb is ideal for beaches and river trips; mid-year is wetter and more humid.",
  },

  // Guinea
  GN: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "A long wet season dominates much of the year; the short, cooler dry season around Dec–Feb is generally more comfortable.",
  },

  // Guinea-Bissau
  GW: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Dry season at the turn of the year is more pleasant for islands and mangroves; other months are hotter and rainier.",
  },

  // Equatorial Guinea
  GQ: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Tropical climate with heavy rains mid-year; the main dry season around Dec–Feb is usually easier for travel.",
  },

  // Gabon
  GA: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4],
    notes: "A drier, cooler stretch in mid-year tends to suit national parks and coasts better than the wetter shoulder seasons.",
  },

  // Comoros
  KM: {
    best: [5, 6, 7, 8, 9],
    shoulder: [4, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Cooler, drier winter months are best for beaches and diving; cyclone season clusters around the start of the year.",
  },

  // Libya (climate baseline only)
  LY: {
    best: [3, 4, 5, 10, 11],
    shoulder: [2, 6],
    avoid: [7, 8, 9, 1, 12],
    notes: "Mediterranean coast is pleasant in spring and fall; summers are extremely hot, especially inland. Always verify current safety conditions separately.",
  },

  // Somalia (climate baseline only)
  SO: {
    best: [12, 1, 2],
    shoulder: [3, 11],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Very hot and arid for much of the year; relatively cooler, drier winter months are somewhat more manageable. Always check current safety guidance.",
  },

  // Saint Helena, Ascension and Tristan da Cunha
  SH: {
    best: [3, 4, 5, 9, 10],
    shoulder: [2, 6, 7, 8, 11],
    avoid: [1, 12],
    notes: "Mild subtropical climate with no extreme seasons; spring and fall often feel nicest for outdoor exploring.",
  },

  // Brunei Darussalam
  BN: {
    best: [2, 3, 4, 7, 8, 9],
    shoulder: [1, 5, 6, 10],
    avoid: [11, 12],
    notes: "Hot and humid year-round; some mid-year months are slightly drier, but heavy showers are possible anytime.",
  },

  // North Korea (climate baseline only)
  KP: {
    best: [5, 6, 9, 10],
    shoulder: [4, 7, 8],
    avoid: [11, 12, 1, 2, 3],
    notes: "Continental pattern: late spring and early fall are most pleasant; winters are very cold and summers can be hot and humid. Access is heavily restricted.",
  },

  // Timor-Leste
  TL: {
    best: [5, 6, 7],
    shoulder: [4, 8],
    avoid: [11, 12, 1, 2, 3, 9, 10],
    notes: "Dry season (roughly May–Jul) is best for diving and mountain travel; the wet season can bring heavy rains and rough seas.",
  },

  // Nauru
  NR: {
    best: [5, 6, 7, 8],
    shoulder: [4, 9],
    avoid: [1, 2, 3, 10, 11, 12],
    notes: "Equatorial climate with limited seasonal variation, but mid-year can be marginally less stormy and humid.",
  },

  // Tokelau
  TK: {
    best: [6, 7, 8],
    shoulder: [5, 9],
    avoid: [1, 2, 3, 4, 10, 11, 12],
    notes: "Remote Pacific atolls with a sweet spot in mid-year; cyclone risk is higher around the start of the year.",
  },

  // Falkland Islands
  FK: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Sub-Antarctic climate: austral summer months are the most practical for wildlife and hiking, though still cool and windy.",
  },

  // Saint Pierre and Miquelon
  PM: {
    best: [7, 8],
    shoulder: [6, 9],
    avoid: [10, 11, 12, 1, 2, 3, 4, 5],
    notes: "Short North Atlantic summer is the main visiting window; the rest of the year is chilly, windy, and often foggy.",
  },

  // South Georgia and the South Sandwich Islands
  GS: {
    best: [1, 2, 3],
    shoulder: [12, 4],
    avoid: [5, 6, 7, 8, 9, 10, 11],
    notes: "Primarily cruise destinations; the austral summer window offers the least harsh conditions and best wildlife viewing.",
  },

  // Antarctica
  AQ: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Cruise season runs through the austral summer, when sea ice retreats and temperatures are least extreme.",
  },

  // British Indian Ocean Territory
  IO: {
    best: [5, 6, 7, 8],
    shoulder: [4, 9],
    avoid: [10, 11, 12, 1, 2, 3],
    notes: "Tropical Indian Ocean climate with a somewhat drier, calmer mid-year; early-year months see more storms and humidity.",
  },

  // French Southern Territories
  TF: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Remote sub-Antarctic islands visited mainly by expeditions; austral summer offers the most workable conditions.",
  },

  // Bouvet Island
  BV: {
    best: [1, 2],
    shoulder: [12, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10, 11],
    notes: "Uninhabited and extremely remote; any visit would be in the least harsh summer months, though conditions remain severe.",
  },

  // Heard Island and McDonald Islands
  HM: {
    best: [1, 2],
    shoulder: [12, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10, 11],
    notes: "Sub-Antarctic volcanic islands reached only by expeditions; austral summer is the only realistic window, and even then conditions are rough.",
  },

  // Pitcairn Islands
  PN: {
    best: [5, 6, 7, 8],
    shoulder: [4, 9],
    avoid: [1, 2, 3, 10, 11, 12],
    notes: "Subtropical South Pacific with a slightly cooler, drier mid-year; shoulder months can still work but seas may be rougher.",
  },

  // Cocos (Keeling) Islands
  CC: {
    best: [6, 7, 8, 9],
    shoulder: [4, 5, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Tropical atolls where mid-year often brings slightly calmer weather; cyclone season peaks in the first months of the year.",
  },

  // Christmas Island
  CX: {
    best: [6, 7, 8, 9],
    shoulder: [4, 5, 10],
    avoid: [1, 2, 3, 11, 12],
    notes: "Equatorial island with wet and dry swings; mid-year is typically less rainy, which helps with hiking and wildlife watching.",
  },

  // Norfolk Island
  NF: {
    best: [10, 11, 12, 1, 2],
    shoulder: [3, 9],
    avoid: [4, 5, 6, 7, 8],
    notes: "Subtropical climate: late spring through summer and early autumn are mild and pleasant, while winter and early spring can be stormier.",
  },

  // Western Sahara (climate baseline only)
  EH: {
    best: [12, 1, 2],
    shoulder: [11, 3],
    avoid: [4, 5, 6, 7, 8, 9, 10],
    notes: "Desert territory with extreme heat most of the year; cooler winter months are generally more bearable. Always verify political and safety conditions.",
  },

  // U.S. Minor Outlying Islands (aggregate baseline)
  UM: {
    best: [5, 6, 7, 8],
    shoulder: [4, 9],
    avoid: [1, 2, 3, 10, 11, 12],
    notes: "Scattered Pacific and Caribbean islands with tropical climates; mid-year months often provide a somewhat drier, calmer window, but conditions vary by atoll.",
  },
  // --- TEMPLATE: copy/paste for every new country/territory you want ------
  //
  // XX: {
  //   best: [/* 1–12 required: your top months */],
  //   shoulder: [/* 1–12 optional: decent but off-peak months */],
  //   avoid: [/* 1–12 optional: months you warn about */],
  //   notes: "Short human-readable explanation you'll see in the app.",
  // },
  //
  // Replace `XX` with the country's ISO2 code (e.g. `FR`, `IT`, `BR`),
  // then fill in arrays + notes. You do NOT need to add every country
  // right away — only the ones you care about. Others will keep using
  // Frequent Miler or default seasonality logic.
};
