import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/features/home/screens/weather_details_screen.dart';
import 'package:vidhai/features/farm/screens/add_farm_screen.dart';
import 'package:vidhai/features/farm/screens/crop_setup_screen.dart';
import 'package:vidhai/features/farm/screens/farm_workspace_screen.dart';
import 'package:vidhai/features/farm/crop_stage.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/farm_records/screens/expenses_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';
import 'package:vidhai/services/farm_ai_summary_service.dart';

class FarmDetailsScreen extends StatefulWidget {
  final String farmId;

  const FarmDetailsScreen({super.key, required this.farmId});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  FarmProfile? _farm;
  CropRecord? _crop;
  List<CropRecord> _cropHistory = [];
  List<ExpenseRecord> _expenses = [];
  bool _isLoading = true;
  FarmAiSummaryData? _aiSummary;
  bool _summaryLoading = true;

  final NumberFormat _currencyNoDec = NumberFormat('#,##,##0', 'en_IN');
  final NumberFormat _currencyDec = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final farms = await DataService().loadFarms();
      if (!mounted) return;
      for (final f in farms) {
        if (f.farmId == widget.farmId) {
          _farm = f;
          break;
        }
      }
    } catch (_) {}

    if (_farm != null) {
      try {
        final crops = await DataService().loadCrops(widget.farmId);
        if (!mounted) return;
        CropRecord? primary;
        for (final c in crops) {
          if (c.status == 'active') {
            primary = c;
            break;
          }
        }
        _crop = primary;
        _cropHistory = crops.where((c) => !c.isActive).toList()
          ..sort((a, b) => (b.endDate ?? b.plantingDate)
              .compareTo(a.endDate ?? a.plantingDate));
      } catch (_) {}

      try {
        final expenses = await DataService().loadExpenses(widget.farmId);
        if (!mounted) return;
        _expenses = expenses;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _loadAiSummary();
  }

  Future<void> _loadAiSummary() async {
    final farm = _farm;
    if (farm == null) return;
    if (!mounted) return;
    setState(() => _summaryLoading = true);
    final loc = AppLocalizations.of(context);
    try {
      final summary = await FarmAiSummaryService.instance
          .summarize(farm, languageCode: loc.languageCode);
      if (!mounted) return;
      setState(() {
        _aiSummary = summary;
        _summaryLoading = false;
      });
    } catch (e) {
      debugPrint('[FarmAiSummary] failed: $e');
      if (!mounted) return;
      setState(() => _summaryLoading = false);
    }
  }

  Future<void> _openEdit() async {
    if (_farm == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddFarmScreen(initialFarm: _farm)),
    );
    _loadData();
  }

  void _showCropMenu(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.play_circle_fill_rounded,
                  color: colors.brandDeep, size: 22),
              title: Text(loc.t('fd_start_crop')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CropSetupScreen(farmId: widget.farmId)),
                ).then((_) => _loadData());
              },
            ),
            if (_crop != null)
              ListTile(
                leading: Icon(Icons.stop_circle_outlined,
                    color: colors.danger, size: 22),
                title: Text(
                  loc.t('fd_end_crop'),
                  style: TextStyle(color: colors.danger),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _endCropFlow(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00')
        ? '₹${_currencyNoDec.format(v.round())}'
        : '₹${_currencyDec.format(v)}';
  }

  String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Seeds':
        return const Color(0xFF8BC34A);
      case 'Fertilizer':
        return const Color(0xFFFF9800);
      case 'Labor':
        return const Color(0xFF2196F3);
      case 'Equipment':
        return const Color(0xFF9C27B0);
      case 'Irrigation':
        return const Color(0xFF00BCD4);
      case 'Transport':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFF607D8B);
    }
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
          loc.farmDetails,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_farm != null)
            TextButton.icon(
              onPressed: _openEdit,
              icon:
                  Icon(Icons.edit_outlined, color: colors.brandDeep, size: 16),
              label: Text(
                loc.edit,
                style: TextStyle(
                  color: colors.brandDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          VidhAIAssistantButton(
            screen: 'farm_details',
            targetFarmId: widget.farmId,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.brandDeep))
          : _farm == null
              ? Center(
                  child: Text(loc.farmNotFound,
                      style: TextStyle(color: colors.onSurfaceMuted)))
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadData,
      color: colors.brandDeep,
      backgroundColor: colors.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _buildHero(context),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCropMenu(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brandDeep,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.eco_rounded, size: 18),
              label: Text(
                loc.crop,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
          _sectionTitle(context, loc.t('fs_title')),
          _buildAiSummaryCard(context),
          _sectionTitle(context, loc.cropStatus),
          _buildCropStatusCard(context),
          _sectionTitle(
              context, AppLocalizations.of(context).t('fd_crop_history')),
          _buildCropHistoryCard(context),
          _sectionTitle(context, loc.farmInformation),
          _buildFarmInfoCard(context),
          _sectionTitle(context, loc.expenses),
          _buildExpensesCard(context),
          _sectionTitle(context, loc.tools),
          _buildToolsGrid(context),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final colors = VidhAIColorsX(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        title,
        style: TextStyle(
          color: colors.onSurfaceMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Widget child) {
    final colors = VidhAIColorsX(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderColor),
      ),
      child: child,
    );
  }

  Widget _buildAiSummaryCard(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final summary = _aiSummary;
    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: colors.brandDeep, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.t('fs_title'),
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _summaryLoading ? null : _loadAiSummary,
                tooltip: loc.t('fs_refresh'),
                icon: Icon(Icons.refresh_rounded,
                    color:
                        _summaryLoading ? colors.borderColor : colors.brandDeep,
                    size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (summary != null && summary.online && summary.aiNarrative != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('fs_ai').toUpperCase(),
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.aiNarrative!,
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          if (summary != null && !summary.online)
            Text(
              loc.t('fs_offline_note'),
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11.5),
            ),
          const SizedBox(height: 8),
          if (_summaryLoading && summary == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.brandDeep),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    loc.t('fs_from_records').toLowerCase(),
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (summary != null) ...[
            _summaryBullet(loc.t('fs_from_records'), true),
            ..._bulletItems(context, summary).map((b) => _summaryBullet(b)),
          ],
        ],
      ),
    );
  }

  Widget _summaryBullet(String text, [bool isHeader = false]) {
    final colors = VidhAIColorsX(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              isHeader ? Icons.check_circle_rounded : Icons.circle,
              size: isHeader ? 12 : 5,
              color: isHeader ? colors.brandDeep : colors.onSurfaceMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isHeader ? colors.onSurfaceMuted : colors.onBackground,
                fontSize: 12.5,
                fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _bulletItems(BuildContext context, FarmAiSummaryData s) {
    final loc = AppLocalizations.of(context);
    final items = <String>[];
    if (s.hasActiveCrop && s.activeCrop != null) {
      items.add(loc
          .t('fs_active_crop')
          .replaceAll('{crop}', s.activeCrop!)
          .replaceAll('{stage}', s.cropStage ?? '')
          .replaceAll('{progress}', '${s.cropProgressPct ?? 0}'));
    } else {
      items.add(loc.t('fs_no_active_crop'));
    }
    if (s.weatherAvailable) {
      final cond = s.weatherCondition ?? '';
      final temp = s.temperature?.toStringAsFixed(0) ?? '';
      items.add(loc
          .t('fs_weather')
          .replaceAll('{condition}', cond)
          .replaceAll('{temp}', temp)
          .replaceAll('{humidity}', '${s.humidity ?? 0}'));
      if (s.heatAlert) items.add(loc.t('fs_weather_heat'));
      if (s.rainAlert) items.add(loc.t('fs_weather_rain'));
    }
    if (s.marketAvailable) {
      items.add(loc.t('fs_market').replaceAll('{count}', '${s.marketCount}'));
    } else {
      items.add(loc.t('fs_no_market'));
    }
    if (s.historyNames.isNotEmpty) {
      items.add(
          loc.t('fs_history').replaceAll('{names}', s.historyNames.join(', ')));
    }
    if (s.expenseCount > 0) {
      final totalStr =
          _currencyDec.format(s.expenseTotal).replaceAll('.00', '');
      items.add(loc
          .t('fs_expenses')
          .replaceAll('{total}', totalStr)
          .replaceAll('{count}', '${s.expenseCount}'));
    }
    return items;
  }

  List<String> _locationLines() {
    final loc = AppLocalizations.of(context);
    final addr = _farm?.farmLocation;
    final place = extractPlace(addr);
    final districtRaw = extractDistrict(addr);
    final state = extractStateValue(addr);
    final districtPart = districtRaw != null && districtRaw.isNotEmpty
        ? districtLabel(districtRaw, loc.district)
        : '';
    final regionPart =
        [districtPart, state ?? ''].where((s) => s.isNotEmpty).join(', ');
    final lines = <String>[
      if (place != null &&
          place.isNotEmpty &&
          place.toLowerCase() != (districtRaw?.toLowerCase() ?? ''))
        place,
      if (regionPart.isNotEmpty) regionPart,
    ];
    return lines;
  }

  Widget _buildHero(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final farm = _farm!;
    final cropName = _crop?.cropName ?? '';
    final hasCrop = cropName.isNotEmpty;
    final farmTitle = farm.farmName.isNotEmpty
        ? farm.farmName
        : (hasCrop ? cropName : loc.farm);
    final locationLines = _locationLines();
    final stage = _crop != null ? computeCropStage(_crop!) : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colors.brandDeep.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco_rounded,
              color: colors.brandDeep,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            farmTitle,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasCrop) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.eco_rounded, color: colors.brandDeep, size: 16),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    cropName,
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (locationLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: colors.onSurfaceMuted,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: locationLines
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              line,
                              style: TextStyle(
                                color: colors.onSurfaceMuted,
                                fontSize: 13.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (stage?.stage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${loc.stage} • ${stage!.stage}',
                style: TextStyle(
                  color: colors.brandDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              '${loc.stage} • ${loc.notSet}',
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildCropStatusCard(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final crop = _crop;
    final cropName = crop?.cropName ?? '';

    if (crop == null || cropName.isEmpty) {
      return _card(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grass, color: colors.brandDeep, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.t('fd_crop_no_active'),
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CropSetupScreen(farmId: widget.farmId),
                  ),
                ).then((_) => _loadData()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brandDeep,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                label: Text(loc.t('fd_start_crop')),
              ),
            ),
          ],
        ),
      );
    }

    final stageInfo = computeCropStage(crop);
    final stage = stageInfo.stage;
    final progress = stageInfo.progress;
    final currentIndex =
        progress != null ? kCropStages.indexOf(stage ?? '') : -1;

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(context, loc.crop, cropName),
          const SizedBox(height: 4),
          _infoRow(context, loc.currentStage, stage ?? loc.notSet,
              mutedValue: stage == null),
          if (progress != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colors.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(colors.brandDeep),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: kCropStages.asMap().entries.map((entry) {
                final isCurrent = entry.key == currentIndex;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent ? colors.brandDeep : colors.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCurrent ? colors.brandDeep : colors.borderColor,
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isCurrent ? Colors.white : colors.onSurfaceMuted,
                      fontSize: 11,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          if (crop.cropPlanId != null && crop.cropPlanId!.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FarmWorkspaceScreen(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.brandDeep,
                  side: BorderSide(
                      color: colors.brandDeep.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: Text(
                  loc.t('fd_view_plan'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _endCropFlow(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.danger,
                side: BorderSide(color: colors.danger.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: Text(
                loc.t('fd_end_crop'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _endCropFlow(BuildContext context) async {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final crop = _crop;
    if (crop == null) return;

    String status = 'harvested';
    String? notes;
    final notesController = TextEditingController();
    final cropName = crop.cropName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final statusOptions = [
            (loc.t('fd_end_status_harvested'), 'harvested'),
            (loc.t('fd_end_status_completed'), 'completed'),
            (loc.t('fd_end_status_stopped'), 'stopped'),
            (loc.t('fd_end_status_abandoned'), 'abandoned'),
            (loc.t('fd_end_status_failed'), 'failed'),
          ];
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text('${loc.t('fd_end_crop_title')}: $cropName',
                style: TextStyle(color: colors.onBackground)),
            content: SingleChildScrollView(
              child: RadioGroup<String>(
                groupValue: status,
                onChanged: (value) => setState(() => status = value ?? status),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.t('fd_end_crop_subtitle'),
                        style: TextStyle(
                            color: colors.onSurfaceMuted, fontSize: 13)),
                    const SizedBox(height: 14),
                    for (final (label, code) in statusOptions)
                      RadioListTile<String>(
                        value: code,
                        dense: true,
                        title: Text(label,
                            style: TextStyle(
                                color: colors.onBackground, fontSize: 14)),
                        activeColor: colors.brandDeep,
                      ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      style: TextStyle(color: colors.onBackground),
                      decoration: InputDecoration(
                        hintText: loc.t('fd_end_crop_notes'),
                        hintStyle: TextStyle(color: colors.onSurfaceMuted),
                        filled: true,
                        fillColor: colors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.borderColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(loc.cancel,
                    style: TextStyle(color: colors.onSurfaceMuted)),
              ),
              TextButton(
                onPressed: () {
                  notes = notesController.text.trim();
                  Navigator.of(ctx).pop(true);
                },
                child: Text(loc.t('fd_end_crop'),
                    style: TextStyle(
                        color: colors.danger, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
    notesController.dispose();
    if (confirmed != true || crop != _crop) return;

    await DataService().endCrop(
      crop,
      endStatus: status,
      reason: status,
      notes: notes,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(loc.t('fd_end_crop_saved')),
      backgroundColor: colors.brandDeep,
    ));
    await _loadData();
  }

  Widget _buildCropHistoryCard(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    if (_cropHistory.isEmpty) {
      return _card(
        context,
        Row(
          children: [
            Icon(Icons.history_rounded, color: colors.onSurfaceMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loc.t('fd_no_history'),
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    return _card(
      context,
      Column(
        children: [
          for (var i = 0; i < _cropHistory.length; i++) ...[
            _buildHistoryRow(context, _cropHistory[i], loc),
            if (i != _cropHistory.length - 1)
              const Divider(height: 20, color: Color(0x14000000)),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryRow(
      BuildContext context, CropRecord crop, AppLocalizations loc) {
    final colors = VidhAIColorsX(context);
    final status = _statusLabel(crop.status, loc);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(Icons.spa_rounded, color: colors.onSurfaceMuted, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(crop.cropName,
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                '${loc.t('fd_planted_on')} ${_fmtDate(crop.plantingDate)}'
                '${crop.endDate != null ? ' · ${loc.t('fd_ended_on')} ${_fmtDate(crop.endDate!)}' : ''}'
                '${crop.variety.isNotEmpty ? ' · ${crop.variety}' : ''}',
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(crop.status, colors).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status,
              style: TextStyle(
                  color: _statusColor(crop.status, colors),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  String _statusLabel(String status, AppLocalizations loc) {
    switch (status) {
      case 'harvested':
        return loc.t('fd_end_status_harvested');
      case 'completed':
        return loc.t('fd_end_status_completed');
      case 'stopped':
        return loc.t('fd_end_status_stopped');
      case 'abandoned':
        return loc.t('fd_end_status_abandoned');
      case 'failed':
        return loc.t('fd_end_status_failed');
      default:
        return loc.t('active');
    }
  }

  Color _statusColor(String status, VidhAIColorsX colors) {
    switch (status) {
      case 'harvested':
      case 'completed':
        return colors.brandDeep;
      case 'stopped':
      case 'abandoned':
        return colors.warning;
      case 'failed':
        return colors.danger;
      default:
        return colors.onSurfaceMuted;
    }
  }

  Widget _buildFarmInfoCard(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final crop = _crop;
    final cropName = crop?.cropName ?? '';
    final farmName = _farm!.farmName;
    final locationValue = _locationLines().join('\n');
    final stage = crop != null ? computeCropStage(crop).stage : null;

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(context, loc.farmName,
              farmName.isNotEmpty ? farmName : loc.notSet,
              mutedValue: farmName.isEmpty),
          const SizedBox(height: 4),
          _infoRow(
              context, loc.crop, cropName.isNotEmpty ? cropName : loc.noCrop,
              mutedValue: cropName.isEmpty),
          const SizedBox(height: 4),
          _infoRow(context, loc.location,
              locationValue.isNotEmpty ? locationValue : loc.notSet,
              mutedValue: locationValue.isEmpty),
          const SizedBox(height: 4),
          _infoRow(context, loc.stage, stage ?? loc.notSet,
              mutedValue: stage == null),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value,
      {bool mutedValue = false}) {
    final colors = VidhAIColorsX(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: mutedValue ? colors.onSurfaceMuted : colors.onBackground,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesCard(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    if (_expenses.isEmpty) {
      return _card(
        context,
        Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                color: colors.onSurfaceMuted, size: 34),
            const SizedBox(height: 10),
            Text(
              loc.noExpensesYet,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openExpenses(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brandDeep,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(loc.addExpense),
              ),
            ),
          ],
        ),
      );
    }

    final sorted = [..._expenses]..sort((a, b) => b.date.compareTo(a.date));
    final total = _expenses.fold(0.0, (sum, e) => sum + e.amount);
    final byCategory = <String, double>{};
    for (final e in _expenses) {
      final key = e.category.isNotEmpty ? e.category : loc.category;
      byCategory[key] = (byCategory[key] ?? 0) + e.amount;
    }
    final categories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = categories.take(5).toList();
    final recent = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          context,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.totalExpenses,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmt(total),
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.brandDeep.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.payments_rounded,
                    color: colors.brandDeep, size: 22),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...topCategories.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _categoryColor(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.key,
                            style: TextStyle(
                              color: colors.onBackground,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          _fmt(e.value),
                          style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (categories.length > 5) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '${loc.seeAll} • ${_fmt(total)}',
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                  ),
                ),
              ],
              const Divider(height: 20),
              ...recent.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _buildExpenseRow(context, e),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openExpenses(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.brandDeep,
              side: BorderSide(color: colors.brandDeep.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              loc.addExpense,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseRow(BuildContext context, ExpenseRecord e) {
    final colors = VidhAIColorsX(context);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _categoryColor(e.category).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.receipt_outlined,
            color: _categoryColor(e.category),
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.category.isNotEmpty
                    ? e.category
                    : (e.description.isNotEmpty ? e.description : '—'),
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                _fmtDate(e.date),
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _fmt(e.amount),
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _openExpenses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpensesScreen(farmId: widget.farmId),
      ),
    ).then((_) => _loadData());
  }

  Widget _buildToolsGrid(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final farmId = widget.farmId;
    final location = _farm!.farmLocation;

    final items = <_ToolItem>[
      _ToolItem(
        icon: Icons.wb_sunny_outlined,
        label: loc.weather,
        color: const Color(0xFFFFB300),
        onTap: location != null &&
                location.latitude != null &&
                location.longitude != null
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeatherDetailsScreen(
                      farmName: _farm!.farmName,
                      latitude: location.latitude!,
                      longitude: location.longitude!,
                    ),
                  ),
                )
            : null,
      ),
      _ToolItem(
        icon: Icons.science_rounded,
        label: loc.pesticides,
        color: const Color(0xFFAB47BC),
        onTap: () =>
            Navigator.pushNamed(context, '/pesticides', arguments: farmId),
      ),
      _ToolItem(
        icon: Icons.spa_rounded,
        label: loc.fertilizers,
        color: const Color(0xFF26A69A),
        onTap: () =>
            Navigator.pushNamed(context, '/fertilizers', arguments: farmId),
      ),
      _ToolItem(
        icon: Icons.bug_report_rounded,
        label: loc.disease,
        color: const Color(0xFFEF5350),
        onTap: () =>
            Navigator.pushNamed(context, '/diseases', arguments: farmId),
      ),
      _ToolItem(
        icon: Icons.history_rounded,
        label: loc.history,
        color: const Color(0xFF78909C),
        onTap: () =>
            Navigator.pushNamed(context, '/farm_history', arguments: farmId),
      ),
      _ToolItem(
        icon: Icons.storefront_rounded,
        label: loc.marketPrices,
        color: const Color(0xFF8E6E53),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarketPricesScreen(
              initialState: location?.state,
              initialDistrict: location?.district,
              initialCommodity: _crop?.cropName,
            ),
          ),
        ),
      ),
      _ToolItem(
        icon: Icons.auto_awesome_rounded,
        label: loc.recommend,
        color: colors.brandDeep,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CropSetupScreen(farmId: widget.farmId),
          ),
        ).then((_) => _loadData()),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: items.map((item) => _buildToolTile(context, item)).toList(),
    );
  }

  Widget _buildToolTile(BuildContext context, _ToolItem item) {
    final colors = VidhAIColorsX(context);
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ToolItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
}
