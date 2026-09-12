/**
 * VidhAI market-price service.
 *
 * Backend adapter layer for market prices. The UI/engine never talks to a
 * third-party API directly and never reads random scraped sites. Prices come
 * from the AGMARKNET data.gov.in aggregator via the MarketPriceProvider
 * abstraction, are normalised to reliable ₹/kg values, and are cached in
 * Firestore so every user shares a recent snapshot.
 *
 * If the aggregator is unreachable the service degrades to the last cached
 * snapshot (marked `stale: true`) so the offline-first client can still show
 * "Showing last available market prices".
 */

import axios from 'axios';
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {
  INDIAN_STATES,
  IndiaStateInfo,
  REFERENCE_COMMODITIES,
  unitConversionFactor,
  unitLabel,
} from './marketData';
import { groqChat } from './groq';

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

// ── Provider: AGMARKNET/data.gov.in aggregator (mandi-api) ──────────────────

const MANDI_API_BASE = process.env.MANDI_API_BASE_URL ?? 'https://mandi-api.onrender.com/v1';
// Optional key: sent as `x-api-key` when the aggregator requires one. Kept
// server-side only; the client never ships a market-data key.
const MANDI_API_KEY = process.env.MANDI_API_KEY?.trim() || undefined;
const PROVIDER_TIMEOUT_MS = 20_000;

/** States the AGMARKNET aggregator actually serves. Other states 404 (fetch omitted). */
const PROVIDER_STATES = ['Maharashtra', 'Uttar Pradesh', 'Punjab', 'Madhya Pradesh', 'Karnataka'] as const;

function parseNum(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v === 'string') {
    const n = parseFloat(v.replace(/[₹,]/g, ''));
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

export class MandiApiPriceProvider implements MarketPriceProvider {
  readonly id = 'mandi-api';
  readonly name = 'Mandi API (AGMARKNET via data.gov.in)';

  private async get<T>(path: string, params: Record<string, string>): Promise<T> {
    const res = await axios.get<T>(`${MANDI_API_BASE}${path}`, {
      params,
      timeout: PROVIDER_TIMEOUT_MS,
      headers: MANDI_API_KEY
        ? { Accept: 'application/json', 'x-api-key': MANDI_API_KEY }
        : { Accept: 'application/json' },
    });
    return res.data;
  }

  private async fetchRows(
    path: string,
    params: Record<string, string>,
  ): Promise<unknown[]> {
    const payload = await this.get<unknown>(path, params);
    return this.extractRows(payload);
  }

  private extractRows(payload: unknown): unknown[] {
    if (Array.isArray(payload)) return payload;
    if (payload && typeof payload === 'object') {
      const obj = payload as Record<string, unknown>;
      for (const key of ['data', 'prices', 'records', 'response', 'results']) {
        const v = obj[key];
        if (Array.isArray(v)) return v;
      }
    }
    return [];
  }

  async getLatestPrices(query: PriceQuery): Promise<MarketPriceRecord[]> {
    const state = (query.state ?? '').trim();
    const commodity = (query.commodity ?? '').trim();
    const limit = Math.max(1, Math.min(1000, query.limit ?? 500));
    const stateSupported = PROVIDER_STATES.some(
      (s) => s.toLowerCase() === state.toLowerCase(),
    );

    // The aggregator 404s on states it does not publish. Return no records so
    // the client shows "no prices available in this region" instead of an error.
    if (state && !stateSupported) return [];

    const cap = String(Math.min(limit * 2, 1000));
    let rows: unknown[];
    if (state) {
      rows = await this.fetchRows('/prices', {
        state,
        ...(commodity ? { commodity } : {}),
        limit: cap,
      });
    } else if (commodity) {
      rows = await this.fetchRows('/prices', { commodity, limit: cap });
    } else {
      // India overview: the aggregator rejects calls without state/commodity,
      // so fetch each supported state in parallel and merge server-side.
      const perState = Math.max(1, Math.ceil(limit / PROVIDER_STATES.length));
      const settled = await Promise.all(
        PROVIDER_STATES.map((s) =>
          this.fetchRows('/prices', { state: s, limit: String(perState) }).catch(
            () => [] as unknown[],
          ),
        ),
      );
      rows = settled.flat();
    }

    const records = rows
      .map((row) => mapApiRecord(row))
      .filter((p): p is MarketPriceRecord => p !== null);
    records.sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));
    return records.slice(0, limit);
  }

  async getCommodities(state?: string): Promise<string[]> {
    try {
      const params: Record<string, string> = {};
      if (state) params['state'] = state;
      const payload = await this.get<unknown>('/commodities', params);
      const rows = this.extractRows(payload);
      const out = rows
        .map((r) => {
          if (typeof r === 'string') return r;
          if (r && typeof r === 'object') {
            const obj = r as Record<string, unknown>;
            return (obj['commodity'] ?? obj['name'] ?? obj['commodity_name']) as string;
          }
          return '';
        })
        .map((s) => String(s).trim())
        .filter((s, i, a) => s && a.indexOf(s) === i);
      // The aggregator's /commodities endpoint can be page-capped; merge its
      // result with the authoritative reference list so the picker is always
      // usable and expandable.
      const union = [...new Set([...out, ...REFERENCE_COMMODITIES])];
      return union.length ? union : REFERENCE_COMMODITIES.slice();
    } catch {
      return REFERENCE_COMMODITIES.slice();
    }
  }

  async getHistoricalPrices(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]> {
    const commodity = (query.commodity ?? '').trim();
    if (!commodity) return [];
    const state = (query.state ?? '').trim();
    const days = Math.max(1, Math.min(90, query.days ?? 30));
    const stateSupported = PROVIDER_STATES.some((s) => s.toLowerCase() === state.toLowerCase());

    // The aggregator publishes history per supported state; unsupported states
    // or a missing state have no server-side series (out of coverage).
    if (!state || !stateSupported) return [];

    const from = new Date(Date.now() - days * 24 * 3600 * 1000);
    const fromDate = from.toISOString().slice(0, 10);
    let rows: unknown[];
    try {
      const payload = await this.get<unknown>('/prices/history', {
        state,
        commodity,
        from: fromDate,
      });
      rows = this.extractRows(payload);
    } catch {
      // 404/other -> no usable series
      return [];
    }

    const factor = 100; // AGMARKNET daily averages are reported per quintal
    const points = rows
      .map((r) => {
        if (!r || typeof r !== 'object') return null;
        const row = r as Record<string, unknown>;
        const date = String(row['arrival_date'] ?? row['price_date'] ?? '').trim();
        if (!date) return null;
        const modal = parseNum(row['avg_modal_price'] ?? row['modal_price']);
        if (modal === null || modal <= 0) return null;
        return {
          date,
          modalPriceReported: modal,
          minPriceReported: parseNum(row['avg_min_price'] ?? row['min_price']) ?? 0,
          maxPriceReported: parseNum(row['avg_max_price'] ?? row['max_price']) ?? 0,
          dataPoints: Number(row['data_points'] ?? 0) || 0,
          conversionFactor: factor,
          normalizedPricePerKg: round2(modal / factor),
        } satisfies PriceHistoryPoint;
      })
      .filter((p): p is PriceHistoryPoint => p !== null)
      .sort((a, b) => a.date.localeCompare(b.date));
    return points.slice(-days);
  }
}

export function mapApiRecord(raw: unknown): MarketPriceRecord | null {
  if (!raw || typeof raw !== 'object') return null;
  const row = raw as Record<string, unknown>;
  const commodity = String(row['commodity'] ?? row['commodity_name'] ?? row['name'] ?? '').trim();
  if (!commodity) return null;
  const modalPrice = parseNum(row['modal_price']) ?? parseNum(row['model_price']);
  const minPrice = parseNum(row['min_price']);
  const maxPrice = parseNum(row['max_price']);
  const originalUnit = String(row['unit'] ?? row['price_unit'] ?? 'Rs/Quintal').trim();
  const conversionFactor = unitConversionFactor(originalUnit);
  const normalizedPricePerKg =
    conversionFactor && modalPrice !== null ? round2(modalPrice / conversionFactor) : null;
  return {
    commodity,
    variety: row['variety'] ? String(row['variety']) : row['grade'] ? String(row['grade']) : null,
    state: String(row['state'] ?? '').trim(),
    district: districtOf(String(row['state'] ?? ''), String(row['market'] ?? row['mandi'] ?? '')),
    market: String(row['market'] ?? row['mandi'] ?? '').trim(),
    minPrice,
    modalPrice,
    maxPrice,
    originalUnit,
    unitLabel: unitLabel(originalUnit),
    conversionFactor,
    normalizedPricePerKg,
    arrival: row['arrival'] ? String(row['arrival']) : row['arrival_date'] ? null : null,
    date: String(row['date'] ?? row['arrival_date'] ?? row['price_date'] ?? '').trim(),
    source: 'AGMARKNET (data.gov.in)',
    lastUpdated: new Date().toISOString(),
  };
}

export function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

/** Best-effort market name -> district mapping using the authoritative dataset. */
export function districtOf(stateName: string, marketName: string): string {
  const state = findState(stateName);
  if (!state || !marketName) return '';
  let market = marketName.toLowerCase().trim();
  market = market
    .replace(/\b(apmc|mandi|market|yard|bazaar|agricultural|produce|regulate\d*|committee)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const marketTokens = market.split(' ').filter(Boolean);
  let best = '';
  for (const d of state.districts) {
    const dl = d.toLowerCase().replace(/\s+/g, ' ');
    const matches =
      market === dl ||
      market.startsWith(dl + ' ') ||
      dl.startsWith(market + ' ') ||
      (marketTokens.length === 1 && dl.split(' ').includes(marketTokens[0]));
    if (matches && dl.length > best.length) best = d;
  }
  return best;
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

// ── Service: hierarchy + cached latest prices + deterministic insight ────────

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
  constructor(readonly provider: MarketPriceProvider = new MandiApiPriceProvider()) {}

  // ── Hierarchy (deterministic, no external calls) ───────────────────────────

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

  // ── Commodities ────────────────────────────────────────────────────────────

  async getCommodities(state?: string): Promise<string[]> {
    try {
      const commodities = await this.provider.getCommodities(state);
      if (commodities.length) return commodities;
    } catch (e) {
      functions.logger.warn('market commodities provider failed', e);
    }
    return REFERENCE_COMMODITIES.slice();
  }

  // ── Latest prices with Firestore snapshot cache ────────────────────────────

  async getLatestPrices(
    query: PriceQuery,
    opts: { refresh?: boolean } = {},
  ): Promise<{ prices: MarketPriceRecord[]; fromCache: boolean; stale: boolean; fetchedAt: string; source: string; error?: string }> {
    const key = cacheKey(query);
    let cached: CacheDoc | null = null;
    try {
      cached = await this.readCache(key);
    } catch (e) {
      functions.logger.warn('market cache read failed', e);
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
        functions.logger.warn('market refresh failed, falling back to snapshot', e);
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
      functions.logger.warn('market prices provider failed', e);
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

  // ── Historical trend (real reported series only) ───────────────────────────

  async getHistoricalPrices(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]> {
    try {
      return await this.provider.getHistoricalPrices(query);
    } catch (e) {
      functions.logger.warn('market history provider failed', e);
      return [];
    }
  }

  // ── Deterministic analytic insight (numbers only, never fabricated) ────────

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
    if (!process.env.GROQ_API_KEY) return deterministic;
    const system = [
      'You translate a farmer-facing market insight. Follow these hard rules:',
      '1. ONLY reference the exact numbers given. Never invent trends, forecasts, or prices.',
      '2. Do not guarantee future prices or advise on when to sell.',
      '3. Keep it practical, short (max 4 sentences), and in the requested language.',
      '4. Mention that prices are indicative and differ by mandi and quality.',
      `Data you may use (verified numbers only): ${deterministic}`,
    ].join('\n');
    try {
      const result = await groqChat(
        [
          { role: 'system', content: system },
          { role: 'user', content: `Translate/rewrite: ${deterministic}` },
        ],
        { language: opts.language ?? 'en', context: opts.farmContext ? { farmContext: opts.farmContext } : undefined },
      );
      const content = (result.content ?? '').trim();
      return content.length ? content : deterministic;
    } catch (e) {
      functions.logger.warn('AI market insight failed, using deterministic', e);
      return deterministic;
    }
  }

  // ── Firestore cache ────────────────────────────────────────────────────────

  private ensureDb(): admin.firestore.Firestore {
    if (!admin.apps.length) admin.initializeApp();
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

  // ── Aggregates for summary/overview ─────────────────────────────────────────

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