/**
 * Live AI crop recommendation service for VidhAI.
 *
 * Ranking is produced by NVIDIA Nemotron from the farmer's current manual
 * preferences plus auto-collected farm context. The shipped crop catalog is
 * used only to validate/back-fill agronomic reference fields after the model
 * has chosen and ranked the crops; it is never used as a replacement ranking
 * when the live AI request fails.
 */

import {
  llmPost,
  nvidiaProvider,
  NvidiaChatMessage,
} from './nvidia';
import { SHIPPED_CROP_KNOWLEDGE, CropKnowledgeEntry } from './cropData';

export interface CropRecommendationAiInput {
  cropCategoryPreference?: string;
  cropDurationPreference?: string;
  budgetInrPerAcre?: number | null;
  waterAvailability?: string;
  farmingPriority?: string;
  farmerPreference?: string;
  language?: string;

  // Additional farmer-confirmed/auto-filled questionnaire context.
  lastCrop?: string;
  harvestDate?: string;
  landIdleDuration?: string;
  lastIrrigation?: string;
  soilType?: string;
  soilCondition?: string;
  soilFertility?: string;
  drainageCondition?: string;
  irrigationSystem?: string;
  farmLocation?: string;
  farmSize?: string;
  currentSeason?: string;
  waterSource?: string;
  previousCropSowingDate?: string;
  previousCropDuration?: string;
  seasonalWaterReliability?: string;
}

export interface AiRecommendedCrop {
  rank: number;
  cropName: string;
  localName: string;
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

/** Kept as the public contract used by tests/documentation. */
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
          additionalProperties: true,
          required: ['cropName', 'suitabilityScore'],
          properties: {
            rank: { type: 'integer' },
            cropName: { type: 'string' },
            localName: { type: 'string' },
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

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => asString(item))
    .filter(Boolean)
    .slice(0, 8);
}

function clampInt(value: unknown, min: number, max: number): number {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(parsed)) return min;
  return Math.min(max, Math.max(min, Math.round(parsed)));
}

function clampNum(value: unknown, min: number, max: number): number {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(parsed)) return min;
  return Math.min(max, Math.max(min, Math.round(parsed * 100) / 100));
}

function normalizeName(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '').trim();
}

function catalogFor(name: string): CropKnowledgeEntry | null {
  const query = normalizeName(name);
  if (!query) return null;

  const exact = SHIPPED_CROP_KNOWLEDGE.find(
    (crop) => normalizeName(crop.name) === query,
  );
  if (exact) return exact;

  const matches = SHIPPED_CROP_KNOWLEDGE.filter((crop) => {
    const nameKey = normalizeName(crop.name);
    return nameKey.includes(query) || query.includes(nameKey);
  }).sort(
    (a, b) => normalizeName(a.name).length - normalizeName(b.name).length,
  );

  return matches[0] ?? null;
}

function clampMoney(
  value: unknown,
  fallback: { min: number; max: number; currency: string },
): { min: number; max: number; currency: string } {
  const object = asRecord(value);
  if (Object.keys(object).length === 0) return fallback;
  const min = clampNum(object['min'], 0, 10_000_000);
  const max = clampNum(object['max'], min, 10_000_000);
  return {
    min,
    max,
    currency: asString(object['currency']) || 'INR',
  };
}

function catalogMoney(entry: CropKnowledgeEntry | null): {
  investment: { min: number; max: number; currency: string };
  revenue: { min: number; max: number; currency: string };
  profit: { min: number; max: number; currency: string };
} | null {
  if (!entry) return null;
  const investment = {
    min: entry.cultivationCostPerAcre.min,
    max: entry.cultivationCostPerAcre.max,
    currency: 'INR',
  };
  const revenue = {
    min: Math.round(entry.expectedYieldPerAcre.min * entry.pricePerQuintal.min),
    max: Math.round(entry.expectedYieldPerAcre.max * entry.pricePerQuintal.max),
    currency: 'INR',
  };
  const profit = {
    min: Math.max(0, revenue.min - investment.max),
    max: Math.max(0, revenue.max - investment.min),
    currency: 'INR',
  };
  return { investment, revenue, profit };
}

/**
 * Normalizes the model response while preserving the model's crop selection,
 * order and suitability scores. Catalog data only fills factual detail fields.
 */
export function sanitizeAiRecommendations(raw: unknown): AiRecommendedCrop[] {
  const root = asRecord(raw);
  const list = Array.isArray(root['recommendations'])
    ? (root['recommendations'] as unknown[])
    : [];

  const out: AiRecommendedCrop[] = [];
  const seen = new Set<string>();
  const seenCatalogIds = new Set<string>();

  for (const item of list) {
    const object = asRecord(item);
    const cropName = asString(object['cropName']) || asString(object['crop']);
    if (!cropName) continue;

    const nameKey = cropName.toLowerCase();
    if (seen.has(nameKey)) continue;
    seen.add(nameKey);

    const entry = catalogFor(cropName);
    if (entry && seenCatalogIds.has(entry.id)) continue;
    if (entry) seenCatalogIds.add(entry.id);

    const score = clampInt(object['suitabilityScore'], 1, 100);
    const duration =
      clampInt(object['estimatedDurationDays'], 0, 730) ||
      (entry
        ? Math.round((entry.durationDaysMin + entry.durationDaysMax) / 2)
        : 0);

    const verifiedMoney = catalogMoney(entry);
    const zeroMoney = { min: 0, max: 0, currency: 'INR' };
    const investment = verifiedMoney?.investment ??
        clampMoney(object['estimatedInvestment'], zeroMoney);
    const revenue = verifiedMoney?.revenue ??
        clampMoney(object['estimatedRevenue'], zeroMoney);
    const profit = verifiedMoney?.profit ??
        clampMoney(object['estimatedProfit'], zeroMoney);

    const whySuitable = asStringArray(object['whySuitable']);
    if (whySuitable.length === 0) {
      const reason = asString(object['reason']) || asString(object['why']);
      if (reason) whySuitable.push(reason);
    }

    const riskText = asString(object['riskLevel']);
    const riskLevel: 'Low' | 'Medium' | 'High' =
      riskText === 'Low' || riskText === 'High' || riskText === 'Medium'
        ? riskText
        : entry?.riskLevel ?? 'Medium';

    const risks = asStringArray(object['majorRisks']);

    out.push({
      rank: out.length + 1,
      cropName,
      localName:
        asString(object['localName']) || entry?.varieties.firstOrNull || '',
      suitabilityScore: score,
      suitabilityLevel:
        score >= 80
          ? 'Excellent'
          : score >= 60
            ? 'Good'
            : score >= 40
              ? 'Moderate'
              : 'Poor',
      whySuitable,
      soilMatch: asString(object['soilMatch']),
      waterMatch: asString(object['waterMatch']),
      seasonMatch: asString(object['seasonMatch']) || entry?.season || '',
      rotationMatch: asString(object['rotationMatch']),
      marketOutlook: asString(object['marketOutlook']) ||
          (entry ? `Reference market demand: ${entry.marketDemand}.` : ''),
      estimatedDurationDays: duration,
      estimatedInvestment: investment,
      estimatedRevenue: revenue,
      estimatedProfit: profit,
      sowingWindow:
        asString(object['sowingWindow']) || entry?.plantingWindows.join(' / ') || '',
      estimatedHarvestWindow:
        asString(object['estimatedHarvestWindow']) || entry?.harvestMonths || '',
      waterRequirement:
        asString(object['waterRequirement']) || entry?.waterRequirement || '',
      riskLevel,
      majorRisks: risks.length > 0 ? risks : entry?.risks.slice(0, 4) ?? [],
      confidence: clampInt(object['confidence'], 0, 100) || score,
    });

    if (out.length === 10) break;
  }

  return out
      .sort((a, b) => b.suitabilityScore - a.suitabilityScore)
      .map((crop, index) => ({ ...crop, rank: index + 1 }));
}

function valueOrEmpty(value: unknown): string {
  if (value === null || value === undefined || value === '') return '';
  return String(value);
}

/**
 * Accepts both the older flat crop context and the newer nested
 * AiContextSnapshot.toBackendContext shape.
 */
export function buildContextText(farmContext: Record<string, unknown>): string {
  const farm = asRecord(farmContext['farm']);
  const location = asRecord(farmContext['location']);
  const soil = asRecord(farmContext['soil']);
  const water = asRecord(farmContext['water']);

  const state =
    valueOrEmpty(farmContext['state']) ||
    valueOrEmpty(farm['state']) ||
    valueOrEmpty(location['state']);
  const district =
    valueOrEmpty(farmContext['district']) ||
    valueOrEmpty(farm['district']) ||
    valueOrEmpty(location['district']);
  const place =
    valueOrEmpty(farmContext['place']) ||
    valueOrEmpty(farm['place']) ||
    valueOrEmpty(location['place']);
  const farmSize =
    valueOrEmpty(farmContext['farmSizeAcres']) ||
    valueOrEmpty(farm['farmSizeAcres']) ||
    valueOrEmpty(farmContext['farmerProvidedFarmSize']);
  const soilType =
    valueOrEmpty(farmContext['soilType']) ||
    valueOrEmpty(farm['soilType']) ||
    valueOrEmpty(soil['type']);
  const irrigation =
    valueOrEmpty(farmContext['irrigationType']) ||
    valueOrEmpty(farm['irrigationType']) ||
    valueOrEmpty(water['irrigation']);
  const waterSource =
    valueOrEmpty(farmContext['waterSource']) ||
    valueOrEmpty(farm['waterSource']) ||
    valueOrEmpty(water['source']);
  const waterAvailability =
    valueOrEmpty(farmContext['waterAvailability']) ||
    valueOrEmpty(farm['waterAvailability']) ||
    valueOrEmpty(water['availability']);
  const season = valueOrEmpty(farmContext['season']) || valueOrEmpty(farm['season']);
  const month = farmContext['month'] ?? farm['month'];

  const lines: string[] = [];
  if (state) lines.push(`State: ${state}`);
  if (district) lines.push(`District: ${district}`);
  if (place) lines.push(`Taluk/local area: ${place}`);
  if (farmSize) lines.push(`Farm size: ${farmSize}`);
  if (soilType) lines.push(`Soil type: ${soilType}`);
  if (irrigation) lines.push(`Irrigation system: ${irrigation}`);
  if (waterSource) lines.push(`Water source: ${waterSource}`);
  if (waterAvailability) lines.push(`Saved water availability: ${waterAvailability}`);
  if (season) lines.push(`Current agricultural season: ${season}`);
  if (month != null) lines.push(`Current month: ${String(month)}`);

  const latitude = farmContext['latitude'] ?? farm['latitude'] ?? location['latitude'];
  const longitude = farmContext['longitude'] ?? farm['longitude'] ?? location['longitude'];
  if (latitude != null && longitude != null) {
    lines.push(`Coordinates: lat ${String(latitude)}, lng ${String(longitude)}`);
  }

  const rawHistory = farmContext['cropHistory'];
  if (Array.isArray(rawHistory) && rawHistory.length > 0) {
    lines.push(`Previous crop history: ${JSON.stringify(rawHistory.slice(0, 8))}`);
  } else {
    const historyObject = asRecord(rawHistory);
    const crops = historyObject['crops'];
    if (Array.isArray(crops) && crops.length > 0) {
      lines.push(`Previous crop history: ${JSON.stringify(crops.slice(0, 8))}`);
    }
  }

  const weather = farmContext['weather'];
  if (weather && typeof weather === 'object') {
    lines.push(`Current/forecast weather (Open-Meteo): ${JSON.stringify(weather)}`);
  }

  const market = Array.isArray(farmContext['market'])
    ? farmContext['market']
    : farmContext['marketPrices'];
  if (Array.isArray(market) && market.length > 0) {
    lines.push(
      `Recent reported market prices (AGMARKNET): ${JSON.stringify(market.slice(0, 12))}`,
    );
  }

  const providedLocation = valueOrEmpty(farmContext['farmerProvidedLocation']);
  if (providedLocation) lines.push(`Farmer-confirmed location: ${providedLocation}`);
  const providedLastCrop = valueOrEmpty(farmContext['farmerProvidedLastCrop']);
  if (providedLastCrop) lines.push(`Farmer-confirmed previous crop: ${providedLastCrop}`);

  return lines.length
    ? lines.join('\n')
    : 'No additional farm context was available.';
}

function addInputLine(lines: string[], label: string, value: unknown): void {
  if (value === null || value === undefined || value === '') return;
  lines.push(`- ${label}: ${String(value)}`);
}

function parseJsonResponse(content: string): Record<string, unknown> {
  const cleaned = content
    .trim()
    .replace(/^```(?:json)?/i, '')
    .replace(/```\s*$/, '')
    .trim()
    .replace(/,\s*([}\]])/g, '$1');

  try {
    return JSON.parse(cleaned) as Record<string, unknown>;
  } catch {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return JSON.parse(cleaned.slice(start, end + 1)) as Record<string, unknown>;
    }
    throw new Error('NVIDIA returned malformed crop recommendation JSON.');
  }
}

export async function recommendWithAI(
  farmContext: Record<string, unknown>,
  input: CropRecommendationAiInput,
): Promise<AiRecommendationResult> {
  const language = input.language || 'en';
  const contextText = buildContextText(farmContext);
  const model =
    process.env.AI_CROP_MODEL ??
    process.env.AI_MODEL_GENERAL ??
    'nvidia/nemotron-3.5-lightning-30b-a3b';

  const system = [
    'You are VidhAI Crop Recommendation AI, an expert agronomist for Indian farms.',
    'Rank crops only after analysing the complete farmer input and farm context together.',
    'The farmer-selected category, duration, budget, current water availability and farming priority materially affect the ranking; do not ignore them.',
    'Use soil, location, season, irrigation, water source, previous crop/rotation, weather, farm size and reported market context whenever present.',
    'Never return a fixed/default crop list. Different meaningful inputs should be able to produce different rankings.',
    'Never invent live weather or market prices. If those data are missing, say so briefly.',
    'Return exactly 10 unique crops when there are 10 defensible options. Keep every text field concise.',
    `Respond in language code ${language}.`,
    'Return JSON only. No markdown and no explanation outside JSON.',
  ].join('\n');

  const inputLines: string[] = [];
  addInputLine(inputLines, 'Crop category preference', input.cropCategoryPreference || 'No preference');
  addInputLine(inputLines, 'Preferred crop duration', input.cropDurationPreference || 'No preference');
  addInputLine(inputLines, 'Budget per acre (INR)', input.budgetInrPerAcre);
  addInputLine(inputLines, 'Current water availability', input.waterAvailability);
  addInputLine(inputLines, 'Farming priority', input.farmingPriority || 'Balanced');
  addInputLine(inputLines, 'Farmer free-text preference', input.farmerPreference);
  addInputLine(inputLines, 'Previous crop', input.lastCrop);
  addInputLine(inputLines, 'Previous crop harvest date', input.harvestDate);
  addInputLine(inputLines, 'Land idle/fallow duration', input.landIdleDuration);
  addInputLine(inputLines, 'Last irrigation', input.lastIrrigation);
  addInputLine(inputLines, 'Farmer-confirmed soil type', input.soilType);
  addInputLine(inputLines, 'Soil condition', input.soilCondition);
  addInputLine(inputLines, 'Soil fertility', input.soilFertility);
  addInputLine(inputLines, 'Drainage condition', input.drainageCondition);
  addInputLine(inputLines, 'Irrigation system', input.irrigationSystem);
  addInputLine(inputLines, 'Water source', input.waterSource);
  addInputLine(inputLines, 'Farm location', input.farmLocation);
  addInputLine(inputLines, 'Farm size', input.farmSize);
  addInputLine(inputLines, 'Current season', input.currentSeason);
  addInputLine(inputLines, 'Previous crop sowing date', input.previousCropSowingDate);
  addInputLine(inputLines, 'Previous crop duration', input.previousCropDuration);
  addInputLine(inputLines, 'Seasonal water reliability', input.seasonalWaterReliability);

  const user = [
    'Farmer inputs:',
    ...inputLines,
    '',
    'Auto-collected farm context:',
    contextText,
    '',
    'Return this compact JSON shape:',
    '{',
    '  "analysisSummary": "one short sentence",',
    '  "recommendations": [',
    '    {',
    '      "cropName": "",',
    '      "localName": "",',
    '      "suitabilityScore": 0,',
    '      "whySuitable": ["short reason 1", "short reason 2"],',
    '      "soilMatch": "",',
    '      "waterMatch": "",',
    '      "seasonMatch": "",',
    '      "rotationMatch": "",',
    '      "marketOutlook": "",',
    '      "estimatedDurationDays": 0,',
    '      "sowingWindow": "",',
    '      "estimatedHarvestWindow": "",',
    '      "waterRequirement": "Low|Medium|High",',
    '      "riskLevel": "Low|Medium|High",',
    '      "majorRisks": ["short risk"],',
    '      "confidence": 0',
    '    }',
    '  ]',
    '}',
    'Suitability and confidence are integer percentages from 1 to 100.',
  ].join('\n');

  const provider = nvidiaProvider(model);
  const messages: NvidiaChatMessage[] = [
    { role: 'system', content: system },
    { role: 'user', content: user },
  ];

  const data = await llmPost<{
    choices: Array<{ message?: NvidiaChatMessage }>;
    usage?: Record<string, number>;
  }>(
    '/chat/completions',
    {
      model,
      messages,
      temperature: 0.2,
      max_tokens: 4096,
      chat_template_kwargs: { enable_thinking: false },
      response_format: { type: 'json_object' },
    },
    provider,
    { timeout: 40_000 },
  );

  const content = data.choices?.[0]?.message?.content ?? '';
  if (!content.trim()) {
    throw new Error('NVIDIA returned an empty crop recommendation response.');
  }

  const parsed = parseJsonResponse(content);
  const recommendations = sanitizeAiRecommendations(parsed);
  if (recommendations.length === 0) {
    throw new Error('NVIDIA returned no usable crop recommendations.');
  }

  const analysisSummary =
    asString(parsed['analysisSummary']) ||
    'Live AI ranked crops from the current farm data and farmer preferences.';

  return {
    analysisSummary,
    model,
    recommendations,
  };
}

declare global {
  interface Array<T> {
    readonly firstOrNull: T | undefined;
  }
}

if (!Object.getOwnPropertyDescriptor(Array.prototype, 'firstOrNull')) {
  Object.defineProperty(Array.prototype, 'firstOrNull', {
    get() {
      return this.length === 0 ? undefined : this[0];
    },
    configurable: true,
  });
}
