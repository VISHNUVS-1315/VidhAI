import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/features/tools/screens/consumer_market_prices_screen.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/market_price_service.dart';

class ConsumerHomeScreen extends StatefulWidget {
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  final DataService _dataService = DataService();
  final MarketPriceService _marketService = MarketPriceService.instance;

  String _userName = '';
  List<MarketPriceRecord> _topPrices = const [];
  bool _loadingPrices = true;

  @override
  void initState() {
    super.initState();
    _loadConsumerHome();
  }

  Future<void> _loadConsumerHome() async {
    String? state;
    String? district;

    try {
      final profile = await _dataService.loadProfile();
      if (profile != null) {
        _userName = profile.displayName.trim();
        state = profile.address?.state?.trim();
        district = profile.address?.district?.trim();
      }
    } catch (_) {}

    try {
      final hasState = state != null && state.isNotEmpty;
      final payload = hasState
          ? await _marketService.fetchPrices(
              state: state,
              district:
                  district != null && district.isNotEmpty ? district : null,
            )
          : await _marketService.fetchSummary();

      if (!mounted) return;
      setState(() {
        _topPrices = payload.prices.take(3).toList();
        _loadingPrices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPrices = false);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final displayName =
        _userName.isEmpty ? loc.defaultUserNameConsumer : _userName;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadConsumerHome,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              _buildBrandHeader(colors, loc),
              const SizedBox(height: 24),
              Text(
                loc.welcomeBack,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                displayName,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.consumerDescription,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              _buildConsumerDesk(colors, loc),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader(VidhAIColorsX colors, AppLocalizations loc) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/images/logo.png',
            width: 34,
            height: 34,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            loc.t('consumer_desk'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        IconButton(
          tooltip: loc.notificationCenterTitle,
          onPressed: () =>
              Navigator.of(context).pushNamed('/notification_center'),
          icon: Icon(
            Icons.notifications_none_rounded,
            color: colors.onBackground,
          ),
        ),
        const SizedBox(width: 4),
        const VidhAIAssistantButton(
          screen: 'consumer_home',
          size: 40,
          iconSize: 20,
        ),
      ],
    );
  }

  Widget _buildConsumerDesk(
    VidhAIColorsX colors,
    AppLocalizations loc,
  ) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConsumerMarketPricesScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: colors.brandDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.t('consumer_desk'),
                          style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.liveMarketPrices,
                          style: TextStyle(
                            color: colors.onSurfaceMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: colors.onSurfaceMuted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loadingPrices)
                SizedBox(
                  height: 74,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colors.brandDeep,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_topPrices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    loc.marketPricesEmpty,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ..._topPrices.map(
                  (price) => _buildPriceRow(colors, loc, price),
                ),
              if (!_loadingPrices) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    loc.t('view_all'),
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    VidhAIColorsX colors,
    AppLocalizations loc,
    MarketPriceRecord price,
  ) {
    final String value;
    if (price.hasReliablePerKg) {
      value =
          '₹${price.normalizedPricePerKg!.toStringAsFixed(2)}/${loc.t('community_kg_unit')}';
    } else if (price.modalPrice != null && price.modalPrice! > 0) {
      final unit = price.unitLabel.trim().isEmpty
          ? price.originalUnit
          : price.unitLabel;
      value = '₹${price.modalPrice!.toStringAsFixed(0)} / $unit';
    } else {
      value = '--';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.commodity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price.market,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: colors.brandDeep,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.brandDeep.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: colors.brandDeep, size: 23),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
