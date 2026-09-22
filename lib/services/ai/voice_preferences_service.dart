import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A user-facing AI voice style. The actual platform voice is resolved at
/// playback time for the selected app language, while rate/pitch keep each
/// profile recognisably different across Android/iOS devices.
class AiVoiceProfile {
  final String id;
  final String titleKey;
  final String subtitleKey;
  final double speechRate;
  final double pitch;
  final int voiceSlot;

  const AiVoiceProfile({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.speechRate,
    required this.pitch,
    required this.voiceSlot,
  });
}

class AiVoicePreferences extends ChangeNotifier {
  AiVoicePreferences._();
  static final AiVoicePreferences instance = AiVoicePreferences._();

  static const _prefKey = 'selected_ai_voice_profile';

  static const List<AiVoiceProfile> profiles = [
    AiVoiceProfile(
      id: 'natural',
      titleKey: 'ai_voice_natural',
      subtitleKey: 'ai_voice_natural_desc',
      speechRate: 0.48,
      pitch: 1.00,
      voiceSlot: 0,
    ),
    AiVoiceProfile(
      id: 'young_man',
      titleKey: 'ai_voice_young_man',
      subtitleKey: 'ai_voice_young_man_desc',
      speechRate: 0.52,
      pitch: 0.94,
      voiceSlot: 1,
    ),
    AiVoiceProfile(
      id: 'young_woman',
      titleKey: 'ai_voice_young_woman',
      subtitleKey: 'ai_voice_young_woman_desc',
      speechRate: 0.52,
      pitch: 1.08,
      voiceSlot: 2,
    ),
    AiVoiceProfile(
      id: 'calm_man',
      titleKey: 'ai_voice_calm_man',
      subtitleKey: 'ai_voice_calm_man_desc',
      speechRate: 0.44,
      pitch: 0.90,
      voiceSlot: 3,
    ),
    AiVoiceProfile(
      id: 'warm_woman',
      titleKey: 'ai_voice_warm_woman',
      subtitleKey: 'ai_voice_warm_woman_desc',
      speechRate: 0.46,
      pitch: 1.04,
      voiceSlot: 4,
    ),
    AiVoiceProfile(
      id: 'mature_man',
      titleKey: 'ai_voice_mature_man',
      subtitleKey: 'ai_voice_mature_man_desc',
      speechRate: 0.42,
      pitch: 0.86,
      voiceSlot: 5,
    ),
    AiVoiceProfile(
      id: 'mature_woman',
      titleKey: 'ai_voice_mature_woman',
      subtitleKey: 'ai_voice_mature_woman_desc',
      speechRate: 0.43,
      pitch: 0.98,
      voiceSlot: 6,
    ),
  ];

  bool _loaded = false;
  String _selectedId = 'natural';

  String get selectedId => _selectedId;

  AiVoiceProfile get selected => profiles.firstWhere(
        (p) => p.id == _selectedId,
        orElse: () => profiles.first,
      );

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && profiles.any((p) => p.id == saved)) {
      _selectedId = saved;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> select(String id) async {
    final profile = profiles.where((p) => p.id == id).firstOrNull;
    if (profile == null || profile.id == _selectedId) return;
    _selectedId = profile.id;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _selectedId);
    notifyListeners();
  }
}
