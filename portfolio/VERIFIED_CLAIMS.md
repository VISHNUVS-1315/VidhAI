# VidhAI Portfolio: Verified Claims Matrix

This audit file records every public technical claim made on the VidhAI engineering portfolio, mapped directly to its verifying repository source file.

---

| ID | Technical Claim | Verifying Source File | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **CLM-01** | Mobile Framework: Flutter & Dart | `pubspec.yaml:7-12` | **VERIFIED** | Displayed without hardcoded versions. |
| **CLM-02** | State Management: `flutter_bloc` & `provider` | `pubspec.yaml:18-19` | **VERIFIED** | `flutter_bloc: ^9.1.0`, `provider: ^6.1.2`. |
| **CLM-03** | Local Caching: `shared_preferences` | `pubspec.yaml:25` | **VERIFIED** | SharedPreferences used for caching; no SQLite. |
| **CLM-04** | Cloud Sync: Firebase Auth & Cloud Firestore | `pubspec.yaml:43-45`, `functions/src/firebase.ts` | **VERIFIED** | Cloud Firestore for profiles, farms, and records. |
| **CLM-05** | Dual Consoles: Farmer & Consumer | `lib/screens/home/farmer_home_screen.dart`, `lib/screens/home/consumer_home_screen.dart` | **VERIFIED** | Distinct screens and route separation. |
| **CLM-06** | Dedicated Streaming Chat: Groq `openai/gpt-oss-20b` | `functions/src/aiService.ts`, `functions/src/aiGateway.ts` | **VERIFIED** | Described as "Dedicated low-latency streaming chat path" without speculative numerical claims. |
| **CLM-07** | Specialized Agronomy AI: NVIDIA NIM Nemotron | `functions/src/aiGateway.ts:43-53`, `functions/src/cropAiService.ts` | **VERIFIED** | `nemotron-3-ultra-550b-a55b` (main/agronomy), `nemotron-3.5-lightning-30b-a3b` (fast), `nemotron-3-nano-omni-30b-a3b-reasoning` (vision). |
| **CLM-08** | Market Architecture: AGMARKNET 2.0 + Server Fallback | `functions/src/marketService.ts:5-190`, `functions/src/marketData.ts` | **VERIFIED** | Primary: AGMARKNET 2.0 API; Fallback: data.gov.in AGMARKNET dataset via VidhAI backend. |
| **CLM-09** | ₹/kg Mandi Price Normalization | `functions/src/marketData.ts`, `functions/src/marketService.ts` | **VERIFIED** | Server normalizes quintals/bags into standard ₹/kg. |
| **CLM-10** | Multilingual Engine: 13 Indian Languages + Urdu RTL | `lib/l10n/`, `pubspec.yaml:13` | **VERIFIED** | 13 languages supported; Urdu layout supports RTL. |
| **CLM-11** | Crop Recommendation Fallback Pipeline | `functions/src/cropAiService.ts`, `functions/src/app.ts:261-315` | **VERIFIED** | Online Structured Recommendation (NVIDIA NIM) → Deterministic Catalog → Shipped Local Knowledge. |
| **CLM-12** | Voice Transcription & Speech Synthesis | `pubspec.yaml:48-52` (`speech_to_text`, `flutter_tts`) | **VERIFIED** | On-device partial speech recognition and TTS. |
| **CLM-13** | Background Tasks & Scheduled Reminders | `pubspec.yaml:28-32` (`workmanager`, `flutter_local_notifications`) | **VERIFIED** | Background task triggers require network when fetching fresh weather. |
| **CLM-14** | Offline-Friendly / Cached Resilience | `lib/services/offline_service.dart`, `pubspec.yaml:25` | **VERIFIED** | Profile, farm, task, recommendation, market, and preference caches allow offline review. AI requests require connectivity. |
| **CLM-15** | Illustrative Market & Community Scenarios | `src/data/mockData.ts` | **ILLUSTRATIVE** | Visibly labeled as "ILLUSTRATIVE SCENARIO" with generic "DEMO FARMER" / "DEMO BUYER" personas. |
| **CLM-16** | Genuine App Screenshots Gate | `src/data/screenshots.ts` | **VERIFIED** | Only screenshots verified in the repository (`farmer-home.jpg`, `ai-assistant.jpg`, `tools-dashboard.jpg`, `government-schemes.jpg`) are rendered with `verified: true`. |

---

### Status Definitions:
- **VERIFIED**: Proven directly by current repository code.
- **ILLUSTRATIVE**: Demo simulation data, clearly labeled as non-real illustrative scenarios.
- **IN DEVELOPMENT**: Architectural roadmap items clearly marked as future iterations.
- **REMOVE**: Unsubstantiated claims (e.g., "100% offline", "sub-second guaranteed", "5-tier fallback", invented farmer names) — **all removed**.
