import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:vidhai/services/ai/ai_orchestrator.dart';
import 'package:vidhai/services/ai/voice_conversation_controller.dart';
import 'package:vidhai/services/ai/voice_output_service.dart';
import 'package:vidhai/services/ai/device_speech_service.dart';

class FakeCapturer implements VoiceCapturer {
  final StreamController<double> _amp = StreamController<double>.broadcast();
  final StreamController<String> _text = StreamController<String>.broadcast();
  bool permission = true;
  bool startOk = true;
  VoiceCaptureResult nextResult = const VoiceCaptureResult();
  int startCount = 0;
  int transcribedCount = 0;
  int cancelCount = 0;
  String? languageUsed;

  @override
  Stream<double> get onAmplitude => _amp.stream;

  @override
  Stream<String> get onTranscript => _text.stream;

  @override
  Future<bool> get isRecording async => false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> startRecording({String? language}) async {
    languageUsed = language;
    startCount++;
    return startOk;
  }

  @override
  Future<VoiceCaptureResult> stopAndTranscribe({String? language}) async {
    transcribedCount++;
    languageUsed = language;
    return nextResult;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  void emit(double db) => _amp.add(db);

  Future<void> dispose() async {
    await _amp.close();
    await _text.close();
  }
}

class FakeSynth implements VoiceSynthesizer {
  final StreamController<bool> _events = StreamController<bool>.broadcast();
  final List<String> spoken = [];
  @override
  String activeBackend = 'deviceTts';
  bool accept = true;
  int stopCount = 0;
  String? languageUsed;
  bool _speaking = false;

  @override
  String get name => 'fakeSynth';

  @override
  bool get speaking => _speaking;

  @override
  Stream<bool> get speakingChanges => _events.stream;

  @override
  Future<bool> speak(String text, {String? language}) async {
    spoken.add(text);
    languageUsed = language;
    if (accept) {
      _speaking = true;
      _events.add(true);
      return true;
    }
    return false;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _speaking = false;
    if (!_events.isClosed) _events.add(false);
  }

  Future<void> finishSpeaking() async {
    _speaking = false;
    if (!_events.isClosed) _events.add(false);
  }

  Future<void> dispose() async => _events.close();
}

Future<AiOrchestratorReply> okAsk({
  required String input,
  required String language,
}) async =>
    const AiOrchestratorReply.text('Great, I can help with that!');

void main() {
  Future<void> wait([int ms = 180]) =>
      Future.delayed(Duration(milliseconds: ms));

  ({
    VoiceConversationController controller,
    FakeCapturer capturer,
    FakeSynth synth
  }) build({
    bool bargeInEnabled = true,
    VoiceAsk? ask,
    Future<bool> Function()? hasConnection,
  }) {
    final capturer = FakeCapturer()
      ..nextResult = const VoiceCaptureResult(
          success: true, text: 'good morning', provider: 'device-speech');
    final synth = FakeSynth();
    final controller = VoiceConversationController(
      capturer: capturer,
      synthesizer: synth,
      getLanguage: () async => 'en',
      ask: ask ?? okAsk,
      hasInternetConnection: hasConnection ?? () async => true,
      silenceAutoEnd: const Duration(milliseconds: 60),
      minHold: const Duration(milliseconds: 20),
      maxClip: const Duration(milliseconds: 400),
      speechDb: -30,
      bargeInEnabled: bargeInEnabled,
      bargeInDb: -28,
      bargeInHold: const Duration(milliseconds: 50),
      bargeInIgnoreWindow: const Duration(milliseconds: 40),
    );
    return (controller: controller, capturer: capturer, synth: synth);
  }

  /// Deterministic "user speaks then goes silent": the first silence tick marks
  /// the pause, the second (after > silenceAutoEnd) finalises the turn.
  Future<void> speakThenPause(FakeCapturer capturer) async {
    await wait(30);
    capturer.emit(-15); // speech
    await wait(50);
    capturer.emit(-120); // silence begins
    await wait(80); // longer than silenceAutoEnd (60)
    capturer.emit(-120); // → auto-end finalises the turn
    await wait(50); // transcription → thinking → reply spoken
  }

  /// Full happy-path turn: speak → silence → AI answer spoken → audio ends.
  Future<void> completeOneTurn(FakeCapturer capturer, FakeSynth synth) async {
    await speakThenPause(capturer);
    await synth.finishSpeaking();
    await wait(30);
  }

  group('listening', () {
    test('auto-ends a turn on silence, answers, and auto-continues', () async {
      final t = build();
      await t.controller.start();
      await completeOneTurn(t.capturer, t.synth);

      expect(t.capturer.transcribedCount, 1);
      expect(t.capturer.languageUsed, 'en');
      expect(t.capturer.startCount, 1);
      expect(t.synth.spoken, ['Great, I can help with that!']);
      expect(t.controller.turns.length, 1);

      // Auto-continue: loop re-listens after the inter-turn gap.
      await wait(700);
      expect(t.controller.phase, VoiceConversationPhase.listening);
      expect(t.capturer.startCount, greaterThanOrEqualTo(2));

      await t.controller.stop();
      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('caps a silent recording at maxClip and surfaces an error', () async {
      final t = build();
      t.capturer.nextResult =
          const VoiceCaptureResult(error: 'Could not understand the audio.');
      await t.controller.start();
      await wait(60); // listener subscribed, no speech emitted

      // Only silence → no auto-end; recording must close via maxClip.
      await wait(500);
      expect(t.capturer.transcribedCount, 1);
      expect(t.controller.error, VoiceConversationError.generic);
      expect(t.controller.errorDetail, 'Could not understand the audio.');
      expect(t.controller.phase, VoiceConversationPhase.error);
      expect(t.controller.running, isFalse);

      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('reports input unavailable when mic permission is denied', () async {
      final t = build();
      t.capturer.permission = false;
      await t.controller.start();
      await wait(80);
      expect(t.controller.error, VoiceConversationError.inputUnavailable);
      expect(t.controller.phase, VoiceConversationPhase.error);
      expect(t.controller.running, isFalse);
      expect(t.capturer.startCount, 0);

      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('surfaces offline when there is no connection', () async {
      final t = build(hasConnection: () async => false);
      await t.controller.start();
      await wait(80);
      expect(t.controller.error, VoiceConversationError.offline);
      expect(t.controller.phase, VoiceConversationPhase.error);
      expect(t.capturer.startCount, 0);

      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });
  });

  group('answering', () {
    test('records turn history with STT + TTS provider routing', () async {
      final t = build();
      t.capturer.nextResult = const VoiceCaptureResult(
          success: true, text: 'tomato price', provider: 'device-speech');
      await t.controller.start();
      await completeOneTurn(t.capturer, t.synth);

      expect(t.controller.lastSttProvider, 'device-speech');
      expect(t.controller.lastTtsBackend, 'deviceTts');
      final turn = t.controller.turns.single;
      expect(turn.userText, 'tomato price');
      expect(turn.reply, 'Great, I can help with that!');
      expect(turn.sttProvider, 'device-speech');
      expect(turn.ttsBackend, 'deviceTts');

      await t.controller.stop();
      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('accrues multiple turns in one session', () async {
      final t = build();
      await t.controller.start();
      await completeOneTurn(t.capturer, t.synth);
      expect(t.controller.turns.length, 1);

      // Let the auto-continue gap elapse so the loop is listening again.
      await wait(650);
      await completeOneTurn(t.capturer, t.synth);

      expect(t.controller.turns.length, 2);
      expect(t.capturer.transcribedCount, 2);

      await t.controller.stop();
      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('surfaces the brain auth error', () async {
      final t = build(
          ask: ({required String input, required String language}) async =>
              const AiOrchestratorReply.error(AiErrorKind.auth));
      await t.controller.start();
      await speakThenPause(t.capturer);
      expect(t.controller.error, VoiceConversationError.auth);
      expect(t.controller.phase, VoiceConversationPhase.error);

      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('surfaces the brain generic error on an empty transcript', () async {
      final t = build();
      t.capturer.nextResult =
          const VoiceCaptureResult(error: 'Recording was empty.');
      await t.controller.start();
      await speakThenPause(t.capturer);
      expect(t.controller.error, VoiceConversationError.generic);
      expect(t.controller.errorDetail, 'Recording was empty.');
      expect(t.controller.phase, VoiceConversationPhase.error);

      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });
  });

  group('loop & barge-in', () {
    test('stays idle after one turn when auto-continue is off', () async {
      final t = build();
      t.controller.toggleAutoContinue(); // defaults on → off
      expect(t.controller.autoContinue, isFalse);
      await t.controller.start();
      await completeOneTurn(t.capturer, t.synth);
      await wait(700); // gap would normally re-listen; must not

      expect(t.controller.phase, VoiceConversationPhase.idle);
      expect(t.capturer.startCount, 1);
      expect(t.controller.running, isTrue);

      await t.controller.stop();
      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('barge-in interrupts assistant speech and keeps talking', () async {
      final t = build();
      await t.controller.start();
      await speakThenPause(t.capturer);
      expect(t.controller.phase, VoiceConversationPhase.speaking);
      expect(t.synth.spoken, isNotEmpty);

      // User starts talking over the assistant.
      for (var i = 0; i < 6; i++) {
        t.capturer.emit(-20); // loud enough for barge-in
        await wait(25);
      }
      await wait(60);

      // Assistant stopped; auto-continue falls back to listening.
      expect(t.synth.stopCount, greaterThanOrEqualTo(1));
      await wait(650);
      expect(t.controller.phase, VoiceConversationPhase.listening);
      expect(t.capturer.startCount, greaterThanOrEqualTo(2));

      await t.controller.stop();
      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('does not barge in when disabled', () async {
      final t = build(bargeInEnabled: false);
      await t.controller.start();
      await speakThenPause(t.capturer);
      expect(t.controller.phase, VoiceConversationPhase.speaking);

      final stopsBefore = t.synth.stopCount;
      for (var i = 0; i < 6; i++) {
        t.capturer.emit(-20);
        await wait(25);
      }
      await wait(80);
      expect(t.synth.stopCount, stopsBefore); // no interruption
      expect(t.controller.phase, VoiceConversationPhase.speaking);

      await t.controller.stop();
      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('stop() halts listening mid-turn', () async {
      final t = build();
      await t.controller.start();
      await wait(60);
      expect(t.controller.phase, VoiceConversationPhase.listening);

      await t.controller.stop();
      expect(t.controller.running, isFalse);
      expect(t.controller.phase, VoiceConversationPhase.idle);
      expect(t.capturer.cancelCount, greaterThanOrEqualTo(1));

      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });

    test('reset() clears session history and diagnostics', () async {
      final t = build();
      await t.controller.start();
      await completeOneTurn(t.capturer, t.synth);
      expect(t.controller.turns.length, 1);

      t.controller.reset();
      expect(t.controller.turns, isEmpty);
      expect(t.controller.lastSttProvider, isNull);
      expect(t.controller.lastTtsBackend, 'none');

      await t.controller.stop();
      await t.capturer.dispose();
      await t.synth.dispose();
      t.controller.dispose();
    });
  });
}
