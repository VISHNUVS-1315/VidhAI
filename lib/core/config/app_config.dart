class AppConfig {
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY_HERE', // Replace with key from https://aistudio.google.com/app/apikey
  );

  static const String geminiModel = 'gemini-2.0-flash';
  static const int maxOutputTokens = 2048;
  static const double temperature = 0.7;
}
