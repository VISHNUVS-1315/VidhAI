import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/farm/screens/farm_details_screen.dart';
import 'package:vidhai/features/farm/screens/farm_workspace_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/crop_backend_service.dart';
import 'package:vidhai/services/crop_knowledge_base.dart';
import 'package:vidhai/services/crop_recommendation_service.dart';
import 'package:vidhai/services/market_price_service.dart';

/// Manual crop check against the verified knowledge database (server
/// `/crop/check`, local fallback offline). Shows a per-factor verdict, a
/// suitability score and reference (estimated) figures, and can start the crop.
class ManualCropCheckScreen extends StatefulWidget {
  final FarmProfile farm;
  final String? prefillCrop;
  final Future<void> Function(ManualCropCheck check)? onStartManually;

  const ManualCropCheckScreen({
    super.key,
    required this.farm,
    this.prefillCrop,
    this.onStartManually,
  });

  @override
  State<ManualCropCheckScreen> createState() => _ManualCropCheckScreenState();
}

class _ManualCropCheckScreenState extends State<ManualCropCheckScreen> {
  final _searchController = TextEditingController();
  final CropKnowledgeBase _knowledgeBase = CropKnowledgeBase();

  List<String> _suggestions = [];
  bool _checking = false;
  ManualCropCheck? _result;
  String? _selectedVariety;
  List<MarketPriceRecord> _marketRecords = [];

  @override
  void initState() {
    super.initState();
    if (widget.prefillCrop != null) {
      _searchController.text = widget.prefillCrop!;
      _refreshCandidates(widget.prefillCrop!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshCandidates(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    final online = await CropBackendService.instance.search(query: q, limit: 8);
    if (online.isNotEmpty) {
      _suggestions = online.map((e) => e.name).toSet().toList();
    } else {
      final lower = q.toLowerCase();
      _suggestions = _knowledgeBase.allCrops
          .where((c) =>
              c.name.toLowerCase().contains(lower) ||
              c.category.toLowerCase().contains(lower))
          .take(8)
          .map((c) => c.name)
          .toList();
    }
  }

  Future<void> _runCheck(String cropName) async {
    FocusScope.of(context).unfocus();
    if (cropName.trim().isEmpty) return;
    setState(() {
      _checking = true;
      _result = null;
    });
    final result = await CropRecommendationService.instance.manualCheck(
      farm: widget.farm,
      cropName: cropName.trim(),
      variety: _selectedVariety,
    );
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
      _marketRecords = const [];
    });
    final market = await _loadMarketRecords(result.cropName);
    if (!mounted) return;
    setState(() => _marketRecords = market);
  }

  /// Cache-only market prices that match the checked crop (offline-safe).
  Future<List<MarketPriceRecord>> _loadMarketRecords(String cropName) async {
    final state = widget.farm.farmLocation?.state ?? '';
    if (state.isEmpty) return const [];
    try {
      final records = await MarketPriceService.instance.cachedPrices(
        state: state,
        district: widget.farm.farmLocation?.district,
        commodity: cropName,
      );
      final q = cropName.trim().toLowerCase();
      final matches =
          records.where((r) => r.commodity.toLowerCase().contains(q)).toList();
      final seen = <String>{};
      return matches
          .where((r) => seen.add('${r.commodity}|${r.market}'.toLowerCase()))
          .take(4)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _startCrop() async {
    final check = _result;
    if (check == null) return;
    if (widget.onStartManually != null) {
      await widget.onStartManually!(check);
      return;
    }
    final loc = AppLocalizations.of(context);
    final date = DateTime.now();
    await CropRecommendationService.instance.startManualCrop(
      farm: widget.farm,
      check: check,
      startDate: date,
    );
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VidhAIColorsX(context).surface,
        icon: const Icon(Icons.check_circle_rounded,
            color: Color(0xFF2E7D32), size: 40),
        title: Text(loc.t('cp_plan_generated'),
            style: TextStyle(color: VidhAIColorsX(context).onBackground)),
        content: Text(
          loc.t('cp_started_manual'),
          style: TextStyle(color: VidhAIColorsX(context).onSurfaceMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FarmWorkspaceScreen()));
            },
            child: Text(loc.t('cp_view_plan'),
                style: TextStyle(color: VidhAIColorsX(context).brandDeep)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      FarmDetailsScreen(farmId: widget.farm.farmId)));
            },
            child: Text(loc.t('cp_view_farm'),
                style: TextStyle(color: VidhAIColorsX(context).onSurfaceMuted)),
          ),
        ],
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
        leading: IconButton(
          icon: Icon(directionalIcon(context, Icons.arrow_back_ios_rounded),
              color: colors.onBackground, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.t('cp_manual_check_title'),
          style: TextStyle(
              color: colors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          const VidhAIAssistantButton(
              screen: 'manual_crop_check', size: 36, iconSize: 18),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            loc.t('cp_manual_check_hint'),
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          // Search field with suggestions
          RawAutocomplete<String>(
            textEditingController: _searchController,
            focusNode: FocusNode(),
            optionsBuilder: (value) => _suggestions.where((s) =>
                s.toLowerCase().contains(value.text.trim().toLowerCase())),
            onSelected: (v) => _searchController.text = v,
            fieldViewBuilder: (ctx, controller, focusNode, onSubmit) =>
                Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderColor),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                onChanged: (v) => _refreshCandidates(v),
                onSubmitted: (_) => _runCheck(controller.text),
                style: TextStyle(color: colors.onBackground),
                decoration: InputDecoration(
                  hintText: loc.t('cp_manual_check_hint'),
                  hintStyle:
                      TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: colors.onSurfaceMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search_rounded,
                        color: colors.brandDeep, size: 22),
                    onPressed: () => _runCheck(controller.text),
                  ),
                ),
              ),
            ),
            optionsViewBuilder: (ctx, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: colors.surface,
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 48,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final o in options.take(6))
                        ListTile(
                          dense: true,
                          title: Text(o,
                              style: TextStyle(
                                  color: colors.onBackground, fontSize: 13)),
                          onTap: () {
                            onSelected(o);
                            _runCheck(o);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_checking)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: colors.brandDeep),
              ),
            ),
          if (_result != null) ...[
            const SizedBox(height: 4),
            _ResultCard(
              check: _result!,
              marketRecords: _marketRecords,
              onStart: _startCrop,
              showCompare: widget.onStartManually != null,
              onOpenMarket: (commodity) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MarketPricesScreen(
                    initialState: widget.farm.farmLocation?.state,
                    initialDistrict: widget.farm.farmLocation?.district,
                    initialCommodity: commodity,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ManualCropCheck check;
  final List<MarketPriceRecord> marketRecords;
  final VoidCallback onStart;
  final bool showCompare;
  final ValueChanged<String> onOpenMarket;

  const _ResultCard({
    required this.check,
    required this.marketRecords,
    required this.onStart,
    required this.showCompare,
    required this.onOpenMarket,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final verdict = _verdictLabel(check.verdict, loc);
    final color = _verdictColor(check.verdict, colors);
    final notFound = !check.found;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: check.found ? colors.borderColor : colors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(check.cropName,
                        style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    if (check.variety != null && check.variety!.isNotEmpty)
                      Text('${loc.t('cp_choose_variety')}: ${check.variety}',
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  notFound
                      ? loc.t('cp_verdict_not')
                      : '$verdict · ${check.score}',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (notFound) ...[
            Text('${loc.t('cp_not_found_title')}:',
                style: TextStyle(
                    color: colors.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 4),
            Text(check.reason,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
          ] else ...[
            Text(check.reason,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
            const SizedBox(height: 12),
            Text(loc.t('cp_factors'),
                style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final f in check.factors)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Icon(
                      f.verdict == 'Excellent'
                          ? Icons.check_circle_rounded
                          : f.verdict == 'Potential Concern'
                              ? Icons.warning_amber_rounded
                              : Icons.error_rounded,
                      size: 16,
                      color: f.verdict == 'Excellent'
                          ? colors.brandDeep
                          : f.verdict == 'Potential Concern'
                              ? colors.warning
                              : colors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f.label,
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 13)),
                    ),
                    Text(_factorVerdictLabel(f.verdict, loc),
                        style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (check.estimates.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(loc.t('cp_estimates'),
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final e in check.estimates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(e.label,
                            style: TextStyle(
                                color: colors.onSurfaceMuted, fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(
                          '${e.value} (${e.accuracy == 'Verified' ? loc.t('cp_verified') : loc.t('cp_estimated')})',
                          style: TextStyle(
                              color: colors.onBackground, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (check.strengths.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(loc.t('cp_strengths'),
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final s in check.strengths)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: colors.brandDeep),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(s,
                            style: TextStyle(
                                color: colors.onSurfaceMuted, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
            ],
            if (check.concerns.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(loc.t('cp_concerns'),
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final c in check.concerns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          size: 14, color: colors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(c,
                            style: TextStyle(
                                color: colors.onSurfaceMuted, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
            ],
            if (check.seasonNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('${loc.t('cp_season_notes')}: ${check.seasonNotes}',
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
              ),
            if (check.regionNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${loc.t('cp_region_notes')}: ${check.regionNotes}',
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
              ),
            if (marketRecords.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMarketSection(context),
            ],
            if (showCompare)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.compare_rounded, color: colors.info, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(loc.t('cp_compare_with_ai'),
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: notFound ? null : onStart,
              icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
              label: Text(loc.t('cp_start_crop'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brandDeep,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (notFound)
            Text(loc.t('cp_start_not_allowed'),
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMarketSection(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onOpenMarket(check.cropName),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded,
                    color: colors.brandDeep, size: 16),
                const SizedBox(width: 6),
                Text(loc.marketLatestPrices,
                    style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text(loc.marketViewDetails,
                    style: TextStyle(color: colors.brandDeep, fontSize: 11)),
                Icon(Icons.chevron_right_rounded,
                    color: colors.brandDeep, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final r in marketRecords)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colors.brandDeep.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.agriculture_rounded,
                      color: colors.brandDeep, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r.market} · ${r.district}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colors.onBackground, fontSize: 12)),
                      if (r.date.isNotEmpty)
                        Text('${loc.marketUpdated}: ${r.date}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: colors.onSurfaceMuted, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  r.hasReliablePerKg
                      ? MarketFormat.inr(r.normalizedPricePerKg)
                      : loc.marketPriceUnitUnavailable,
                  style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(loc.marketDisclaimer,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
      ],
    );
  }

  String _verdictLabel(String verdict, AppLocalizations loc) {
    switch (verdict) {
      case 'Highly Suitable':
        return loc.t('cp_verdict_highly');
      case 'Suitable':
        return loc.t('cp_verdict_suitable');
      case 'Suitable with Conditions':
        return loc.t('cp_verdict_moderate');
      case 'Low Suitability':
        return loc.t('cp_verdict_marginal');
      case 'Not Recommended':
        return loc.t('cp_verdict_not');
      default:
        return verdict;
    }
  }

  String _factorVerdictLabel(String verdict, AppLocalizations loc) {
    switch (verdict) {
      case 'Excellent':
        return loc.t('cp_factor_excellent');
      case 'Potential Concern':
        return loc.t('cp_factor_concern');
      case 'Severe Risk':
        return loc.t('cp_factor_severe');
      default:
        return verdict;
    }
  }

  Color _verdictColor(String verdict, VidhAIColorsX colors) {
    switch (verdict) {
      case 'Highly Suitable':
      case 'Suitable':
        return colors.brandDeep;
      case 'Suitable with Conditions':
        return colors.info;
      case 'Low Suitability':
        return colors.warning;
      default:
        return colors.danger;
    }
  }
}
