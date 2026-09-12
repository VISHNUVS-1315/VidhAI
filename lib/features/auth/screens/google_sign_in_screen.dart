import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/core/bloc/auth_event.dart';
import 'package:vidhai/core/bloc/auth_state.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class GoogleSignInScreen extends StatefulWidget {
  const GoogleSignInScreen({super.key});

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  bool _isSigningIn = false;
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colors.bg,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is GoogleSignInSuccess && !_navigated) {
            _navigated = true;
            setState(() => _isSigningIn = false);
            Navigator.of(context).pushReplacementNamed(
              state.resumeToMain ? '/main_shell' : '/personal_details',
            );
          } else if (state is AuthErrorState) {
            setState(() => _isSigningIn = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_messageFor(loc, state.errorMessage ?? '')),
                backgroundColor: colors.danger,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        child: Stack(
          children: [
            _buildHeader(size),
            Positioned.fill(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          onPressed: _isSigningIn
                              ? null
                              : () => Navigator.of(context)
                                  .pushReplacementNamed('/domain_selection'),
                          icon: Icon(
                              directionalIcon(context, Icons.arrow_back_ios),
                              color: Colors.white,
                              size: 22),
                        ),
                      ),
                      SizedBox(height: size.height * 0.10),
                      Container(
                        width: 92,
                        height: 92,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'VidhAI',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Empowering Farmers, Enriching Lives',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildSignInCard(colors, loc),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: size.height * 0.62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1B5E3E),
              const Color(0xFF2E7D32),
              const Color(0xFF4CAF6C),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInCard(colors, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.signInWithGoogle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.signInDescription,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 24),
          _buildGoogleButton(colors, loc),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined,
                  size: 15, color: colors.onSurfaceMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Secure • No passwords',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(colors, AppLocalizations loc) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isSigningIn
              ? null
              : () {
                  setState(() => _isSigningIn = true);
                  context.read<AuthBloc>().add(const GoogleSignInPressed());
                },
          child: Center(
            child: _isSigningIn
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF2E7D32),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const GoogleGLogo(size: 24),
                      const SizedBox(width: 12),
                      Text(
                        loc.signInWithGoogle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2F23),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _messageFor(AppLocalizations loc, String code) {
    switch (code) {
      case 'google-sign-in-cancelled':
        return loc.googleSigninCancelled;
      case 'network-error':
        return loc.networkError;
      case 'google-sign-in-config-error':
        return loc.signInConfigError;
      case 'google-sign-in-not-enabled':
      case 'google-sign-in-failed':
      default:
        return loc.errorGeneric;
    }
  }
}

class GoogleGLogo extends StatelessWidget {
  final double size;

  const GoogleGLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _GoogleGPainter());
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(_blue(), paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawPath(_green(), paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(_yellow(), paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(_red(), paint);

    canvas.restore();
  }

  Path _blue() {
    final path = Path()
      ..moveTo(22.56, 12.25)
      ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10.0)
      ..lineTo(12.0, 10.0)
      ..lineTo(12.0, 14.26)
      ..lineTo(17.92, 14.26)
      ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
      ..lineTo(15.71, 20.34)
      ..lineTo(19.28, 20.34)
      ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
      ..close();
    return path;
  }

  Path _green() {
    final path = Path()
      ..moveTo(12.0, 23.0)
      ..cubicTo(14.97, 23.0, 17.43, 22.02, 19.28, 20.34)
      ..lineTo(15.71, 17.57)
      ..cubicTo(14.73, 18.23, 13.48, 18.63, 12.0, 18.63)
      ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.1)
      ..lineTo(2.18, 14.1)
      ..lineTo(2.18, 16.94)
      ..cubicTo(3.99, 20.53, 7.7, 23.0, 12.0, 23.0)
      ..close();
    return path;
  }

  Path _yellow() {
    final path = Path()
      ..moveTo(5.84, 14.09)
      ..cubicTo(5.62, 13.43, 5.49, 12.73, 5.49, 12.0)
      ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
      ..lineTo(5.84, 7.07)
      ..lineTo(2.18, 7.07)
      ..cubicTo(1.43, 8.55, 1.0, 10.22, 1.0, 12.0)
      ..cubicTo(1.0, 13.78, 1.43, 15.45, 2.18, 16.93)
      ..lineTo(5.84, 14.09)
      ..close();
    return path;
  }

  Path _red() {
    final path = Path()
      ..moveTo(12.0, 5.38)
      ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
      ..lineTo(19.36, 3.87)
      ..cubicTo(17.45, 2.09, 14.97, 1.0, 12.0, 1.0)
      ..cubicTo(7.7, 1.0, 3.99, 3.47, 2.18, 7.07)
      ..lineTo(5.84, 9.91)
      ..cubicTo(6.71, 7.31, 9.14, 5.38, 12.0, 5.38)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
