import 'package:flutter/material.dart';

import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/ai/voice_conversation_controller.dart';

class LiveVoiceScreen extends StatefulWidget {
  final VoidCallback? onExit;

  const LiveVoiceScreen({super.key, this.onExit});

  @override
  State<LiveVoiceScreen> createState() => _LiveVoiceScreenState();
}

class _LiveVoiceScreenState extends State<LiveVoiceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final VoiceConversationController _controller = VoiceConversationController();

  Color get _accent => VidhAIColorsX(context).brandDeep;
  Color get _bgColor => VidhAIColorsX(context).bg;
  Color get _muted => VidhAIColorsX(context).onSurfaceMuted;
  Color get _text => VidhAIColorsX(context).onBackground;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _localizedError(VoiceConversationError? kind) {
    final loc = AppLocalizations.of(context);
    switch (kind) {
      case VoiceConversationError.offline:
        return loc.aiOffline;
      case VoiceConversationError.auth:
        return loc.aiAuthError;
      case VoiceConversationError.inputUnavailable:
        return loc.voiceInputNotAvailable;
      case VoiceConversationError.generic:
      case null:
        return loc.aiGenericError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final phase = _controller.phase;
            final transcript = _controller.transcript;
            final reply = _controller.reply;
            final error = _controller.error;
            return Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      onPressed:
                          widget.onExit ?? () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: _text, size: 24),
                      tooltip: loc.exitLiveVoice,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildOrb(phase),
                        const SizedBox(height: 28),
                        _buildPhaseLabel(phase, error),
                        const SizedBox(height: 18),
                        if (transcript.isNotEmpty) _buildTranscript(transcript),
                        if (reply.isNotEmpty) ..._buildReplySection(reply),
                        if (error != null) _buildError(error),
                        if (_controller.turns.isNotEmpty) _buildProviders(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildControls(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrb(VoiceConversationPhase phase) {
    final active = phase == VoiceConversationPhase.listening ||
        phase == VoiceConversationPhase.speaking;
    final color = switch (phase) {
      VoiceConversationPhase.listening => Colors.redAccent,
      VoiceConversationPhase.speaking => _accent,
      VoiceConversationPhase.thinking => Colors.orangeAccent,
      VoiceConversationPhase.error => Colors.redAccent.withValues(alpha: 0.6),
      VoiceConversationPhase.idle => _accent,
    };

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Container(
                  width: 220 * (0.6 + t * 0.4),
                  height: 220 * (0.6 + t * 0.4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15 * (1 - t)),
                  ),
                ),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  phase == VoiceConversationPhase.listening
                      ? Icons.mic_rounded
                      : phase == VoiceConversationPhase.speaking
                          ? Icons.graphic_eq_rounded
                          : phase == VoiceConversationPhase.thinking
                              ? Icons.auto_awesome_rounded
                              : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhaseLabel(
    VoiceConversationPhase phase,
    VoiceConversationError? error,
  ) {
    final loc = AppLocalizations.of(context);
    final label = switch (phase) {
      VoiceConversationPhase.idle => loc.aiVoiceTapToStart,
      VoiceConversationPhase.listening => loc.aiVoiceListening,
      VoiceConversationPhase.thinking => loc.aiVoiceThinking,
      VoiceConversationPhase.speaking => loc.aiVoiceSpeaking,
      VoiceConversationPhase.error => loc.aiVoiceError,
    };
    if (error != null && phase == VoiceConversationPhase.error) {
      return Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: _text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            _localizedError(error),
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      );
    }
    return Text(
      label,
      style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTranscript(String transcript) {
    return Container(
      width: double.maxFinite,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VidhAIColorsX(context).surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '"$transcript"',
        style: TextStyle(color: _text, fontSize: 14, height: 1.4),
      ),
    );
  }

  List<Widget> _buildReplySection(String reply) {
    return [
      Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          reply,
          style: TextStyle(color: _accent, fontSize: 14, height: 1.4),
        ),
      ),
      const SizedBox(height: 10),
    ];
  }

  Widget _buildError(VoiceConversationError error) {
    final detail = _controller.errorDetail;
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail ?? _localizedError(error),
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Provider routing diagnostics: which STT engine transcribed and which TTS
  /// backend spoke the last turn.
  Widget _buildProviders() {
    final stt = _controller.lastSttProvider;
    final tts = _controller.lastTtsBackend;
    final chips = <String>[
      if (stt != null && stt.isNotEmpty) 'STT: $stt',
      if (tts.isNotEmpty && tts != 'none') 'TTS: $tts',
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        chips.join('  ·  '),
        style: TextStyle(color: _muted, fontSize: 11),
      ),
    );
  }

  Widget _buildControls() {
    final running = _controller.running;
    final loc = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _controller.stop,
              icon: Icon(Icons.stop_circle_rounded, color: _muted, size: 32),
              tooltip: loc.stop,
            ),
            const SizedBox(width: 32),
            InkWell(
              onTap: running ? _controller.stop : _controller.start,
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.redAccent, _accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  running ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(width: 32),
            IconButton(
              onPressed: _controller.toggleAutoContinue,
              icon: Icon(
                _controller.autoContinue
                    ? Icons.loop_rounded
                    : Icons.repeat_on_rounded,
                color: _controller.autoContinue ? _accent : _muted,
                size: 28,
              ),
              tooltip: _controller.autoContinue
                  ? loc.autoContinueOn
                  : loc.autoContinueOff,
            ),
          ],
        ),
      ),
    );
  }
}
