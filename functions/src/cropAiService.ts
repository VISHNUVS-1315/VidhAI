/**
 * VidhAI AI crop recommendation service (Structured Outputs).
 *
 * Groq GPT-OSS reasons
 * over ALL of the provided farm context at once — location, soil, water,
 * irrigation, crop history/rotation, current season, live/forecast weather,
 * recent market prices, farm size, budget, duration/category preference,
 * water availability and farming priority. It never invents market prices or
 * weather: those figures are only ever included when the client supplied them
 * from AGMARKNET / Open-Meteo.
 *
 * Output is strictly enforced with a JSON Schema and validated again in code.
 * Financial figures are labelled estimates by the client.
 */

import { groqJson, NvidiaChatMessage } from './nvidia';
import { SHIPPED_CROP_KNOWLEDGE, CropKnowledgeEntry } from './cropData';
import { scoreCrop, FarmContext } from './cropService';

export interface CropRecommendationAiInput {
  cropCategoryPreference?: string;
  lastCrop?: string;
  cropDurationPreference?: string;
  budgetInrPerAcre?: number | null;
  waterAvailability?: string;
  farmingPriority?: string;
  farmerPreference?: string;
  harvestDate?: string;
  landIdleDuration?: string;
  previousCropSowingDate?: string;
  previousCropDuration?: string;
  waterSource?: string;
  seasonalWaterReliability?: string;
  language?: string;
}

export interface AiRecommendedCrop {
  rank: number;
  cropName: string;
  localName: string;
  category: string;
  season: string;
  suitabilityScore: number;
  suitabilityLevel: 'Excellent' | 'Good' | 'Moderate' | 'Poor';
  whySuitable: string[];
  soilMatch: string;
  waterMatch: string;
  seasonMatch: string;
  rotationMatch: string;
  marketOutlook: string;
  estimatedDurationDays: number;
  estimatedInvestment: { min: number; max: number; currency: string };
  estimatedRevenue: { min: number; max: number; currency: string };
  estimatedProfit: { min: number; max: number; currency: string };
  sowingWindow: string;
  estimatedHarvestWindow: string;
  waterRequirement: string;
  riskLevel: 'Low' | 'Medium' | 'High';
  majorRisks: string[];
  confidence: number;
}

export interface AiRecommendationResult {
  analysisSummary: string;
  model: string;
  recommendations: AiRecommendedCrop[];
}

const moneySchema = {
  type: 'object',
  additionalProperties: false,
  required: ['min', 'max', 'currency'],
  properties: {
    min: { type: 'number' },
    max: { type: 'number' },
    currency: { type: 'string', const: 'INR' },
  },
} as const;

/** Strict JSON Schema (Structured Outputs). Every field is required. */
export const cropRecommendationSchema = {
  name: 'crop_recommendations',
  strict: true,
  schema: {
    type: 'object',
    additionalProperties: false,
    required: ['analysisSummary', 'recommendations'],
    properties: {
      analysisSummary: { type: 'string' },
      recommendations: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          required: [
            'rank',
            'cropName',
            'localName',
            'category',
            'season',
            'suitabilityScore',
            'suitabilityLevel',
            'whySuitable',
            'soilMatch',
            'waterMatch',
            'seasonMatch',
            'rotationMatch',
            'marketOutlook',
            'estimatedDurationDays',
            'estimatedInvestment',
            'estimatedRevenue',
            'estimatedProfit',
            'sowingWindow',
            'estimatedHarvestWindow',
            'waterRequirement',
            'riskLevel',
            'majorRisks',
            'confidence',
          ],
          properties: {
            rank: { type: 'integer' },
            cropName: { type: 'string' },
            localName: { type: 'string' },
            category: { type: 'string' },
            season: { type: 'string' },
            suitabilityScore: { type: 'integer' },
            suitabilityLevel: {
              type: 'string',
              enum: ['Excellent', 'Good', 'Moderate', 'Poor'],
            },
            whySuitable: { type: 'array', items: { type: 'string' } },
            soilMatch: { type: 'string' },
            waterMatch: { type: 'string' },
            seasonMatch: { type: 'string' },
            rotationMatch: { type: 'string' },
            marketOutlook: { type: 'string' },
            estimatedDurationDays: { type: 'integer' },
            estimatedInvestment: moneySchema,
            estimatedRevenue: moneySchema,
            estimatedProfit: moneySchema,
            sowingWindow: { type: 'string' },
            estimatedHarvestWindow: { type: 'string' },
            waterRequirement: { type: 'string' },
            riskLevel: { type: 'string', enum: ['Low', 'Medium', 'High'] },
            majorRisks: { type: 'array', items: { type: 'string' } },
            confidence: { type: 'integer' },
          },
        },
      },
    },
  },
} as const;

function clampInt(v: unknown, min: number, max: number): number {
  const n = typeof v === 'number' ? Math.round(v) : Number(v);
  if (!Number.isFinite(n)) return min;
  return Math.min(max, Math.max(min, n));
}

function clampNum(v: unknown, min: number, max: number): number {
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n)) return min;
  return Math.min(max, Math.max(min, Math.round(n * 100) / 100));
}

function asString(v: unknown): string {
  return typeof v === 'string' ? v.trim() : '';
}

function asStringArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v
    .map((x) => asString(x))
    .filter((s) => s.length > 0)
    .slice(0, 12);
}

function normalizeName(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '').trim();
}

function canonicalCategoryPreference(value: string | undefined): string | null {
  const key = (value ?? '').trim().toLowerCase().replace(/[_-]+/g, ' ');
  if (!key || key === 'no preference' || key === 'any' || key === 'other') {
    return null;
  }
  const aliases: Record<string, string> = {
    vegetable: 'Vegetables',
    vegetables: 'Vegetables',
    fruit: 'Fruits',
    fruits: 'Fruits',
    flower: 'Flowers',
    flowers: 'Flowers',
    cereal: 'Cereals',
    cereals: 'Cereals',
    pulse: 'Pulses',
    pulses: 'Pulses',
    oilseed: 'Oilseeds',
    oilseeds: 'Oilseeds',
    spice: 'Spices',
    spices: 'Spices',
    plantation: 'Plantation Crops',
    'plantation crop': 'Plantation Crops',
    'plantation crops': 'Plantation Crops',
    tree: 'Tree Crops',
    'tree crop': 'Tree Crops',
    'tree crops': 'Tree Crops',
    leafy: 'Leafy Vegetables',
    'leafy vegetable': 'Leafy Vegetables',
    'leafy vegetables': 'Leafy Vegetables',
    medicinal: 'Medicinal/Aromatic',
    aromatic: 'Medicinal/Aromatic',
    'medicinal/aromatic': 'Medicinal/Aromatic',
    'commercial/cash crops': 'Commercial/Cash Crops',
    'commercial crops': 'Commercial/Cash Crops',
    'cash crops': 'Commercial/Cash Crops',
    commercial: 'Commercial/Cash Crops',
  };
  return aliases[key] ?? value!.trim();
}

function categoryMatches(entry: CropKnowledgeEntry, requested: string | null): boolean {
  if (!requested) return true;
  return entry.category.trim().toLowerCase() === requested.trim().toLowerCase();
}

/** Matches a model-reported crop name against the shipped deterministic catalog. */
function catalogFor(name: string): CropKnowledgeEntry | null {
  const q = normalizeName(name);
  if (!q) return null;
  const exact = SHIPPED_CROP_KNOWLEDGE.find((c) => normalizeName(c.name) === q);
  if (exact) return exact;
  const contains = SHIPPED_CROP_KNOWLEDGE.filter(
    (c) => normalizeName(c.name).includes(q) || q.includes(normalizeName(c.name)),
  ).sort((a, b) => normalizeName(a.name).length - normalizeName(b.name).length);
  return contains[0] ?? null;
}

/** Parses model-formatted amounts such as "?18,000" / "₹18,000" / 18000. */
function parseAmount(v: unknown): number | null {
  if (typeof v === 'number') return Number.isFinite(v) ? Math.round(v) : null;
  if (typeof v !== 'string') return null;
  const cleaned = v.replace(/[₹Rs$?,\s]/gi, '').replace('-', '').trim();
  if (!/^\d{1,9}$/.test(cleaned)) return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? Math.round(n) : null;
}

function clampMoney(
  v: unknown,
  fallback: { min: number; max: number; currency: string },
): { min: number; max: number; currency: string } {
  if (!v || typeof v !== 'object') return fallback;
  const o = v as Record<string, unknown>;
  const min = clampNum(o['min'], 0, 10_000_000);
  const max = clampNum(o['max'], min, 10_000_000);
  return { min, max, currency: asString(o['currency']) || 'INR' };
}

/**
 * Validates and normalizes model JSON into a guaranteed-safe recommendation
 * set. The model sometimes returns a compact schema (`crop`, `reason`,
 * per-acre ₹ strings) instead of the full canonical schema; every missing
 * field is back-filled from the deterministic catalog so the client always
 * receives complete, honest agronomic facts (durations, water need, sowing
 * windows, budget/money ranges, risks).
 */
export function sanitizeAiRecommendations(
  raw: unknown,
  ctx?: Record<string, unknown>,
  requestedCategory?: string,
): AiRecommendedCrop[] {
  if (!raw || typeof raw !== 'object') return [];
  const list = (raw as Record<string, unknown>)['recommendations'];
  if (!Array.isArray(list)) return [];

  const out: AiRecommendedCrop[] = [];
  const seen = new Set<string>();
  const seenCatalogIds = new Set<string>();
  for (const item of list) {
    if (!item || typeof item !== 'object') continue;
    const o = item as Record<string, unknown>;
    const cropName = asString(o['cropName']) || asString(o['crop']);
    if (!cropName || seen.has(cropName.toLowerCase())) continue;
    seen.add(cropName.toLowerCase());

    const entry = catalogFor(cropName);
    const categoryConstraint = canonicalCategoryPreference(requestedCategory);
    // With a selected crop type, only verified catalog crops in that exact
    // category are allowed. Unknown model names are discarded instead of
    // widening the farmer's request.
    if (categoryConstraint && (!entry || !categoryMatches(entry, categoryConstraint))) {
      continue;
    }
    // Dedupe semantic twins (e.g. "Ragi" vs "Finger Millet", variety variants).
    if (entry && seenCatalogIds.has(entry.id)) continue;
    if (entry) seenCatalogIds.add(entry.id);
    const rawDuration = clampInt(o['estimatedDurationDays'], 0, 730);
    const duration =
      rawDuration || (entry ? clampInt(entry.durationDaysMin, 1, 730) : 0);

    const modelScore = clampInt(o['suitabilityScore'], 0, 100);
    const score =
      modelScore ||
      (entry && ctx
        ? clampInt(scoreCrop(entry, ctx as unknown as FarmContext).score, 0, 100)
        : 0) ||
      Math.max(50, 95 - (out.length + 1) * 5);

    const zero = { min: 0, max: 0, currency: 'INR' };
    let investment = clampMoney(o['estimatedInvestment'], zero);
    let revenue = clampMoney(o['estimatedRevenue'], zero);
    let profit = clampMoney(o['estimatedProfit'], zero);
    if (entry) {
      // Honest deterministic ranges from the shipped catalog take precedence
      // over any free-form figures the model may have produced.
      const inv = entry.cultivationCostPerAcre;
      const yld = entry.expectedYieldPerAcre;
      const prc = entry.pricePerQuintal;
      investment = clampMoney({ min: inv.min, max: inv.max }, zero);
      revenue = clampMoney(
        { min: Math.round(yld.min * prc.min), max: Math.round(yld.max * prc.max) },
        zero,
      );
      profit = clampMoney(
        {
          min: Math.max(0, revenue.min - investment.max),
          max: Math.max(0, revenue.max - investment.min),
        },
        zero,
      );
    } else {
      // No catalog match: use the model-compact per-acre estimates as a band.
      const applyBand = (key: string, target: { min: number; max: number }) => {
        const n = parseAmount(o[key]);
        if (n === null) return;
        const min = Math.max(0, Math.round(n * 0.9));
        target.min = clampNum(min, 0, 10_000_000);
        target.max = clampNum(Math.round(n * 1.1), target.min, 10_000_000);
      };
      applyBand('estimatedInvestmentPerAcre', investment);
      applyBand('estimatedRevenuePerAcre', revenue);
      applyBand('estimatedProfitPerAcre', profit);
    }

    const why = asStringArray(o['whySuitable']);
    if (why.length === 0) {
      const reason = asString(o['reason']) || asString(o['why']);
      if (reason) why.push(reason);
    }

    const modelRisks = asStringArray(o['majorRisks']);
    const riskLabel = asString(o['riskLevel']);
    const modelMoneyBand = () =>
      `${investment.min.toLocaleString('en-IN')}–${investment.max.toLocaleString('en-IN')} INR`;

    out.push({
      rank: out.length + 1,
      cropName: entry?.name ?? cropName,
      localName: asString(o['localName']) || (entry ? entry.varieties[0] ?? '' : ''),
      category: entry?.category ?? asString(o['category']),
      season: asString(o['season']) || (entry ? entry.season : ''),
      suitabilityScore: score,
      suitabilityLevel:
        score >= 80 ? 'Excellent' : score >= 60 ? 'Good' : score >= 40 ? 'Moderate' : 'Poor',
      whySuitable: why,
      soilMatch: asString(o['soilMatch']),
      waterMatch: asString(o['waterMatch']),
      seasonMatch: asString(o['seasonMatch']) || (entry ? entry.season : ''),
      rotationMatch: asString(o['rotationMatch']),
      marketOutlook:
        asString(o['marketOutlook']) ||
        (entry
          ? `Market demand: ${entry.marketDemand}. Reference price band: ${modelMoneyBand()}.`
          : ''),
      estimatedDurationDays: duration,
      estimatedInvestment: investment,
      estimatedRevenue: revenue,
      estimatedProfit: profit,
      sowingWindow:
        asString(o['sowingWindow']) || (entry ? entry.plantingWindows.join(' / ') : ''),
      estimatedHarvestWindow:
        asString(o['estimatedHarvestWindow']) || (entry ? entry.harvestMonths : ''),
      waterRequirement:
        asString(o['waterRequirement']) || (entry ? String(entry.waterRequirement) : ''),
      riskLevel: ['Low', 'Medium', 'High'].includes(riskLabel)
        ? (riskLabel as 'Low' | 'Medium' | 'High')
        : entry
          ? entry.riskLevel
          : 'Medium',
      majorRisks:
        modelRisks.length > 0 ? modelRisks : entry ? entry.risks.slice(0, 6) : [],
      confidence: clampInt(o['confidence'], 0, 100) || (entry ? 88 : 70),
    });
    if (out.length === 10) break;
  }
  return out;
}

function sortRecommended(a: AiRecommendedCrop, b: AiRecommendedCrop): number {
  if (b.suitabilityScore !== a.suitabilityScore) return b.suitabilityScore - a.suitabilityScore;
  return a.rank - b.rank;
}

/**
 * Builds a plain-text context block for the model. Only facts the caller
 * provided are included; unknown/missing values are explicitly marked
 * "(not provided)" so the model never fills gaps with guesses.
 */
export function buildContextText(farmContext: Record<string, unknown>): string {
  const s = (v: unknown): string => {
    if (v === null || v === undefined || v === '') return '(not provided)';
    return String(v);
  };
  const object = (v: unknown): Record<string, unknown> =>
    v && typeof v === 'object' && !Array.isArray(v)
      ? (v as Record<string, unknown>)
      : {};

  const location = object(farmContext['location']);
  const farm = object(farmContext['farm']);
  const soil = object(farmContext['soil']);
  const water = object(farmContext['water']);
  const history = object(farmContext['cropHistory']);
  const expenses = object(farmContext['expenses']);
  const weather = object(farmContext['weather']);
  const language = object(farmContext['language']);
  const currentCrops = Array.isArray(farmContext['currentCrops'])
    ? farmContext['currentCrops']
    : [];
  const market = Array.isArray(farmContext['marketPrices'])
    ? farmContext['marketPrices']
    : [];

  const lines: string[] = [];
  lines.push(`Selected language: ${s(language['code'])}`);
  lines.push(`Farm state: ${s(location['state'] ?? farm['state'])}`);
  lines.push(`District: ${s(location['district'] ?? farm['district'])}`);
  lines.push(`Local area: ${s(location['place'])}`);
  if (location['latitude'] != null && location['longitude'] != null) {
    lines.push(
      `Coordinates: lat ${s(location['latitude'])}, lng ${s(location['longitude'])}`,
    );
  }
  lines.push(`Farm name: ${s(farm['farmName'])}`);
  lines.push(`Farm area (acres): ${s(farm['farmSizeAcres'])}`);
  lines.push(`Soil type: ${s(soil['type'] ?? farm['soilType'])}`);
  if (soil['aiAnalysis']) {
    lines.push(`Stored soil analysis: ${s(soil['aiAnalysis'])}`);
  }
  lines.push(
    `Water availability: ${s(water['availability'] ?? farm['waterAvailability'])}`,
  );
  lines.push(`Water source: ${s(water['source'] ?? farm['waterSource'])}`);
  lines.push(
    `Irrigation system: ${s(water['irrigation'] ?? farm['irrigationType'])}`,
  );
  lines.push(`Farming method: ${s(farm['farmingMethod'])}`);
  lines.push(`Current agricultural season: ${s(farmContext['season'])}`);
  lines.push(`Context date: ${s(farmContext['date'])}`);

  if (currentCrops.length > 0) {
    lines.push(
      `Currently active crop(s): ${JSON.stringify(currentCrops.slice(0, 3))}`,
    );
  }

  const historyCrops = Array.isArray(history['crops']) ? history['crops'] : [];
  if (historyCrops.length > 0 || history['lastCrop']) {
    lines.push(
      `Previous crop history: ${JSON.stringify({
        lastCrop: history['lastCrop'] ?? null,
        count: history['count'] ?? historyCrops.length,
        crops: historyCrops.slice(0, 8),
      })}`,
    );
  }

  if (Object.keys(expenses).length > 0) {
    lines.push(`Farm expense summary: ${JSON.stringify(expenses)}`);
  }

  if (Object.keys(weather).length > 0) {
    lines.push(
      `Current/forecast weather from Open-Meteo: ${JSON.stringify(weather)}`,
    );
  } else {
    lines.push('Current/forecast weather: (not available)');
  }

  if (market.length > 0) {
    lines.push(
      `Recent reported market prices from AGMARKNET: ${JSON.stringify(
        market.slice(0, 12),
      )}`,
    );
  } else {
    lines.push('Recent reported market prices: (not available)');
  }

  return lines.join('\n');
}

export async function recommendWithAI(
  farmContext: Record<string, unknown>,
  input: CropRecommendationAiInput,
): Promise<AiRecommendationResult> {
  const language = input.language || 'en';
  const contextText = buildContextText(farmContext);
  const requestedCategory =
    canonicalCategoryPreference(input.cropCategoryPreference);
  const allowedCandidates = requestedCategory
    ? SHIPPED_CROP_KNOWLEDGE.filter((entry) =>
        categoryMatches(entry, requestedCategory),
      )
    : SHIPPED_CROP_KNOWLEDGE;

  if (requestedCategory && allowedCandidates.length === 0) {
    return {
      analysisSummary:
        `No verified ${requestedCategory} crops are currently available in the server catalogue; the app should use its verified local fallback for this crop type.`,
      model:
        process.env.AI_CROP_MODEL ??
        process.env.AI_CHAT_MODEL ??
        'openai/gpt-oss-20b',
      recommendations: [],
    };
  }

  const candidateText = allowedCandidates
    .slice(0, 40)
    .map(
      (entry) =>
        `${entry.name} [${entry.category}; ${entry.season}; ${entry.durationDaysMin}-${entry.durationDaysMax} days; water ${entry.waterRequirement}]`,
    )
    .join('\n');

  const system = [
    'You are VidhAI, an expert agronomist for Indian farms.',
    'Analyse ALL of the provided farm context together: location, soil, water, irrigation, crop rotation/history, current season, live or forecast weather, recent reported market prices, farm size, budget, crop duration and category preference, water availability and farming priority.',
    'The selected crop type/category is a HARD FILTER, not a soft preference.',
    'If a crop type is selected, NEVER return a crop from another category even if it scores well on other factors.',
    'Do NOT recommend a crop merely because it belongs to the requested category; rank only category-valid crops after analysing soil, water, season, rotation, budget, duration, weather and location.',
    'Only use facts that were provided. If live market prices or weather were not provided, state that in marketOutlook/seasonMatch and never invent numbers.',
    'Every recommendation must have an understandable reason for its ranking.',
    'Financial figures (investment, revenue, profit) are rough estimates in INR; use a modest, realistic range and never guarantee prices.',
    `Respond in the requested language: ${language}.`,
  ].join('\n');

  const user = [
    'Farmer inputs:',
    `- Crop category preference: ${input.cropCategoryPreference || '(no preference)'}`,
    `- Preferred duration: ${input.cropDurationPreference || '(no preference)'}`,
    `- Budget per acre (INR): ${input.budgetInrPerAcre ?? '(not provided)'}`,
    `- Current water availability: ${input.waterAvailability || '(not provided)'}`,
    `- Water source: ${input.waterSource || '(auto context if available)'}`,
    `- Previous crop: ${input.lastCrop || '(auto context if available)'}`,
    `- Last harvest date: ${input.harvestDate || '(not available)'}`,
    `- Land idle duration (months): ${input.landIdleDuration || '(not available)'}`,
    `- Previous sowing date: ${input.previousCropSowingDate || '(not available)'}`,
    `- Previous crop duration (days): ${input.previousCropDuration || '(not available)'}`,
    `- Farming priority: ${input.farmingPriority || 'Balanced'}`,
    `- Optional preference: ${input.farmerPreference || '(none)'}`,
    '',
    'Automatically collected farm context:',
    contextText,
    '',
    requestedCategory
      ? `HARD CROP TYPE CONSTRAINT: ${requestedCategory}. Return ONLY crops in this category.`
      : 'Crop type constraint: none (all verified categories may be considered).',
    '',
    'Verified candidate catalogue for this request:',
    candidateText,
    '',
    'Choose only from the verified candidate catalogue above.',
    'Return up to 10 ranked suitable crops in the strict JSON schema. If fewer than 10 verified category-valid crops are suitable, return fewer; never pad with another category.',
  ].join('\n');

  const messages: NvidiaChatMessage[] = [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ];

  const result = await groqJson<Record<string, unknown>>(messages, {
    schema: cropRecommendationSchema,
    language,
    model:
      process.env.AI_CROP_MODEL ??
      process.env.AI_CHAT_MODEL ??
      'openai/gpt-oss-20b',
    temperature: 0.25,
    maxTokens: 10000,
    reasoningEffort: 'low',
    timeoutMs: 45_000,
  });
  const recommendations = sanitizeAiRecommendations(
    result.data,
    farmContext,
    requestedCategory ?? undefined,
  ).sort(sortRecommended);
  const analysisSummary =
    asString((result.data as Record<string, unknown>)['analysisSummary']) ||
    'Ranked top crops for your farm based on the available data.';

  return {
    analysisSummary,
    model: result.model,
    recommendations,
  };
}