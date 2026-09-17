import axios, { AxiosInstance } from 'axios';
import type {
  MarketPriceProvider,
  MarketPriceRecord,
  PriceHistoryPoint,
  PriceHistoryQuery,
  PriceQuery,
} from './marketService';

/** Direct adapter for the public AGMARKNET 2.0 report backend. */
export class Agmarknet2PriceProvider implements MarketPriceProvider {
  readonly id = 'agmarknet-2';
  readonly name = 'AGMARKNET 2.0 (DMI)';

  private readonly http: AxiosInstance;
  private filters: { until: number; value: Record<string, unknown> } | null = null;

  constructor() {
    this.http = axios.create({
      baseURL: process.env.AGMARKNET_API_BASE_URL ?? 'https://api.agmarknet.gov.in/v1',
      timeout: 25000,
      headers: {
        Accept: 'application/json, text/plain, */*',
        Origin: 'https://agmarknet.gov.in',
        Referer: 'https://agmarknet.gov.in/',
        'User-Agent': 'Mozilla/5.0 AppleWebKit/537.36 Chrome/135 Safari/537.36',
      },
    });
  }

  async getLatestPrices(query: PriceQuery): Promise<MarketPriceRecord[]> {
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

  async getCommodities(_state?: string): Promise<string[]> {
    const filters = await this.getFilters();
    const names = section(filters, 'commodity_data')
      .map((row) => text(value(row, 'commodity_name', 'commodity', 'name')))
      .filter(Boolean);
    return [...new Set(names)].sort((a, b) => a.localeCompare(b));
  }

  async getHistoricalPrices(query: PriceHistoryQuery): Promise<PriceHistoryPoint[]> {
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

    const buckets = new Map<string, number[]>();
    for (const row of rows) {
      const mapped = mapRow(row, '', state, '');
      if (!mapped?.date || mapped.modalPrice === null || !sameText(mapped.commodity, commodity)) continue;
      const stamp = Date.parse(mapped.date);
      if (!Number.isFinite(stamp) || stamp < cutoff) continue;
      const values = buckets.get(mapped.date) ?? [];
      values.push(mapped.modalPrice);
      buckets.set(mapped.date, values);
    }

    return [...buckets.entries()]
      .map(([date, prices]) => {
        const modal = average(prices);
        return {
          date,
          modalPriceReported: round2(modal),
          minPriceReported: round2(Math.min(...prices)),
          maxPriceReported: round2(Math.max(...prices)),
          dataPoints: prices.length,
          conversionFactor: 100,
          normalizedPricePerKg: round2(modal / 100),
        };
      })
      .sort((a, b) => a.date.localeCompare(b.date))
      .slice(-days);
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
      keys.some((key) => key.includes('modalprice') || key.includes('modelprice') || key.includes('minprice') || key.includes('maxprice'))
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
  const min = number(value(row, 'min_price', 'minPrice', 'minimum_price'));
  const max = number(value(row, 'max_price', 'maxPrice', 'maximum_price'));
  const directModal = number(value(row, 'modal_price', 'modalPrice', 'model_price', 'modelPrice'));
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

function number(input: unknown): number | null {
  if (typeof input === 'number') return Number.isFinite(input) ? input : null;
  if (typeof input !== 'string') return null;
  const parsed = Number(input.replace(/[₹,]/g, '').trim());
  return Number.isFinite(parsed) ? parsed : null;
}

function dateText(input: unknown): string {
  const raw = text(input);
  if (!raw) return '';
  const dmy = /^(\d{1,2})[\/-](\d{1,2})[\/-](\d{4})$/.exec(raw);
  if (dmy) return `${dmy[3]}-${dmy[2].padStart(2, '0')}-${dmy[1].padStart(2, '0')}`;
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? '' : parsed.toISOString().slice(0, 10);
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
  return values.reduce((sum, item) => sum + item, 0) / values.length;
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
