class AppConfig {
  AppConfig._();

  /// Secure VidhAI backend. AI keys never ship in the Flutter app.
  static const String aiBackendUrl = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: 'https://vidhai-pp7n.onrender.com',
  );
}
