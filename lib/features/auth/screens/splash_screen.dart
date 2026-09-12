import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/services/data_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      final dataService = DataService();
      final onboardingComplete = await dataService.isOnboardingComplete();

      if (onboardingComplete) {
        try {
          await dataService.restoreFromBackend();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main_shell');
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/language_selection');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: colors.brandDeep.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'VidhAI',
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Agriculture Ecosystem',
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 16),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.brandDeep.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
