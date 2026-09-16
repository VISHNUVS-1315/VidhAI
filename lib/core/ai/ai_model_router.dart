/// Client-side mirror of the backend model router.
///
/// Produces the same tier hints as the server-side [`chatWithRouter`] so the
/// UI can label which model answered or attach an explicit tier to a request
/// without needing the server to classify first.
library;

enum AiTier {
  main,
  general,
  fast,
  creative,
  vision,
  safety,
}

class AiModelRouter {
  AiModelRouter._();

  static const List<String> _complexWords = [
    'recommend',
    'plan',
    'compare',
    'why ',
    'should',
    ' best ',
    'analy',
    'strategy',
    'profit',
    'rotation',
    'disease',
    'pesticid',
    'yield',
    'forecast',
    'because',
    'how to',
    'what is the',
    'scheme',
    'subsid',
    'loan',
  ];

  static const List<String> _simpleWords = [
    'hi',
    'hello',
    'hey',
    'namaste',
    'open',
    'show',
    'weather',
    'price',
    'market',
    'task',
    'diary',
    'community',
    'home',
    'back',
    'help',
    'thanks',
    'thank',
    'ok',
    'yes',
    'no',
  ];

  /// Human-readable model names per tier (for diagnostics/UI labels only).
  /// All production AI tiers are served through NVIDIA NIM.
  static const Map<AiTier, String> tierNames = {
    AiTier.main: 'Nemotron Ultra 550B',
    AiTier.general: 'Nemotron Lightning 30B',
    AiTier.fast: 'Nemotron Lightning 30B',
    AiTier.creative: 'Nemotron Ultra 550B',
    AiTier.vision: 'Nano Omni 30B',
    AiTier.safety: 'Content Safety',
  };

  /// Wire model IDs per tier (mirrors the backend config; the backend remains
  /// authoritative and env-configurable).
  static const Map<AiTier, String> tierModels = {
    AiTier.main: 'nvidia/nemotron-3-ultra-550b-a55b',
    AiTier.general: 'nvidia/nemotron-3.5-lightning-30b-a3b',
    AiTier.fast: 'nvidia/nemotron-3.5-lightning-30b-a3b',
    AiTier.creative: 'nvidia/nemotron-3-ultra-550b-a55b',
    AiTier.vision: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning',
    AiTier.safety: 'nvidia/nemotron-3.5-content-safety',
  };

  /// Chat tiers the backend router accepts for /ai/chat.
  static const Set<AiTier> chatTiers = {
    AiTier.main,
    AiTier.general,
    AiTier.fast,
    AiTier.creative,
  };

  /// Wire name sent to the backend for a chat tier hint.
  static String wireName(AiTier tier) {
    switch (tier) {
      case AiTier.main:
        return 'main';
      case AiTier.general:
        return 'general';
      case AiTier.fast:
        return 'fast';
      case AiTier.creative:
        return 'creative';
      case AiTier.vision:
        return 'vision';
      case AiTier.safety:
        return 'safety';
    }
  }

  /// Deterministic, dependency-free routing hint mirroring the backend's
  /// rule classifier. Returns chat tiers (main/general/fast/creative).
  static AiTier tierForHint(
    String text, {
    String? complexity,
    String? intent,
  }) {
    final trimmed = text.trim();
    if (intent == 'complex_query' || complexity == 'high') return AiTier.main;
    final lower = ' $trimmed '.toLowerCase();
    final len = trimmed.length;
    if (_complexWords.any(lower.contains) || len > 220) return AiTier.main;
    if (_simpleWords.any(lower.contains) && len < 60) return AiTier.fast;
    return len < 80 ? AiTier.fast : AiTier.general;
  }
}