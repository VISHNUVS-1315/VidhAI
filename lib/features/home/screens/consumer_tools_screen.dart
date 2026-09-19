import '../../consumer/screens/consumer_utilities.dart';
import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/features/tools/screens/fertilizer_guide_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/locale/locale.dart';

class ConsumerToolsScreen extends StatelessWidget {
  const ConsumerToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        titleSpacing: 18,
        title: Text(
          loc.tools,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _ConsumerToolCard(
            colors: colors,
            icon: Icons.receipt_long_rounded,
            title: loc.t('purchase_history'),
            subtitle: loc.t('purchase_history'),
            emphasized: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ConsumerPurchaseHistoryScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ConsumerToolCard(
            colors: colors,
            icon: Icons.query_stats_rounded,
            title: loc.marketPrices,
            subtitle: loc.t('mk_subtitle'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MarketPricesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ConsumerToolCard(
            colors: colors,
            icon: Icons.science_outlined,
            title: loc.t('fertilizer_prices'),
            subtitle: loc.fertilizerGuideDesc,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _FertilizerPricesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ConsumerToolCard(
            colors: colors, icon: Icons.calculate_outlined,
            title: loc.t('consumer_calculator'), subtitle: loc.t('consumer_calculator'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsumerCalculatorScreen())),
          ),
          const SizedBox(height: 10),
          _ConsumerToolCard(
            colors: colors, icon: Icons.note_alt_outlined,
            title: loc.t('consumer_notes'), subtitle: loc.t('consumer_notes_local'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsumerNotesScreen())),
          ),
        ],
      ),
    );
  }
}

class _ConsumerToolCard extends StatelessWidget {
  const _ConsumerToolCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final VidhAIColorsX colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: emphasized
                  ? colors.brandDeep.withValues(alpha: 0.42)
                  : colors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.brandDeep.withValues(
                    alpha: emphasized ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: colors.brandDeep,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FertilizerPricesScreen extends StatelessWidget {
  const _FertilizerPricesScreen();

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          loc.t('fertilizer_prices'),
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.science_outlined,
                color: colors.brandDeep,
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                loc.marketPricesEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FertilizerGuideScreen(),
                  ),
                ),
                icon: const Icon(Icons.eco_outlined),
                label: Text(loc.fertilizerGuide),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
