/**
 * VidhAI crop knowledge service.
 *
 * Deterministic, auditable suitability engine over the shipped crop pool plus a
 * Firestore mirror (`cropKnowledge/{id}`) seeded at deploy time. The engine is
 * pure and offline-testable; the app combines these structured results with the
 * existing online AI chat relay (see AiChatBrain) only for narrative text.
 */

import * as admin from 'firebase-admin';
import { ensureFirebaseAdmin } from './config/firebase';
import { SHIPPED_CROP_KNOWLEDGE, CROP_DATA_VERSION, CropKnowledgeEntry } from './cropData';
import { INDIAN_STATES } from './marketData';

export interface FarmContext {
  state?: string;
  district?: string;
  soilType?: string;
  irrigationType?: string;
  waterAvailability?: string; // 'abundant' | 'moderate' | 'limited' | 'rainfed'
  farmingMethod?: string; // e.g. 'organic', 'conventional'
  farmSizeAcres?: number;
  season?: string; // 'kharif' | 'rabi' | 'zaid' | ''
  month?: number; // 1-12 current month for planting-window matching
  budgetInrPerAcre?: number;
  durationPreference?: string; // 'short' | 'medium' | 'long' | ''
  categoryPreferences?: string[];
  fallowMonths?: number; // months the land has been idle
  lastCrop?: string;
  /** Recent actual mandi prices for the farm region (optional; never dominant). */
  market?: MarketContextEntry[];
}

export interface MarketContextEntry {
  commodity: string;
  normalizedPricePerKg: number;
  state?: string;
  date?: string;
  source?: string;
}

export interface RecommendationInput {
  waterAvailability: string;
  soilType: string;
  irrigationSystem: string;
  farmLocation: string;
  currentSeason: string;
  cropDurationPreference: string;
  cropCategoryPreference: string;
  budgetInrPerAcre?: number;
  lastCrop?: string;
  landIdleDuration?: string;
}

export interface SuitabilityFactor {
  name: string;
  weight: number;
  score: number; // 0..1
  detail: string;
}

export interface CropSuitability {
  entry: CropKnowledgeEntry;
  score: number; // 0..100
  confidence: 'High' | 'Medium' | 'Low';
  factors: SuitabilityFactor[];
  strengths: string[];
  concerns: string[];
  waterNotes: string;
  budget: {
    perAcreUsable: number | null; // budget after seed cost (or null when not provided)
    classification: 'Within' | 'Slightly Above' | 'Far Above' | 'Not Specified';
    cultivationCostMin: number;
    cultivationCostMax: number;
    seedCostMin: number;
    seedCostMax: number;
  };
  money: {
    estimatedYield: { min: number; max: number; unit: string };
    estimatedRevenuePerAcre: { min: number; max: number };
    potentialProfitPerAcre: { min: number; max: number };
  };
  plantingWindow: string;
  harvestHint: string;
  estimatedLabel: boolean; // all money/yield figures are estimates
}

export interface RankedRecommendation extends CropSuitability {
  rank: number;
}

export interface RecommendResponse {
  success: boolean;
  top10: RankedRecommendation[];
  limited: boolean; // true when pool had < 10 matches
  poolSize: number;
  generatedAt: string;
  input: RecommendationInput;
  error?: string;
}

export type FactorVerdict = 'Excellent' | 'Potential Concern' | 'Severe Risk';

export interface CheckFactor {
  factor: string;
  verdict: FactorVerdict;
  detail: string;
}

export interface CheckEstimate {
  label: string;
  value: string;
  accuracy: 'Verified' | 'Estimated';
}

export interface ManualCheckResult {
  success: boolean;
  found: boolean;
  matchedCrop?: CropKnowledgeEntry | null;
  matchedVariety?: string;
  score: number;
  verdict: string; // Highly Suitable | Suitable | Moderately Suitable | Marginal | Not Recommended
  verdictLevel: number; // 0..4 (higher is better suitability)
  factors: CheckFactor[];
  estimates: CheckEstimate[];
  strengths: string[];
  concerns: string[];
  seasonNotes: string;
  regionNotes: string;
  reason: string;
  fallbackCandidates: CropKnowledgeEntry[];
  error?: string;
}

// ── Season helpers ───────────────────────────────────────────────────────────

function seasonOf(month: number | undefined): string {
  if (month === undefined) return '';
  if (month >= 6 && month <= 10) return 'kharif';
  if (month >= 11 || month <= 2) return 'rabi';
  return 'zaid';
}

function normalize(value: string | undefined | null): string {
  return (value ?? '').trim().toLowerCase();
}

function canonicalCategoryPreference(value: string | undefined | null): string | null {
  const key = normalize(value).replace(/[_-]+/g, ' ');
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
    commercial: 'Commercial/Cash Crops',
    'commercial crop': 'Commercial/Cash Crops',
    'commercial crops': 'Commercial/Cash Crops',
    'cash crop': 'Commercial/Cash Crops',
    'cash crops': 'Commercial/Cash Crops',
    'commercial/cash crops': 'Commercial/Cash Crops',
  };
  return aliases[key] ?? value!.trim();
}

function categoryMatches(entry: CropKnowledgeEntry, requested: string | null): boolean {
  if (!requested) return true;
  return normalize(entry.category) === normalize(requested);
}

// ── Pool ─────────────────────────────────────────────────────────────────────

export function stateKnown(crop: CropKnowledgeEntry, state: string | undefined): boolean {
  const s = normalize(state);
  if (!s) return true; // unknown state does not disqualify
  return crop.states.some((st) => {
    const l = normalize(st);
    return l === s || s.includes(l) || l.includes(s);
  });
}

export function selectCandidatePool(
  entries: CropKnowledgeEntry[],
  ctx: FarmContext,
): CropKnowledgeEntry[] {
  const season = normalize(ctx.season) || seasonOf(ctx.month);
  return entries.filter((c) => {
    if (!stateKnown(c, ctx.state)) return false;
    if (season) {
      const cat = normalize(c.season);
      if (cat && !cat.split('/').includes(season)) return false;
    }
    return true;
  });
}

// ── Factor scoring ───────────────────────────────────────────────────────────

function soilFit(entry: CropKnowledgeEntry, ctx: FarmContext): number {
  const soil = normalize(ctx.soilType);
  if (!soil) return 0.7; // unknown soil -> neutral
  const names = ['clay', 'sand', 'loam', 'red', 'black', 'alluvial', 'laterite'];
  const tokenize = (s: string): string[] => names.filter((n) => s.includes(n));
  const cropTokens = entry.soilTypes.flatMap((t) => tokenize(normalize(t)));
  const farmTokens = tokenize(soil);
  if (farmTokens.length === 0) return 0.6;
  const overlap = farmTokens.filter((t) => cropTokens.includes(t)).length;
  if (overlap === 0) return 0.25;
  const ratio = overlap / farmTokens.length;
  return Math.min(1, 0.45 + ratio * 0.55);
}

function waterFit(entry: CropKnowledgeEntry, ctx: FarmContext): { score: number; notes: string } {
  const avail = normalize(ctx.waterAvailability);
  const need = entry.waterRequirement.toLowerCase();
  // Farm water availability -> numeric 0..1 scale
  const availScore: Record<string, number> = {
    abundant: 1,
    high: 1,
    moderate: 0.65,
    medium: 0.65,
    limited: 0.35,
    low: 0.35,
    'very low': 0.2,
    'no water': 0.05,
    rainfed: 0.5,
    '': 0.6,
  };
  const a = availScore[avail] ?? 0.6;
  const needScore: Record<string, number> = { low: 1, medium: 0.65, high: 0.3 };
  const n = needScore[need] ?? 0.6;
  let score = Math.min(1, a + n > 1 ? 1 : Math.max(0, a + n - 0.35));
  let notes = '';
  if ((avail === 'limited' || avail === 'low' || avail === 'very low' || avail === 'no water') && need === 'high') {
    score = 0.2;
    notes = 'Assured high water supply is a precondition; limited water is a serious constraint.';
  } else if (need === 'high') {
    notes = 'Needs frequent irrigation; best with drip or assured canal/bore-well water.';
  } else if (need === 'low') {
    notes = 'Thrives under rainfed or limited water, reducing irrigation cost.';
  } else {
    notes = 'Moderate water need; maintain scheduled irrigation during dry spells.';
  }
  return { score, notes };
}

function irrigationFit(entry: CropKnowledgeEntry, ctx: FarmContext): number {
  const irr = normalize(ctx.irrigationType);
  if (!irr) return 0.7;
  const need = entry.waterRequirement.toLowerCase();
  if (irr.includes('drip') || irr.includes('sprinkler')) return 1;
  if (need === 'low') return 0.9;
  if (irr.includes('canal') || irr.includes('bore') || irr.includes('well') || irr.includes('ditch')) {
    return 0.8;
  }
  return 0.5;
}

function temperatureFit(entry: CropKnowledgeEntry, _ctx: FarmContext): number {
  // Template-level check: crop range is reasonable for Indian conditions.
  if (entry.temperatureMax - entry.temperatureMin < 10) return 0.5;
  if (entry.temperatureMax >= 42) return 0.6;
  return 0.9;
}

function matchingSeasons(entry: CropKnowledgeEntry): string[] {
  return normalize(entry.season)
    .split('/')
    .filter(Boolean);
}

function seasonalFit(entry: CropKnowledgeEntry, ctx: FarmContext): number {
  const season = normalize(ctx.season) || seasonOf(ctx.month);
  const cats = matchingSeasons(entry);
  if (!season) return 0.7;
  if (cats.length === 0) return 0.5;
  if (cats.includes(season)) return 1;
  if (cats.includes('zaid')) return 0.6;
  return 0.3;
}

function monthWindowFit(entry: CropKnowledgeEntry, ctx: FarmContext): number {
  if (!ctx.month) return 0.7;
  const season = seasonOf(ctx.month);
  return seasonalFit({ ...entry, season } as CropKnowledgeEntry, { season }) > 0.5 ? 0.95 : 0.6;
}

function durationPrefFit(entry: CropKnowledgeEntry, pref: string | undefined): number {
  if (!pref) return 0.75;
  const mid = (entry.durationDaysMin + entry.durationDaysMax) / 2;
  switch (pref.toLowerCase()) {
    case 'short':
    case 'short-term':
    case 'short term':
      return mid <= 100 ? 1 : mid <= 150 ? 0.7 : 0.35;
    case 'medium':
    case 'medium-term':
    case 'medium term':
      return mid > 100 && mid <= 200 ? 1 : 0.7;
    case 'long':
    case 'long-term':
    case 'long term':
      return mid > 200 ? 1 : 0.6;
    case 'no preference':
    case 'any':
      return 0.75;
    default:
      return 0.75;
  }
}

function categoryPrefFit(entry: CropKnowledgeEntry, prefs: string[] | undefined): number {
  if (!prefs || prefs.length === 0) return 0.75;
  const normalizedPrefs = prefs.map(normalize).filter(Boolean);
  if (normalizedPrefs.length === 0) return 0.75;
  return normalizedPrefs.includes(normalize(entry.category)) ? 1 : 0.75;
}

function fallowFit(entry: CropKnowledgeEntry, months: number | undefined): number {
  if (months === undefined || months <= 0) return 0.7;
  if (months >= 20) return entry.fallowSuitable ? 0.9 : 0.5;
  return 0.8;
}

function regionFit(entry: CropKnowledgeEntry, _ctx: FarmContext): number {
  return 0.85; // region already used as a hard pool filter
}

/**
 * Optional market-price factor. Uses only actual reported prices when the
 * client supplies them (farm.market); weights stay limited so the factor
 * can never dominate the deterministic suitability ranking.
 */
function marketFit(
  entry: CropKnowledgeEntry,
  market: MarketContextEntry[] | undefined,
): { score: number; detail: string } {
  if (!market || market.length === 0) return { score: 0.5, detail: 'No recent market-price data available for scoring.' };
  const q = normalize(entry.name);
  const match = market.find((m) => {
    const c = normalize(m.commodity);
    return c === q || c.includes(q) || q.includes(c);
  });
  if (!match || match.normalizedPricePerKg <= 0) {
    return { score: 0.5, detail: `No recent reported price for '${entry.name}' in the selected region.` };
  }
  const perKgMin = entry.pricePerQuintal.min / 100;
  const perKgMax = entry.pricePerQuintal.max / 100;
  const actual = match.normalizedPricePerKg;
  const sourceNote = match.date ? ` (${match.date})` : '';
  if (actual >= perKgMax) {
    return {
      score: 1,
      detail: `Actual modal price \u20B9${actual}/kg${sourceNote} is above the reference range \u20B9${perKgMin}–\u20B9${perKgMax}/kg (favourable currently).`,
    };
  }
  if (actual >= perKgMin) {
    return {
      score: 0.75,
      detail: `Actual modal price \u20B9${actual}/kg${sourceNote} is within the reference range \u20B9${perKgMin}–\u20B9${perKgMax}/kg.`,
    };
  }
  return {
    score: 0.4,
    detail: `Actual modal price \u20B9${actual}/kg${sourceNote} is below the reference range \u20B9${perKgMin}–\u20B9${perKgMax}/kg (check local demand).`,
  };
}

// ── Suitability ──────────────────────────────────────────────────────────────

interface FactorBundle {
  name: string;
  weight: number;
  score: number;
  detail: string;
}

/**
 * Budget directly influences ranking (Part 5): within-budget crops rank above
 * costlier ones, regardless of revenue potential. Score comes only from the
 * deterministic cultivation-cost ranges, never from projected revenue.
 */
function budgetFit(entry: CropKnowledgeEntry, budget: number | undefined): { score: number; detail: string } {
  if (budget === undefined || budget === null || budget <= 0) {
    return { score: 0.7, detail: 'No budget provided; cost-fit not scored (neutral).' };
  }
  const b = budgetFor(entry, budget);
  if (b.classification === 'Within') {
    return { score: 1, detail: `Fits your budget — estimated cultivation cost \u20B9${b.cultivationCostMin}–\u20B9${b.cultivationCostMax}/acre (seed \u20B9${b.seedCostMin}–\u20B9${b.seedCostMax}).` };
  }
  if (b.classification === 'Slightly Above') {
    return { score: 0.65, detail: `Slightly above budget — estimated cultivation cost \u20B9${b.cultivationCostMin}–\u20B9${b.cultivationCostMax}/acre.` };
  }
  return { score: 0.3, detail: `Above your budget — estimated cultivation cost up to \u20B9${b.cultivationCostMax}/acre; plan financing before sowing.` };
}

/** Rotational compatibility: repeating the same family/crop is penalised. */
function cropCategoryOf(cropName: string | undefined): string {
  const q = normalize(cropName);
  if (!q) return '';
  return (
    SHIPPED_CROP_KNOWLEDGE.find((c) => normalize(c.name) === q)?.category ??
    SHIPPED_CROP_KNOWLEDGE.find((c) => c.varieties.some((v) => normalize(v) === q))?.category ??
    ''
  );
}

function previousCropFit(entry: CropKnowledgeEntry, lastCrop: string | undefined): { score: number; detail: string } {
  const q = normalize(lastCrop);
  if (!q) return { score: 0.75, detail: 'No previous-crop history entered; rotation treated as neutral.' };
  if (normalize(entry.name) === q) {
    return { score: 0.3, detail: `Same crop as the previous season (${lastCrop}) — repeating it risks pest build-up; review rotation.` };
  }
  const prevCat = cropCategoryOf(q);
  if (prevCat && prevCat === normalize(entry.category)) {
    return { score: 0.6, detail: `Previous crop (${lastCrop}) is in the same category (${prevCat}) — consider a different family for rotation.` };
  }
  return { score: 0.85, detail: `Previous crop (${lastCrop}) differs in family — good rotational fit.` };
}

/** Expected profitability from estimated revenue minus estimated cost (estimates only, never a guarantee). */
function profitabilityFit(entry: CropKnowledgeEntry): { score: number; detail: string } {
  const money = moneyFor(entry);
  const costAvg = (entry.cultivationCostPerAcre.min + entry.cultivationCostPerAcre.max) / 2;
  if (costAvg <= 0) return { score: 0.7, detail: 'Expected profitability not published for this crop.' };
  const revAvg = (money.estimatedRevenuePerAcre.min + money.estimatedRevenuePerAcre.max) / 2;
  const margin = (revAvg - costAvg) / costAvg;
  if (margin >= 0.5) {
    return { score: 0.9, detail: `Expected profit margin (est.) roughly ${Math.round(margin * 100)}% over cultivation cost.` };
  }
  if (margin >= 0.2) {
    return { score: 0.7, detail: `Expected profit margin (est.) roughly ${Math.round(margin * 100)}% over cultivation cost.` };
  }
  return { score: 0.45, detail: `Expected margin (est.) ${Math.round(margin * 100)}% — modest; verify local price trends.` };
}

/** District-level fit: validates the selected district against the authoritative master. */
function districtFit(entry: CropKnowledgeEntry, ctx: FarmContext): { score: number; detail: string } {
  const district = normalize(ctx.district);
  if (!district) return { score: 0.8, detail: 'No district selected; scored at state/region level.' };
  const state = normalize(ctx.state);
  const stateInfo = state ? INDIAN_STATES.find((s) => normalize(s.name) === state) : undefined;
  if (!stateInfo && !state) {
    return { score: 0.5, detail: 'District selected without a state — confirm your location for an accurate score.' };
  }
  const validDistrict = stateInfo?.districts.some((d) => normalize(d) === district);
  if (stateInfo && !validDistrict) {
    return { score: 0.45, detail: `"${ctx.district}" is not listed in ${stateInfo.name}; choose the district from the list in the app.` };
  }
  const known = stateInfo ? stateKnown(entry, stateInfo.name) : true;
  return known
    ? { score: 0.95, detail: `Grown in your district's state (${ctx.state}); district recognised against the official master.` }
    : { score: 0.6, detail: 'Not commonly reported in your state — verify local suitability with an advisory.' };
}

export function scoreCrop(entry: CropKnowledgeEntry, ctx: FarmContext): CropSuitability {
  const water = waterFit(entry, ctx);
  const districtF = districtFit(entry, ctx);
  const prevF = previousCropFit(entry, ctx.lastCrop);
  const profitF = profitabilityFit(entry);
  const budgetF = budgetFit(entry, ctx.budgetInrPerAcre);
  const factors: FactorBundle[] = [
    {
      name: 'State fit',
      weight: 10,
      score: regionFit(entry, ctx),
      detail: stateKnown(entry, ctx.state)
        ? 'Traditionally grown / reported in your state.'
        : 'Not commonly reported in your state.',
    },
    {
      name: 'Soil suitability',
      weight: 20,
      score: soilFit(entry, ctx),
      detail: soilFitDetail(entry, ctx),
    },
    {
      name: 'Water requirement',
      weight: 15,
      score: water.score,
      detail: water.notes,
    },
    {
      name: 'Irrigation compatibility',
      weight: 5,
      score: irrigationFit(entry, ctx),
      detail: `Crop water need is ${entry.waterRequirement.toLowerCase()}.`,
    },
    {
      name: 'Season fit',
      weight: 15,
      score: seasonalFit(entry, ctx),
      detail: `Crop is grown in ${entry.season}.`,
    },
    {
      name: 'Planting window',
      weight: 10,
      score: monthWindowFit(entry, ctx),
      detail: entry.plantingWindows.join('; '),
    },
    {
      name: 'Temperature',
      weight: 10,
      score: temperatureFit(entry, ctx),
      detail: `Suitable range ${entry.temperatureMin}\u00B0C–${entry.temperatureMax}\u00B0C.`,
    },
    {
      name: 'Duration preference',
      weight: 5,
      score: durationPrefFit(entry, ctx.durationPreference),
      detail: `${entry.durationDaysMin}–${entry.durationDaysMax} days`,
    },
    {
      name: 'Category preference',
      weight: 5,
      score: categoryPrefFit(entry, ctx.categoryPreferences),
      detail: categoryPrefFit(entry, ctx.categoryPreferences) >= 1 ? 'Matches your preference.' : 'Alternative category.',
    },
    {
      name: 'Land idle time',
      weight: 5,
      score: fallowFit(entry, ctx.fallowMonths),
      detail: fallowFit(entry, ctx.fallowMonths) >= 0.85
        ? 'Fits your idle land window.'
        : 'Review land availability against crop duration.',
    },
    { name: 'District & regional fit', weight: 5, score: districtF.score, detail: districtF.detail },
    { name: 'Previous crop compatibility', weight: 6, score: prevF.score, detail: prevF.detail },
    { name: 'Expected profitability', weight: 6, score: profitF.score, detail: profitF.detail },
    { name: 'Budget fit', weight: 12, score: budgetF.score, detail: budgetF.detail },
  ];

  if (ctx.market && ctx.market.length > 0) {
    const market = marketFit(entry, ctx.market);
    factors.push({ name: 'Market price (actual)', weight: 8, score: market.score, detail: market.detail });
  }

  const totalWeight = factors.reduce((s, f) => s + f.weight, 0);
  const raw = factors.reduce((s, f) => s + f.weight * f.score, 0) / totalWeight;
  const score = Math.round(raw * 100);
  const confidence: 'High' | 'Medium' | 'Low' =
    score >= 80 ? 'High' : score >= 60 ? 'Medium' : 'Low';

  const strengths = factors
    .filter((f) => f.score >= 0.75)
    .map((f) => f.detail)
    .slice(0, 3);
  const concerns = factors
    .filter((f) => f.score < 0.5)
    .map((f) => `${f.name}: ${f.detail}`)
    .slice(0, 3);

  return {
    entry,
    score,
    confidence,
    factors: factors.map((f) => ({ name: f.name, weight: f.weight, score: f.score, detail: f.detail })),
    strengths,
    concerns,
    waterNotes: water.notes,
    budget: budgetFor(entry, ctx.budgetInrPerAcre),
    money: moneyFor(entry),
    plantingWindow: entry.plantingWindows.join('; '),
    harvestHint: entry.harvestMonths,
    estimatedLabel: true,
  };
}

function soilFitDetail(entry: CropKnowledgeEntry, ctx: FarmContext): string {
  const soil = normalize(ctx.soilType);
  if (!soil) return `Grows in ${entry.soilTypes.join(', ')}.`;
  if (soilFit(entry, ctx) >= 0.8) return `Matches your ${ctx.soilType} soil.`;
  if (soilFit(entry, ctx) <= 0.45) return `Needs soil amendment; prefers ${entry.soilTypes.join(', ')}.`;
  return `Tolerable fit with your ${ctx.soilType} soil.`;
}

function budgetFor(entry: CropKnowledgeEntry, budget: number | undefined): CropSuitability['budget'] {
  const seedMin = entry.seedCostPerAcre.min;
  const seedMax = entry.seedCostPerAcre.max;
  const costMin = entry.cultivationCostPerAcre.min;
  const costMax = entry.cultivationCostPerAcre.max;
  if (budget === undefined || budget === null || budget <= 0) {
    return {
      perAcreUsable: null,
      classification: 'Not Specified',
      cultivationCostMin: costMin,
      cultivationCostMax: costMax,
      seedCostMin: seedMin,
      seedCostMax: seedMax,
    };
  }
  if (budget >= costMax) {
    return {
      perAcreUsable: budget - seedMax,
      classification: 'Within',
      cultivationCostMin: costMin,
      cultivationCostMax: costMax,
      seedCostMin: seedMin,
      seedCostMax: seedMax,
    };
  }
  if (budget >= costMin) {
    return {
      perAcreUsable: budget - seedMax,
      classification: 'Slightly Above',
      cultivationCostMin: costMin,
      cultivationCostMax: costMax,
      seedCostMin: seedMin,
      seedCostMax: seedMax,
    };
  }
  return {
    perAcreUsable: budget - seedMax,
    classification: 'Far Above',
    cultivationCostMin: costMin,
    cultivationCostMax: costMax,
    seedCostMin: seedMin,
    seedCostMax: seedMax,
  };
}

function moneyFor(entry: CropKnowledgeEntry): CropSuitability['money'] {
  const yMin = entry.expectedYieldPerAcre.min;
  const yMax = entry.expectedYieldPerAcre.max;
  const pMin = entry.pricePerQuintal.min;
  const pMax = entry.pricePerQuintal.max;
  const revenueMin = Math.round(yMin * (pMin / 100));
  const revenueMax = Math.round(yMax * (pMax / 100));
  const costMin = entry.cultivationCostPerAcre.min;
  const costMax = entry.cultivationCostPerAcre.max;
  return {
    estimatedYield: { min: yMin, max: yMax, unit: entry.expectedYieldPerAcre.unit },
    estimatedRevenuePerAcre: { min: revenueMin, max: revenueMax },
    potentialProfitPerAcre: {
      min: Math.max(0, revenueMin - costMax),
      max: Math.max(0, revenueMax - costMin),
    },
  };
}

// ── Top-10 ranking ───────────────────────────────────────────────────────────

export function recommend(ctx: FarmContext, input: RecommendationInput): RecommendResponse {
  const requestedCategory =
    canonicalCategoryPreference(input.cropCategoryPreference) ??
    canonicalCategoryPreference(ctx.categoryPreferences?.[0]);
  let pool = selectCandidatePool(SHIPPED_CROP_KNOWLEDGE, ctx);

  // Crop type is a hard constraint. Never pad the list with another category.
  if (requestedCategory) {
    pool = pool.filter((entry) => categoryMatches(entry, requestedCategory));
  }

  const scored = pool.map((crop) => scoreCrop(crop, ctx));
  scored.sort(
    (a, b) =>
      b.score - a.score ||
      a.entry.durationDaysMin - b.entry.durationDaysMin,
  );
  const limited = scored.length < 10;
  const top10 = scored.slice(0, 10).map((s, i) => ({
    ...s,
    rank: i + 1,
  }));
  return {
    success: true,
    top10,
    limited,
    poolSize: pool.length,
    generatedAt: new Date().toISOString(),
    input,
  };
}

// ── Manual crop check (24-factor) ────────────────────────────────────────────

export interface CheckQuery {
  cropName: string;
  variety?: string;
  season?: string;
}

function findBestMatch(query: string): { entry: CropKnowledgeEntry | null; verbatim: boolean } {
  const q = normalize(query);
  if (!q) return { entry: null, verbatim: false };
  // exact name or alias match first
  const exact = SHIPPED_CROP_KNOWLEDGE.find((c) => normalize(c.name) === q);
  if (exact) return { entry: exact, verbatim: true };
  const contains = SHIPPED_CROP_KNOWLEDGE
    .filter((c) => normalize(c.name).includes(q) || q.includes(normalize(c.name)))
    .sort((a, b) => normalize(a.name).length - normalize(b.name).length);
  return { entry: contains[0] ?? null, verbatim: false };
}

const VERDICT_THRESHOLDS: { min: number; label: string; level: number }[] = [
  { min: 80, label: 'Highly Suitable', level: 4 },
  { min: 65, label: 'Suitable', level: 3 },
  { min: 50, label: 'Suitable with Conditions', level: 2 },
  { min: 35, label: 'Low Suitability', level: 1 },
  { min: 0, label: 'Not Recommended', level: 0 },
];

function verdictFor(score: number): { label: string; level: number } {
  return VERDICT_THRESHOLDS.find((t) => score >= t.min) ?? VERDICT_THRESHOLDS[VERDICT_THRESHOLDS.length - 1];
}

function checkSoil(entry: CropKnowledgeEntry, soil: string | undefined): CheckFactor {
  const s = normalize(soil);
  if (!s) return { factor: 'Soil type', verdict: 'Excellent', detail: 'No soil data provided; verify against local reports.' };
  const score = soilFit(entry, { soilType: soil });
  const base = `Crop prefers ${entry.soilTypes.join(', ')}.`;
  if (score >= 0.85) return { factor: 'Soil type', verdict: 'Excellent', detail: `Your ${soil} soil matches well. ${base}` };
  if (score >= 0.55) return { factor: 'Soil type', verdict: 'Potential Concern', detail: `Your ${soil} soil is a tolerable but imperfect fit. ${base}` };
  return { factor: 'Soil type', verdict: 'Severe Risk', detail: `Your ${soil} soil may need major amendment. ${base}` };
}

function checkAgainst(value: string | undefined, cropSoil: string[], cropWater: string): CheckFactor {
  return { factor: 'Drainage / tilth', verdict: 'Excellent', detail: 'Assume standard field drainage; confirm after a field-level check.' };
}

export function checkCrop(ctx: FarmContext, query: CheckQuery): ManualCheckResult {
  const { entry, verbatim } = findBestMatch(query.cropName);
  if (!entry) {
    const candidates = SHIPPED_CROP_KNOWLEDGE.filter((c) =>
      c.category.toLowerCase().includes(query.cropName.toLowerCase()) ||
      query.cropName.toLowerCase().includes(c.category.toLowerCase()),
    ).slice(0, 3);
    return {
      success: false,
      found: false,
      factors: [],
      estimates: [],
      strengths: [],
      concerns: [],
      seasonNotes: '',
      regionNotes: '',
      score: 0,
      verdict: 'Not Recommended',
      verdictLevel: 0,
      fallbackCandidates: candidates,
      reason: 'Crop not found in the verified database.',
    };
  }

  const season = normalize(ctx.season) || seasonOf(ctx.month);
  const seasonCats = matchingSeasons(entry);
  const seasonOk =
    !season || seasonCats.length === 0 || seasonCats.includes(season) || seasonCats.includes('zaid');
  const water = waterFit(entry, ctx);
  const soil = checkSoil(entry, ctx.soilType);

  const factors: CheckFactor[] = [
    soil,
    checkAgainst(ctx.soilType, entry.soilTypes, entry.waterRequirement),
    {
      factor: 'Water availability',
      verdict: water.score >= 0.7 ? 'Excellent' : water.score >= 0.4 ? 'Potential Concern' : 'Severe Risk',
      detail: water.notes,
    },
    {
      factor: 'Irrigation source & method',
      verdict: irrigationFit(entry, ctx) >= 0.8 ? 'Excellent' : irrigationFit(entry, ctx) >= 0.5 ? 'Potential Concern' : 'Severe Risk',
      detail: `Crop water requirement: ${entry.waterRequirement.toLowerCase()}.`,
    },
    {
      factor: 'Current season fit',
      verdict: seasonOk ? 'Excellent' : 'Severe Risk',
      detail: seasonCats.length
        ? `Crop season(s): ${entry.season}.`
        : 'Seasonal guidance not published for this crop.',
    },
    {
      factor: 'Planting window',
      verdict: 'Potential Concern',
      detail: entry.plantingWindows.join('; '),
    },
    {
      factor: 'Sowing duration',
      verdict: 'Excellent',
      detail: `${entry.durationDaysMin}–${entry.durationDaysMax} days`,
    },
    {
      factor: 'Variety selection',
      verdict: query.variety ? 'Excellent' : 'Potential Concern',
      detail: `Recommended varieties: ${entry.varieties.slice(0, 5).join(', ')}.`,
    },
    {
      factor: 'Seed availability',
      verdict: 'Excellent',
      detail: 'Seed of these varieties is generally available through local dealers.',
    },
    {
      factor: 'Temperature fit',
      verdict: temperatureFit(entry, ctx) >= 0.8 ? 'Excellent' : 'Potential Concern',
      detail: `${entry.temperatureMin}\u00B0C–${entry.temperatureMax}\u00B0C`,
    },
    { factor: 'Rainfall dependence', verdict: 'Excellent', detail: 'Plan irrigation for dry spells as per local advisory.' },
    { factor: 'Market demand', verdict: entry.marketDemand === 'High' ? 'Excellent' : entry.marketDemand === 'Medium' ? 'Excellent' : 'Potential Concern', detail: `Market demand: ${entry.marketDemand}.` },
    { factor: 'Price outlook', verdict: 'Potential Concern', detail: `Reference price range (est.): \u20B9${entry.pricePerQuintal.min}–\u20B9${entry.pricePerQuintal.max}/quintal.` },
    { factor: 'Yield potential', verdict: 'Excellent', detail: `${entry.expectedYieldPerAcre.min}–${entry.expectedYieldPerAcre.max} ${entry.expectedYieldPerAcre.unit} (estimate).` },
    { factor: 'Inputs & cultivation cost', verdict: 'Excellent', detail: `Cultivation cost (est.): \u20B9${entry.cultivationCostPerAcre.min}–\u20B9${entry.cultivationCostPerAcre.max}/acre.` },
    {
      factor: 'Rodent / bird damage',
      verdict: entry.riskLevel === 'High' ? 'Potential Concern' : 'Excellent',
      detail: 'Use timely bird/rodent controls near maturity.',
    },
    {
      factor: 'Pest pressure',
      verdict: entry.commonPests.length <= 3 ? 'Excellent' : 'Potential Concern',
      detail: `Common pests: ${entry.commonPests.join(', ')}.`,
    },
    {
      factor: 'Disease pressure',
      verdict: entry.riskLevel === 'High' ? 'Potential Concern' : 'Excellent',
      detail: `Common diseases: ${entry.commonDiseases.join(', ')}.`,
    },
    { factor: 'Crop rotation & previous crop', verdict: 'Excellent', detail: entry.cropRotationNotes ?? 'Generally rotation-tolerant.' },
    {
      factor: 'Land idle / fallow period',
      verdict: entry.fallowSuitable ? 'Excellent' : 'Potential Concern',
      detail: `Suitable after fallow: ${entry.fallowSuitable ? 'yes' : 'review'}.`,
    },
    {
      factor: 'Organic / method fit',
      verdict: entry.organicFriendly ? 'Excellent' : 'Potential Concern',
      detail: 'Compatible with low-input / organic management.' ,
    },
    { factor: 'Knowledge & labour', verdict: 'Excellent', detail: 'Standard package-of-practice support available.' },
    { factor: 'Storage & handling', verdict: 'Excellent', detail: 'Follow recommended drying/storage practice after harvest.' },
  ];

  if (ctx.market && ctx.market.length > 0) {
    const market = marketFit(entry, ctx.market);
    factors.push({
      factor: 'Market price (actual)',
      verdict: market.score >= 0.75 ? 'Excellent' : market.score >= 0.5 ? 'Potential Concern' : 'Severe Risk',
      detail: market.detail,
    });
  }

  // Weighted verdict score (each Excellent=1, Concern=0.5, Severe=0)
  const weighted = factors.reduce((s, f) => {
    const w = f.verdict === 'Excellent' ? 1 : f.verdict === 'Potential Concern' ? 0.5 : 0.2;
    return s + w;
  }, 0);
  const score = Math.round((weighted / factors.length) * 100);
  const verdict = verdictFor(score);

  const strengths = factors.filter((f) => f.verdict === 'Excellent').slice(0, 6).map((f) => f.factor);
  const concerns = factors
    .filter((f) => f.verdict !== 'Excellent')
    .map((f) => `${f.factor}: ${f.detail}`)
    .slice(0, 6);

  const estimates: CheckEstimate[] = [
    { label: 'Cultivation cost', value: `\u20B9${entry.cultivationCostPerAcre.min}–\u20B9${entry.cultivationCostPerAcre.max}/acre`, accuracy: 'Estimated' },
    { label: 'Expected yield', value: `${entry.expectedYieldPerAcre.min}–${entry.expectedYieldPerAcre.max} ${entry.expectedYieldPerAcre.unit}`, accuracy: 'Estimated' },
    { label: 'Reference price', value: `\u20B9${entry.pricePerQuintal.min}–\u20B9${entry.pricePerQuintal.max}/quintal`, accuracy: 'Estimated' },
    { label: 'Seed rate', value: entry.seedRatePerAcre, accuracy: 'Verified' },
    { label: 'Duration', value: `${entry.durationDaysMin}–${entry.durationDaysMax} days`, accuracy: 'Verified' },
    { label: 'Suitable soils', value: entry.soilTypes.join(', '), accuracy: 'Verified' },
  ];

  const reason = concerns.length
    ? `Primary concerns: ${concerns.slice(0, 3).join(' | ')}`
    : 'Looks like a strong fit for this farm.';

  return {
    success: true,
    found: true,
    matchedCrop: entry,
    matchedVariety: query.variety?.trim() ? query.variety.trim() : entry.varieties[0],
    score,
    verdict: verdict.label,
    verdictLevel: verdict.level,
    factors,
    estimates,
    strengths,
    concerns,
    seasonNotes: `Best season(s): ${entry.season}. ${entry.plantingWindows.join('; ')}.`,
    regionNotes: `Grown in: ${entry.states.slice(0, 8).join(', ')}${verbatim ? '' : ' (closest catalogue match to your input)'}.`,
    reason,
    fallbackCandidates: [],
  };
}

// ── Firestore mirror + seed ──────────────────────────────────────────────────

const COLLECTION = 'cropKnowledge';
const CACHE_TTL_MS = 6 * 60 * 60 * 1000; // 6h
let cache: { entries: CropKnowledgeEntry[]; at: number } | null = null;

export function ensureCropData(): void {
  ensureFirebaseAdmin();
}

export function cropPool(): CropKnowledgeEntry[] {
  if (cache && Date.now() - cache.at < CACHE_TTL_MS) return cache.entries;
  return SHIPPED_CROP_KNOWLEDGE;
}

export async function readCropKnowledgeFromFirestore(): Promise<CropKnowledgeEntry[] | null> {
  try {
    ensureCropData();
    const snap = await admin.firestore().collection(COLLECTION).limit(1).get();
    if (snap.empty) return null;
    const docs: CropKnowledgeEntry[] = [];
    const all = await admin.firestore().collection(COLLECTION).get();
    all.forEach((d) => {
      const data = d.data();
      docs.push(data as unknown as CropKnowledgeEntry);
    });
    cache = { entries: docs.length ? docs : SHIPPED_CROP_KNOWLEDGE, at: Date.now() };
    return cache.entries;
  } catch {
    return null;
  }
}

/** Idempotent seeding of `cropKnowledge/{id}` docs + version marker. */
export async function seedCropKnowledge(): Promise<{ written: number }> {
  ensureCropData();
  const db = admin.firestore();
  const batch = db.batch();
  SHIPPED_CROP_KNOWLEDGE.forEach((c) => {
    batch.set(db.doc(`${COLLECTION}/${c.id}`), {
      ...(c as unknown as Record<string, unknown>),
      dataVersion: CROP_DATA_VERSION,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  await batch.commit();
  return { written: SHIPPED_CROP_KNOWLEDGE.length };
}

/** Returns the live pool (Firestore mirror when available, else shipped default). */
export async function resolvePool(): Promise<CropKnowledgeEntry[]> {
  if (cache) return cache.entries;
  const fromDb = await readCropKnowledgeFromFirestore();
  return fromDb ?? SHIPPED_CROP_KNOWLEDGE;
}