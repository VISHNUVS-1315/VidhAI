import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/vidhai_theme.dart';
import '../../services/ai/device_speech_service.dart';
import 'assistant_overlay.dart';
import 'assistant_session.dart';

/// Reusable futuristic Live AI entry point used across VidhAI screens.
///
/// The control reacts to the real assistant state (listening / thinking /
/// speaking), shows recognition confidence when the platform provides it and
/// opens the contextual assistant over the current screen instead of routing
/// the user away from their work.
class VidhAIAssistantButton extends StatefulWidget {
  final String screen;
  final String? targetFarmId;
  final double size;
  final double iconSize;

  const VidhAIAssistantButton({
    super.key,
    required this.screen,
    this.targetFarmId,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  State<VidhAIAssistantButton> createState() =>
      _VidhAIAssistantButtonState();
}

class _VidhAIAssistantButtonState extends State<VidhAIAssistantButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  StreamSubscription<double>? _confidenceSub;
  double? _confidence;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _confidenceSub = DeviceSpeechService.instance.onConfidence.listen((value) {
      if (!mounted || value <= 0) return;
      setState(() => _confidence = value.clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _confidenceSub?.cancel();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _openAssistant() async {
    final session = AssistantSession.instance;
    // Jarvis-style behaviour: after the assistant replies, it should be ready
    // for the next user turn without requiring a second tap.
    if (!session.autoContinue) session.toggleAutoContinue();
    await session.open(widget.screen, targetFarmId: widget.targetFarmId);
    if (!mounted) return;
    await showVidhAIAssistantOverlay(context);
  }

  Color _phaseColor(VidhAIColorsX colors, AssistantPhase phase) {
    return switch (phase) {
      AssistantPhase.listening => const Color(0xFF00D7FF),
      AssistantPhase.thinking => const Color(0xFFFFB020),
      AssistantPhase.executing => const Color(0xFF9B7CFF),
      AssistantPhase.speaking => const Color(0xFF4ADE80),
      AssistantPhase.error => colors.danger,
      AssistantPhase.idle => colors.brandDeep,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final session = AssistantSession.instance;

    return Semantics(
      button: true,
      label: 'VidhAI Live AI',
      child: GestureDetector(
        onTap: () => unawaited(_openAssistant()),
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, _) {
            return ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                final phase = session.phase;
                final phaseColor = _phaseColor(colors, phase);
                final active = session.isOpen && phase != AssistantPhase.idle;
                final confidence = _confidence;

                return SizedBox(
                  width: widget.size + 4,
                  height: widget.size + 4,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(widget.size * 0.3),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.surface,
                              phaseColor.withValues(alpha: active ? 0.16 : 0.07),
                            ],
                          ),
                          border: Border.all(
                            color: phaseColor.withValues(alpha: active ? 0.85 : 0.35),
                            width: active ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: phaseColor.withValues(
                                alpha: active ? 0.32 : 0.12,
                              ),
                              blurRadius: active ? 15 : 8,
                              spreadRadius: active ? 1 : 0,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _MiniIntelligencePainter(
                            progress: _spin.value,
                            color: phaseColor,
                            active: active,
                            amplitude: session.isListening ? 1 : 0.45,
                          ),
                        ),
                      ),
                      if (confidence != null && session.isOpen)
                        PositionedDirectional(
                          end: -5,
                          bottom: -4,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            height: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: phaseColor.withValues(alpha: 0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: phaseColor.withValues(alpha: 0.18),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Text(
                              '${(confidence * 100).round()}%',
                              maxLines: 1,
                              style: TextStyle(
                                color: phaseColor,
                                fontSize: 7,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Small "intelligence core" instead of a static sparkle icon. The rotating
/// orbital nodes make the assistant visibly alive even before the overlay is
/// opened, while the glow becomes stronger during an active voice turn.
class _MiniIntelligencePainter extends CustomPainter {
  const _MiniIntelligencePainter({
    required this.progress,
    required this.color,
    required this.active,
    required this.amplitude,
  });

  final double progress;
  final Color color;
  final bool active;
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    final coreRadius = shortest * (active ? 0.115 : 0.105);

    final glow = Paint()
      ..color = color.withValues(alpha: active ? 0.18 : 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(center, shortest * 0.23, glow);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..color = color.withValues(alpha: active ? 0.72 : 0.42);

    for (var i = 0; i < 2; i++) {
      final radius = shortest * (0.22 + i * 0.085);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final start = progress * math.pi * 2 + i * math.pi * 0.7;
      canvas.drawArc(rect, start, math.pi * (0.85 + i * 0.18), false, ringPaint);
    }

    final nodePaint = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final angle = progress * math.pi * 2 + (math.pi * 2 / 3) * i;
      final radius = shortest * (0.24 + 0.025 * math.sin(angle * 2));
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawCircle(point, active ? 1.8 : 1.35, nodePaint);
    }

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          color,
          color.withValues(alpha: 0.45),
        ],
      ).createShader(Rect.fromCircle(
        center: center,
        radius: coreRadius * (1 + amplitude * 0.16),
      ));
    canvas.drawCircle(
      center,
      coreRadius * (1 + amplitude * 0.16),
      corePaint,
    );

    final linkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = color.withValues(alpha: 0.5);
    for (var i = 0; i < 4; i++) {
      final angle = progress * math.pi * 2 * (i.isEven ? 1 : -1) + i;
      final point = Offset(
        center.dx + math.cos(angle) * shortest * 0.16,
        center.dy + math.sin(angle) * shortest * 0.16,
      );
      canvas.drawLine(center, point, linkPaint);
      canvas.drawCircle(point, 1.1, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniIntelligencePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.active != active ||
        oldDelegate.amplitude != amplitude;
  }
}
