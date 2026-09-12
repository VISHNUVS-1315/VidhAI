import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/vidhai_theme.dart';
import '../../../locale/locale.dart';
import '../../assistant/voice_turn_recorder.dart';

/// Shows a full voice-typing overlay for AI Chat. The farmer talks, sees the
/// live transcript accumulate, then presses ✓ to put the (combined) text into
/// the chat input for review — nothing is sent yet. X cancels and discards.
/// Returns the transcript string or null on cancel.
Future<String?> showVoiceTypingOverlay(
  BuildContext context, {
  required String language,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _VoiceTypingOverlay(language: language),
  );
}

class _VoiceTypingOverlay extends StatefulWidget {
  final String language;
  const _VoiceTypingOverlay({required this.language});

  @override
  State<_VoiceTypingOverlay> createState() => _VoiceTypingOverlayState();
}

class _VoiceTypingOverlayState extends State<_VoiceTypingOverlay> {
  final _turn = VoiceTurnRecorder();
  StreamSubscription<double>? _ampSub;
  final List<double> _levels = List.filled(60, 0.0);
  bool _started = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _turn.onText = (text) {
      if (mounted) setState(() {});
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    if (_started || !mounted) return;
    _started = true;
    _ampSub = _turn.amplitude.listen((db) {
      if (!mounted) return;
      final v = ((db + 50) / 44).clamp(0.0, 1.0).toDouble();
      setState(() {
        _levels
          ..removeAt(0)
          ..add(v);
      });
    }, onError: (_) {});
    final ok = await _turn.start(widget.language);
    if (!ok && mounted) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    await _ampSub?.cancel();
    final text = await _turn.finish();
    if (mounted) Navigator.of(context).pop(text);
  }

  Future<void> _cancel() async {
    if (_closing) return;
    _closing = true;
    await _ampSub?.cancel();
    await _turn.cancel();
    if (mounted) Navigator.of(context).pop(null);
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _turn.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final transcript = _turn.text;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.vidhaiAssistant,
              style: TextStyle(
                color: colors.onBackground,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              loc.listenNowInstruction,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            _buildWave(colors),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  transcript.isEmpty ? loc.listenNowListening : transcript,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: transcript.isEmpty
                        ? colors.onSurfaceMuted
                        : colors.onBackground,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _cancel,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.bg,
                      border: Border.all(
                        color: colors.danger.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: colors.danger, size: 26),
                  ),
                ),
                const SizedBox(width: 28),
                GestureDetector(
                  onTap: _finish,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF16A34A),
                          Colors.green,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWave(VidhAIColorsX colors) {
    return Container(
      height: 72,
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < _levels.length; i++)
                Container(
                  width: 3,
                  height: 4 + (_levels[i] * 60),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: colors.brandDeep.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
