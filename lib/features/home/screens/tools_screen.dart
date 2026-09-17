import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/features/tools/screens/multi_pest_detection_screen.dart';
import 'package:vidhai/features/tools/screens/fertilizer_guide_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/features/tools/screens/crop_search_screen.dart';
import 'package:vidhai/features/tools/screens/community_placeholder_screen.dart';
import 'package:vidhai/features/farm/screens/crop_setup_screen.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/assistant/assistant_overlay.dart';
import 'package:vidhai/features/assistant/assistant_session.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

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
          loc.tools,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          const VidhAIAssistantButton(screen: 'tools'),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            loc.smartFarmingUtilities,
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final useSingleColumn = width < 340;
              final cardHeight = useSingleColumn ? 154.0 : (width < 380 ? 196.0 : 184.0);
              return GridView.builder(
                itemCount: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: useSingleColumn ? 1 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: cardHeight,
                ),
                itemBuilder: (context, index) {
                  final cards = <Widget>[
                    _ToolCard(
                      icon: Icons.bug_report_rounded,
                      title: loc.pestDetection,
                      description: loc.pestDetectDesc,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MultiPestDetectionScreen(),
                        ),
                      ),
                    ),
                    _ToolCard(
                      icon: Icons.grass_rounded,
                      title: loc.fertilizerGuide,
                      description: loc.fertilizerGuideDesc,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FertilizerGuideScreen(),
                        ),
                      ),
                    ),
                    _ToolCard(
                      icon: Icons.trending_up_rounded,
                      title: loc.marketPrices,
                      description: loc.liveMandiPrices,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarketPricesScreen(),
                        ),
                      ),
                    ),
                    _ToolCard(
                      icon: Icons.search_rounded,
                      title: loc.cropSearch,
                      description: loc.cropSearchDesc,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CropSearchScreen(),
                        ),
                      ),
                    ),
                    _ToolCard(
                      icon: Icons.terrain_rounded,
                      title: loc.soilScanner,
                      description: loc.soilScannerDesc,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CropSetupScreen(farmId: ''),
                        ),
                      ),
                    ),
                    _ToolCard(
                      icon: Icons.auto_awesome_rounded,
                      title: loc.vidhaiAssistant,
                      description: loc.askFarmingDesc,
                      onTap: () {
                        AssistantSession.instance.open('tools');
                        showVidhAIAssistantOverlay(context);
                      },
                    ),
                    _ToolCard(
                      icon: Icons.account_balance_rounded,
                      title: loc.govtSchemes,
                      description: loc.govtSchemesDesc,
                      onTap: () =>
                          Navigator.pushNamed(context, '/government-schemes'),
                    ),
                    _ToolCard(
                      icon: Icons.forum_rounded,
                      title: loc.community,
                      description: loc.communityDesc,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CommunityPlaceholderScreen(),
                        ),
                      ),
                    ),
                  ];
                  return cards[index];
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.borderColor,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: colors.brandDeep,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                description,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 11,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
