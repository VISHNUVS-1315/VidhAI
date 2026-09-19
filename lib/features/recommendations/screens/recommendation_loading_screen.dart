import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/crop_backend_service.dart';
import 'package:vidhai/services/crop_recommendation_service.dart';
import 'package:vidhai/services/data_service.dart';

class RecommendationLoadingScreen extends StatefulWidget {
  final String? farmId;
  final CropSetupQuestionnaire? questionnaire;

  const RecommendationLoadingScreen({
    super.key,
    this.farmId,
    this.questionnaire,
  });

  @override
  State<RecommendationLoadingScreen> createState() =>
      _RecommendationLoadingScreenState();
}

class _RecommendationLoadingScreenState
    extends State<RecommendationLoadingScreen> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _leafController;

  Timer? _textTimer;
  int _currentTextIndex = 0;
  bool _running = false;
  String? _error;

  VidhAIColorsX get colors => VidhAIColorsX(context);

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _leafController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _textTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted || !_running) return;
      setState(() => _currentTextIndex = (_currentTextIndex + 1) % 5);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _analyse());
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _leafController.dispose();
    _textTimer?.cancel();
    super.dispose();
  }

  Future<void> _analyse() async {
    if (_running) return;

    final questionnaire = widget.questionnaire;
    final farmId = widget.farmId?.trim() ?? '';
    if (questionnaire == null || farmId.isEmpty) {
      setState(() => _error = 'invalid_input');
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _currentTextIndex = 0;
    });

    try {
      final farms = await DataService().loadFarms();
      FarmProfile? farm;
      for (final item in farms) {
        if (item.farmId == farmId) {
          farm = item;
          break;
        }
      }
      if (farm == null) {
        throw StateError('farm_not_found');
      }

      final results =
          await CropRecommendationService.instance.getRecommendations(
        farm: farm,
        questionnaire: questionnaire,
      );

      if (!mounted) return;
      if (results.isEmpty) {
        setState(() {
          _running = false;
          _error = 'no_results';
        });
        return;
      }

      Navigator.of(context).pushReplacementNamed(
        '/crop_recommendation',
        arguments: {
          'farm': farm,
          'farmId': farmId,
          'questionnaire': questionnaire,
          'preloadedResults': results,
          'wasOnline': CropBackendService.instance.wasLastCallOnline,
        },
      );
    } catch (e) {
      debugPrint('[RecommendationLoadingScreen] analysis failed: $e');
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final loadingTexts = <String>[
      loc.t('rec_loading_soil'),
      loc.t('rec_loading_weather'),
      loc.t('rec_loading_market'),
      loc.t('rec_loading_crops'),
      loc.t('loading_text_4'),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: _error == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) => Transform.scale(
                          scale: 0.92 + (_pulseController.value * 0.16),
                          child: child,
                        ),
                        child: AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) => Transform.rotate(
                            angle: _rotationController.value * 2 * pi,
                            child: child,
                          ),
                          child: CustomPaint(
                            size: const Size(142, 142),
                            painter: _AgricultureLoaderPainter(
                              leafPhase: _leafController.value,
                              brandColor: colors.brandDeep,
                              surfaceColor: colors.surface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 42),
                      Text(
                        loc.t('rec_loading_heading'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          loadingTexts[_currentTextIndex],
                          key: ValueKey(_currentTextIndex),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.brandDeep,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          backgroundColor: colors.surface,
                          color: colors.brandDeep,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc.t('cp_ai_note'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  )
                : _buildError(loc),
          ),
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations loc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.refresh_rounded,
            color: colors.warning,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          loc.t('cp_empty'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          loc.errorFallback,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceMuted,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _analyse,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(loc.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brandDeep,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            loc.cancel,
            style: TextStyle(color: colors.onSurfaceMuted),
          ),
        ),
      ],
    );
  }
}

class _AgricultureLoaderPainter extends CustomPainter {
  final double leafPhase;
  final Color brandColor;
  final Color surfaceColor;

  _AgricultureLoaderPainter({
    required this.leafPhase,
    required this.brandColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.fill,
    );

    final ringPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 8, ringPaint);

    final accentPaint = Paint()
      ..color = brandColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -pi / 2,
      2 * pi * 0.35,
      false,
      accentPaint,
    );

    final stemPaint = Paint()
      ..color = brandColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy + 20),
      Offset(center.dx, center.dy - 18),
      stemPaint,
    );

    final leafPaint = Paint()
      ..color = brandColor
      ..style = PaintingStyle.fill;
    final leafOffset = 4.0 * sin(leafPhase * pi);

    final leftLeaf = Path()
      ..moveTo(center.dx, center.dy - 8)
      ..quadraticBezierTo(
        center.dx - 22 - leafOffset,
        center.dy - 22,
        center.dx - 6,
        center.dy - 30,
      )
      ..quadraticBezierTo(
        center.dx - 2,
        center.dy - 16,
        center.dx,
        center.dy - 8,
      );
    canvas.drawPath(leftLeaf, leafPaint);

    final rightLeaf = Path()
      ..moveTo(center.dx, center.dy - 12)
      ..quadraticBezierTo(
        center.dx + 22 + leafOffset,
        center.dy - 26,
        center.dx + 6,
        center.dy - 34,
      )
      ..quadraticBezierTo(
        center.dx + 2,
        center.dy - 20,
        center.dx,
        center.dy - 12,
      );
    canvas.drawPath(rightLeaf, leafPaint);

    final soilPaint = Paint()
      ..color = const Color(0xFF6D4C41)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 26),
          width: 40,
          height: 10,
        ),
        const Radius.circular(5),
      ),
      soilPaint,
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          brandColor.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _AgricultureLoaderPainter oldDelegate) =>
      oldDelegate.leafPhase != leafPhase;
}
