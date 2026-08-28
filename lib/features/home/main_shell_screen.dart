import 'package:flutter/material.dart';
import 'package:vidhai/features/home/screens/farmer_home_screen.dart';
import 'package:vidhai/features/home/screens/consumer_home_screen.dart';
import 'package:vidhai/features/farm/screens/farm_screen.dart';
import 'package:vidhai/services/notification_service.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/features/home/screens/tools_screen.dart';
import 'package:vidhai/features/home/screens/account_screen.dart';
import 'package:vidhai/features/home/screens/ai_chat_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  String _selectedConsole = 'farmer';
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadConsole();
    _loadUnreadCount();
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
    switch (_currentIndex) {
      case 0:
        return _selectedConsole == 'farmer'
            ? const FarmerHomeScreen()
            : const ConsumerHomeScreen();
      case 1:
        return const FarmScreen();
      case 2:
        return const AiChatScreen();
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1A),
        body: _buildCurrentScreen(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
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
              _buildNavItem(0, Icons.home_rounded, 'Home', badge: _unreadCount),
              _buildNavItem(1, Icons.landscape_rounded, 'Farm'),
              _buildCenterButton(),
              _buildNavItem(3, Icons.build_rounded, 'Tools'),
              _buildNavItem(4, Icons.person_rounded, 'Account'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badge = 0}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
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
                  color: isSelected
                      ? const Color(0xFF4CAF50)
                      : Colors.white.withValues(alpha: 0.35),
                  size: 22,
                ),
                if (badge > 0)
                  Positioned(
                    right: -6,
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
                color: isSelected
                    ? const Color(0xFF4CAF50)
                    : Colors.white.withValues(alpha: 0.35),
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
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
