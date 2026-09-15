/**
 * Shared Express application for the VidhAI gateway.
 *
 * Single source of truth for every route. Mounted by:
 *  - src/server.ts  → standalone Node server (Render, local `npm start`)
 *  - src/index.ts   → Firebase Cloud Functions wrapper (`onRequest(app)`)
 *
 * All secrets are read from process.env (see src/config/env.ts). The app is
 * deliberately Firebase-Functions-free so it deploys on Spark-free hosts.
 */

import express from 'express';
import cors from 'cors';

import { corsOrigins, appVersion, serviceName } from './config/env';
import { logger } from './config/logger';
import { ensureFirebaseAdmin } from './config/firebase';
import { NvidiaChatMessage, ToolSpec } from './nvidia';
import {
  AiGatewayError,
  chatWithRouter,
  classifyIntent,
  httpStatusFor,
  moderateText,
  visionAnalyze,
  VisionImage,
} from './aiGateway';
import {
  checkCrop,
  recommend,
  resolvePool,
  selectCandidatePool,
  FarmContext,
  RecommendationInput,
  CheckQuery,
} from './cropService';
import { MarketService } from './marketService';
import { recommendWithAI, CropRecommendationAiInput } from './cropAiService';

// Initialize Firebase Admin up front so every downstream service (auth,
// Firestore cache, seeding) shares the same credential-aware app.
ensureFirebaseAdmin();

const app = express();
app.disable('x-powered-by');
app.use(cors({ origin: corsOrigins() }));
app.use(express.json({ limit: '30mb' }));

/**
 * GET /health
 * Public liveness probe (Render + external monitors). No secrets.
 */
app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: serviceName,
    version: appVersion,
    timestamp: new Date().toISOString(),
  });
});

interface AuthedRequest extends express.Request {
  firebaseUid?: string;
}

/** Verifies Firebase Auth ID token and attaches uid. */
function requireAuth(req: AuthedRequest, res: express.Response, next: express.NextFunction): void {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : '';
  if (!token) {
    res.status(401).json({ success: false, error: 'Missing Firebase ID token.' });
    return;
  }
  const admin = ensureFirebaseAdmin();
  admin
    .auth()
    .verifyIdToken(token)
    .then((decoded) => {
      req.firebaseUid = decoded.uid;
      next();
    })
    .catch((e: unknown) => {
      const err = e as { code?: string; message?: string };
      logger.error('auth verifyIdToken rejected', {
        code: err?.code ?? 'unknown',
        message: err?.message ?? String(e),
      });
      res.status(401).json({ success: false, error: 'Invalid or expired token.' });
    });
}

const APP_TIERS = new Set(['main', 'general', 'fast', 'creative']);

/**
 * POST /ai/chat
 * body: { messages, language?, context?, tools?, tier?, classify? }
 *
 * All AI requests are served only through NVIDIA NIM. The router selects the
 * NVIDIA model tier and uses NVIDIA-only fallbacks.
 */
app.post('/ai/chat', requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};
    const messages = Array.isArray(body.messages)
      ? (body.messages as NvidiaChatMessage[])
      : [];
    if (messages.length === 0) {
      res.status(400).json({ success: false, error: 'messages is required.' });
      return;
    }

    const tier =
      typeof body.tier === 'string' && APP_TIERS.has(body.tier)
        ? (body.tier as 'main' | 'general' | 'fast' | 'creative')
        : undefined;

    const result = await chatWithRouter({
      messages,
      language: body.language,
      context: body.context,
      tools: body.tools as ToolSpec[] | undefined,
      tier,
      classify: body.classify === true,
      complexity: body.complexity,
      intent: body.intent,
      label: body.label,
    });

    res.json({
      success: true,
      content: result.content,
      toolCalls: result.toolCalls,
      metadata: {
        provider: 'nvidia',
        model: result.model,
        tier: result.tier,
        triedTiers: result.triedTiers,
        retries: result.retries,
        classification: result.classification,
      },
    });
  } catch (e) {
    const status = e instanceof AiGatewayError ? httpStatusFor(e) : 500;
    const message = e instanceof Error ? e.message : String(e);
    logger.error('chat failed', e);
    res.status(status).json({ success: false, error: message });
  }
});

/**
 * POST /ai/classify
 * body: { text, language?, useModel?, label? }
 * Classifies user intent into a tier for downstream routing.
 */
app.post('/ai/classify', requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};
    const text = typeof body.text === 'string' ? body.text : '';
    if (text.trim().length === 0) {
      res.status(400).json({ success: false, error: 'text is required.' });
      return;
    }
    const result = await classifyIntent({
      text,
      language: body.language,
      useModel: body.useModel !== false,
      label: body.label,
    });
    res.json({ success: true, ...result });
  } catch (e) {
    const status = e instanceof AiGatewayError ? httpStatusFor(e) : 500;
    const message = e instanceof Error ? e.message : String(e);
    logger.error('classify failed', e);
    res.status(status).json({ success: false, error: message });
  }
});

/**
 * POST /ai/moderate
 * body: { text, language? }
 * Content-safety classification via the NVIDIA safety model (fail-open).
 */
app.post('/ai/moderate', requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};
    const result = await moderateText(
      typeof body.text === 'string' ? body.text : '',
    );
    res.json({ success: true, ...result });
  } catch (e) {
    const status = e instanceof AiGatewayError ? httpStatusFor(e) : 500;
    const message = e instanceof Error ? e.message : String(e);
    logger.error('moderate failed', e);
    res.status(status).json({ success: false, error: message });
  }
});

/**
 * POST /ai/image
 * body: { prompt, language?, images: [{ base64, mimeType }] }
 * Image analysis is served only by the NVIDIA vision tier.
 */
app.post('/ai/image', requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};
    const prompt = String(body.prompt ?? 'Analyze this crop image and provide guidance.');
    const images = (Array.isArray(body.images) ? body.images : []) as VisionImage[];
    if (images.length === 0) {
      res.status(400).json({ success: false, error: 'At least one image is required.' });
      return;
    }
    const result = await visionAnalyze({
      prompt,
      images,
      language: body.language,
    });
    res.json({
      success: true,
      content: result.content,
      text: result.content,
      model: result.model,
      provider: result.provider,
      fallbackUsed: result.fallbackUsed,
    });
  } catch (e) {
    const status = e instanceof AiGatewayError ? httpStatusFor(e) : 500;
    const message = e instanceof Error ? e.message : String(e);
    logger.error('vision failed', e);
    res.status(status).json({ success: false, error: message });
  }
});

/**
 * POST /market/history
 * body: { state?, commodity, days? }
 * Real reported daily averages (AGMARKNET) for a supported commodity+state.
 * Returns [] when no history exists — never fabricated.
 */
app.post('/market/history', requireAuth, async (req, res) => {
  try {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const commodity = String(body.commodity ?? '').trim();
    if (!commodity) {
      res.status(400).json({ success: false, error: 'commodity is required.' });
      return;
    }
    const state = String(body.state ?? '').trim() || undefined;
    const days = Math.min(30, Math.max(1, Number(body.days ?? 30) || 30));
    const history = await marketService.getHistoricalPrices({ state, commodity, days });
    res.json({ success: true, commodity, state: state ?? null, days, history });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('market history failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

const marketService = new MarketService();

/**
 * POST /crop/recommend
 * body: { farm: FarmContext, input?: RecommendationInput }
 *
 * Deterministic, cached crop-data engine: returns exactly 10 scored
 * recommendations (or fewer only when the state+season pool is smaller).
 * All money/yield figures are labelled estimates by the client.
 */
app.post('/crop/recommend', requireAuth, async (req, res) => {
  try {
    const pool = await resolvePool();
    const farm = (req.body?.farm ?? {}) as FarmContext;
    const input = (req.body?.input ?? {}) as RecommendationInput;
    const ctx: FarmContext = {
      ...farm,
      month: typeof farm.month === 'number' ? farm.month : new Date().getMonth() + 1,
      durationPreference: input.cropDurationPreference || farm.durationPreference,
      categoryPreferences: input.cropCategoryPreference ? [input.cropCategoryPreference] : farm.categoryPreferences,
      budgetInrPerAcre: input.budgetInrPerAcre ?? farm.budgetInrPerAcre,
      fallowMonths: input.landIdleDuration ? parseInt(input.landIdleDuration, 10) || undefined : farm.fallowMonths,
      lastCrop: input.lastCrop || farm.lastCrop,
      waterAvailability: input.waterAvailability || farm.waterAvailability,
      soilType: input.soilType || farm.soilType,
      irrigationType: input.irrigationSystem || farm.irrigationType,
    };
    const result = recommend(ctx, input);
    res.json({ ...result, poolSize: pool.length });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('crop recommend failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /crop/ai-recommend
 *
 * NVIDIA AI reasons over ALL supplied farm context at once: location, soil,
 * water, irrigation, crop history, season, weather from
 * Open-Meteo, market prices from AGMARKNET and the farmer's ~6 manual inputs)
 * and returns a STRUCTURED top-10. Prices/weather are never invented: the
 * model is instructed to state when market or weather data was not provided,
 * and the response is validated + normalized against the shipped catalog.
 * body: { context, input }
 */
app.post('/crop/ai-recommend', requireAuth, async (req, res) => {
  try {
    const context = (req.body?.context ?? {}) as Record<string, unknown>;
    const input = (req.body?.input ?? {}) as CropRecommendationAiInput;
    const result = await recommendWithAI(context, input);
    res.json({ success: true, ...result });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('crop ai-recommend failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /crop/check
 * body: { query: { cropName, variety? }, farm: FarmContext }
 */
app.post('/crop/check', requireAuth, async (req, res) => {
  try {
    const farm = (req.body?.farm ?? {}) as FarmContext;
    const query = (req.body?.query ?? {}) as CheckQuery;
    if (!query.cropName || typeof query.cropName !== 'string' || !query.cropName.trim()) {
      res.status(400).json({ success: false, error: 'cropName is required.' });
      return;
    }
    const result = checkCrop(farm, { cropName: query.cropName.trim(), variety: query.variety });
    res.json({ ...result });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('crop check failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /crop/search
 * body: { query?, category?, state?, season?, limit? }
 * Returns catalog summaries for a location-aware pool (no financial estimates;
 * the client enriches selected crops via /crop/check).
 */
app.post('/crop/search', requireAuth, async (req, res) => {
  try {
    const pool = await resolvePool();
    const q = String(req.body?.query ?? '').trim().toLowerCase();
    const category = String(req.body?.category ?? '').trim().toLowerCase();
    const state = String(req.body?.state ?? '').trim();
    const limit = Math.min(50, Math.max(1, Number(req.body?.limit ?? 30) || 30));

    let results = selectCandidatePool(pool, { state, month: new Date().getMonth() + 1 });
    if (category) results = results.filter((c) => c.category.toLowerCase() === category);
    if (q) {
      results = results.filter(
        (c) =>
          c.id.includes(q) ||
          c.name.toLowerCase().includes(q) ||
          c.category.toLowerCase().includes(q) ||
          c.varieties.some((v) => v.toLowerCase().includes(q)),
      );
    }
    const summaries = results.slice(0, limit).map((c) => ({
      id: c.id,
      name: c.name,
      category: c.category,
      varieties: c.varieties,
      season: c.season,
      durationDaysMin: c.durationDaysMin,
      durationDaysMax: c.durationDaysMax,
      waterRequirement: c.waterRequirement,
      states: c.states,
      marketDemand: c.marketDemand,
      riskLevel: c.riskLevel,
      description: c.description,
    }));
    res.json({ success: true, total: results.length, returned: summaries.length, crops: summaries });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('crop search failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

const marketFilter = (body: Record<string, unknown>) => ({
  state: typeof body.state === 'string' && body.state.trim() ? body.state.trim() : undefined,
  district: typeof body.district === 'string' && body.district.trim() ? body.district.trim() : undefined,
  commodity: typeof body.commodity === 'string' && body.commodity.trim() ? body.commodity.trim() : undefined,
  limit: Math.min(1000, Math.max(1, Number(body.limit) || 300)),
});

/**
 * POST /market/states
 * Administrative States/UTs dataset (no external call, no pricing).
 */
app.post('/market/states', requireAuth, async (_req, res) => {
  try {
    res.json({
      success: true,
      states: marketService.getStates().map((s) => ({ id: s.id, name: s.name, ut: s.ut, districtCount: s.districts.length })),
      total: marketService.getStates().length,
      source: 'Govt. of India administrative reference',
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('market states failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /market/districts
 * body: { state }
 */
app.post('/market/districts', requireAuth, async (req, res) => {
  try {
    const state = String(req.body?.state ?? '').trim();
    if (!state) {
      res.status(400).json({ success: false, error: 'state is required.' });
      return;
    }
    const districts = marketService.getDistricts(state);
    res.json({ success: true, state, districts, count: districts.length });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('market districts failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /market/commodities
 * body: { state? }  (provider-backed with reference fallback)
 */
app.post('/market/commodities', requireAuth, async (req, res) => {
  try {
    const state = String(req.body?.state ?? '').trim() || undefined;
    const commodities = await marketService.getCommodities(state);
    res.json({ success: true, state: state ?? null, commodities, count: commodities.length });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('market commodities failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /market/prices
 * body: { state?, district?, commodity?, limit?, refresh? }
 * Returns normalised ₹/kg records (original unit + conversion always included).
 * Offline-capable: provider failure while a snapshot exists returns `stale: true`.
 */
app.post('/market/prices', requireAuth, async (req, res) => {
  try {
    const query = marketFilter((req.body ?? {}) as Record<string, unknown>);
    const refresh = req.body?.refresh === true;
    const result = await marketService.getLatestPrices(query, { refresh });
    res.json({ success: true, ...result, query: { ...query, refresh } });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('market prices failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /market/summary
 * Overview aggregates derived only from actually reported records.
 */
app.post('/market/summary', requireAuth, async (req, res) => {
  try {
    const query = marketFilter((req.body ?? {}) as Record<string, unknown>);
    const result = await marketService.getLatestPrices(query, { refresh: req.body?.refresh === true });
    const summary = marketService.summarize(result.prices);
    res.json({ success: true, ...summary, fromCache: result.fromCache, stale: result.stale, source: result.source });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('market summary failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /market/insight
 * body: { state?, district?, commodity?, language?, farmContext?, refresh? }
 */
app.post('/market/insight', requireAuth, async (req, res) => {
  try {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const query = marketFilter(body);
    const language = typeof body.language === 'string' ? body.language : 'en';
    const farmContext = typeof body.farmContext === 'string' ? body.farmContext : '';
    const result = await marketService.getLatestPrices(query, { refresh: body.refresh === true });
    const prices = result.prices;
    const pricesByCommodity = [...new Set(prices.map((p) => p.commodity))].slice(0, 12);
    const sample = prices.filter((p) => pricesByCommodity.includes(p.commodity)).slice(0, 60);
    const insight = await marketService.buildAiMarketInsight(sample, { language, farmContext });
    res.json({
      success: true,
      insight,
      fromCache: result.fromCache,
      stale: result.stale,
      recordCount: prices.length,
      updatedAt: result.fetchedAt,
      source: result.source,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    logger.error('market insight failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

// 404 for unknown routes.
app.use((_req, res) => {
  res.status(404).json({ success: false, error: 'Not found.' });
});

// Final error guard: never leak internals (or secrets) to clients.
app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error('unhandled error', err);
  res.status(500).json({ success: false, error: 'Internal server error.' });
});

export { app };
export default app;