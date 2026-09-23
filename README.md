<div align="center">

# 🌱 VidhAI
### AI-Powered Agriculture Ecosystem for Indian Farmers & Consumers

**“The farmer doesn’t need to understand VidhAI — VidhAI understands the farmer.”**

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-Supported-3DDC84?logo=android&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0.0%2B1-42572A)
![Languages](https://img.shields.io/badge/Languages-13%2B-C2DBB9)
![Firebase](https://img.shields.io/badge/Firebase-Integrated-FFCA28?logo=firebase&logoColor=black)

### 📱 Public Android Build

[![Download APK](https://img.shields.io/badge/Download-VidhAI%20v1.0.0%20APK-42572A?style=for-the-badge&logo=android&logoColor=white)](https://raw.githubusercontent.com/VISHNUVS-1315/VidhAI-Public/main/releases/VidhAI-v1.0.0.apk)

**Portfolio:** https://vishnuvs-1315.github.io/VidhAI-Public/

</div>

---

## 📌 Project Overview

**VidhAI** is an agriculture-focused AI platform built to support the complete farming journey in one ecosystem. It combines personalized crop planning, AI assistance, disease/pest support, live weather, market-price information, government schemes, farm records, community interaction and farmer–consumer connectivity.

The product is designed around three access paths:

1. **Farmer Console** — farm setup, personalized AI guidance, crop recommendation, farm management and agricultural tools.
2. **Consumer Console** — agriculture community, demand/supply interaction, farmer discovery, market information and consumer-oriented AI assistance.
3. **AI Assistance Layer** — contextual AI, voice-enabled interaction and guided actions across the application.

VidhAI is built for multilingual Indian users and is designed to remain useful under unstable connectivity while keeping live AI and live-data operations online.

---

## 🚀 What’s New in the Current Build

### ✅ Live AI Crop Recommendation
The recommendation flow now sends **real farm details and user preferences to live AI**. Generic placeholder crop fallback has been removed from the online result path.

Recommendation context can include:

- Location / district
- Soil type
- Water source and availability
- Irrigation method
- Previous crop and crop history
- Farm size
- Current season
- Budget
- Crop category / type
- Preferred crop duration

The output is designed to provide ranked crop choices with suitability reasoning and practical planning context.

### ✅ Groq-Powered Main Chat
The main application chat is isolated on **Groq** using **`openai/gpt-oss-20b`** for lower response latency. It is separate from NVIDIA-based crop, vision and safety workloads.

### ✅ NVIDIA Multi-Model AI Routing
VidhAI routes different workloads to different NVIDIA Nemotron models instead of forcing every task through one model.

### ✅ Context-Aware Assistant
The assistant architecture includes farm context building, intent/action routing, chat history, attachments and contextual app-assistance flows.

### ✅ Multi-Image Disease / Pest Analysis
The app contains image-based crop analysis flows, including multi-image and multi-pest handling backed by NVIDIA vision routing.

### ✅ Expanded Farm Workspace
Farm records include crop history, crop diary, expenses, disease records, fertilizer/pesticide records, notes and crop planning information.

### ✅ Community + Demand/Supply
Community features support agriculture-focused posts, discussions and farmer/consumer demand-supply interaction.

### ✅ Task & Notification System
Local scheduling and notification infrastructure supports reminders, farm tasks and time-based user alerts.

---

# 🌾 Farmer Console

## Home & Farm Context
- Personalized farmer onboarding
- Language selection
- Farm creation and saved farm profiles
- Weather summary
- Daily tasks
- AI quick actions
- Notifications

## AI Crop Recommendation
- Uses live backend AI
- Considers farm + preference context
- Supports crop suitability reasoning
- Avoids replacing failed live results with misleading generic “AI” output

## AI Chat
- Groq `openai/gpt-oss-20b`
- Context-aware agricultural conversations
- Chat history architecture
- Attachments / file support
- Farm-aware assistant context

## Disease & Pest Support
- Crop image analysis
- Multi-image analysis flows
- Multi-pest handling
- NVIDIA vision model routing
- Structured disease/pest guidance

## Farm Management
- Farm profiles
- Crop lifecycle/history
- Crop diary
- Expense tracking
- Notes/workspace
- Disease records
- Fertilizer records
- Pesticide records
- Crop planning and crop calendar support

## Agricultural Tools
- Market prices
- Government schemes
- Fertilizer guide
- Crop search/checking
- Weather details
- Crop planning
- Community
- Demand/supply
- Rental/equipment-related user flows where enabled

---

# 🛒 Consumer Console

The consumer experience uses agriculture information from a non-farmer perspective instead of reusing farmer-only wording.

Key areas include:

- Consumer home experience
- Community feed
- Demand posting / supply discovery
- Consumer-oriented AI chat
- Market prices
- Crop/calendar information
- Farmer/crop discovery
- Agriculture tools relevant to consumers
- Account, profile and language settings

---

# 🌐 Localization

VidhAI includes localization resources for **13+ Indian languages**:

- English
- Tamil
- Hindi
- Telugu
- Kannada
- Malayalam
- Marathi
- Bengali
- Gujarati
- Punjabi
- Odia
- Assamese
- Urdu

The localization system is intended to translate the interface consistently instead of mixing English labels into localized screens.

---

# 🤖 AI Architecture

## Model Routing

| Workload | Provider | Default model |
|---|---|---|
| Main App Chat | **Groq** | `openai/gpt-oss-20b` |
| Main / Deep Reasoning | **NVIDIA NIM** | `nvidia/nemotron-3-ultra-550b-a55b` |
| General AI | **NVIDIA NIM** | `nvidia/nemotron-3.5-lightning-30b-a3b` |
| Fast AI / classification | **NVIDIA NIM** | `nvidia/nemotron-3.5-lightning-30b-a3b` |
| Vision / disease analysis | **NVIDIA NIM** | `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` |
| Safety | **NVIDIA NIM** | `nvidia/nemotron-3.5-content-safety` |
| Creative / long-form reasoning | **NVIDIA NIM** | `nvidia/nemotron-3-ultra-550b-a55b` |

Model names can be overridden through backend environment variables without rebuilding the Flutter application.

---

# 🔌 APIs & Services

| Service | Role in VidhAI |
|---|---|
| **Groq API** | Main app AI chat |
| **NVIDIA NIM API** | Crop reasoning, vision, safety and other AI workloads |
| **data.gov.in / AGMARKNET** | Agricultural commodity / mandi market-price data |
| **Open-Meteo** | Weather information; no API key required |
| **Firebase Authentication** | User authentication |
| **Cloud Firestore** | Cloud data storage and synchronization |
| **Firebase Storage** | User-uploaded files/images where required |
| **Firebase Messaging** | Messaging / notification infrastructure |
| **Render** | Node.js/TypeScript backend hosting |
| **On-device Speech Recognition** | Voice input |
| **On-device TTS** | Voice output |

---

# 🔐 API Keys & Secret Handling

**Never commit real API keys, Firebase service-account JSON or production credentials.**

The backend expects these secret environment variables:

```env
GROQ_API_KEY=
NVIDIA_API_KEY=
DATA_GOV_API_KEY=
FIREBASE_SERVICE_ACCOUNT_JSON=
```

Non-secret / optional runtime configuration includes:

```env
FIREBASE_PROJECT_ID=vidhai-app
APP_VERSION=1.0.0
CORS_ORIGINS=*
PORT=8080
RATE_LIMIT_REQUESTS_PER_MINUTE=60
AI_RATE_LIMIT_REQUESTS_PER_MINUTE=20

AI_MODEL_MAIN=nvidia/nemotron-3-ultra-550b-a55b
AI_MODEL_GENERAL=nvidia/nemotron-3.5-lightning-30b-a3b
AI_MODEL_FAST=nvidia/nemotron-3.5-lightning-30b-a3b
AI_MODEL_VISION=nvidia/nemotron-3-nano-omni-30b-a3b-reasoning
AI_MODEL_SAFETY=nvidia/nemotron-3.5-content-safety
AI_MODEL_CREATIVE=nvidia/nemotron-3-ultra-550b-a55b

AI_CHAT_MODEL=openai/gpt-oss-20b
AI_CHAT_REASONING_EFFORT=low
```

Production secrets belong in **Render → Environment** or another secure secret store. The Android application should never contain privileged AI or Firebase Admin credentials.

---

# 🏗️ System Architecture

```text
                       ┌────────────────────────┐
                       │       VidhAI App       │
                       │     Flutter / Dart     │
                       └───────────┬────────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
                ▼                  ▼                  ▼
       ┌─────────────────┐  ┌───────────────┐  ┌───────────────┐
       │ Secure Backend  │  │   Firebase    │  │   Open-Meteo  │
       │ Node.js + TS    │  │ Auth/DB/Store │  │    Weather    │
       │ Render          │  └───────────────┘  └───────────────┘
       └────────┬────────┘
                │
       ┌────────┼───────────────┐
       │        │               │
       ▼        ▼               ▼
   ┌───────┐ ┌──────────┐ ┌────────────────┐
   │ Groq  │ │ NVIDIA   │ │ data.gov.in / │
   │ Chat  │ │ NIM AI   │ │ AGMARKNET     │
   └───────┘ └──────────┘ └────────────────┘
```

### Backend responsibilities

- Keeps privileged API credentials away from the client
- Verifies authenticated requests where required
- Routes AI workloads by task type
- Applies AI/request rate limits
- Calls market-price providers
- Normalizes backend responses for the Flutter client

---

# 📶 Offline & Connectivity Strategy

VidhAI uses an **offline-aware** design:

- Local preferences and selected persisted app data can remain available on-device.
- The UI can distinguish online and offline states.
- Live AI requires network access.
- Current weather requires network access.
- Current market prices require network access.
- Firebase cloud synchronization requires network access.

This avoids showing placeholder or cached content as if it were a fresh live-AI response.

---

# 🧰 Technology Stack

### Frontend
- Flutter / Dart
- BLoC + Provider state management
- Shared Preferences
- GoRouter-based navigation
- Local notifications + WorkManager
- Geolocation / geocoding
- Image/file picker
- Speech-to-Text and Text-to-Speech

### Backend
- Node.js
- TypeScript
- Express-based API service
- Render deployment
- Firebase Admin integration
- AI gateway / model routing
- Rate limiting and request validation

### Cloud / Data
- Firebase Authentication
- Firestore
- Firebase Storage
- Firebase Messaging
- data.gov.in / AGMARKNET
- Open-Meteo

---

# 📁 Repository Structure

```text
VidhAI/
├── lib/                    # Flutter application
│   ├── core/               # Routing, shared utilities, AI model routing
│   ├── features/           # Farmer/consumer feature modules
│   ├── services/           # AI, weather, market, voice and other services
│   ├── l10n/               # 13+ language resources
│   └── main.dart           # Application entry point
├── functions/              # Node.js/TypeScript secure backend
│   ├── src/
│   │   ├── aiGateway.ts    # AI workload/model routing
│   │   ├── nvidia.ts       # Groq/NVIDIA provider clients
│   │   ├── marketService.ts
│   │   └── ...
│   └── .env.example        # Environment variable names only
├── android/                # Android platform project
├── ios/                    # iOS platform project
├── web/                    # Flutter web platform
├── windows/                # Windows platform
├── test/                   # Automated tests
├── render.yaml             # Backend deployment blueprint
├── pubspec.yaml            # Flutter dependencies/version
└── README.md
```

---

# ▶️ Run the Flutter App Locally

## Requirements

- Flutter SDK compatible with Dart `^3.6.0`
- Android Studio or VS Code with Flutter tooling
- Android device/emulator
- Firebase configuration required by the project

## Commands

```bash
git clone https://github.com/VISHNUVS-1315/VidhAI.git
cd VidhAI
flutter clean
flutter pub get
flutter run
```

To list available devices:

```bash
flutter devices
```

Then run on a specific device:

```bash
flutter run -d <device-id>
```

---

# 🖥️ Run the Backend Locally

```bash
cd functions
npm install
```

Create a local environment file using `functions/.env.example` as the reference and add your own development credentials. **Do not commit the populated secret file.**

Then run the backend with the scripts defined in `functions/package.json`.

---

# 🧪 Verification Status

The repository includes automated and manual verification for areas such as:

- App startup/navigation
- Localization completeness
- AI routing/services
- Crop recommendation behavior
- Disease/pest flows
- Notifications
- Voice flows
- Farm workspace and records

A recent project verification confirmed:

- Android debug APK builds successfully
- App launches successfully on the tested Android device
- Splash → language → domain navigation works
- Web build compiles successfully

---

# 📦 Build Android APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Expected local output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Current public APK

**VidhAI v1.0.0**  
https://raw.githubusercontent.com/VISHNUVS-1315/VidhAI-Public/main/releases/VidhAI-v1.0.0.apk

> The source repository can receive improvements after the packaged public APK is published. Publish a new APK whenever the submission build is intentionally refreshed.

---

# 🔗 Public Project Links

- **Public showcase repository:** https://github.com/VISHNUVS-1315/VidhAI-Public
- **Project portfolio:** https://vishnuvs-1315.github.io/VidhAI-Public/
- **Direct APK:** https://raw.githubusercontent.com/VISHNUVS-1315/VidhAI-Public/main/releases/VidhAI-v1.0.0.apk

---

# 🎯 Project Goal

VidhAI is designed to reduce the gap between agricultural information and practical farm decisions. Instead of forcing users to move between disconnected apps and sources, it brings **AI guidance, farm context, disease support, market awareness, records, schemes, community and consumer connection** into one agriculture-focused experience.

<div align="center">

### 🌱 VidhAI — Smarter decisions from seeding to selling.

</div>
