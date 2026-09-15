class AppConfig {
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue:
        'YOUR_GEMINI_API_KEY_HERE', // Replace with key from https://aistudio.google.com/app/apikey
  );

  static const String geminiModel = 'gemini-2.0-flash';
  static const int maxOutputTokens = 2048;
  static const double temperature = 0.7;

  /// Secure VidhAI AI proxy. Keys live only on this backend.
  /// Override at build time: --dart-define=AI_BACKEND_URL=https://...
  static const String aiBackendUrl = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: 'https://us-central1-vidhai-app.cloudfunctions.net/api',
  );

  /// Direct Groq API key (set at build time: --dart-define=GROQ_API_KEY=...).
  /// When empty, the AI chat falls back to the secure backend proxy.
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  /// Groq model used for direct chat requests. Defaults to GPT-OSS-20B; can be
  /// changed at build time without any UI/code change.
  static const String groqModel =
      String.fromEnvironment('GROQ_MODEL', defaultValue: 'openai/gpt-oss-20b');

  /// Direct Deepgram Nova-3 API key (build time: --dart-define=DEEPGRAM_API_KEY=...).
  /// When set, real-time STT goes through Deepgram first; on any failure the
  /// app falls back to the existing Groq Whisper / backend chain.
  static const String deepgramApiKey =
      String.fromEnvironment('DEEPGRAM_API_KEY');

  /// Deepgram speech model used for direct transcription.
  static const String deepgramModel =
      String.fromEnvironment('DEEPGRAM_MODEL', defaultValue: 'nova-3');

  /// AI brain selection: 'groq' (default, existing verified path) or 'gemini'.
  /// Set at build time: --dart-define=AI_CHAT_PROVIDER=gemini.
  static const String aiChatProvider =
      String.fromEnvironment('AI_CHAT_PROVIDER', defaultValue: 'groq');

  /// True when a real Gemini key was compiled in (the shipped placeholder is
  /// ignored) so the Gemini brain can be the primary orchestrator.
  static bool get hasConfiguredGeminiKey =>
      geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';

  /// Gemini is the central brain when explicitly selected via AI_CHAT_PROVIDER
  /// or when a real GEMINI_API_KEY is present.
  static bool get preferGeminiBrain =>
      aiChatProvider == 'gemini' || hasConfiguredGeminiKey;
}
