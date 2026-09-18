import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/features/tools/screens/multi_pest_detection_screen.dart';
import 'package:vidhai/features/tools/screens/fertilizer_guide_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/features/community/screens/community_feed_screen.dart';
import 'package:vidhai/features/farm/screens/crop_setup_screen.dart';
import 'package:vidhai/features/farm_records/screens/crop_diary_screen.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/services/data_service.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  Future<void> _openCropRecommendation(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    final farms = await DataService().loadFarms();
    if (!context.mounted) return;

    if (farms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('no_farms_found_body')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String? farmId;
    if (farms.length == 1) {
      farmId = farms.first.farmId;
    } else {
      farmId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.60,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc.t('ai_crop_recommend'),
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: farms.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: colors.borderColor, height: 1),
                    itemBuilder: (_, index) {
                      final farm = farms[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                colors.brandDeep.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.agriculture_rounded,
                            color: colors.brandDeep,
                          ),
                        ),
                        title: Text(
                          farm.farmName.trim().isEmpty
                              ? loc.farm
                              : farm.farmName,
                          style: TextStyle(
                            color: colors.onBackground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: colors.onSurfaceMuted,
                        ),
                        onTap: () =>
                            Navigator.pop(sheetContext, farm.farmId),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!context.mounted || farmId == null || farmId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropSetupScreen(farmId: farmId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 18,
        title: Text(
          loc.tools,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const [
          VidhAIAssistantButton(screen: 'tools'),
          SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _CommunityHero(
            title: loc.community,
            description: loc.communityDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CommunityFeedScreen(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _ToolRow(
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
          const SizedBox(height: 10),
          _ToolRow(
            icon: Icons.eco_rounded,
            title: loc.fertilizerGuide,
            description: loc.fertilizerGuideDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FertilizerGuideScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ToolRow(
            icon: Icons.query_stats_rounded,
            title: loc.marketPrices,
            description: loc.liveMandiPrices,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MarketPricesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ToolRow(
            icon: Icons.account_balance_rounded,
            title: loc.govtSchemes,
            description: loc.govtSchemesDesc,
            onTap: () =>
                Navigator.pushNamed(context, '/government-schemes'),
          ),
          const SizedBox(height: 10),
          _ToolRow(
            icon: Icons.auto_awesome_rounded,
            title: loc.t('ai_crop_recommend'),
            description: loc.t('ai_crop_recommend_desc'),
            highlighted: true,
            onTap: () => _openCropRecommendation(context),
          ),
          const SizedBox(height: 10),
          _ToolRow(
            icon: Icons.menu_book_rounded,
            title: loc.t('crop_diary'),
            description: loc.t('crop_diary_desc'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CropDiaryScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityHero extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  const _CommunityHero({
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);

    return Material(
      color: colors.brandDeep,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 144),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool highlighted;

  const _ToolRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
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
                    alpha: highlighted ? 0.16 : 0.10,
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
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 11.5,
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
