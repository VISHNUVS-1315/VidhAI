# VidhAI — AI-Powered Agriculture Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.19+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-blue.svg)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**VidhAI** is an intelligent agricultural ecosystem designed to help farmers make smarter decisions, improve productivity, and connect with markets — all powered by AI and built for rural connectivity challenges.

---

## 🌾 Features

### 🤖 AI-Powered Intelligence
- **AI Chat Assistant** — Contextual farming advice in 13+ Indian languages
- **Crop Analysis** — Health scoring, growth stage detection, recommendations
- **Pest & Disease Detection** — AI vision + symptom analysis with treatment plans
- **Crop Recommendations** — Personalized suggestions based on soil, weather, season
- **Soil Health Analysis** — pH assessment, nutrient estimation, improvement plans
- **Weather Intelligence** — Hyperlocal forecasts, irrigation alerts, climate insights

### 🚜 Farm Management
- Multi-farm support with GPS mapping
- Crop tracking through growth stages
- Activity logging & record keeping
- Expense & income tracking
- Fertilizer & pesticide application logs
- Disease outbreak tracking
- Irrigation scheduling

### 🛒 Market & Commerce
- **Live Mandi Prices** — Real-time commodity prices from data.gov.in
- **Marketplace** — Direct farmer-to-consumer sales
- **Consumer Demand** — Post requirements, get matched with farmers
- Price trends & market insights

### 🏛️ Government & Knowledge
- Scheme eligibility checker
- Subsidy application guidance
- Training videos & best practices
- Expert consultation marketplace
- Document vault for agricultural records
- Multilingual translator (13 languages)

### 📱 Offline-First Architecture
- Core features work without internet
- Local SQLite/IndexedDB storage
- Action queue for offline actions
- Automatic cloud sync when online
- Conflict resolution for data sync

---

## 📱 Screenshots

| Dashboard | AI Chat | Crop Analysis | Market Prices |
|-----------|---------|---------------|---------------|
| ![Dashboard](screenshots/dashboard.png) | ![Chat](screenshots/chat.png) | ![Crop](screenshots/crop.png) | ![Market](screenshots/market.png) |

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.19+
- Dart 3.3+
- Android Studio / VS Code
- Firebase project (for auth, Firestore, Storage)
- Google AI Studio API key (for Gemini) — optional, works in mock mode

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/vidhai.git
cd vidhai

# Install dependencies
flutter pub get

# Configure Firebase (required)
# 1. Create Firebase project at console.firebase.google.com
# 2. Add Android app with package name: com.example.vidhai
# 3. Download google-services.json to android/app/
# 4. Enable Authentication (Email/Password, Google)
# 4. Enable Firestore Database
# 5. Enable Storage

# Run the app
flutter run
```

### Build Release APK

```bash
# With Gemini API key (for real AI)
flutter build apk --release --dart-define=GEMINI_API_KEY=YOUR_APIZA_KEY

# Without API key (mock mode - works offline)
flutter build apk --release
```

### Install on Device
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔧 Configuration

### Firebase Setup
1. Create project at [Firebase Console](https://console.firebase.google.com)
2. Add Android app: `com.example.vidhai`
3. Download `google-services.json` → `android/app/google-services.json`
4. Enable: Authentication (Email, Google), Firestore, Storage

### Gemini AI (Optional)
1. Get API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Build with: `--dart-define=GEMINI_API_KEY=AIzaSy...`

Without API key, app runs in **mock mode** (offline, contextual responses).

---

## 📦 Release APK

Download the latest release APK from [Releases](https://github.com/your-org/vidhai/releases):

- **app-release.apk** — Full app with mock AI (works offline)
- **app-release-gemini.apk** — With real Gemini AI (requires API key)

### Current Build
- **Version**: 1.0.0+1
- **Size**: ~58 MB
- **Min SDK**: 21 (Android 5.0)
- **Target SDK**: 34 (Android 14)

---

## 🌐 VidhAI Portfolio Website

A companion interactive portfolio website showcasing the VidhAI platform:

```
vidhai-portfolio/
├── src/
│   ├── app/                    # Next.js 14 App Router
│   ├── components/             # React components
│   │   ├── Hero.tsx           # Hero with animated phone mockup
│   │   ├── Problem.tsx        # Problem statement cards
│   │   ├── Solution.tsx       # Interactive ecosystem diagram
│   │   ├── Workflow.tsx       # 11-step workflow visualization
│   │   ├── AppScreens.tsx     # Interactive phone with 8 app screens
│   │   ├── Modules.tsx        # 19-module interactive showcase
│   │   ├── FarmerConsumer.tsx # Supply-demand workflow
│   │   ├── AIEngine.tsx       # Animated AI brain visualization
│   │   ├── Offline.tsx        # Offline-first demo with phone
│   │   ├── Technology.tsx     # Tech stack cards
│   │   ├── Impact.tsx         # Metrics & testimonials
│   │   ├── Research.tsx       # Links & project resources
│   │   ├── CTA.tsx            # Final call-to-action
│   │   └── Footer.tsx         # Minimal footer
│   └── lib/utils.ts
├── public/
│   └── logo.png
└── package.json
```

### Run Portfolio Locally
```bash
cd vidhai-portfolio
npm install
npm run dev
# Open http://localhost:3000
```

### Build Portfolio
```bash
npm run build
npm start
```

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── bloc/              # BLoC state management
│   ├── config/            # App configuration
│   ├── connectivity/      # Network monitoring
│   ├── error/             # Error handling
│   ├── local_storage/     # Offline storage abstraction
│   ├── routing/           # Navigation
│   └── theme/             # Material 3 theming
├── data/
│   ├── datasources/       # Local & remote data sources
│   ├── models/            # Data models
│   └── repositories/      # Repository implementations
├── features/
│   ├── auth/              # Authentication
│   ├── home/              # Dashboards & AI chat
│   ├── onboarding/        # Language, domain, profile setup
│   ├── farm/              # Farm management
│   ├── farm_records/      # Expenses, pesticides, fertilizers, diseases
│   ├── recommendations/   # Crop recommendations
│   ├── schemes/           # Government schemes
│   ├── tools/             # Market prices, crop search, fertilizer guide, pest detection
│   ├── community/         # Social features
│   ├── notifications/     # Push notifications
│   └── account/           # Profile & settings
├── locale/                # 13-language localization
├── services/
│   ├── ai/                # AI services (Gemini, mock, domain services)
│   └── ...                # Weather, market, weather, voice, etc.
└── main.dart
```

---

## 🌍 Localization (13 Languages)

| Language | Code | Native Name |
|----------|------|-------------|
| English | en | English |
| Hindi | hi | हिन्दी |
| Tamil | ta | தமிழ் |
| Telugu | te | తెలుగు |
| Kannada | kn | ಕನ್ನಡ |
| Malayalam | ml | മലയാളം |
| Bengali | bn | বাংলা |
| Marathi | mr | मराठी |
| Gujarati | gu | ગુજરાતી |
| Punjabi | pa | ਪੰਜਾਬੀ |
| Odia | or | ଓଡ଼ିଆ |
| Assamese | as | অসমীয়া |
| Urdu | ur | اردو |

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open Pull Request

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- [Google AI Studio](https://aistudio.google.com) for Gemini API
- [data.gov.in](https://data.gov.in) for mandi price data
- [IMD](https://mausam.imd.gov.in) for weather data
- Firebase for backend infrastructure
- Flutter team for the amazing framework

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-org/vidhai/issues)
- **Email**: support@vidhai.app
- **Website**: https://vidhai.app

---

**VidhAI** — *Empowering every farmer with intelligent agriculture* 🌱