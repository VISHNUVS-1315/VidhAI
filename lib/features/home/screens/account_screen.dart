import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/features/account/screens/edit_profile_screen.dart';
import 'package:vidhai/features/account/screens/language_settings_screen.dart';
import 'package:vidhai/features/notifications/screens/notification_center_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final DataService _dataService = DataService();
  UserProfile? _profile;
  bool _isLoading = true;

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _accent = Color(0xFF4CAF50);
  static const Color _danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _dataService.loadCachedProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  String _getInitial() {
    final name = _profile?.displayName ?? '';
    if (name.isNotEmpty) return name[0].toUpperCase();
    final email = _profile?.email ?? '';
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: _cardColor,
                    child: Text(
                      _getInitial(),
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _profile?.displayName.isNotEmpty == true
                        ? _profile!.displayName
                        : 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _profile?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildMenuItem(
                  Icons.person_outline,
                  'Edit Profile',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                    _loadProfile();
                  },
                ),
                _buildMenuItem(
                  Icons.language,
                  'Language',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LanguageSettingsScreen(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  Icons.notifications_outlined,
                  'Notifications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  Icons.help_outline,
                  'Help & Support',
                  onTap: () => _showHelpSheet(context),
                ),
                _buildMenuItem(
                  Icons.info_outline,
                  'About VidhAI',
                  onTap: () => _showAboutDialog(context),
                ),
                _buildMenuItem(
                  Icons.terminal,
                  'Console',
                  onTap: () => _showConsoleDialog(context),
                ),
                _buildMenuItem(
                  Icons.g_mobiledata,
                  'Link Google Account',
                  onTap: () => _showGoogleLinkDialog(context),
                ),
                const SizedBox(height: 16),
                _buildEmailVerificationSection(),
                const SizedBox(height: 16),
                _buildLogoutButton(context),
              ],
            ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildEmailVerificationSection() {
    final isVerified = _profile?.isEmailVerified ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.mail_outline,
            color: isVerified ? _accent : Colors.white.withValues(alpha: 0.5),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isVerified ? 'Email verified ✓' : 'Email not verified',
              style: TextStyle(
                color: isVerified ? _accent : Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isVerified)
            TextButton(
              onPressed: () => _sendVerificationEmail(),
              style: TextButton.styleFrom(
                backgroundColor: _accent.withValues(alpha: 0.15),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Verify',
                style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Verification email sent!'),
              backgroundColor: _accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send verification email'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: _cardColor,
              title: const Text('Logout',
                  style: TextStyle(color: Colors.white)),
              content: Text(
                'Are you sure you want to logout?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Logout',
                      style: TextStyle(color: _danger)),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            context.read<AuthBloc>().logout();
            Navigator.of(context).pushReplacementNamed('/language_selection');
          }
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _danger, width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Logout',
          style: TextStyle(
            color: _danger,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Help & Support',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _helpItem(Icons.email_outlined, 'Email Us',
                'support@vidhai.com'),
            _helpItem(Icons.phone_outlined, 'Call Us', '+91 1800-VIDHAI'),
            _helpItem(Icons.chat_bubble_outline, 'Live Chat',
                'Available 9AM - 6PM IST'),
            _helpItem(Icons.article_outlined, 'FAQ',
                'Visit our help center'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: _accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'VidhAI',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 VidhAI. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        Text(
          'VidhAI is an AI-powered farming assistant that provides '
          'personalized crop recommendations, disease detection, and '
          'farm management tools for Indian farmers.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  void _showConsoleDialog(BuildContext context) async {
    final currentConsole = await _dataService.getSelectedConsole();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          'Switch Console',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _consoleOption(ctx, 'Farmer Console', 'farmer', currentConsole),
            _consoleOption(
                ctx, 'Consumer Console', 'consumer', currentConsole),
          ],
        ),
      ),
    );
  }

  Widget _consoleOption(
      BuildContext ctx, String title, String value, String current) {
    final isSelected = value == current;
    return RadioListTile<String>(
      value: value,
      groupValue: current,
      onChanged: (val) async {
        if (val != null) {
          await _dataService.setSelectedConsole(val);
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            _loadProfile();
            showDialog(
              context: context,
              builder: (dCtx) => AlertDialog(
                backgroundColor: _cardColor,
                title: const Text('Console Switched', style: TextStyle(color: Colors.white)),
                content: Text(
                  'Switched to ${val == 'farmer' ? 'Farmer' : 'Consumer'} Console. Some features may change.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dCtx);
                      if (mounted) setState(() {});
                    },
                    child: const Text('OK', style: TextStyle(color: _accent)),
                  ),
                ],
              ),
            );
          }
        }
      },
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      activeColor: _accent,
      secondary: Icon(
        value == 'farmer' ? Icons.agriculture : Icons.shopping_cart,
        color: isSelected ? _accent : Colors.white.withValues(alpha: 0.5),
      ),
    );
  }

  void _showGoogleLinkDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isGoogleLinked = user.providerData.any((p) => p.providerId == 'google.com');
    if (isGoogleLinked) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardColor,
          title: const Text('Google Account', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: _accent, size: 48),
              const SizedBox(height: 16),
              Text(
                'Your Google account is already linked.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: _accent))),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Link Google Account', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.g_mobiledata, size: 64, color: _accent),
            const SizedBox(height: 16),
            Text(
              'Link your Google account to sign in with Google on any device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6)))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Link Now', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final googleProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.currentUser?.linkWithProvider(googleProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Google account linked successfully!'), backgroundColor: _accent, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          );
          _loadProfile();
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          String msg = 'Failed to link Google account.';
          if (e.code == 'provider-already-linked') {
            msg = 'This account is already linked to a Google account.';
          } else if (e.code == 'credential-already-in-use') {
            msg = 'This Google account is already linked to another user.';
          } else if (e.code == 'invalid-credential') {
            msg = 'Invalid Google credentials. Please try again.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: _danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Google sign-in cancelled or failed.'), backgroundColor: _danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          );
        }
      }
    }
  }
}
