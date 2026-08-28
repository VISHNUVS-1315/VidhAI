import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/locale/locale.dart';

class DomainSelectionScreen extends StatefulWidget {
  const DomainSelectionScreen({super.key});

  @override
  State<DomainSelectionScreen> createState() => _DomainSelectionScreenState();
}

class _DomainSelectionScreenState extends State<DomainSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushReplacementNamed('/language_selection');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1A),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context)
                      .pushReplacementNamed('/language_selection'),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.vertical -
                          48,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2332),
                              borderRadius: BorderRadius.circular(16),
                              image: const DecorationImage(
                                image: AssetImage('assets/images/logo.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            loc.chooseDomain,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            loc.selectOneLanguage,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),
                          _buildDomainCard(
                            icon: Icons.agriculture_rounded,
                            title: loc.farmerConsole,
                            subtitle: loc.farmerDescription,
                            color: const Color(0xFF4CAF50),
                            onTap: () => _selectDomain('farmer'),
                          ),
                          const SizedBox(height: 16),
                          _buildDomainCard(
                            icon: Icons.shopping_cart_rounded,
                            title: loc.consumerConsole,
                            subtitle: loc.consumerDescription,
                            color: const Color(0xFFFF9800),
                            onTap: () => _selectDomain('consumer'),
                          ),
                          const Spacer(flex: 3),
                          Text(
                            loc.appName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDomainCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectDomain(String domain) {
    _saveDomain(domain);

    Navigator.of(context).pushReplacementNamed('/personal_details');
  }

  Future<void> _saveDomain(String domain) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setString('selected_domain', domain);
  }
}
