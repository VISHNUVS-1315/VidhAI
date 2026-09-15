enum AIProvider { backend }

class AIConfig {
  final AIProvider provider;

  const AIConfig({this.provider = AIProvider.backend});

  static const defaultConfig = AIConfig();

  bool get isBackend => true;

  Map<String, dynamic> toMap() => {'provider': provider.name};

  factory AIConfig.fromMap(Map<String, dynamic> map) =>
      const AIConfig(provider: AIProvider.backend);
}
