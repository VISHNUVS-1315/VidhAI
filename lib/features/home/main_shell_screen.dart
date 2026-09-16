import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vidhai/core/routing/main_shell_controller.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/features/home/screens/farmer_home_screen.dart';
import 'package:vidhai/features/home/screens/consumer_home_screen.dart';
import 'package:vidhai/features/farm/screens/farm_screen.dart';
import 'package:vidhai/services/notification_service.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/features/home/screens/tools_screen.dart';
import 'package:vidhai/features/home/screens/account_screen.dart';
import 'package:vidhai/features/home/screens/ai_chat_screen.dart';
import 'package:vidhai/features/assistant/assistant_session.dart';
import 'package:vidhai/features/assistant/assistant_overlay.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final MainShellController _shell = MainShellController.instance;
  String _selectedConsole = 'farmer';
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _shell.addListener(_onShellChanged);
    _loadConsole();
    _loadUnreadCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeWelcome();
      // Non-blocking: welcome once, schedule reminders, weather pass.
      NotificationService().syncAfterSignIn();
    });
  }

  /// First-entry AI welcome: once per app process, when the shell opens on the
  /// Home tab, greet with the contextual voice assistant overlay.
  Future<void> _maybeWelcome() async {
    if (_shell.currentIndex != 0) return;
    if (AssistantSession.instance.isOpen) return;
    if (!AssistantSession.consumeWelcomeOnce()) return;
    await _loadConsole();
    if (!mounted) return;
    if (_shell.currentIndex != 0) return;
    unawaited(AssistantSession.instance.open('home', welcomeBack: true));
    unawaited(showVidhAIAssistantOverlay(context));
  }

  void _onShellChanged() {
    if (mounted) setState(() {});
    if (_shell.currentIndex == 0) _loadConsole();
  }

  @override
  void dispose() {
    _shell.removeListener(_onShellChanged);
    super.dispose();
  }

  Future<void> _loadConsole() async {
    final console = await DataService().getSelectedConsole();
    if (mounted) setState(() => _selectedConsole = console);
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService().getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  Widget _buildCurrentScreen() {
    switch (_shell.currentIndex) {
      case 0:
        return _selectedConsole == 'farmer'
            ? const FarmerHomeScreen()
            : const ConsumerHomeScreen();
      case 1:
        return const FarmScreen();
      case 2:
        return const AiChatScreen(source: 'shell');
      case 3:
        return const ToolsScreen();
      case 4:
        return const AccountScreen();
      default:
        return _selectedConsole == 'farmer'
            ? const FarmerHomeScreen()
            : const ConsumerHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: _buildCurrentScreen(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, loc.home,
                  badge: _unreadCount),
              _buildNavItem(1, Icons.landscape_rounded, loc.farm),
              _buildCenterButton(),
              _buildNavItem(3, Icons.build_rounded, loc.tools),
              _buildNavItem(4, Icons.person_rounded, loc.account),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label,
      {int badge = 0}) {
    final colors = VidhAIColorsX(context);
    final isSelected = _shell.currentIndex == index;
    return GestureDetector(
      onTap: () {
        _shell.switchTab(index);
        if (index == 0) _loadConsole();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? colors.brandDeep : colors.onSurfaceMuted,
                  size: 22,
                ),
                if (badge > 0)
                  PositionedDirectional(
                    end: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.brandDeep : colors.onSurfaceMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    final colors = VidhAIColorsX(context);
    return GestureDetector(
      onTap: () => _shell.switchTab(MainShellController.indexAi),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.brand, colors.brandDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.brand.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome,
          color: colors.isDark ? Colors.white : colors.bg,
          size: 22,
        ),
      ),
    );
  }
}
