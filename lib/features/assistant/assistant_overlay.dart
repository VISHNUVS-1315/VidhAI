import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/vidhai_theme.dart';
import '../../locale/locale.dart';
import 'assistant_session.dart';

/// Opens the VidhAI Assistant as an overlay on top of the current screen.
/// It is not a navigation route — the underlying screen stays mounted and
/// editable, which is what makes real form filling possible.
Future<void> showVidhAIAssistantOverlay(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'VidhAI Assistant',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) =>
        const _AssistantOverlayContent(),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _AssistantOverlayContent extends StatefulWidget {
  const _AssistantOverlayContent();

  @override
  State<_AssistantOverlayContent> createState() =>
      _AssistantOverlayContentState();
}

class _AssistantOverlayContentState extends State<_AssistantOverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  StreamSubscription<double>? _ampSub;
  double _amp = 0;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _ampSub = AssistantSession.instance.amplitudeStream.listen((db) {
      if (!mounted) return;
      setState(() {
        _amp = ((db + 55) / 45).clamp(0.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _wave.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await AssistantSession.instance.close();
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  /// X / Cancel: stops mic/STT/TTS, drops the current transcript, keeps the
  /// underlying screen untouched and closes the overlay.
  Future<void> _onCancel() async {
    final s = AssistantSession.instance;
    if (s.pending != null) {
      await s.cancelPending();
    }
    await s.cancelTurn();
    await _close();
  }

  /// ✓ / Confirm: finalises the current voice turn into ONE query. When idle
  /// it starts the next turn; when a Save/Review confirmation is pending it
  /// confirms that action.
  Future<void> _onConfirm() async {
    final s = AssistantSession.instance;
    if (s.pending != null) {
      await s.confirmPending();
      return;
    }
    if (s.isListening) {
      await s.confirmTurn();
      return;
    }
    if (s.phase == AssistantPhase.idle || s.phase == AssistantPhase.error) {
      await s.startListening();
    }
  }

  Color _phaseColor(AssistantPhase phase) {
    final colors = VidhAIColorsX(context);
    return switch (phase) {
      AssistantPhase.listening => Colors.redAccent,
      AssistantPhase.thinking => Colors.orangeAccent,
      AssistantPhase.executing => Colors.orangeAccent,
      AssistantPhase.speaking => colors.brandDeep,
      AssistantPhase.error => colors.danger,
      AssistantPhase.idle => colors.brandDeep,
    };
  }

  String _phaseLabel(
      AssistantPhase phase, AssistantErrorKind? error, AppLocalizations loc) {
    if (phase == AssistantPhase.error) {
      return switch (error) {
        AssistantErrorKind.offline => loc.aiOffline,
        AssistantErrorKind.auth => loc.aiAuthError,
        _ => loc.aiVoiceError,
      };
    }
    return switch (phase) {
      AssistantPhase.idle => loc.aiVoiceTapToStart,
      AssistantPhase.listening => loc.aiVoiceListening,
      AssistantPhase.thinking => loc.aiVoiceThinking,
      AssistantPhase.executing => loc.aiVoiceThinking,
      AssistantPhase.speaking => loc.aiVoiceSpeaking,
      AssistantPhase.error => loc.aiVoiceError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => _close(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: AnimatedBuilder(
                animation: AssistantSession.instance,
                builder: (context, _) {
                  final session = AssistantSession.instance;
                  final phase = session.phase;
                  final color = _phaseColor(phase);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: 320,
                        constraints: const BoxConstraints(maxHeight: 560),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: color.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 44,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: color.withValues(alpha: 0.14),
                              blurRadius: 28,
                              spreadRadius: -6,
                            ),
                          ],
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.06),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: colors.brandDeep
                                          .withValues(alpha: 0.13),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.auto_awesome_rounded,
                                        color: colors.brandDeep, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      loc.vidhaiAssistant,
                                      style: TextStyle(
                                        color: colors.onBackground,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _close,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: colors.bg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.close_rounded,
                                          color: colors.onSurfaceMuted,
                                          size: 20),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              GestureDetector(
                                onTap: () {
                                  if (phase == AssistantPhase.idle ||
                                      phase == AssistantPhase.error) {
                                    AssistantSession.instance.startListening();
                                  }
                                },
                                child: _WaveOrb(
                                  phase: phase,
                                  color: color,
                                  amplitude: _amp,
                                  progress: _wave,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color,
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.55),
                                          blurRadius: 7,
                                          spreadRadius:
                                              phase == AssistantPhase.listening
                                                  ? 3
                                                  : 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _phaseLabel(
                                          phase, session.errorKind, loc),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colors.onBackground,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (session.transcript.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildChip(
                                  colors,
                                  Icons.mic_rounded,
                                  session.transcript,
                                  colors.brandDeep.withValues(alpha: 0.08),
                                  textColor: colors.onBackground,
                                ),
                              ],
                              if (session.reply.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildChip(
                                  colors,
                                  Icons.assistant_rounded,
                                  session.reply,
                                  colors.brandDeep.withValues(alpha: 0.1),
                                  textColor: colors.brandDeep,
                                ),
                              ],
                              if (session.pending != null) ...[
                                const SizedBox(height: 12),
                                _buildConfirmation(session, loc, colors),
                              ] else ...[
                                const SizedBox(height: 16),
                                _buildControls(session, colors),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(
    VidhAIColorsX colors,
    IconData icon,
    String text,
    Color bg, {
    Color? textColor,
  }) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor ?? colors.brandDeep, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? colors.onBackground,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation(
    AssistantSession session,
    AppLocalizations loc,
    VidhAIColorsX colors,
  ) {
    final p = session.pending!;
    final isSave = p.confirmLabel != null;
    final backgroundColor = isSave ? colors.brandDeep : colors.danger;
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  isSave
                      ? Icons.saved_search_rounded
                      : Icons.warning_amber_rounded,
                  color: colors.warning,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.summary,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: session.cancelPending,
                child: Text(
                  p.cancelLabel ?? loc.cancel,
                  style: TextStyle(color: colors.onSurfaceMuted),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: session.confirmPending,
                style: FilledButton.styleFrom(
                  backgroundColor: backgroundColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  p.confirmLabel ?? loc.assistantConfirm,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(AssistantSession session, VidhAIColorsX colors) {
    final listening = session.isListening;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: session.toggleAutoContinue,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.borderColor),
            ),
            child: Icon(
              session.autoContinue
                  ? Icons.loop_rounded
                  : Icons.repeat_on_rounded,
              color: session.autoContinue
                  ? colors.brandDeep
                  : colors.onSurfaceMuted,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: _onCancel,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.bg,
              border: Border.all(color: colors.danger.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.close_rounded, color: colors.danger, size: 26),
          ),
        ),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: _onConfirm,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: listening
                    ? [Colors.green, const Color(0xFF16A34A)]
                    : [
                        colors.brandDeep,
                        colors.brandDeep.withValues(alpha: 0.78)
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: listening
                      ? const Color(0xFF16A34A).withValues(alpha: 0.35)
                      : colors.brandDeep.withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              listening ? Icons.check_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: listening ? 32 : 26,
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated wave orb: a center core with concentric rings that pulse gently,
/// and (while listening) swell in reaction to the real mic amplitude.
class _WaveOrb extends StatelessWidget {
  final AssistantPhase phase;
  final Color color;
  final double amplitude;
  final Animation<double> progress;

  const _WaveOrb({
    required this.phase,
    required this.color,
    required this.amplitude,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          return SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _WavePainter(
                color: color,
                phase: phase,
                amplitude: amplitude,
                t: progress.value,
              ),
              child: Center(
                child: Container(
                  width: 84,
                  height: 84,
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
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _iconFor(phase),
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(AssistantPhase phase) {
    return switch (phase) {
      AssistantPhase.listening => Icons.mic_rounded,
      AssistantPhase.thinking => Icons.auto_awesome_rounded,
      AssistantPhase.executing => Icons.auto_awesome_rounded,
      AssistantPhase.speaking => Icons.graphic_eq_rounded,
      AssistantPhase.error => Icons.error_outline_rounded,
      AssistantPhase.idle => Icons.mic_none_rounded,
    };
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  final AssistantPhase phase;
  final double amplitude;
  final double t;

  _WavePainter({
    required this.color,
    required this.phase,
    required this.amplitude,
    required this.t,
  });

  bool get _active =>
      phase == AssistantPhase.listening ||
      phase == AssistantPhase.speaking ||
      phase == AssistantPhase.thinking ||
      phase == AssistantPhase.executing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rings = _active ? 3 : 1;
    for (var i = 0; i < rings; i++) {
      final radius = _ringRadius(i, rings);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 - i * 0.7
        ..color = color.withValues(alpha: (0.5 - i * 0.13).clamp(0.05, 0.5));
      canvas.drawCircle(center, radius, paint);
    }
  }

  double _ringRadius(int i, int rings) {
    const base = 40.0;
    switch (phase) {
      case AssistantPhase.listening:
        return base + amplitude * 26 + i * 12;
      case AssistantPhase.speaking:
        return base +
            8 +
            6 * math.sin(math.pi * 2 * (t + i / rings)) +
            amplitude * 4;
      case AssistantPhase.thinking:
      case AssistantPhase.executing:
        return base + 6 + 5 * math.sin(math.pi * 2 * (t * 0.6 + i / rings));
      case AssistantPhase.error:
        return base + 5;
      case AssistantPhase.idle:
        return base + 5 * (0.5 + 0.5 * math.sin(math.pi * 2 * t));
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.amplitude != amplitude ||
      oldDelegate.color != color ||
      oldDelegate.t != t;
}
