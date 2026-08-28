import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class RecommendationLoadingScreen extends StatefulWidget {
  final String? farmId;
  final dynamic questionnaire;
  const RecommendationLoadingScreen({super.key, this.farmId, this.questionnaire});

  @override
  State<RecommendationLoadingScreen> createState() =>
      _RecommendationLoadingScreenState();
}

class _RecommendationLoadingScreenState
    extends State<RecommendationLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _leafController;

  int _currentTextIndex = 0;
  double _progress = 0.0;
  Timer? _textTimer;
  Timer? _progressTimer;
  Timer? _navigationTimer;

  final List<String> _loadingTexts = const [
    'Checking soil compatibility...',
    'Analyzing weather patterns...',
    'Evaluating market conditions...',
    'Finding best crops...',
  ];

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

    _textTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (mounted) {
        setState(() {
          _currentTextIndex = (_currentTextIndex + 1) % _loadingTexts.length;
        });
      }
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (mounted) {
        setState(() {
          _progress += 0.0055;
          if (_progress > 1.0) _progress = 1.0;
        });
      }
    });

    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/crop_recommendation',
          arguments: {
            'farmId': widget.farmId,
            'questionnaire': widget.questionnaire,
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _leafController.dispose();
    _textTimer?.cancel();
    _progressTimer?.cancel();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.9 + (_pulseController.value * 0.3),
                    child: child,
                  );
                },
                child: AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * pi,
                      child: child,
                    );
                  },
                  child: CustomPaint(
                    size: const Size(150, 150),
                    painter: _AgricultureLoaderPainter(
                      leafPhase: _leafController.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'Analyzing your farm data...',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 28,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _loadingTexts[_currentTextIndex],
                    key: ValueKey<int>(_currentTextIndex),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF1A2235),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = index == _currentTextIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF1A2235),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgricultureLoaderPainter extends CustomPainter {
  final double leafPhase;

  _AgricultureLoaderPainter({this.leafPhase = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint = Paint()
      ..color = const Color(0xFF1A2235)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 8, ringPaint);

    final accentPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * 0.35;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -pi / 2,
      sweepAngle,
      false,
      accentPaint,
    );

    final stemPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final stemStart = Offset(center.dx, center.dy + 20);
    final stemEnd = Offset(center.dx, center.dy - 18);
    canvas.drawLine(stemStart, stemEnd, stemPaint);

    final leafPaint = Paint()
      ..color = const Color(0xFF4CAF50)
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
    final soilRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 26),
        width: 40,
        height: 10,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(soilRect, soilPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4CAF50).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _AgricultureLoaderPainter oldDelegate) {
    return oldDelegate.leafPhase != leafPhase;
  }
}
