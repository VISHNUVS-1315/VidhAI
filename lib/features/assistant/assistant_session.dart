import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../locale/locale.dart';
import '../../models/ai/ai_message.dart';
import '../../models/ai/ai_tool_call.dart';
import '../../services/data_service.dart';
import '../../services/ai/ai_chat_brain.dart';
import '../../services/ai/secure_api_client.dart';
import '../../services/ai/tts_service.dart';
import '../../tools/ai_tool.dart';
import 'assistant_field_registry.dart';
import 'voice_turn_recorder.dart';

enum AssistantPhase { idle, listening, thinking, executing, speaking, error }

enum AssistantErrorKind { offline, auth, generic }

/// Confirmation surfaced for a destructive/save action.
class AssistantConfirmation {
  final String screen;
  final String action;
  final Map<String, dynamic> args;
  final String summary;

  /// Localized labels; when null the overlay uses its generic defaults
  /// (Confirm / Cancel).
  final String? confirmLabel;
  final String? cancelLabel;

  const AssistantConfirmation({
    required this.screen,
    required this.action,
    required this.args,
    required this.summary,
    this.confirmLabel,
    this.cancelLabel,
  });
}

/// The VidhAI Assistant: a contextual, always-on overlay assistant that works
/// on top of the current screen (it never navigates to AI Chat). It reuses the
/// secure NVIDIA brain, on-device speech input/output and safe app tools
/// registry, so everything is real — never faked.
///
/// Each turn is fully user-controlled: after the short voice greeting the
/// assistant keeps accumulating the spoken transcript and stays listening until
/// the farmer presses ✓ (finalize → one AI query) or X (cancel).
class AssistantSession extends ChangeNotifier {
  AssistantSession._();
  static final AssistantSession instance = AssistantSession._();

  static const int _maxToolRounds = 4;
  static const int _maxTurnsPerSession = 6;

  final VoiceTurnRecorder _turn = VoiceTurnRecorder();
  final TtsService _tts = TtsService.instance;
  final DataService _data = DataService();
  final AssistantFieldRegistry _registry = AssistantFieldRegistry.instance;

  /// Process-lifetime flag so the Home "first entry" welcome only ever happens
  /// once per app launch — even if the user leaves Home and returns.
  static bool _welcomeConsumed = false;

  bool _open = false;
  bool _busy = false;
  bool _autoContinue = false;
  bool _welcomeBack = false;
  bool _turnDone = false;
  String _screenName = '';
  String? _targetFarmId;
  String _language = 'en';
  int _turnsUsed = 0;

  final List<AIMessage> _history = [];

  AssistantPhase _phase = AssistantPhase.idle;
  AssistantErrorKind? _errorKind;
  AssistantConfirmation? _pending;
  String _transcript = '';
  String _reply = '';

  bool get isOpen => _open;
  bool get autoContinue => _autoContinue;
  bool get isListening => _phase == AssistantPhase.listening;
  bool get isSpeaking => _phase == AssistantPhase.speaking;
  String get screenName => _screenName;
  String get language => _language;
  AssistantPhase get phase => _phase;
  AssistantErrorKind? get errorKind => _errorKind;
  AssistantConfirmation? get pending => _pending;
  String get transcript => _transcript;
  String get reply => _reply;

  /// Live mic amplitude (0..1) for the wave animation while listening.
  Stream<double> get amplitudeStream => _turn.amplitude;

  /// Returns true exactly once per app process, so the Home screen can trigger
  /// the first-entry welcome without repeating it on Home→Farm→Home.
  static bool consumeWelcomeOnce() {
    if (_welcomeConsumed) return false;
    _welcomeConsumed = true;
    return true;
  }

  /// Opens the assistant over the current screen. Greets briefly in the
  /// selected language (with voice), then starts listening so the farmer can
  /// just talk. [welcomeBack] selects the "Welcome back to VidhAI" variant
  /// used only for the first Home entry.
  Future<void> open(String screen,
      {String? targetFarmId, bool welcomeBack = false}) async {
    if (_open) return;
    _screenName = screen;
    _targetFarmId = targetFarmId ?? '';
    _welcomeBack = welcomeBack;
    _history.clear();
    _pending = null;
    _phase = AssistantPhase.idle;
    _transcript = '';
    _reply = '';
    _errorKind = null;
    _busy = false;
    _language = await _data.getSelectedLanguage();
    _turnsUsed = 0;
    _open = true;
    notifyListeners();
    unawaited(_greetAndListen());
  }

  Future<void> close() async {
    _turnDone = true;
    await _turn.cancel();
    await _tts.stop();
    _open = false;
    _busy = false;
    _phase = AssistantPhase.idle;
    _pending = null;
    _history.clear();
    _turnsUsed = 0;
    _transcript = '';
    _reply = '';
    notifyListeners();
  }

  void toggleAutoContinue() {
    _autoContinue = !_autoContinue;
    notifyListeners();
  }

  /// Starts a new listening turn (uses the mic button / orb tap).
  Future<void> startListening() async {
    await _tts.stop();
    if (_busy) return;
    await _beginListeningTurn();
  }

  /// X / cancel: stops the microphone and recognition, drops the temporary
  /// transcript and returns to idle. The overlay then closes on top of the
  /// unchanged underlying screen.
  Future<void> cancelTurn() async {
    _turnDone = true;
    await _tts.stop();
    await _turn.cancel();
    _busy = false;
    _phase = AssistantPhase.idle;
    _transcript = '';
    notifyListeners();
  }

  /// ✓ / confirm: stops the microphone, finalises the accumulated transcript
  /// into ONE query and sends it to the real AI brain (with tools). The answer
  /// is shown and spoken. Listening only resumes when the user starts another
  /// turn (or auto-continue is on).
  Future<void> confirmTurn() async {
    if (!_busy || _turnDone) return;
    _turnDone = true;
    final input = await _turn.finish();
    await _tts.stop();
    if (!_open) return;
    if (input.trim().isEmpty) {
      _busy = false;
      _poseError(AssistantErrorKind.generic);
      return;
    }
    _transcript = input.trim();
    notifyListeners();

    _turnsUsed++;
    if (_turnsUsed > _maxTurnsPerSession) {
      _busy = false;
      _autoContinue = false;
      _reply = AppLocalizations(_language).assistantLimit;
      await _speak(reply: _reply);
      return;
    }

    _setPhase(AssistantPhase.thinking);
    final ok = await _runTurn(input.trim());
    if (!ok) return;
    if (_pending != null) {
      _busy = false;
      return;
    }
    _busy = false;
    await _speak(reply: _reply);
  }

  Future<void> _greetAndListen() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!_open) return;
    _busy = false;
    final greeting = await _greetingFor();
    _reply = greeting;
    _transcript = '';
    _setPhase(AssistantPhase.speaking);
    await _tts.speak(greeting, language: _language);
    if (!_open) return;
    _busy = false;
    await _beginListeningTurn();
  }

  Future<String> _greetingFor() async {
    final loc = AppLocalizations(_language);
    if (_welcomeBack) {
      try {
        final profile = await _data.loadCachedProfile();
        final name = (profile?.displayName ?? '').trim();
        if (name.isNotEmpty) {
          final firstName = name.split(RegExp(r'\s+')).first;
          return loc.assistantWelcomeBackNamed(firstName);
        }
      } catch (_) {}
      return loc.assistantWelcomeBack;
    }
    return loc.assistantWelcome;
  }

  Future<void> _beginListeningTurn() async {
    if (_busy || !_open) return;
    await _tts.stop();
    _busy = true;
    _turnDone = false;
    _transcript = '';
    _reply = '';
    _pending = null;
    _errorKind = null;
    notifyListeners();

    final online = await ConnectivityService.hasInternetConnection();
    if (!online) {
      _poseError(AssistantErrorKind.offline);
      return;
    }

    _turn.onText = (text) {
      if (!_open) return;
      _transcript = text;
      notifyListeners();
    };
    _turn.onListening = (listening) {
      if (!_open) return;
      if (listening && _phase != AssistantPhase.thinking) {
        _setPhase(AssistantPhase.listening);
      }
    };

    _setPhase(AssistantPhase.listening);
    final started = await _turn.start(_language);
    if (!started) {
      _poseError(AssistantErrorKind.generic);
    }
  }

  /// Runs one full tool-aware turn against the real brain and tools.
  /// Returns false on failure (error already posed).
  Future<bool> _runTurn(String input) async {
    final online = await ConnectivityService.hasInternetConnection();
    if (!online) {
      _poseError(AssistantErrorKind.offline);
      return false;
    }

    final profileMap = (await _data.loadCachedProfile())?.toMap() ?? const {};
    final farms = (await _data.loadFarms()).take(5).toList();
    final farmsMap = farms.map((f) => f.toMap()).toList();

    final targetFarmId =
        (_targetFarmId?.isNotEmpty ?? false) ? _targetFarmId! : null;
    final currentFarm =
        farms.where((f) => f.farmId == targetFarmId).firstOrNull ??
            (farms.isNotEmpty ? farms.first : null);
    final location = currentFarm?.farmLocation;

    _history.add(AIMessage.user(input));

    final messages = _history.toList();

    final contextJson = {
      'userProfile': profileMap,
      'farms': farmsMap,
      'source': 'assistant',
      'currentScreen': _screenName,
      'selectedLanguage': _language,
      if (targetFarmId != null) 'targetFarmId': targetFarmId,
      if (currentFarm != null) 'currentFarmId': currentFarm.farmId,
      if (currentFarm != null && currentFarm.farmName.isNotEmpty)
        'currentFarmName': currentFarm.farmName,
      if (location != null)
        'currentFarmLocation': {
          if (location.fullAddress.isNotEmpty)
            'fullAddress': location.fullAddress,
          if (location.district != null) 'district': location.district,
          if (location.state != null) 'state': location.state,
        },
      'formFields': _registry.fieldsFor(_screenName),
      'actions': _registry.actionsFor(_screenName),
    };

    try {
      for (var round = 0; round < _maxToolRounds; round++) {
        final result = await AiChatBrain.chat(
          messages: messages,
          language: _language,
          context: contextJson,
          tools: VidhAIToolRegistry.instance.aiSpecs(),
        );

        if (!result.success) {
          _poseError(AssistantErrorKind.generic);
          return false;
        }

        if (!result.wantsToolCalls) {
          final content = result.content.trim();
          if (content.isEmpty) {
            _poseError(AssistantErrorKind.generic);
            return false;
          }
          _history.add(AIMessage.assistant(content));
          _reply = content;
          _setPhase(AssistantPhase.idle);
          return true;
        }

        _setPhase(AssistantPhase.executing);

        messages.add(AIMessage(
          role: 'assistant',
          content: '',
          toolCalls: result.toolCalls
              .map((t) => AIToolCall(
                  id: t.id, name: t.functionName, arguments: t.arguments))
              .toList(),
        ));

        for (final call in result.toolCalls) {
          final tool = VidhAIToolRegistry.instance.get(call.functionName);
          Object? output;
          if (tool == null) {
            output = {'error': 'Tool "${call.functionName}" is not available.'};
          } else {
            try {
              output = await tool.execute(call.arguments);
            } catch (_) {
              output = {'error': 'Tool execution failed.'};
            }
          }

          if (output is Map<String, dynamic> &&
              output['needsConfirmation'] == true) {
            final loc = AppLocalizations(_language);
            final confirmKey = (output['confirmLabelKey'] as String?) ?? '';
            final cancelKey = (output['cancelLabelKey'] as String?) ?? '';
            _pending = AssistantConfirmation(
              screen: (output['screen'] ?? _screenName).toString(),
              action: (output['action'] ?? '').toString(),
              args: (output['args'] is Map)
                  ? Map<String, dynamic>.from(output['args'] as Map)
                  : call.arguments,
              summary: (output['summary'] ?? '').toString(),
              confirmLabel: _resolveLabel(confirmKey, loc),
              cancelLabel: _resolveLabel(cancelKey, loc),
            );
            messages.add(AIMessage.fromToolResult(
                call.id, jsonEncode({'needsConfirmation': true})));
            _reply = loc.assistantConfirmPrompt
                .replaceAll('{summary}', _pending!.summary);
            _history.add(AIMessage.assistant(_reply));
            _setPhase(AssistantPhase.idle);
            return true;
          }

          messages.add(AIMessage.fromToolResult(call.id, jsonEncode(output)));
        }
      }

      _poseError(AssistantErrorKind.generic);
      return false;
    } on SecureApiException catch (e) {
      if (e.message.contains('Not signed in')) {
        _poseError(AssistantErrorKind.auth);
      } else {
        _poseError(AssistantErrorKind.generic);
      }
      return false;
    } catch (_) {
      _poseError(AssistantErrorKind.generic);
      return false;
    }
  }

  static String? _resolveLabel(String key, AppLocalizations loc) {
    return switch (key) {
      'save' => loc.save,
      'review' => loc.assistantReview,
      'cancel' => loc.cancel,
      'assistant_confirm' => loc.assistantConfirm,
      _ => null,
    };
  }

  /// Runs the confirmed action for real, then continues the loop.
  Future<void> confirmPending() async {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    _setPhase(AssistantPhase.executing);
    final result = await _registry.runAction(
      p.screen,
      action: p.action,
      args: p.args,
      confirmed: true,
      language: _language,
    );
    final ok = result['error'] == null;
    _history.clear();
    final loc = AppLocalizations(_language);
    _reply = ok
        ? loc.assistantDone.replaceAll('{summary}', p.summary)
        : loc.assistantFailed
            .replaceAll('{error}', result['error']?.toString() ?? '');
    _setPhase(AssistantPhase.idle);
    notifyListeners();
    await _speak(reply: _reply);
  }

  Future<void> cancelPending() async {
    _pending = null;
    _history.clear();
    final loc = AppLocalizations(_language);
    _reply = loc.assistantCancelled;
    _setPhase(AssistantPhase.idle);
    notifyListeners();
    await _speak(reply: _reply);
  }

  Future<void> _speak({required String reply}) async {
    if (!_open || reply.trim().isEmpty) return;
    _busy = false;
    _setPhase(AssistantPhase.speaking);
    await _tts.speak(reply, language: _language);
    if (!_open) return;
    _setPhase(AssistantPhase.idle);
    if (_autoContinue) {
      await Future.delayed(const Duration(milliseconds: 400));
      _busy = false;
      if (_open) await _beginListeningTurn();
    }
  }

  void _poseError(AssistantErrorKind kind) {
    _busy = false;
    _errorKind = kind;
    debugPrint(
        '[VidhAI] assistant error kind=$kind screen=$_screenName'); // SAFE: no secrets
    _setPhase(AssistantPhase.error);
  }

  void _setPhase(AssistantPhase phase) {
    _phase = phase;
    notifyListeners();
  }
}
