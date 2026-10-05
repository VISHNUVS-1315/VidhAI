/**
 * VidhAI Project Central Configuration & Fact Sheet
 * 
 * Source of truth for portfolio claims, architecture details,
 * team credits, and genuine repository artifacts.
 */

export interface TeamMember {
  name: string;
  role: string;
  contributions: string[];
  github?: string;
  linkedin?: string;
}

export interface TechItem {
  name: string;
  category: 'Mobile' | 'State' | 'AI' | 'Backend' | 'Cloud' | 'Data' | 'Device' | 'Local';
  purpose: string;
}

export interface ScreenshotMeta {
  id: string;
  title: string;
  category: 'Home' | 'AI Assistant' | 'Tools' | 'Schemes' | 'Farm' | 'Market' | 'Community';
  src: string;
  caption: string;
  verifiedStatus: 'Verified Genuine Screenshot';
  details: string;
}

export interface TimelineMilestone {
  period: string;
  title: string;
  tag: string;
  summary: string;
  details: string[];
}

export interface EngineeringChallenge {
  title: string;
  constraint: string;
  solution: string;
  implementation: string;
}

export const VIDHAI_APK_URL =
  'https://raw.githubusercontent.com/VISHNUVS-1315/VidhAI-Public/main/releases/VidhAI-v1.0.0.apk';

export const PROJECT_CONFIG = {
  name: 'VidhAI',
  tagline: 'Intelligence for Every Field.',
  subtagline:
    'An AI-powered agricultural ecosystem connecting crop decisions, farm management, market intelligence, and farmer–consumer interaction.',
  status: 'Active Development',
  version: 'v1.0.0+1',
  builtFor: 'Student Innovation & Agricultural Impact',
  repositoryUrl: 'https://github.com/VISHNUVS-1315/VidhAI',
  apkUrl: VIDHAI_APK_URL,
  backendDeployment: 'Render Standalone Express Architecture',
  
  creator: {
    name: 'Vishnu',
    handle: 'VISHNUVS-1315',
    roles: ['Product Design', 'Flutter Architecture', 'AI Routing Gateway', 'Full-Stack Engineering'],
    bio: 'Lead engineer and creator of the VidhAI agricultural operating system.',
    github: 'https://github.com/VISHNUVS-1315',
    confirmedContributions: [
      {
        category: 'Product & System Design',
        summary: 'Architected the core dual-console ecosystem (Farmer vs Consumer) and unified the end-to-end VidhAI system architecture.',
        evidence: 'System architecture specs, BLoC/Provider state separation, and interaction design.',
      },
      {
        category: 'Flutter Development',
        summary: 'Authored mobile client components with verified Android build, Google Sign-In authentication flows, and SharedPreferences offline-friendly caching.',
        evidence: 'lib/main.dart, lib/screens/home/, and feature presentation modules.',
      },
      {
        category: 'AI Integration',
        summary: 'Designed dual-router dispatch logic connecting low-latency Groq streaming (openai/gpt-oss-20b) with NVIDIA NIM agricultural reasoning.',
        evidence: 'lib/core/services/ai_routing_service.dart and functions/src/aiGateway.ts.',
      },
      {
        category: 'Backend/API Integration',
        summary: 'Implemented standalone Node.js Express gateway on Render, enforcing Firebase Admin ID token verification and zero client-side API secrets.',
        evidence: 'functions/src/app.ts and functions/src/server.ts.',
      },
      {
        category: 'Agricultural Data Integration',
        summary: 'Built normalized ingestion pipelines converting AGMARKNET 2.0 mandi commodity prices into uniform ₹/kg with 1-hour server-side snapshot caching.',
        evidence: 'functions/src/marketService.ts and functions/src/marketData.ts.',
      },
      {
        category: 'UI/UX & Accessibility Iteration',
        summary: 'Engineered 13-language localization infrastructure, dynamic Urdu RTL layout switches, and audio TTS/STT feedback loops.',
        evidence: 'lib/l10n/ and presentation widget accessibility compliance.',
      },
    ],
  },

  stats: [
    { label: 'Supported Languages', value: '13', note: 'Indian vernaculars with Urdu RTL' },
    { label: 'AI Specialization', value: 'Hybrid Gateway', note: 'Groq Conversational + NVIDIA Agronomy' },
    { label: 'Verified App Screens', value: '43', note: 'Across Farmer & Consumer consoles' },
    { label: 'Market Data Standard', value: '₹ / kg', note: 'AGMARKNET 2.0 automatic conversion' },
  ],

  aiArchitecture: {
    appChat: {
      provider: 'Groq',
      model: 'openai/gpt-oss-20b',
      purpose: 'Dedicated low-latency streaming chat path for mobile farm dialogue.',
    },
    publicOverview: {
      conversational: 'Groq: Conversational AI',
      specialized: 'NVIDIA: Agricultural reasoning · Vision · Safety',
    },
    specializedTiers: [
      {
        tier: 'Agricultural Reasoning (Main)',
        model: 'nvidia/nemotron-3-ultra-550b-a55b',
        role: 'Multi-factor crop planning, rotation strategy, and economic risk forecasting.',
      },
      {
        tier: 'General / Fast Intelligence',
        model: 'nvidia/nemotron-3.5-lightning-30b-a3b',
        role: 'Agricultural Q&A, weather condition explanation, and task advisory.',
      },
      {
        tier: 'Vision & Issue Analysis',
        model: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning',
        role: 'Multimodal pest symptom diagnosis and crop foliage inspection.',
      },
      {
        tier: 'Content Safety & Moderation',
        model: 'nvidia/nemotron-3.5-content-safety',
        role: 'Pre-flight prompt filtering and community safety verification.',
      },
    ],
    clientTools: [
      { name: 'farm_tool', description: 'Loads farm name, farm size, soil type, water availability, irrigation, and active crop records' },
      { name: 'mandi_price_tool', description: 'Queries AGMARKNET 2.0 commodity prices and trends' },
      { name: 'weather_tool', description: 'Retrieves hyperlocal Open-Meteo current and hourly forecast' },
      { name: 'task_tool', description: 'Schedules, tracks, and reads farm workspace activity reminders' },
      { name: 'profile_tool', description: 'Accesses farmer location, language, and regional preferences' },
      { name: 'navigation_tool', description: 'Executes in-app deep links based on AI recommendations' },
    ],
  },

  languages: [
    { code: 'en', name: 'English', native: 'English', dir: 'ltr' },
    { code: 'ta', name: 'Tamil', native: 'தமிழ்', dir: 'ltr' },
    { code: 'hi', name: 'Hindi', native: 'हिन्दी', dir: 'ltr' },
    { code: 'te', name: 'Telugu', native: 'తెలుగు', dir: 'ltr' },
    { code: 'kn', name: 'Kannada', native: 'ಕನ್ನಡ', dir: 'ltr' },
    { code: 'ml', name: 'Malayalam', native: 'മലയാളം', dir: 'ltr' },
    { code: 'bn', name: 'Bengali', native: 'বাংলা', dir: 'ltr' },
    { code: 'mr', name: 'Marathi', native: 'मराठी', dir: 'ltr' },
    { code: 'gu', name: 'Gujarati', native: 'ગુજરાતી', dir: 'ltr' },
    { code: 'pa', name: 'Punjabi', native: 'ਪੰਜਾਬੀ', dir: 'ltr' },
    { code: 'or', name: 'Odia', native: 'ଓଡ଼ିଆ', dir: 'ltr' },
    { code: 'as', name: 'Assamese', native: 'অসমীয়া', dir: 'ltr' },
    { code: 'ur', name: 'Urdu', native: 'اردو', dir: 'rtl' },
  ],

  screenshots: [
    {
      id: 'farmer-home',
      title: 'Compiled Android Application',
      category: 'Home',
      src: '/screenshots/farmer-home.jpg',
      caption: 'Clean VidhAI application launch screen featuring the official sprout insignia and compiled Android architecture.',
      verifiedStatus: 'Verified Genuine Screenshot',
      details: 'Built in Flutter with BLoC state management and SharedPreferences caching.',
    },
    {
      id: 'ai-assistant',
      title: 'VidhAI Farm-Aware Assistant',
      category: 'AI Assistant',
      src: '/screenshots/ai-assistant.jpg',
      caption: 'Conversational chat experience with farm context selection, speech-to-text, and audio playback.',
      verifiedStatus: 'Verified Genuine Screenshot',
      details: 'Integrated with Groq (gpt-oss-20b) for fast conversational streaming.',
    },
    {
      id: 'tools-dashboard',
      title: 'Agricultural Tools & Utilities',
      category: 'Tools',
      src: '/screenshots/tools-dashboard.jpg',
      caption: 'Unified launcher for Pest Detection, Fertilizer Guide, Mandi Prices, Crop Search, and Soil Scanner.',
      verifiedStatus: 'Verified Genuine Screenshot',
      details: 'Verified screen connecting client utilities with backend intelligence services.',
    },
    {
      id: 'government-schemes',
      title: 'Government Agricultural Schemes',
      category: 'Schemes',
      src: '/screenshots/government-schemes.jpg',
      caption: 'Curated agricultural subsidy directory and welfare support information for rural farmers.',
      verifiedStatus: 'Verified Genuine Screenshot',
      details: 'State and national scheme eligibility guidance built directly into the mobile client.',
    },
  ] as ScreenshotMeta[],

  techStack: [
    { name: 'Flutter & Dart', category: 'Mobile', purpose: 'Cross-platform Flutter client with current verified application build for Android' },
    { name: 'flutter_bloc & Provider', category: 'State', purpose: 'Predictable reactive state management for auth, farms, and chat sessions' },
    { name: 'Groq (openai/gpt-oss-20b)', category: 'AI', purpose: 'Dedicated low-latency streaming conversational AI path optimized for mobile interaction' },
    { name: 'NVIDIA NIM Architecture', category: 'AI', purpose: 'Nemotron Ultra 550B agronomic reasoning, Nano Omni 30B vision, and safety models' },
    { name: 'Node.js, Express & TypeScript', category: 'Backend', purpose: 'Standalone gateway deployed on Render with Firebase Admin auth verification' },
    { name: 'Firebase Suite', category: 'Cloud', purpose: 'Firebase Authentication, Cloud Firestore document store, and Cloud Messaging' },
    { name: 'SharedPreferences', category: 'Local', purpose: 'Offline-friendly cached storage for user profiles, farms, crop catalog, and offline states' },
    { name: 'AGMARKNET 2.0 (data.gov.in)', category: 'Data', purpose: 'Official mandi prices across Indian states normalized into standard ₹/kg' },
    { name: 'Open-Meteo API', category: 'Data', purpose: 'Hyperlocal weather forecasts, hourly rain predictions, and temperature telemetry' },
    { name: 'WorkManager (Android)', category: 'Device', purpose: 'Background periodic tasks for weather monitoring and proactive notifications' },
    { name: 'Speech-to-Text & Flutter TTS', category: 'Device', purpose: 'Hands-free voice recognition and speech synthesis in native Indian accents' },
  ] as TechItem[],

  challenges: [
    {
      title: 'Language Accessibility',
      constraint: 'Indian farmers speak diverse regional vernaculars; English-only interfaces create severe adoption barriers.',
      solution: 'Implemented 13 native Indian languages with dedicated translation tables and full bidirectional RTL support for Urdu.',
      implementation: 'Custom `lib/locale` localization engine with 13 translation files and live runtime switching.',
    },
    {
      title: 'Intermittent Rural Connectivity',
      constraint: 'Fields frequently suffer from spotty 2G/3G connectivity or complete signal blackouts.',
      solution: 'Engineered a local-first caching strategy that persists farms, previous recommendations, and cached mandi prices.',
      implementation: 'SharedPreferences-backed offline fallback with graceful degradation from Cloud to Local Mode.',
    },
    {
      title: 'AI Conversational Latency',
      constraint: 'Multi-turn agronomic chatbots using heavy frontier models often take 4–8 seconds to generate first tokens.',
      solution: 'Dedicated Groq inference path running `openai/gpt-oss-20b` for responsive streaming dialogue optimized for mobile interaction.',
      implementation: 'Separate chat route `/ai/chat` connected to Groq, keeping NVIDIA NIM for complex deep-reasoning jobs.',
    },
    {
      title: 'Heterogeneous AI Workload Routing',
      constraint: 'One single model cannot efficiently handle text chat, multimodal leaf diagnosis, and safety moderation.',
      solution: 'Backend AI Gateway dynamically routes tasks to specialized model tiers based on intent classification.',
      implementation: '`functions/src/aiGateway.ts` orchestrates Nemotron Ultra 550B, Lightning 30B, Nano Omni 30B, and Content Safety.',
    },
    {
      title: 'Chaotic Mandi Price Formats',
      constraint: 'Government mandi data uses non-standard units across states (Quintal, Maund, Crates, Metric Tonnes).',
      solution: 'Centralized conversion layer calculates normalization multipliers, converting all reported modal prices to ₹/kg.',
      implementation: '`functions/src/marketService.ts` normalizes incoming data and maintains a 1-hour server-side market snapshot cache for resilience, fallback handling and rate-limit protection.',
    },
    {
      title: 'Deep Farm Context Assembly',
      constraint: 'Generic AI fails farmers because it does not know their soil, irrigation, past crops, or local weather.',
      solution: '`AIContextBuilder` automatically bundles 7 distinct farm parameters into every AI request payload.',
      implementation: 'Farmer profile + active farm + crop stage + GPS + Open-Meteo + AGMARKNET bundled into typed snapshot.',
    },
    {
      title: 'Proactive Alerting in the Background',
      constraint: 'Farmers cannot constantly open the app to check for incoming heavy rain or pending fertilization duties.',
      solution: 'Background WorkManager workers wake periodically to evaluate weather alerts against safety thresholds.',
      implementation: '`lib/services/background_work.dart` evaluates weather signatures and triggers local push notifications.',
    },
    {
      title: 'Disintermediated Market Matching',
      constraint: 'Middlemen exploit information asymmetry; farmers harvest produce without committed buyers.',
      solution: 'Direct district-filtered community marketplace linking farmer pre-harvest listings with buyer demand posts.',
      implementation: 'Community models (`available_soon` harvest & `demand`) with bilateral interest responses.',
    },
  ] as EngineeringChallenge[],

  timeline: [
    {
      period: 'Milestone 01',
      title: 'Core Flutter Architecture & Consoles',
      tag: 'Foundation',
      summary: 'Established BLoC state management, 5-tab main shell, and dedicated Farmer & Consumer consoles.',
      details: [
        'Implemented Splash, Language Selection, and Onboarding flows',
        'Configured Google Sign-In → Firebase Authentication → Firestore user profile → SharedPreferences local session fallback',
        'Engineered multi-farm workspace with GPS coordinate binding',
      ],
    },
    {
      period: 'Milestone 02',
      title: 'Backend AI Gateway & Model Routing',
      tag: 'AI Engineering',
      summary: 'Replaced generic API calls with an authenticated Node.js gateway hosting multi-tier AI routing.',
      details: [
        'Integrated NVIDIA NIM for Nemotron Ultra 550B & Nano Omni 30B reasoning',
        'Implemented intent classifier to route queries based on agronomic complexity',
        'Protected all endpoints with Firebase Bearer token verification',
      ],
    },
    {
      period: 'Milestone 03',
      title: 'Groq Integration for Low-Latency Mobile Chat',
      tag: 'Optimization',
      summary: 'Migrated conversational assistant to Groq with openai/gpt-oss-20b for responsive streaming conversational AI.',
      details: [
        'ChatGPT-style drawer redesign with persistent session history',
        'On-device speech-to-text live transcription and text-to-speech synthesis',
        'Dynamic farm context injection (`AIContextBuilder`)',
      ],
    },
    {
      period: 'Milestone 04',
      title: 'AGMARKNET 2.0 & Market Intelligence',
      tag: 'Data Integration',
      summary: 'Integrated official Government of India data.gov.in AGMARKNET 2.0 resource.',
      details: [
        'Built automated unit conversion factors into uniform ₹ / kg values',
        'Engineered 1-hour server-side market snapshot cache for resilience, fallback handling and rate-limit protection',
        'Implemented 7-day to 30-day historical commodity price trends',
      ],
    },
    {
      period: 'Milestone 05',
      title: 'Community Ecosystem & Pre-Harvest Marketplace',
      tag: 'Product Ecosystem',
      summary: 'Engineered bilateral community marketplace connecting farmers to buyers before harvest.',
      details: [
        'Structured `CommunityPost` categories: Experience, Problem, Harvest Soon, Demand',
        'Implemented status lifecycle: Active, Reserved, Fulfilled, Closed',
        'Integrated background WorkManager notifications for local weather thresholds',
      ],
    },
  ] as TimelineMilestone[],
};
