export interface ScreenshotManifestEntry {
  id: string;
  file: string;
  screenName: string;
  feature: string;
  language: string;
  device: string;
  verified: boolean;
  capturedAt: string;
  description: string;
}

/**
 * STRICT SCREENSHOT MANIFEST
 * Only screenshots where verified === true may be rendered on the website.
 * No AI-generated or redesigned UI mockups allowed.
 */
export const SCREENSHOT_MANIFEST: ScreenshotManifestEntry[] = [
  {
    id: 'farmer-home',
    file: '/screenshots/farmer-home.jpg',
    screenName: 'Compiled Android Application',
    feature: 'VidhAI Agriculture Ecosystem Splash & Application Launcher',
    language: 'English',
    device: 'Android Physical / Emulator',
    verified: true,
    capturedAt: '2025-02-15',
    description:
      'Genuine Android screen showing clean VidhAI splash interface, official sprout insignia, and compiled mobile ecosystem architecture.',
  },
  {
    id: 'ai-assistant',
    file: '/screenshots/ai-assistant.jpg',
    screenName: 'VidhAI AI Farm Assistant',
    feature: 'Conversational Agricultural Intelligence & Farm Context',
    language: 'English',
    device: 'Android Physical / Emulator',
    verified: true,
    capturedAt: '2025-02-15',
    description:
      'Genuine Android conversation interface demonstrating contextual farm anchoring, Groq fast streaming text response, and voice input capability.',
  },
  {
    id: 'tools-dashboard',
    file: '/screenshots/tools-dashboard.jpg',
    screenName: 'Agricultural Tools Suite',
    feature: 'Integrated Agricultural Utilities & Calculators',
    language: 'English',
    device: 'Android Physical / Emulator',
    verified: true,
    capturedAt: '2025-02-15',
    description:
      'Genuine Android tools screen featuring Crop Recommendation, Disease & Pest Analysis, Mandi Price Explorer, and Fertilizer Calculators.',
  },
  {
    id: 'government-schemes',
    file: '/screenshots/government-schemes.jpg',
    screenName: 'Government Schemes Directory',
    feature: 'Subsidies, Eligibility Criteria & Scheme Applications',
    language: 'English',
    device: 'Android Physical / Emulator',
    verified: true,
    capturedAt: '2025-02-15',
    description:
      'Genuine Android screen cataloging verified Central and State government agricultural schemes, criteria filters, and direct application links.',
  },
];

/**
 * Filtered helper: returns ONLY screenshots that have been verified in the repository.
 */
export const VERIFIED_SCREENSHOTS = SCREENSHOT_MANIFEST.filter(
  (screen) => screen.verified === true
);
