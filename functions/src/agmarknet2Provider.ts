import axios, { AxiosInstance } from 'axios';
import type {
  MarketPriceProvider,
  MarketPriceRecord,
  PriceHistoryPoint,
  PriceHistoryQuery,
  PriceQuery,
} from './marketService';

/**
 * Direct adapter for the public AGMARKNET 2.0 report backend.
 *
 * AGMARKNET is the preferred source. In production the public AGMARKNET API can
 * occasionally respond very slowly, so this provider automatically fails over
 * to the official data.gov.in AGMARKNET dataset when DATA_GOV_API_KEY is
 * configured. MarketService still provides the final cached-snapshot fallback.
 */
export class Agmarknet2PriceProvider implements MarketPriceProvider {
  readonly id = 'agmarknet-2-with-data-gov-failover';
  readonly name = 'AGMARKNET 2.0 / data.gov.in';

  private readonly http: AxiosInstance;
  private filters: { until: number; value: Record<string, unknown> } | null = null;

  private readonly dataGovResourceId =
    process.env.DATA_GOV_RESOURCE_ID ?? '35985678-0d79-46b4-9ed6-6f13308a1d24';

  constructor() {
    this.http = axios.create({
      baseURL: process.env.AGMARKNET_API_BASE_URL ?? 'https://api.agmarknet.gov.in/v1',
      // Do not let a slow upstream block the app for 25+ seconds. The official
      // data.gov.in feed is attempted immediately after this timeout.
      timeout: 8000,
      headers: {
        Accept: 'application/json, text/plain, */*',
        Origin: 'https://agmarknet.gov.in',
        Referer: 'https://agmarknet.gov.in/',
        'User-Agent': 'Mozilla/5.0 AppleWebKit/537.36 Chrome/135 Safari/537.36',
      },
    });
  }

  async getLatestPrices(query: PriceQuery): Promise<MarketPriceRecord[]> {
    let primaryError: unknown = null;

    try {
      const rows = await this.getLatestFromAgmarknet(query);
      if (rows.length) return rows;
    } catch (error) {
      primaryError = error;
      console.warn('[MarketPrice] AGMARKNET 2.0 failed; trying data.gov.in.', error);
    }

    try {
      const rows = await this.getLatestFromDataGov(query);
      if (rows.length) return rows;
    } catch (error) {
      console.warn('[MarketPrice] data.gov.in failover failed.', error);
      if (primaryError) throw primaryError;
      throw error;
    }

    if (primaryError) throw primaryError;
    return [];
  }

  private async getLatestFromAgmarknet(query: PriceQuery): Promise<MarketPriceRecord[]> {
    const state = (query.state ?? '').trim();
    if (!state) return [];
    const filters = await this.getFilters();
    const stateId = this.findId(section(filters, 'state_data'), state, ['state_name', 'name']);
    if (stateId === null) return [];

    const district = (query.district ?? '').trim();
    const marketIds = district ? this.marketIds(filters, stateId, district) : [];
    const limit = Math.max(1, Math.min(1000, query.limit ?? 300));

    for (let offset = 0; offset < 10; offset += 1) {
      const date = daysAgo(offset);
      const raw = marketIds.length
        ? await this.marketDaily(date, stateId, marketIds)
        : await this.stateDaily(date, stateId);
      const rows = extractPriceRows(raw)
        .map((row) => mapRow(row, date, state, district))
        .filter((row): row is MarketPriceRecord => row !== null)
        .filter((row) => !district || sameText(row.district, district))
        .filter((row) => !query.commodity?.trim() || sameText(row.commodity, query.commodity!));
      if (rows.length) return dedupe(rows).slice(0, limit);
    }
    return [];
  }

  private async getLatestFromDataGov(query: PriceQuery): Promise<MarketPriceRecord[]> {
    const apiKey = (process.env.DATA_GOV_API_KEY ?? '').trim();
    if (!apiKey) throw new Error('DATA_GOV_API_KEY is not configured.');

    const state = (query.state ?? '').trim();
    const district = (query.district ?? '').trim();
    const commodity = (query.commodity ?? '').trim();
    if (!state && !district && !commodity) return [];

    const params: Record<string, string | number> = {
      'api-key': apiKey,
      format: 'json',
      limit: Math.max(1, Math.min(1000, (query.limit ?? 300) * 2)),
      offset: 0,
    };
    if (state) params['filters[State]'] = state;
    if (district) params['filters[District]'] = district;
    if (commodity) params['filters[Commodity]'] = commodity;

    const base =
      process.env.DATA_GOV_API_BASE_URL ??
      `https://api.data.gov.in/resource/${this.dataGovResourceId}`;
    const response = await axios.get<Record<string, unknown>>(base, {
      params,
      timeout: 10000,
      headers: { Accept: 'application/json' },
    });
    const records = Array.isArray(response.data?.records) ? response.data.records : [];

    return records
      .filter((row): row is Record<string, unknown> => Boolean(row) && typeof row === 'object')
      .map((row) => mapDataGovRow(row))
      .filter((row): row is MarketPriceRecord => row !== null)
      .sort((a, b) => b.date.localeCompare(a.date))
      .slice(0, Math.max(1, Math.min(1000, query.limit ?? 300)));
  }

  async getCommodities(_state?: string): Promise<string[]> {
    try {
      const filters = await this.getFilters();
      const names = section(filters, 'commodity_data')
        .map((row) => text(value(row, 'commodity_name', 'commodity', 'name')))
        .filter(Boolean);
      return [...new Set(names)].sort((a, b) => a.localeCompare(b));
    } catch (error) {
      // MarketService already owns the reference commodity list. Returning an
      // empty list here lets it use that safe non-price fallback.
      console.warn('[MarketPrice] commodity filter request failed.', error);
      return [];
    }
  }

  async getHistoricalPrices(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]> {
    let primaryError: unknown = null;
    try {
      const points = await this.getHistoryFromAgmarknet(query);
      if (points.length) return points;
    } catch (error) {
      primaryError = error;
      console.warn('[MarketPrice] AGMARKNET history failed; trying data.gov.in.', error);
    }

    try {
      const points = await this.getHistoryFromDataGov(query);
      if (points.length) return points;
    } catch (error) {
      console.warn('[MarketPrice] data.gov.in history failover failed.', error);
      if (primaryError) throw primaryError;
      throw error;
    }

    if (primaryError) throw primaryError;
    return [];
  }

  private async getHistoryFromAgmarknet(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]> {
    const state = (query.state ?? '').trim();
    const commodity = query.commodity.trim();
    if (!state || !commodity) return [];

    const filters = await this.getFilters();
    const stateId = this.findId(section(filters, 'state_data'), state, ['state_name', 'name']);
    const commodityId = this.findId(
      section(filters, 'commodity_data'),
      commodity,
      ['commodity_name', 'commodity', 'name'],
    );
    if (stateId === null || commodityId === null) return [];

    const days = Math.max(1, Math.min(90, query.days ?? 30));
    const cutoff = Date.now() - (days + 2) * 86400000;
    const rows: Record<string, unknown>[] = [];
    for (const month of monthsFor(days)) {
      const response = await this.request('GET', '/prices-and-arrivals/date-wise/specific-commodity', {
        params: {
          year: month.year,
          month: month.month,
          stateId,
          commodityId,
          includeExcel: 'false',
        },
      });
      rows.push(...extractPriceRows(response));
    }

    return historyFromRecords(
      rows
        .map((row) => mapRow(row, '', state, ''))
        .filter((row): row is MarketPriceRecord => row !== null)
        .filter((row) => sameText(row.commodity, commodity)),
      days,
      cutoff,
    );
  }

  private async getHistoryFromDataGov(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]> {
    const apiKey = (process.env.DATA_GOV_API_KEY ?? '').trim();
    if (!apiKey) throw new Error('DATA_GOV_API_KEY is not configured.');

    const state = (query.state ?? '').trim();
    const commodity = query.commodity.trim();
    if (!state || !commodity) return [];

    const days = Math.max(1, Math.min(90, query.days ?? 30));
    const base =
      process.env.DATA_GOV_API_BASE_URL ??
      `https://api.data.gov.in/resource/${this.dataGovResourceId}`;
    const response = await axios.get<Record<string, unknown>>(base, {
      params: {
        'api-key': apiKey,
        format: 'json',
        limit: 1000,
        offset: 0,
        'filters[State]': state,
        'filters[Commodity]': commodity,
      },
      timeout: 10000,
      headers: { Accept: 'application/json' },
    });
    const records = Array.isArray(response.data?.records) ? response.data.records : [];
    const cutoff = Date.now() - (days + 2) * 86400000;
    return historyFromRecords(
      records
        .filter((row): row is Record<string, unknown> => Boolean(row) && typeof row === 'object')
        .map((row) => mapDataGovRow(row))
        .filter((row): row is MarketPriceRecord => row !== null),
      days,
      cutoff,
    );
  }

  private async getFilters(): Promise<Record<string, unknown>> {
    if (this.filters && this.filters.until > Date.now()) return this.filters.value;
    const response = await this.request('GET', '/daily-price-arrival/filters');
    const root = record(response);
    const data = record(value(root, 'data'));
    const result = Object.keys(data).length ? data : root;
    this.filters = { until: Date.now() + 6 * 60 * 60 * 1000, value: result };
    return result;
  }

  private findId(
    rows: Record<string, unknown>[],
    wanted: string,
    names: string[],
  ): string | number | null {
    const target = norm(wanted);
    for (const row of rows) {
      if (norm(text(value(row, ...names))) !== target) continue;
      const id = value(row, 'id', 'state_id', 'district_id', 'market_id', 'commodity_id');
      if (typeof id === 'string' || typeof id === 'number') return id;
    }
    return null;
  }

  private marketIds(
    filters: Record<string, unknown>,
    stateId: string | number,
    district: string,
  ): Array<string | number> {
    const districtId = this.findId(section(filters, 'district_data'), district, ['district_name', 'name']);
    const targetDistrict = norm(district);
    const targetState = String(stateId);
    const ids: Array<string | number> = [];
    for (const row of section(filters, 'market_data')) {
      const dId = text(value(row, 'district_id', 'districtId'));
      const dName = norm(text(value(row, 'district_name', 'district')));
      const sId = text(value(row, 'state_id', 'stateId'));
      if (sId && sId !== targetState) continue;
      if (!((districtId !== null && dId === String(districtId)) || dName === targetDistrict)) continue;
      const id = value(row, 'id', 'market_id', 'marketId');
      if (typeof id === 'string' || typeof id === 'number') ids.push(id);
    }
    return [...new Set(ids.map(String))];
  }

  private async marketDaily(
    date: string,
    stateId: string | number,
    marketIds: Array<string | number>,
  ): Promise<unknown> {
    const combined: unknown[] = [];
    for (let i = 0; i < marketIds.length; i += 75) {
      const result = await this.request('POST', '/prices-and-arrivals/market-report/daily', {
        data: {
          date,
          marketIds: marketIds.slice(i, i + 75),
          stateIds: [stateId],
          includeExcel: false,
        },
      });
      combined.push(result);
    }
    return combined;
  }

  private async stateDaily(date: string, stateId: string | number): Promise<unknown> {
    const first = await this.request('GET', '/prices-and-arrivals/commodity-market/daily-report-state', {
      params: { date, state: stateId, includeExcel: 'false' },
    });
    if (extractPriceRows(first).length) return first;
    return this.request('GET', '/prices-and-arrivals/commodity-wise/daily-report-state', {
      params: { date, stateIds: String(stateId), includeExcel: 'false' },
    });
  }

  private async request(
    method: 'GET' | 'POST',
    url: string,
    config: { params?: Record<string, unknown>; data?: Record<string, unknown> } = {},
  ): Promise<unknown> {
    const response = await this.http.request({ method, url, ...config });
    return response.data;
  }
}

function mapDataGovRow(row: Record<string, unknown>): MarketPriceRecord | null {
  const commodity = String(
    looseValue(row, 'Commodity', 'commodity', 'commodity_name', 'Name', 'name') ?? '',
  ).trim();
  if (!commodity) return null;

  const state = String(looseValue(row, 'State', 'state') ?? '').trim();
  const district = String(looseValue(row, 'District', 'district') ?? '').trim();
  const market = String(looseValue(row, 'Market', 'market', 'mandi') ?? '').trim();
  const varietyRaw = looseValue(row, 'Variety', 'variety', 'Grade', 'grade');
  const minPrice = numeric(looseValue(row, 'Min_Price', 'min_price'));
  const maxPrice = numeric(looseValue(row, 'Max_Price', 'max_price'));
  const modalPrice = numeric(
    looseValue(row, 'Modal_Price', 'modal_price', 'Model_Price', 'model_price'),
  );
  if (modalPrice === null) return null;

  const unitRaw = String(
    looseValue(row, 'Unit', 'unit', 'Price_Unit', 'price_unit') ?? 'Rs/Quintal',
  ).trim();
  // The official daily mandi dataset reports prices per quintal in the common
  // feed. Preserve the raw unit and only use the known conversion.
  const isKg = /(^|[^a-z])kg([^a-z]|$)|kilogram/i.test(unitRaw);
  const factor = isKg ? 1 : 100;

  return {
    commodity,
    variety: varietyRaw ? String(varietyRaw) : null,
    state,
    district,
    market,
    minPrice,
    modalPrice,
    maxPrice,
    originalUnit: unitRaw,
    unitLabel: isKg ? '₹/kg' : '₹/quintal',
    conversionFactor: factor,
    normalizedPricePerKg: round2(modalPrice / factor),
    arrival: null,
    date: parseDate(
      looseValue(row, 'Arrival_Date', 'arrival_date', 'Price_Date', 'price_date', 'Date', 'date'),
    ),
    source: 'AGMARKNET (data.gov.in)',
    lastUpdated: new Date().toISOString(),
  };
}

function looseValue(row: Record<string, unknown>, ...keys: string[]): unknown {
  const indexed = new Map(Object.entries(row).map(([key, val]) => [normKey(key), val]));
  for (const key of keys) {
    const found = indexed.get(normKey(key));
    if (found !== undefined && found !== null && found !== '') return found;
  }
  return undefined;
}

function historyFromRecords(
  records: MarketPriceRecord[],
  days: number,
  cutoff: number,
): PriceHistoryPoint[] {
  const buckets = new Map<string, { modal: number[]; min: number[]; max: number[]; factor: number[] }>();
  for (const row of records) {
    if (!row.date || row.modalPrice === null || row.modalPrice <= 0) continue;
    const stamp = Date.parse(row.date);
    if (Number.isFinite(stamp) && stamp < cutoff) continue;
    const bucket = buckets.get(row.date) ?? { modal: [], min: [], max: [], factor: [] };
    bucket.modal.push(row.modalPrice);
    bucket.min.push(row.minPrice ?? row.modalPrice);
    bucket.max.push(row.maxPrice ?? row.modalPrice);
    bucket.factor.push(row.conversionFactor ?? 100);
    buckets.set(row.date, bucket);
  }

  return [...buckets.entries()]
    .map(([date, values]) => {
      const modal = average(values.modal);
      const factor = average(values.factor) || 100;
      return {
        date,
        modalPriceReported: round2(modal),
        minPriceReported: round2(average(values.min)),
        maxPriceReported: round2(average(values.max)),
        dataPoints: values.modal.length,
        conversionFactor: factor,
        normalizedPricePerKg: round2(modal / factor),
      } satisfies PriceHistoryPoint;
    })
    .sort((a, b) => a.date.localeCompare(b.date))
    .slice(-days);
}

function section(root: Record<string, unknown>, key: string): Record<string, unknown>[] {
  const raw = value(root, key);
  return Array.isArray(raw) ? raw.map(record).filter((row) => Object.keys(row).length > 0) : [];
}

function value(row: Record<string, unknown>, ...names: string[]): unknown {
  const indexed = new Map(Object.entries(row).map(([key, val]) => [normKey(key), val]));
  for (const name of names) {
    const found = indexed.get(normKey(name));
    if (found !== undefined && found !== null && found !== '') return found;
  }
  return undefined;
}

function record(input: unknown): Record<string, unknown> {
  return input && typeof input === 'object' && !Array.isArray(input)
    ? (input as Record<string, unknown>)
    : {};
}

function extractPriceRows(input: unknown): Record<string, unknown>[] {
  const rows: Record<string, unknown>[] = [];
  const walk = (node: unknown): void => {
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (!node || typeof node !== 'object') return;
    const row = node as Record<string, unknown>;
    const keys = Object.keys(row).map(normKey);
    if (
      keys.some((key) => key.includes('commodity')) &&
      keys.some(
        (key) =>
          key.includes('modalprice') ||
          key.includes('modelprice') ||
          key.includes('minprice') ||
          key.includes('maxprice'),
      )
    ) {
      rows.push(row);
    }
    Object.values(row).forEach(walk);
  };
  walk(input);
  return rows;
}

function mapRow(
  row: Record<string, unknown>,
  fallbackDate: string,
  fallbackState: string,
  fallbackDistrict: string,
): MarketPriceRecord | null {
  const commodity = text(value(row, 'commodity_name', 'commodityName', 'commodity'));
  const min = numeric(value(row, 'min_price', 'minPrice', 'minimum_price'));
  const max = numeric(value(row, 'max_price', 'maxPrice', 'maximum_price'));
  const directModal = numeric(value(row, 'modal_price', 'modalPrice', 'model_price', 'modelPrice'));
  const modal = directModal ?? (min !== null && max !== null ? (min + max) / 2 : min ?? max);
  if (!commodity || modal === null) return null;
  return {
    commodity,
    variety: text(value(row, 'variety_name', 'varietyName', 'variety')) || null,
    state: text(value(row, 'state_name', 'stateName', 'state')) || fallbackState,
    district: text(value(row, 'district_name', 'districtName', 'district')) || fallbackDistrict,
    market: text(value(row, 'market_name', 'marketName', 'market', 'mandi_name', 'mandi')),
    minPrice: min,
    modalPrice: modal,
    maxPrice: max,
    originalUnit: 'Rs/Quintal',
    unitLabel: '₹/quintal',
    conversionFactor: 100,
    normalizedPricePerKg: round2(modal / 100),
    arrival: text(value(row, 'arrival', 'arrivals', 'arrival_qty')) || null,
    date: dateText(value(row, 'arrival_date', 'arrivalDate', 'price_date', 'priceDate', 'report_date', 'date')) || fallbackDate,
    source: 'AGMARKNET 2.0 (DMI)',
    lastUpdated: new Date().toISOString(),
  };
}

function text(input: unknown): string {
  if (typeof input === 'string' || typeof input === 'number') return String(input).trim();
  if (!input || typeof input !== 'object' || Array.isArray(input)) return '';
  const row = input as Record<string, unknown>;
  return text(value(row, 'name', 'state_name', 'district_name', 'market_name', 'commodity_name', 'label'));
}

function numeric(input: unknown): number | null {
  if (typeof input === 'number') return Number.isFinite(input) ? input : null;
  if (typeof input !== 'string') return null;
  const parsed = Number(input.replace(/[₹,]/g, '').trim());
  return Number.isFinite(parsed) ? parsed : null;
}

function parseDate(input: unknown): string {
  const raw = String(input ?? '').trim();
  if (!raw) return '';
  const dmy = /^(\d{1,2})[\/-](\d{1,2})[\/-](\d{4})$/.exec(raw);
  if (dmy) return `${dmy[3]}-${dmy[2].padStart(2, '0')}-${dmy[1].padStart(2, '0')}`;
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? '' : parsed.toISOString().slice(0, 10);
}

function dateText(input: unknown): string {
  return parseDate(text(input));
}

function normKey(input: string): string {
  return input.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function norm(input: string): string {
  return input.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function sameText(a: string, b: string): boolean {
  const left = norm(a);
  const right = norm(b);
  return left === right || left.includes(right) || right.includes(left);
}

function daysAgo(days: number): string {
  return new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);
}

function monthsFor(days: number): Array<{ year: number; month: number }> {
  const count = Math.max(1, Math.ceil((days + 31) / 28));
  const now = new Date();
  return Array.from({ length: count }, (_, index) => {
    const date = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - index, 1));
    return { year: date.getUTCFullYear(), month: date.getUTCMonth() + 1 };
  });
}

function average(values: number[]): number {
  return values.length ? values.reduce((sum, item) => sum + item, 0) / values.length : 0;
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function dedupe(rows: MarketPriceRecord[]): MarketPriceRecord[] {
  const map = new Map<string, MarketPriceRecord>();
  for (const row of rows) {
    const key = [row.state, row.district, row.market, row.commodity, row.variety ?? '', row.date]
      .map(norm)
      .join('|');
    map.set(key, row);
  }
  return [...map.values()];
}
