import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/farm/screens/farm_details_screen.dart';
import 'package:vidhai/features/farm/screens/farm_workspace_screen.dart';
import 'package:vidhai/features/recommendations/screens/manual_crop_check_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/crop_backend_service.dart';
import 'package:vidhai/services/crop_recommendation_service.dart';
import 'package:vidhai/services/data_service.dart';

/// Top 10 crop recommendations for a farm.
///
/// Sources, in order: online structured engine (VidhAI backend `/crop/*`),
/// cached online results, then the local knowledge-base fallback. Every card
/// shows a suitability score, budget fit, reference (estimated) money figures
/// and the structured "why" text. "Start this crop" wires the crop into the
/// Workspace to-do list.
class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> {
  bool _isLoading = true;
  String? _error;
  FarmProfile? _farm;
  CropSetupQuestionnaire? _questionnaire;
  List<CropRecommendationResult> _top10 = const [];
  bool _offline = false;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    FarmProfile? farm;
    CropSetupQuestionnaire? questionnaire;
    try {
      if (args is Map<String, dynamic>) {
        farm = args['farm'] as FarmProfile?;
        questionnaire = args['questionnaire'] as CropSetupQuestionnaire?;
        if (farm == null) {
          final farms = await DataService().loadFarms();
          final match = farms.where((f) => f.farmId == args['farmId']);
          if (match.isNotEmpty) farm = match.first;
        }
      } else if (args is FarmProfile) {
        farm = args;
      } else if (args is String && args.isNotEmpty) {
        final farms = await DataService().loadFarms();
        final match = farms.where((f) => f.farmId == args);
        if (match.isNotEmpty) farm = match.first;
      }
      if (farm == null) {
        final farms = await DataService().loadFarms();
        debugPrint('[CropRecommendationScreen] no farm in route args '
            '(${args is Map ? "farmId=${args['farmId']}" : "args=${args?.runtimeType}"}); '
            'loaded ${farms.length} farm(s)');
        if (farms.isNotEmpty) farm = farms.first;
      }
      debugPrint('[CropRecommendationScreen] selected farm: '
          '${farm?.farmId ?? 'null'} (${farm?.farmName ?? '-'})');
    } catch (e) {
      debugPrint('[CropRecommendationScreen] farm resolution failed: $e');
    }
    setState(() {
      _farm = farm;
      _questionnaire = questionnaire;
    });
    if (farm == null) {
      setState(() {
        _isLoading = false;
        _error = 'farm_not_loaded';
      });
      return;
    }

    try {
      final results = await CropRecommendationService.instance.getRecommendations(
        farm: farm,
        questionnaire: questionnaire ?? CropSetupQuestionnaire(),
      );
      if (!mounted) return;
      setState(() {
        _top10 = results;
        _offline = results.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[CropRecommendationScreen] getRecommendations failed: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Forces a fresh AI run: clears the cached online results so a changed
  /// context (updated farm, new season, market data) always re-evaluates.
  Future<void> _refresh() async {
    final farm = _farm;
    if (farm == null || _isLoading) return;
    await CropBackendService.instance.clearTop10Cache(farm.farmId);
    setState(() {
      _isLoading = true;
      _top10 = const [];
      _error = null;
    });
    await _load();
  }

  VidhAIColorsX get colors => VidhAIColorsX(context);

  Future<void> _startCrop(CropRecommendationResult rec) async {
    final farm = _farm;
    if (farm == null) return;

    final startDate = await _askStartDateAndVariety(rec);
    if (startDate == null || !mounted) return;

    final date = startDate.$1;
    final variety = startDate.$2;
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircularProgressIndicator(color: colors.brandDeep),
              const SizedBox(width: 16),
              Text(loc.t('cp_plan_generated_loading'),
                  style: TextStyle(color: colors.onBackground)),
            ],
          ),
        ),
      ),
    );

    try {
      final plan = await CropRecommendationService.instance.startCrop(
        farm: farm,
        recommendation: rec,
        startDate: date,
        varietyOverride: variety,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // loading dialog
      await _showPlanSuccess(plan, farm.farmId);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${loc.t('cp_start_failed')} $e'),
        backgroundColor: colors.danger,
      ));
    }
  }

  Future<(DateTime?, String?)?> _askStartDateAndVariety(
      CropRecommendationResult rec) async {
    final loc = AppLocalizations.of(context);
    DateTime selectedDate = DateTime.now();
    String? selectedVariety =
        rec.varieties.isNotEmpty ? rec.varieties.first : null;
    final result = await showDialog<(DateTime, String?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
              loc.t('cp_start_dialog_title').replaceAll('{crop}', rec.cropName),
              style: TextStyle(color: colors.onBackground)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.t('cp_start_date'),
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      icon: Icon(Icons.calendar_month_rounded,
                          size: 18, color: colors.brandDeep),
                      label: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: TextStyle(color: colors.onBackground),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        setState(() => selectedDate = DateTime.now()),
                    child: Text(
                        '${loc.t('cp_today')} (${DateTime.now().day}/${DateTime.now().month})',
                        style: TextStyle(color: colors.brandDeep)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(loc.t('cp_choose_variety'),
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedVariety,
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.onBackground),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.borderColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: (rec.varieties.isEmpty ? [rec.cropName] : rec.varieties)
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v,
                            style: TextStyle(color: colors.onBackground))))
                    .toList(),
                onChanged: (v) => setState(() => selectedVariety = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.cancel,
                  style: TextStyle(color: colors.onSurfaceMuted)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop((selectedDate, selectedVariety)),
              child: Text(loc.t('cp_start_crop'),
                  style: TextStyle(color: colors.brandDeep)),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _showPlanSuccess(CropPlan plan, String farmId) async {
    final loc = AppLocalizations.of(context);
    final tasks = await DataService().loadCropTasks(plan.cropId);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        icon:
            Icon(Icons.check_circle_rounded, color: colors.brandDeep, size: 40),
        title: Text(loc.t('cp_plan_generated'),
            style: TextStyle(color: colors.onBackground),
            textAlign: TextAlign.center),
        content: Text(
          loc.t('cp_tasks_generated').replaceAll('{count}', '${tasks.length}'),
          style: TextStyle(color: colors.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FarmWorkspaceScreen()));
            },
            child: Text(loc.t('cp_view_plan'),
                style: TextStyle(color: colors.brandDeep)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FarmDetailsScreen(farmId: farmId)));
            },
            child: Text(loc.t('cp_view_farm'),
                style: TextStyle(color: colors.onSurfaceMuted)),
          ),
        ],
      ),
    );
  }

  void _openManualCheck({String? prefill}) {
    if (_farm == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ManualCropCheckScreen(
        farm: _farm!,
        prefillCrop: prefill,
        onStartManually: (check) async {
          final rec =
              _top10.where((r) => r.cropId == check.matchedCrop).firstOrNull;
          if (rec != null) {
            await _startCrop(rec);
          }
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
          AppLocalizations.of(context).t('cp_title'),
          style: TextStyle(
              color: colors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: colors.onBackground, size: 20),
            onPressed: _isLoading ? null : _refresh,
            tooltip: AppLocalizations.of(context).t('cp_refresh'),
          ),
          const VidhAIAssistantButton(
              screen: 'crop_recommendation', size: 36, iconSize: 18),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final loc = AppLocalizations.of(context);
    if (_isLoading) return const _LoadingView();
    if (_farm == null || _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.agriculture_rounded,
                  color: colors.onSurfaceMuted, size: 48),
              const SizedBox(height: 12),
              Text(loc.t('cp_empty'),
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    if (_top10.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(loc.t('cp_empty'),
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
              textAlign: TextAlign.center),
        ),
      );
    }
    final state = _farm!.farmLocation?.state ?? '';
    final season = _questionnaire?.currentSeason.isNotEmpty == true
        ? _questionnaire!.currentSeason
        : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          loc
              .t('cp_subtitle')
              .replaceAll('{state}', state.isNotEmpty ? state : '-')
              .replaceAll('{season}', season.isNotEmpty ? season : '-'),
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
        ),
        const SizedBox(height: 4),
        if (_offline)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: colors.warning, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(loc.t('cp_offline'),
                      style: TextStyle(color: colors.warning, fontSize: 12)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        // Manual check entry point
        _ManualCheckEntryCard(onTap: () => _openManualCheck()),
        const SizedBox(height: 14),
        _SummaryHeader(results: _top10),
        const SizedBox(height: 14),
        Text(loc.t('cp_result_label'),
            style: TextStyle(
                color: colors.onBackground,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(loc.t('cp_ai_note'),
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
        const SizedBox(height: 12),
        for (var i = 0; i < _top10.length; i++) ...[
          _RankedCard(
            result: _top10[i],
            expanded: _expandedIndex == i,
            onExpand: () =>
                setState(() => _expandedIndex = _expandedIndex == i ? null : i),
            onStart: () => _startCrop(_top10[i]),
            onCompare: () => _openManualCheck(prefill: _top10[i].cropName),
          ),
          if (i != _top10.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RankedCard extends StatelessWidget {
  final CropRecommendationResult result;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onStart;
  final VoidCallback onCompare;

  const _RankedCard({
    required this.result,
    required this.expanded,
    required this.onExpand,
    required this.onStart,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final color = _scoreColor(result.score, colors);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.rank == 1
              ? colors.brandDeep.withValues(alpha: 0.4)
              : colors.borderColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onExpand,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ScoreBadge(
                        rank: result.rank, score: result.score, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.cropName,
                              style: TextStyle(
                                  color: colors.onBackground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${result.category} · ${result.durationLabel} · ${result.marketDemand.isEmpty ? result.season : result.marketDemand} demand',
                            style: TextStyle(
                                color: colors.onSurfaceMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: colors.onSurfaceMuted),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _calendarChip(result, colors, loc),
                    _chip('${loc.t('cp_estimated')} ${loc.t('cp_ai_based')}',
                        colors),
                    _chip(
                        _budgetLabel(result.budget.classification, loc), colors,
                        emphasized: result.budget.isWithinBudget),
                    if (result.confidence.isNotEmpty)
                      _chip('${loc.t('cp_confidence')}: ${result.confidence}',
                          colors),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _compactWhy(result, loc),
                  maxLines: expanded ? null : 2,
                  overflow: expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                ),
                if (expanded) ...[
                  const SizedBox(height: 12),
                  Divider(color: colors.borderColor),
                  _factRow(
                      loc.t('cp_investment'),
                      _inr(result.budget.cultivationCostMin,
                          result.budget.cultivationCostMax),
                      colors),
                  _factRow(
                      loc.t('cp_yield'),
                      '${_money(result.money.yieldMin)}-${_money(result.money.yieldMax)} ${result.money.yieldUnit}',
                      colors),
                  _factRow(
                      loc.t('cp_revenue'),
                      _inr(result.money.revenueMin, result.money.revenueMax),
                      colors),
                  _factRow(
                      loc.t('cp_profit'),
                      _inr(result.money.profitMin, result.money.profitMax),
                      colors,
                      green: true),
                  _factRow(loc.t('cp_planting_window'), result.plantingWindow,
                      colors),
                  if (result.harvestHint.isNotEmpty)
                    _factRow(
                        loc.t('cp_harvest_hint'), result.harvestHint, colors),
                  if (result.waterNotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('💧 ${result.waterNotes}',
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 12)),
                    ),
                  if (result.factors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(loc.t('cp_factors'),
                        style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    for (final f in result.factors.take(6))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.circle,
                                size: 8,
                                color: f.score >= 0.75
                                    ? colors.brandDeep
                                    : f.score >= 0.5
                                        ? colors.warning
                                        : colors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${f.name}: ${f.detail}',
                                  style: TextStyle(
                                      color: colors.onSurfaceMuted,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (result.risks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('${loc.t('cp_risks')}: ${result.risks.join(', ')}',
                        style: TextStyle(color: colors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  _sectionHeader(loc.t('cp_calendar'), colors),
                  _factRow(loc.t('cp_planting_window'), result.plantingWindow,
                      colors),
                  if (result.sowingWindow != null &&
                      result.sowingWindow != result.plantingWindow)
                    _factRow(loc.t('cp_sowing_window'), result.sowingWindow!,
                        colors),
                  if (result.harvestWindowLocal != null)
                    _factRow(loc.t('cp_harvest_hint'),
                        result.harvestWindowLocal!, colors),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_calendarLabel(result, loc),
                        style: TextStyle(
                            color: _calendarColor(result, colors),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (result.rotationAnalysis != null) ...[
                    const SizedBox(height: 12),
                    _sectionHeader(loc.t('cp_rotation'), colors),
                    _factRow(
                        loc.t('cp_previous_crop'),
                        result.previousCrop?.isNotEmpty == true
                            ? result.previousCrop!
                            : loc.t('cp_no_prior_crop'),
                        colors),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(result.rotationAnalysis!,
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 12)),
                    ),
                  ],
                  if (result.costPerAcre != null ||
                      result.profitMarginPct != null) ...[
                    const SizedBox(height: 12),
                    _sectionHeader(loc.t('cp_economics'), colors),
                    if (result.costPerAcre != null)
                      _factRow(
                          loc.t('cp_cost_per_acre'),
                          _moneyD(result.costPerAcre),
                          colors),
                    if (result.revenuePerAcre != null)
                      _factRow(loc.t('cp_revenue_per_acre'),
                          _moneyD(result.revenuePerAcre), colors),
                    if (result.profitPerAcre != null)
                      _factRow(
                          loc.t('cp_profit_per_acre'),
                          _moneyD(result.profitPerAcre),
                          colors,
                          green: true),
                    if (result.profitMarginPct != null)
                      _factRow(loc.t('cp_profit_margin'),
                          '${result.profitMarginPct!.round()}%', colors),
                    if (result.marketPricePerKg != null)
                      _factRow(
                          loc.t('cp_market_price'),
                          loc.t('cp_price_per_kg').replaceAll(
                              '{price}',
                              result.marketPricePerKg!.toStringAsFixed(
                                  result.marketPricePerKg! < 10 ? 2 : 0)),
                          colors),
                    if (result.farmAreaAcres != null &&
                        result.totalCost != null) ...[
                      const SizedBox(height: 6),
                      Divider(color: colors.borderColor),
                      _factRow(
                          '${loc.t('cp_farm_area')} (${loc.t('cp_acres')})',
                          '${result.farmAreaAcres!}',
                          colors),
                      if (result.totalCost != null)
                        _factRow(loc.t('cp_total_investment'),
                            _moneyD(result.totalCost), colors),
                      if (result.totalRevenue != null)
                        _factRow(loc.t('cp_total_revenue'),
                            _moneyD(result.totalRevenue), colors),
                      if (result.totalProfit != null)
                        _factRow(
                            loc.t('cp_total_profit'),
                            _moneyD(result.totalProfit),
                            colors,
                            green: true),
                    ],
                    if (result.costBreakdown != null &&
                        result.costBreakdown!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(loc.t('cp_cost_split'),
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      for (final line in result.costBreakdown!
                          .take(4)
                          .toList())
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(_costLabel(line.label, loc),
                                    style: TextStyle(
                                        color: colors.onSurfaceMuted,
                                        fontSize: 11)),
                              ),
                              Expanded(
                                child: Text('${line.sharePct.round()}%',
                                    style: TextStyle(
                                        color: colors.onBackground,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                              Text(_moneyD(line.amountPerAcre),
                                  style: TextStyle(
                                      color: colors.onSurfaceMuted,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                    ],
                  ],
                  if (result.riskExplanation != null) ...[
                    const SizedBox(height: 12),
                    _sectionHeader(loc.t('cp_risk_analysis'), colors),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(result.riskExplanation!,
                          style: TextStyle(color: colors.danger, fontSize: 12)),
                    ),
                  ],
                  if (result.confidencePct > 0 ||
                      result.dataSources.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionHeader(loc.t('cp_confidence_pct'), colors),
                    if (result.confidencePct > 0)
                      _factRow(
                          loc.t('cp_confidence_pct'),
                          '${result.confidencePct.round()}%'
                              ' · ${_confidenceLabel(result.confidencePct, loc)}',
                          colors),
                    if (result.dataSources.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final src in result.dataSources.take(8))
                            _chip(src, colors),
                          _chip(_weatherLabel(result.weatherAvailability, loc),
                              colors),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCompare,
                          icon: Icon(Icons.compare_rounded,
                              size: 16, color: colors.onSurfaceMuted),
                          label: Text(loc.t('cp_compare'),
                              style: TextStyle(color: colors.onSurfaceMuted)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.borderColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('${loc.t('cp_score')}: ${result.score}',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: onStart,
                      icon:
                          const Icon(Icons.play_circle_fill_rounded, size: 18),
                      label: Text(loc.t('cp_start_crop'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brandDeep,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                        '${loc.t('cp_planting_window')}: ${result.plantingWindow}',
                        style: TextStyle(
                            color: colors.onSurfaceMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _compactWhy(CropRecommendationResult result, AppLocalizations loc) {
    if (result.strengths.isNotEmpty) return result.strengths.join('. ');
    if (result.factors.isNotEmpty) {
      return result.factors
          .where((f) => f.score >= 0.7)
          .take(2)
          .map((f) => f.detail)
          .join('; ');
    }
    return loc.t('cp_ai_based');
  }

  Color _scoreColor(int score, VidhAIColorsX colors) {
    if (score >= 80) return colors.brandDeep;
    if (score >= 60) return colors.info;
    return colors.warning;
  }

  Widget _chip(String label, VidhAIColorsX colors, {bool emphasized = false}) {
    final c = emphasized ? colors.brandDeep : colors.onSurfaceMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (emphasized ? colors.brandDeep : c)
            .withValues(alpha: emphasized ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style:
              TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  String _budgetLabel(String classification, AppLocalizations loc) {
    switch (classification) {
      case 'Within':
        return loc.t('cp_within_budget');
      case 'Slightly Above':
        return loc.t('cp_slightly_above_budget');
      case 'Far Above':
        return loc.t('cp_far_above_budget');
      default:
        return loc.t('cp_budget_not_set');
    }
  }

  String _inr(int min, int max) {
    if (min <= 0 && max <= 0) return '-';
    return '${_money(min)}-${_money(max)}';
  }

  String _money(int v) {
    if (v <= 0) return '-';
    return '₹${_group(v)}';
  }

  String _group(int n) {
    String raw = n.toString();
    if (raw.length <= 3) return raw;
    final last3 = raw.substring(raw.length - 3);
    var rest = raw.substring(0, raw.length - 3);
    final buf = StringBuffer(last3);
    while (rest.length > 2) {
      buf.write(',${rest.substring(rest.length - 2)}');
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) buf.write(',$rest');
    return buf.toString().split(',').reversed.join(',');
  }

  Widget _factRow(String label, String value, VidhAIColorsX colors,
      {bool green = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: green ? colors.brandDeep : colors.onBackground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, VidhAIColorsX colors) => Text(
        title,
        style: TextStyle(
            color: colors.onBackground,
            fontSize: 13,
            fontWeight: FontWeight.w700),
      );

  Widget _calendarChip(
      CropRecommendationResult result, VidhAIColorsX colors,
      AppLocalizations loc) {
    final color = _calendarColor(result, colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_calendarLabel(result, loc),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Color _calendarColor(CropRecommendationResult result, VidhAIColorsX colors) {
    switch (result.calendarStatus) {
      case 'ideal_now':
        return colors.brandDeep;
      case 'sow_soon':
        return colors.warning;
      case 'next_window':
        return colors.info;
      default:
        return colors.onSurfaceMuted;
    }
  }

  String _calendarLabel(CropRecommendationResult result, AppLocalizations loc) {
    switch (result.calendarStatus) {
      case 'ideal_now':
        return loc.t('cp_cal_ideal');
      case 'sow_soon':
        return loc.t('cp_cal_sow_soon');
      case 'next_window':
        return loc.t('cp_cal_next');
      case 'not_now':
        return loc.t('cp_cal_not_now');
      case 'unknown':
      default:
        return loc.t('cp_cal_unknown');
    }
  }

  String _weatherLabel(String? status, AppLocalizations loc) {
    switch (status) {
      case 'available':
        return loc.t('cp_weather_available');
      case 'cached':
        return loc.t('cp_weather_cached');
      case 'absent':
      default:
        return loc.t('cp_weather_absent');
    }
  }

  String _confidenceLabel(double pct, AppLocalizations loc) {
    if (pct >= 85) return loc.t('cp_verdict_highly');
    if (pct >= 65) return loc.t('cp_factor_excellent');
    return loc.t('cp_verdict_moderate');
  }

  String _costLabel(String label, AppLocalizations loc) {
    switch (label) {
      case 'seed':
        return loc.t('cp_cost_seed');
      case 'fertilizer':
        return loc.t('cp_cost_fertilizer');
      case 'pesticide':
        return loc.t('cp_cost_pesticide');
      case 'labour':
        return loc.t('cp_cost_labour');
      case 'irrigation':
        return loc.t('cp_cost_irrigation');
      case 'machinery':
        return loc.t('cp_cost_machinery');
      case 'other':
      default:
        return loc.t('cp_cost_other');
    }
  }

  String _moneyD(double? v) {
    if (v == null || v <= 0) return '-';
    return '₹${_group(v.round())}';
  }
}

class _SummaryHeader extends StatefulWidget {
  final List<CropRecommendationResult> results;

  const _SummaryHeader({required this.results});

  @override
  State<_SummaryHeader> createState() => _SummaryHeaderState();
}

class _SummaryHeaderState extends State<_SummaryHeader> {
  bool _showCompare = false;

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final results = widget.results;
    final best = results.first;
    final toCompare = results.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: colors.brandDeep.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colors.brandDeep.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.eco_rounded, color: colors.brandDeep, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.t('cp_best_match'),
                    style: TextStyle(
                        color: colors.brandDeep,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${best.rank}. ${best.cropName}',
                          style: TextStyle(
                              color: colors.onBackground,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        '${best.category} · ${best.durationLabel}',
                        style: TextStyle(
                            color: colors.onSurfaceMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.brandDeep.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${best.score}',
                      style: TextStyle(
                          color: colors.brandDeep,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _summaryChip(_scoreStatus(best, loc), colors.brandDeep, colors),
                if (best.profitMarginPct != null)
                  _summaryChip(
                      '${loc.t('cp_profit_margin')} ~${best.profitMarginPct!.round()}%',
                      colors.brandDeep,
                      colors),
                if (best.confidencePct > 0)
                  _summaryChip(
                      '${loc.t('cp_confidence_pct')} ${best.confidencePct.round()}%',
                      colors.info,
                      colors),
              ],
            ),
            if (best.rotationAnalysis != null) ...[
              const SizedBox(height: 8),
              Text(best.rotationAnalysis!,
                  style: TextStyle(
                      color: colors.onSurfaceMuted, fontSize: 12)),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showCompare = !_showCompare),
                icon: Icon(
                    _showCompare
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: colors.brandDeep),
                label: Text(
                    _showCompare
                        ? loc.t('cp_hide_compare')
                        : loc.t('cp_compare_top'),
                    style: TextStyle(color: colors.brandDeep, fontSize: 13)),
              ),
            ),
            if (_showCompare) _ComparisonTable(results: toCompare),
          ],
        ),
      ),
    );
  }

  String _scoreStatus(CropRecommendationResult best, AppLocalizations loc) {
    final s = best.calendarStatus;
    if (s == 'ideal_now') return loc.t('cp_cal_ideal');
    if (s == 'sow_soon') return loc.t('cp_cal_sow_soon');
    if (s == 'next_window') return loc.t('cp_cal_next');
    if (s == 'not_now') return loc.t('cp_cal_not_now');
    return '$best.score';
  }

  Widget _summaryChip(String label, Color color, VidhAIColorsX colors) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _ComparisonTable extends StatelessWidget {
  final List<CropRecommendationResult> results;

  const _ComparisonTable({required this.results});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row([
                _head(loc.t('cp_col_crop'), colors),
                _head(loc.t('cp_col_score'), colors),
                _head(loc.t('cp_col_cost'), colors),
                _head(loc.t('cp_col_margin'), colors),
                _head(loc.t('cp_col_sowing'), colors),
              ], colors, header: true),
              for (final r in results)
                _row([
                  Text('${r.rank}. ${r.cropName}',
                      style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  _cell('${r.score}', colors),
                  _cell(
                      r.costPerAcre != null
                          ? '₹${r.costPerAcre!.round()}'
                          : '-',
                      colors),
                  _cell(
                      r.profitMarginPct != null
                          ? '${r.profitMarginPct!.round()}%'
                          : '-',
                      colors),
                  _cell(_sowingShort(r, loc), colors),
                ], colors),
            ],
          ),
        ),
      ),
    );
  }

  String _sowingShort(CropRecommendationResult r, AppLocalizations loc) {
    switch (r.calendarStatus) {
      case 'ideal_now':
        return loc.t('cp_cal_ideal');
      case 'sow_soon':
        return loc.t('cp_cal_sow_soon');
      case 'next_window':
        return loc.t('cp_cal_next');
      case 'not_now':
        return loc.t('cp_cal_not_now');
      default:
        return '-';
    }
  }

  Widget _head(String label, VidhAIColorsX colors) => Text(label,
      style: TextStyle(
          color: colors.onSurfaceMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700));

  Widget _cell(String value, VidhAIColorsX colors) => Text(value,
      style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11));

  Widget _row(List<Widget> cells, VidhAIColorsX colors, {bool header = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 120, child: cells[0]),
          SizedBox(width: 40, child: cells[1]),
          SizedBox(width: 70, child: cells.length > 2 ? cells[2] : null),
          SizedBox(
              width: 60,
              child: cells.length > 3 ? cells[3] : null),
          SizedBox(
              width: 110,
              child: cells.length > 4 ? cells[4] : null),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int rank;
  final int score;
  final Color color;

  const _ScoreBadge(
      {required this.rank, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$score',
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            Text('#$rank',
                style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ManualCheckEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ManualCheckEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Material(
      color: colors.info.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.travel_explore_rounded, color: colors.info, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.t('cp_manual_check_title'),
                        style: TextStyle(
                            color: colors.info,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(loc.t('cp_manual_check_hint'),
                        style: TextStyle(
                            color: colors.onSurfaceMuted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(directionalIcon(context, Icons.chevron_right_rounded),
                  color: colors.info),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: colors.brandDeep),
          ),
          const SizedBox(height: 16),
          Text(loc.t('cp_loading'),
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
