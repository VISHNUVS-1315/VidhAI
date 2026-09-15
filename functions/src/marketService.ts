/**
 * VidhAI market-price service.
 *
 * Backend adapter layer for market prices. The UI never talks to a third-party
 * market API directly. Prices come only from the official AGMARKNET data.gov.in
 * resource via the MarketPriceProvider abstraction, are normalised to reliable
 * ₹/kg values, and are cached in
 * Firestore so every user shares a recent snapshot.
 *
 * If the aggregator is unreachable the service degrades to the last cached
 * snapshot (marked `stale: true`) so the offline-first client can still show
 * "Showing last available market prices".
 */

import axios from 'axios';
import * as admin from 'firebase-admin';
import { logger } from './config/logger';
import { ensureFirebaseAdmin } from './config/firebase';
import {
  INDIAN_STATES,
  IndiaStateInfo,
  REFERENCE_COMMODITIES,
  unitConversionFactor,
  unitLabel,
} from './marketData';
import { nvidiaChat } from './nvidia';

export interface MarketPriceRecord {
  commodity: string;
  variety: string | null;
  state: string;
  district: string;
  market: string;
  minPrice: number | null;
  modalPrice: number | null;
  maxPrice: number | null;
  originalUnit: string;
  unitLabel: string;
  conversionFactor: number | null; // kg per original unit, null when unknown
  normalizedPricePerKg: number | null; // modal price converted to ₹/kg
  arrival: string | null;
  date: string;
  source: string;
  lastUpdated: string;
}

export interface PriceQuery {
  state?: string;
  district?: string;
  commodity?: string;
  limit?: number;
}

export interface PriceHistoryQuery {
  state?: string;
  commodity: string;
  days?: number; // 7 or 30 (default 30)
}

/** One daily average reported by the aggregator (AGMARKNET, per quintal). */
export interface PriceHistoryPoint {
  date: string; // yyyy-mm-dd
  modalPriceReported: number; // avg_modal_price in the reported unit (quintal)
  minPriceReported: number;
  maxPriceReported: number;
  dataPoints: number;
  conversionFactor: number; // kg per reported unit (quintal -> 100)
  normalizedPricePerKg: number; // modal price converted to ₹/kg
}

/** Adapter contract so another approved data source can be connected later. */
export interface MarketPriceProvider {
  readonly id: string;
  readonly name: string;
  getLatestPrices(query: PriceQuery): Promise<MarketPriceRecord[]>;
  getCommodities(state?: string): Promise<string[]>;
  getHistoricalPrices(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]>;
}

// Official AGMARKNET provider: data.gov.in only.
const PROVIDER_TIMEOUT_MS = 20_000;

const DATA_GOV_RESOURCE_ID =
  process.env.DATA_GOV_RESOURCE_ID ?? '35985678-0d79-46b4-9ed6-6f13308a1d24';
const DATA_GOV_API_BASE =
  process.env.DATA_GOV_API_BASE_URL ??
  `https://api.data.gov.in/resource/${DATA_GOV_RESOURCE_ID}`;

function rowValue(row: Record<string, unknown>, ...keys: string[]): unknown {
  for (const key of keys) {
    if (row[key] !== undefined && row[key] !== null && row[key] !== '') return row[key];
  }
  return undefined;
}

function parseDataGovDate(raw: unknown): string {
  const value = String(raw ?? '').trim();
  if (!value) return '';
  const dmy = /^(\d{1,2})[\/-](\d{1,2})[\/-](\d{4})$/.exec(value);
  if (dmy) {
    const [, dd, mm, yyyy] = dmy;
    return `${yyyy}-${mm.padStart(2, '0')}-${dd.padStart(2, '0')}`;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toISOString().slice(0, 10);
}

/**
 * Official data.gov.in AGMARKNET provider.
 *
 * Unlike the legacy mandi-api mirror, this provider is not restricted to five
 * states. It queries the Government of India resource directly using the
 * server-side DATA_GOV_API_KEY and supports State/District/Commodity filters.
 */
export class DataGovPriceProvider implements MarketPriceProvider {
  readonly id = 'data-gov-agmarknet';
  readonly name = 'AGMARKNET (data.gov.in)';

  private get apiKey(): string {
    return (process.env.DATA_GOV_API_KEY ?? '').trim();
  }

  private async fetchRows(
    filters: Record<string, string>,
    limit = 1000,
    offset = 0,
  ): Promise<Record<string, unknown>[]> {
    if (!this.apiKey) {
      throw new Error('DATA_GOV_API_KEY is not configured.');
    }
    const params: Record<string, string | number> = {
      'api-key': this.apiKey,
      format: 'json',
      limit: Math.max(1, Math.min(1000, limit)),
      offset: Math.max(0, offset),
    };
    for (const [key, value] of Object.entries(filters)) {
      if (value.trim()) params[`filters[${key}]`] = value.trim();
    }
    const res = await axios.get<Record<string, unknown>>(DATA_GOV_API_BASE, {
      params,
      timeout: PROVIDER_TIMEOUT_MS,
      headers: { Accept: 'application/json' },
    });
    const records = Array.isArray(res.data?.records) ? res.data.records : [];
    return records
      .filter((r): r is Record<string, unknown> => Boolean(r) && typeof r === 'object')
      .map((r) => ({ ...r }));
  }

  private mapRow(row: Record<string, unknown>): MarketPriceRecord | null {
    const commodity = String(
      rowValue(row, 'Commodity', 'commodity', 'commodity_name', 'Name', 'name') ?? '',
    ).trim();
    if (!commodity) return null;

    const state = String(rowValue(row, 'State', 'state') ?? '').trim();
    const district = String(rowValue(row, 'District', 'district') ?? '').trim();
    const market = String(rowValue(row, 'Market', 'market', 'mandi') ?? '').trim();
    const varietyRaw = rowValue(row, 'Variety', 'variety', 'Grade', 'grade');
    const minPrice = parseNum(rowValue(row, 'Min_Price', 'min_price'));
    const maxPrice = parseNum(rowValue(row, 'Max_Price', 'max_price'));
    const modalPrice = parseNum(
      rowValue(row, 'Modal_Price', 'modal_price', 'Model_Price', 'model_price'),
    );
    const originalUnit = String(
      rowValue(row, 'Unit', 'unit', 'Price_Unit', 'price_unit') ?? 'Rs/Quintal',
    ).trim();
    const conversionFactor = unitConversionFactor(originalUnit) ?? 100;
    const normalizedPricePerKg =
      modalPrice !== null ? round2(modalPrice / conversionFactor) : null;

    return {
      commodity,
      variety: varietyRaw ? String(varietyRaw) : null,
      state,
      district,
      market,
      minPrice,
      modalPrice,
      maxPrice,
      originalUnit,
      unitLabel: unitLabel(originalUnit || 'Rs/Quintal'),
      conversionFactor,
      normalizedPricePerKg,
      arrival: null,
      date: parseDataGovDate(
        rowValue(row, 'Arrival_Date', 'arrival_date', 'Price_Date', 'price_date', 'Date', 'date'),
      ),
      source: 'AGMARKNET (data.gov.in)',
      lastUpdated: new Date().toISOString(),
    };
  }

  async getLatestPrices(query: PriceQuery): Promise<MarketPriceRecord[]> {
    const filters: Record<string, string> = {};
    if (query.state?.trim()) filters.State = query.state.trim();
    if (query.district?.trim()) filters.District = query.district.trim();
    if (query.commodity?.trim()) filters.Commodity = query.commodity.trim();

    // The UI normally supplies the farmer's saved state. Avoid an unbounded
    // all-India scan when no filters are available.
    if (Object.keys(filters).length === 0) return [];

    const limit = Math.max(1, Math.min(1000, query.limit ?? 300));
    const rows = await this.fetchRows(filters, Math.min(1000, limit * 2));
    const records = rows
      .map((row) => this.mapRow(row))
      .filter((p): p is MarketPriceRecord => p !== null)
      .sort((a, b) => b.date.localeCompare(a.date));
    return records.slice(0, limit);
  }

  async getCommodities(_state?: string): Promise<string[]> {
    // A full distinct scan of the national resource is expensive and slow.
    // Keep the curated picker list; price queries themselves hit live data.gov.in.
    return REFERENCE_COMMODITIES.slice();
  }

  async getHistoricalPrices(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]> {
    const state = (query.state ?? '').trim();
    const commodity = query.commodity.trim();
    if (!state || !commodity) return [];

    const days = Math.max(1, Math.min(90, query.days ?? 30));
    const rows = await this.fetchRows(
      { State: state, Commodity: commodity },
      1000,
    );
    const cutoff = Date.now() - (days + 2) * 24 * 3600 * 1000;
    const byDate = new Map<string, { modal: number[]; min: number[]; max: number[] }>();

    for (const row of rows) {
      const date = parseDataGovDate(
        rowValue(row, 'Arrival_Date', 'arrival_date', 'Price_Date', 'price_date', 'Date', 'date'),
      );
      if (!date) continue;
      const ts = Date.parse(date);
      if (Number.isFinite(ts) && ts < cutoff) continue;

      const modal = parseNum(rowValue(row, 'Modal_Price', 'modal_price'));
      if (modal === null || modal <= 0) continue;
      const min = parseNum(rowValue(row, 'Min_Price', 'min_price')) ?? modal;
      const max = parseNum(rowValue(row, 'Max_Price', 'max_price')) ?? modal;
      const bucket = byDate.get(date) ?? { modal: [], min: [], max: [] };
      bucket.modal.push(modal);
      bucket.min.push(min);
      bucket.max.push(max);
      byDate.set(date, bucket);
    }

    const avg = (values: number[]) =>
      values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0;

    return [...byDate.entries()]
      .map(([date, values]) => {
        const modal = avg(values.modal);
        return {
          date,
          modalPriceReported: round2(modal),
          minPriceReported: round2(avg(values.min)),
          maxPriceReported: round2(avg(values.max)),
          dataPoints: values.modal.length,
          conversionFactor: 100,
          normalizedPricePerKg: round2(modal / 100),
        } satisfies PriceHistoryPoint;
      })
      .sort((a, b) => a.date.localeCompare(b.date))
      .slice(-days);
  }
}

function parseNum(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v === 'string') {
    const n = parseFloat(v.replace(/[₹,]/g, ''));
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

export function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

export function findState(stateName: string): IndiaStateInfo | undefined {
  const q = (stateName ?? '').trim();
  if (!q) return undefined;
  const ql = q.toLowerCase();
  const qc = ql.replace(/[^a-z]/g, '');
  return (
    INDIAN_STATES.find((s) => s.name.toLowerCase() === ql) ??
    INDIAN_STATES.find((s) => s.name.toLowerCase().replace(/[^a-z]/g, '') === qc) ??
    INDIAN_STATES.find((s) => {
      const n = s.name.toLowerCase();
      return n.includes(ql) || ql.includes(n);
    })
  );
}

// â”€â”€ Service: hierarchy + cached latest prices + deterministic insight â”€â”€â”€â”€â”€â”€â”€â”€

const CACHE_COLLECTION = 'marketCache';
const CACHE_TTL_MS = 60 * 60 * 1000; // 1h shared snapshot

interface CacheDoc {
  key: string;
  prices: MarketPriceRecord[];
  fetchedAt: number;
  source: string;
}

function cacheKey(query: PriceQuery): string {
  return ['marketPrices', query.state ?? '*', query.district ?? '*', query.commodity ?? '*']
    .join('|')
    .toLowerCase();
}

export class MarketService {
  constructor(readonly provider: MarketPriceProvider = new DataGovPriceProvider()) {}

  // â”€â”€ Hierarchy (deterministic, no external calls) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  getStates(): IndiaStateInfo[] {
    return INDIAN_STATES.slice();
  }

  getStateNames(): string[] {
    return INDIAN_STATES.map((s) => s.name);
  }

  getDistricts(stateName: string | undefined | null): string[] {
    const state = findState(stateName ?? '');
    return state ? state.districts.slice() : [];
  }

  // â”€â”€ Commodities â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  async getCommodities(state?: string): Promise<string[]> {
    try {
      const commodities = await this.provider.getCommodities(state);
      if (commodities.length) return commodities;
    } catch (e) {
      logger.warn('market commodities provider failed', e);
    }
    return REFERENCE_COMMODITIES.slice();
  }

  // â”€â”€ Latest prices with Firestore snapshot cache â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  async getLatestPrices(
    query: PriceQuery,
    opts: { refresh?: boolean } = {},
  ): Promise<{ prices: MarketPriceRecord[]; fromCache: boolean; stale: boolean; fetchedAt: string; source: string; error?: string }> {
    const key = cacheKey(query);
    let cached: CacheDoc | null = null;
    try {
      cached = await this.readCache(key);
    } catch (e) {
      logger.warn('market cache read failed', e);
    }

    const fresh = cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS;
    if (fresh && !opts.refresh) {
      return {
        prices: cached!.prices,
        fromCache: true,
        stale: false,
        fetchedAt: new Date(cached!.fetchedAt).toISOString(),
        source: this.provider.name,
      };
    }

    if (opts.refresh && cached) {
      // Serve latest snapshot immediately for UI responsiveness while refreshing.
      try {
        const live = await this.provider.getLatestPrices(query);
        if (live.length) {
          await this.writeCache(key, live);
          return {
            prices: live,
            fromCache: false,
            stale: false,
            fetchedAt: new Date().toISOString(),
            source: this.provider.name,
          };
        }
      } catch (e) {
        logger.warn('market refresh failed, falling back to snapshot', e);
        // fall through to cached
      }
      return {
        prices: cached.prices,
        fromCache: true,
        stale: true,
        fetchedAt: new Date(cached.fetchedAt).toISOString(),
        source: this.provider.name,
        error: 'Live refresh failed; showing last available market prices.',
      };
    }

    try {
      const live = await this.provider.getLatestPrices(query);
      if (live.length) {
        await this.writeCache(key, live);
        return {
          prices: live,
          fromCache: false,
          stale: false,
          fetchedAt: new Date().toISOString(),
          source: this.provider.name,
        };
      }
    } catch (e) {
      logger.warn('market prices provider failed', e);
      if (cached && cached.prices.length) {
        return {
          prices: cached.prices,
          fromCache: true,
          stale: true,
          fetchedAt: new Date(cached.fetchedAt).toISOString(),
          source: this.provider.name,
          error: 'Live refresh failed; showing last available market prices.',
        };
      }
      const message = e instanceof Error ? e.message : String(e);
      throw new Error(`Market price feed is temporarily unavailable. ${message}`);
    }

    return { prices: [], fromCache: false, stale: false, fetchedAt: new Date().toISOString(), source: this.provider.name };
  }

  // â”€â”€ Historical trend (real reported series only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  async getHistoricalPrices(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]> {
    try {
      return await this.provider.getHistoricalPrices(query);
    } catch (e) {
      logger.warn('market history provider failed', e);
      return [];
    }
  }

  // â”€â”€ Deterministic analytic insight (numbers only, never fabricated) â”€â”€â”€â”€â”€â”€â”€â”€

  buildMarketInsight(prices: MarketPriceRecord[], language = 'en'): string {
    if (!prices.length) return '';
    const byCommodity = new Map<string, MarketPriceRecord[]>();
    for (const p of prices) {
      const list = byCommodity.get(p.commodity) ?? [];
      list.push(p);
      byCommodity.set(p.commodity, list);
    }
    const lines: string[] = [];
    const latestDate = maxRecentDate(prices);
    for (const [commodity, rows] of byCommodity) {
      const perKg = rows
        .map((r) => r.normalizedPricePerKg)
        .filter((v): v is number => v !== null);
      if (!perKg.length) continue;
      const markets = rows.filter((r) => r.market).length;
      const min = Math.min(...perKg);
      const max = Math.max(...perKg);
      const avg = round2(perKg.reduce((s, v) => s + v, 0) / perKg.length);
      lines.push(
        `${commodity}: modal price between \u20B9${min} and \u20B9${max} per kg (average \u20B9${avg}/kg) across ${markets} reported market${markets === 1 ? '' : 's'}.`,
      );
    }
    if (!lines.length) return '';
    const header =
      latestDate
        ? `Based on reported prices from ${latestDate}, latest available. `
        : 'Based on the latest available reported prices. ';
    return header + lines.join(' ');
  }

  async buildAiMarketInsight(
    prices: MarketPriceRecord[],
    opts: { language?: string; farmContext?: string } = {},
  ): Promise<string> {
    const deterministic = this.buildMarketInsight(prices, opts.language ?? 'en');
    if (!deterministic) return '';
    if (!process.env.NVIDIA_API_KEY) return deterministic;
    const system = [
      'You translate a farmer-facing market insight. Follow these hard rules:',
      '1. ONLY reference the exact numbers given. Never invent trends, forecasts, or prices.',
      '2. Do not guarantee future prices or advise on when to sell.',
      '3. Keep it practical, short (max 4 sentences), and in the requested language.',
      '4. Mention that prices are indicative and differ by mandi and quality.',
      `Data you may use (verified numbers only): ${deterministic}`,
    ].join('\n');
    try {
      const result = await nvidiaChat(
        [
          { role: 'system', content: system },
          { role: 'user', content: `Translate/rewrite: ${deterministic}` },
        ],
        { language: opts.language ?? 'en', context: opts.farmContext ? { farmContext: opts.farmContext } : undefined },
      );
      const content = (result.content ?? '').trim();
      return content.length ? content : deterministic;
    } catch (e) {
      logger.warn('AI market insight failed, using deterministic', e);
      return deterministic;
    }
  }

  // â”€â”€ Firestore cache â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  private ensureDb(): admin.firestore.Firestore {
    ensureFirebaseAdmin();
    return admin.firestore();
  }

  private async readCache(key: string): Promise<CacheDoc | null> {
    const db = this.ensureDb();
    const ref = db.doc(`${CACHE_COLLECTION}/${key.replace(/[^a-z0-9]/gi, '_')}`);
    const doc = await ref.get();
    if (!doc.exists) return null;
    const data = doc.data() as CacheDoc | undefined;
    if (!data || !Array.isArray(data.prices)) return null;
    return data;
  }

  private async writeCache(key: string, prices: MarketPriceRecord[]): Promise<void> {
    const db = this.ensureDb();
    const ref = db.doc(`${CACHE_COLLECTION}/${key.replace(/[^a-z0-9]/gi, '_')}`);
    await ref.set({
      key,
      prices,
      fetchedAt: Date.now(),
      source: this.provider.name,
    } satisfies CacheDoc);
  }

  // â”€â”€ Aggregates for summary/overview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  summarize(prices: MarketPriceRecord[]): {
    totalPriceRecords: number;
    statesWithData: string[];
    commodities: string[];
    latestDate: string | null;
    pricePerKgAvailable: number;
  } {
    const states = [...new Set(prices.map((p) => p.state).filter(Boolean))].sort();
    const commodities = [...new Set(prices.map((p) => p.commodity))].sort();
    return {
      totalPriceRecords: prices.length,
      statesWithData: states,
      commodities,
      latestDate: maxRecentDate(prices),
      pricePerKgAvailable: prices.filter((p) => p.normalizedPricePerKg !== null).length,
    };
  }
}

function maxRecentDate(prices: MarketPriceRecord[]): string | null {
  let best: Date | null = null;
  for (const p of prices) {
    if (!p.date) continue;
    const d = new Date(p.date.replace(/\//g, '-'));
    if (isNaN(d.getTime())) continue;
    if (!best || d > best) best = d;
  }
  return best ? best.toISOString().slice(0, 10) : null;
}