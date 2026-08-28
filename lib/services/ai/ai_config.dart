enum AIProvider { backend, openai, gemini, ollama, mock }

class AIConfig {
  final AIProvider provider;
  final String backendUrl;
  final String? apiKey; // Only used if provider != backend (for local dev/testing)

  const AIConfig({
    this.provider = AIProvider.mock,
    this.backendUrl = 'https://vidhai-backend.example.com',
    this.apiKey,
  });

  static const defaultConfig = AIConfig();

  AIConfig copyWith({
    AIProvider? provider,
    String? backendUrl,
    String? apiKey,
  }) {
    return AIConfig(
      provider: provider ?? this.provider,
      backendUrl: backendUrl ?? this.backendUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  bool get isBackend => provider == AIProvider.backend;
  bool get isMock => provider == AIProvider.mock;

  Map<String, dynamic> toMap() {
    return {
      'provider': provider.name,
      'backendUrl': backendUrl,
      'apiKey': apiKey,
    };
  }

  factory AIConfig.fromMap(Map<String, dynamic> map) {
    return AIConfig(
      provider: AIProvider.values.firstWhere(
        (e) => e.name == map['provider'],
        orElse: () => AIProvider.mock,
      ),
      backendUrl: map['backendUrl'] ?? 'https://vidhai-backend.example.com',
      apiKey: map['apiKey'],
    );
  }
}
