import 'package:flutter/material.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/market_price_service.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/features/schemes/screens/government_schemes_screen.dart';
import 'package:vidhai/features/tools/screens/crop_search_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/features/home/screens/ai_chat_screen.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';

class ConsumerHomeScreen extends StatefulWidget {
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  String _userName = '';
  List<MarketPriceRecord> _topPrices = [];
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
      final payload = await MarketPriceService.instance.fetchPrices();
      if (mounted) {
        setState(() {
          _topPrices = payload.prices.take(5).toList();
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
    final colors = VidhAIColorsX(context);

    return Scaffold(
      backgroundColor: colors.bg,
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
                        loc.helloNamed.replaceFirst(
                            '{name}',
                            _userName.isEmpty
                                ? loc.defaultUserNameConsumer
                                : _userName),
                        style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.discoverFresh,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const VidhAIAssistantButton(screen: 'consumer_home'),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.shopping_cart_rounded,
                          color: colors.warning, size: 22),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildQuickActions(loc),
            const SizedBox(height: 24),
            _buildSectionHeader(loc.liveMarketPrices,
                trailing: loc.t('view_all'), onTrailing: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MarketPricesScreen()));
            }),
            const SizedBox(height: 12),
            _buildMarketPrices(loc),
            const SizedBox(height: 24),
            _buildSectionHeader(loc.explore),
            const SizedBox(height: 12),
            _buildExploreGrid(loc),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return Row(
      children: [
        _quickAction(Icons.search_rounded, loc.cropSearch, colors.info, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CropSearchScreen()));
        }),
        const SizedBox(width: 12),
        _quickAction(
            Icons.account_balance_rounded, loc.govtSchemes, colors.brandDeep,
            () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const GovernmentSchemesScreen()));
        }),
        const SizedBox(width: 12),
        _quickAction(Icons.auto_awesome, loc.aiChat, const Color(0xFF9C27B0),
            () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AiChatScreen(source: 'consumer_home')));
        }),
        const SizedBox(width: 12),
        _quickAction(
            Icons.trending_up_rounded, loc.marketPrices, colors.warning, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MarketPricesScreen()));
        }),
      ],
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
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
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title,
      {String? trailing, VoidCallback? onTrailing}) {
    final colors = VidhAIColorsX(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                color: colors.onBackground,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailing,
            child: Text(trailing,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildMarketPrices(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    if (_isLoadingPrices) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
            child: CircularProgressIndicator(
                color: colors.warning, strokeWidth: 2)),
      );
    }

    if (_topPrices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.store_rounded, color: colors.onSurfaceMuted, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                loc.marketPricesEmpty,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _topPrices
          .map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.grass_rounded,
                          color: colors.warning, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.commodity,
                              style: TextStyle(
                                  color: colors.onBackground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(p.market,
                              style: TextStyle(
                                  color: colors.onSurfaceMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(
                      '₹${(p.modalPrice ?? 0) > 0 ? (p.modalPrice ?? 0).toStringAsFixed(0) : '--'}',
                      style: TextStyle(
                          color: colors.brandDeep,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildExploreGrid(AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _exploreCard(Icons.eco_rounded, loc.cropGuide, loc.cropGuideDesc,
            colors.brandDeep, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CropSearchScreen()));
        }),
        _exploreCard(Icons.account_balance_rounded, loc.govtSchemes,
            loc.govtSchemesDesc, colors.info, () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const GovernmentSchemesScreen()));
        }),
        _exploreCard(Icons.trending_up_rounded, loc.priceTrends,
            loc.priceTrendsDesc, colors.warning, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MarketPricesScreen()));
        }),
        _exploreCard(Icons.auto_awesome, loc.askAi, loc.askAiDesc,
            const Color(0xFF9C27B0), () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AiChatScreen(source: 'consumer_home')));
        }),
      ],
    );
  }

  Widget _exploreCard(IconData icon, String title, String subtitle, Color color,
      VoidCallback onTap) {
    final colors = VidhAIColorsX(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
