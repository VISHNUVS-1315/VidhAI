import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import cors from 'cors';
import express from 'express';
import multer from 'multer';

import { groqChat, groqStt, GroqChatMessage, ToolSpec } from './groq';
import { deepgramStt } from './deepgram';
import { geminiChat, geminiVision, VisionImage } from './gemini';
import { googleTts } from './tts';
import {
  createDeepgramRealtimeSession,
  LANGUAGE_WHITELIST,
  UNSUPPORTED_REALTIME_LANGUAGES,
} from './deepgram_realtime';
import {
  checkCrop,
  recommend,
  resolvePool,
  seedCropKnowledge,
  selectCandidatePool,
  FarmContext,
  RecommendationInput,
  CheckQuery,
} from './cropService';
import {
  MarketService,
} from './marketService';

if (!admin.apps.length) {
  admin.initializeApp();
}

const GROQ_API_KEY = defineSecret('GROQ_API_KEY');
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const DEEPGRAM_API_KEY = defineSecret('DEEPGRAM_API_KEY');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '30mb' }));
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 100 * 1024 * 1024 } });

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
  admin
    .auth()
    .verifyIdToken(token)
    .then((decoded) => {
      req.firebaseUid = decoded.uid;
      next();
    })
    .catch(() => {
      res.status(401).json({ success: false, error: 'Invalid or expired token.' });
    });
}

/**
 * POST /ai/chat
 * body: { messages: Groq-style message[], language?, context?, tools?: ToolSpec[] }
 */
app.post('/ai/chat', requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};
    const messages = Array.isArray(body.messages) ? (body.messages as GroqChatMessage[]) : [];
    if (messages.length === 0) {
      res.status(400).json({ success: false, error: 'messages is required.' });
      return;
    }
    const provider = body.provider === 'gemini' ? 'gemini' : 'groq';
    const result =
      provider === 'gemini'
        ? await geminiChat(messages, {
            language: body.language,
            tools: body.tools as ToolSpec[] | undefined,
          })
        : await groqChat(messages, {
            language: body.language,
            context: body.context,
            tools: body.tools as ToolSpec[] | undefined,
          });
    res.json({
      success: true,
      content: result.content,
      toolCalls: result.toolCalls,
      metadata: { provider, model: result.model, usage: result.usage },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    functions.logger.error('chat failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /ai/stt  (multipart: audio file + language [+ provider: 'groq'|'deepgram'])
 */
app.post('/ai/stt', requireAuth, upload.single('audio'), async (req, res) => {
  try {
    const file = req.file;
    if (!file) {
      res.status(400).json({ success: false, error: 'audio file is required.' });
      return;
    }
    const language =
      typeof req.body.language === 'string' ? req.body.language : undefined;
    const provider = req.body.provider === 'deepgram' ? 'deepgram' : 'groq';
    const result =
      provider === 'deepgram'
        ? await deepgramStt(file.buffer, {
            language,
            mime: typeof file.mimetype === 'string' ? file.mimetype : undefined,
          })
        : await groqStt(file.buffer, {
            language,
            filename: file.originalname,
            mime: file.mimetype,
          });
    res.json({
      success: true,
      ...result,
      provider: provider === 'deepgram' ? 'nova-3' : 'whisper-large-v3-turbo',
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    functions.logger.error('stt failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /ai/deepgram/session
 * body: { language? }
 *
 * Mints a short-lived Deepgram access token (JWT, ~180 s) via `/v1/auth/grant`
 * and returns it together with the fully-qualified realtime `/v1/listen`
 * WebSocket URL (Nova-3, linear16 16 kHz, interim results). The mobile client
 * streams PCM16 audio directly to Deepgram with `Authorization: Bearer <jwt>`.
 * The permanent DEEPGRAM_API_KEY never leaves this server. Malayalam and Odia
 * are not supported by any Deepgram streaming model and are rejected clearly.
 */
app.post('/ai/deepgram/session', requireAuth, async (req: AuthedRequest, res) => {
  try {
    const body = req.body ?? {};
    const language =
      typeof body.language === 'string' ? body.language.toLowerCase() : 'en';
    if (!LANGUAGE_WHITELIST.has(language)) {
      res.status(400).json({ success: false, error: `Unsupported language '${language}'.` });
      return;
    }
    if (UNSUPPORTED_REALTIME_LANGUAGES.has(language)) {
      res.status(400).json({
        success: false,
        error: 'LANGUAGE_UNSUPPORTED',
        message: 'Realtime transcription is not yet available in this language.',
      });
      return;
    }

    const session = await createDeepgramRealtimeSession({ languageCode: language });
    functions.logger.info(
      `deepgram realtime session granted uid=${req.firebaseUid} model=${session.model} language=${session.language}`,
    );
    res.json({
      success: true,
      accessToken: session.accessToken,
      expiresIn: session.expiresIn,
      model: session.model,
      language: session.language,
      sampleRate: session.sampleRate,
      encoding: session.encoding,
      wsUrl: session.wsUrl,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    functions.logger.error('deepgram realtime session failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /ai/tts
 * body: { text, language?, speakingRate? }
 */
app.post('/ai/tts', requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};
    const result = await googleTts(body.text ?? '', {
      language: body.language,
      speakingRate: Number(body.speakingRate ?? 1.0),
    });
    res.json({ success: true, ...result });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    functions.logger.error('tts failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /ai/image
 * body: { prompt, language?, images: [{ base64, mimeType }] }
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
    const result = await geminiVision(prompt, images, { language: body.language });
    res.json({ success: true, ...result });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    functions.logger.error('vision failed', e);
    res.status(500).json({ success: false, error: message });
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
    functions.logger.error('market history failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

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
    functions.logger.error('crop recommend failed', e);
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
    functions.logger.error('crop check failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /crop/search
 * body: { query?, category?, state?, season?, limit? }
 *
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
    functions.logger.error('crop search failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

/**
 * POST /crop/seed  (guarded; admin/ops only)
 * Requires header `x-crop-seed-key` to match `process.env.CROP_SEED_TOKEN`
 * (set in the emulator `.secret.local` or as a Cloud Run env var). Idempotent.
 */
app.post('/crop/seed', requireAuth, async (req, res) => {
  try {
    const expected = process.env.CROP_SEED_TOKEN;
    const provided = String(req.headers['x-crop-seed-key'] ?? '');
    if (!expected || provided !== expected) {
      res.status(403).json({ success: false, error: 'Seeding is not enabled.' });
      return;
    }
    const result = await seedCropKnowledge();
    res.json({ success: true, ...result });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    functions.logger.error('crop seed failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

const marketService = new MarketService();

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
    functions.logger.error('market states failed', e);
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
    functions.logger.error('market districts failed', e);
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
    functions.logger.error('market commodities failed', e);
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
    functions.logger.error('market prices failed', e);
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
    functions.logger.error('market summary failed', e);
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
    functions.logger.error('market insight failed', e);
    res.status(500).json({ success: false, error: message });
  }
});

export const api = onRequest(
  {
    secrets: [GROQ_API_KEY, GEMINI_API_KEY, DEEPGRAM_API_KEY],
    timeoutSeconds: 300,
    memory: '1GiB',
    maxInstances: 10,
  },
  app,
);