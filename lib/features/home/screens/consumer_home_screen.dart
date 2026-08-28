import 'package:flutter/material.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/mandi_service.dart';
import 'package:vidhai/features/schemes/screens/government_schemes_screen.dart';
import 'package:vidhai/features/tools/screens/crop_search_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/features/home/screens/ai_chat_screen.dart';
import 'package:vidhai/locale/locale.dart';

class ConsumerHomeScreen extends StatefulWidget {
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  String _userName = 'Consumer';
  List<MandiPrice> _topPrices = [];
  bool _isLoadingPrices = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profile = await DataService().loadProfile();
      if (profile != null && profile.displayName.isNotEmpty) {
        _userName = profile.displayName;
      }
    } catch (_) {}

    try {
      final prices = await MandiService().fetchPrices();
      if (mounted) {
        setState(() {
          _topPrices = prices.take(5).toList();
          _isLoadingPrices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPrices = false);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $_userName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover fresh produce & farming insights',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shopping_cart_rounded, color: Color(0xFFFF9800), size: 22),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildQuickActions(loc),
            const SizedBox(height: 24),
            _buildSectionHeader('Live Market Prices', trailing: 'View All', onTrailing: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketPricesScreen()));
            }),
            const SizedBox(height: 12),
            _buildMarketPrices(loc),
            const SizedBox(height: 24),
            _buildSectionHeader('Explore'),
            const SizedBox(height: 12),
            _buildExploreGrid(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations loc) {
    return Row(
      children: [
        _quickAction(Icons.search_rounded, 'Crop Search', const Color(0xFF2196F3), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CropSearchScreen()));
        }),
        const SizedBox(width: 12),
        _quickAction(Icons.account_balance_rounded, 'Schemes', const Color(0xFF4CAF50), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GovernmentSchemesScreen()));
        }),
        const SizedBox(width: 12),
        _quickAction(Icons.auto_awesome, 'AI Chat', const Color(0xFF9C27B0), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
        }),
        const SizedBox(width: 12),
        _quickAction(Icons.trending_up_rounded, 'Prices', const Color(0xFFFF9800), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketPricesScreen()));
        }),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? trailing, VoidCallback? onTrailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailing,
            child: Text(trailing, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildMarketPrices(AppLocalizations loc) {
    if (_isLoadingPrices) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF9800), strokeWidth: 2)),
      );
    }

    if (_topPrices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.store_rounded, color: Colors.white.withValues(alpha: 0.3), size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Market prices will appear here once data is available.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _topPrices.map((p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.grass_rounded, color: Color(0xFFFF9800), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.commodity, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(p.market, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                ],
              ),
            ),
            Text(
              '₹${p.modalPrice > 0 ? p.modalPrice.toStringAsFixed(0) : '--'}',
              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildExploreGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _exploreCard(Icons.eco_rounded, 'Crop Guide', 'Browse crop information', const Color(0xFF4CAF50), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CropSearchScreen()));
        }),
        _exploreCard(Icons.account_balance_rounded, 'Govt Schemes', 'Subsidies & benefits', const Color(0xFF2196F3), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GovernmentSchemesScreen()));
        }),
        _exploreCard(Icons.trending_up_rounded, 'Price Trends', 'Track market movements', const Color(0xFFFF9800), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketPricesScreen()));
        }),
        _exploreCard(Icons.auto_awesome, 'Ask AI', 'Farming Q&A assistant', const Color(0xFF9C27B0), () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
        }),
      ],
    );
  }

  Widget _exploreCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
