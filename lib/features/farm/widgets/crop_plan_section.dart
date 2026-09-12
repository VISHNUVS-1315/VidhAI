import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/data_service.dart';

/// Crop-plan section shown at the top of the Farmer Workspace.
///
/// Summarises every active crop: current growth stage, days to harvest,
/// budget fit and water guidance, plus the dated to-do tasks (today / this
/// week / upcoming). Tap a crop to open its full plan with checkable tasks
/// and the stage timeline.
class CropPlanSection extends StatefulWidget {
  const CropPlanSection({super.key});

  @override
  State<CropPlanSection> createState() => _CropPlanSectionState();
}

class _PlanBundle {
  final FarmProfile farm;
  final CropRecord crop;
  final CropPlan? plan;
  final List<CropTask> tasks;

  _PlanBundle(this.farm, this.crop, this.plan, this.tasks);
}

class _CropPlanSectionState extends State<CropPlanSection> {
  final DataService _dataService = DataService();
  bool _loading = true;
  List<_PlanBundle> _bundles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<FarmProfile> farms = [];
    try {
      farms = await _dataService.loadFarms();
    } catch (_) {}
    final bundles = <_PlanBundle>[];
    for (final farm in farms) {
      List<CropRecord> crops = [];
      try {
        crops = await _dataService.loadCrops(farm.farmId);
      } catch (_) {}
      for (final crop in crops.where((c) => c.isActive).take(3)) {
        CropPlan? plan;
        try {
          plan = crop.cropPlanId == null
              ? null
              : await _dataService.loadCropPlan(crop.cropPlanId!);
        } catch (_) {}
        List<CropTask> tasks = [];
        try {
          tasks = await _dataService.loadCropTasks(crop.id);
        } catch (_) {}
        bundles.add(_PlanBundle(farm, crop, plan, tasks));
      }
    }
    if (!mounted) return;
    setState(() {
      _bundles = bundles;
      _loading = false;
    });
  }

  Future<void> _toggleTask(CropTask task, bool done) async {
    await _dataService.completeCropTask(task.cropId, task.id, done: done);
    setState(() {
      final bundle =
          _bundles.where((b) => b.crop.id == task.cropId).firstOrNull;
      if (bundle != null) {
        final idx = _bundles.indexOf(bundle);
        _bundles[idx] = _PlanBundle(
          bundle.farm,
          bundle.crop,
          bundle.plan,
          bundle.tasks
              .map((t) => t.id == task.id
                  ? t.copyWith(status: done ? 'done' : 'pending')
                  : t)
              .toList(),
        );
      }
    });
  }

  Future<void> _openPlan(_PlanBundle b) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: VidhAIColorsX(context).surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlanDetailSheet(
        bundle: b,
        onToggle: _toggleTask,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                color: colors.brandDeep, strokeWidth: 2),
          ),
        ),
      );
    }
    if (_bundles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                color: colors.onSurfaceMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loc.t('ws_no_plan'),
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            loc.t('ws_plan_title'),
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (var i = 0; i < _bundles.length; i++) ...[
          _PlanCard(bundle: _bundles[i], onOpen: () => _openPlan(_bundles[i])),
          if (i != _bundles.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanBundle bundle;
  final VoidCallback onOpen;

  const _PlanCard({required this.bundle, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final crop = bundle.crop;
    final plan = bundle.plan;
    final tasks = bundle.tasks;
    final now = DateTime.now();

    final today = tasks.where((t) => t.isDueToday && t.status != 'done').length;
    final weekEnd = now.add(const Duration(days: 7));
    final week = tasks
        .where((t) =>
            t.status != 'done' &&
            !t.isDueToday &&
            !t.dueDate.isBefore(now) &&
            t.dueDate.isBefore(weekEnd))
        .length;
    final upcoming = tasks
        .where((t) => t.status != 'done' && !t.dueDate.isBefore(weekEnd))
        .length;

    int? remaining;
    final harvest = crop.expectedHarvestDate ?? plan?.estimatedHarvestDate;
    if (harvest != null) {
      remaining = harvest.difference(now).inDays;
      if (remaining < 0) remaining = 0;
    }

    String stageName = '';
    if (plan != null) {
      final stage = plan.stageForDay(now);
      if (stage != null) stageName = stage.name;
    }

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.spa_rounded,
                        color: colors.brandDeep, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(crop.cropName,
                            style: TextStyle(
                                color: colors.onBackground,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        if (crop.variety.isNotEmpty)
                          Text(crop.variety,
                              style: TextStyle(
                                  color: colors.onSurfaceMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (remaining != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        loc
                            .t('ws_days_to_harvest')
                            .replaceAll('{days}', '$remaining'),
                        style: TextStyle(
                            color: colors.info,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _stat(
                      colors,
                      Icons.timeline_rounded,
                      stageName.isNotEmpty ? stageName : loc.t('ws_stage'),
                    ),
                  ),
                  if (plan != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(
                        colors,
                        Icons.account_balance_wallet_outlined,
                        '${loc.t('ws_budget')}: '
                        '${plan.budget.cultivationCostMin > 0 ? '₹${plan.budget.cultivationCostMin}' : loc.t('ws_not_set')}',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _taskChip(colors, loc, Icons.today_rounded, today,
                      loc.t('ws_today_tasks')),
                  _taskChip(colors, loc, Icons.date_range_rounded, week,
                      loc.t('ws_week_tasks')),
                  _taskChip(colors, loc, Icons.event_rounded, upcoming,
                      loc.t('ws_upcoming_tasks')),
                ],
              ),
              if (plan != null && plan.waterNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('💧 ${plan.waterNotes}',
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(VidhAIColorsX colors, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.brandDeep, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _taskChip(VidhAIColorsX colors, AppLocalizations loc, IconData icon,
      int count, String label) {
    final active = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? colors.brandDeep.withValues(alpha: 0.13) : colors.bg,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: active ? colors.brandDeep : colors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: active ? colors.brandDeep : colors.onSurfaceMuted),
          const SizedBox(width: 5),
          Text(
            '$count · $label',
            style: TextStyle(
                color: active ? colors.brandDeep : colors.onSurfaceMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PlanDetailSheet extends StatefulWidget {
  final _PlanBundle bundle;
  final void Function(CropTask task, bool done) onToggle;

  const _PlanDetailSheet({required this.bundle, required this.onToggle});

  @override
  State<_PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends State<_PlanDetailSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final b = widget.bundle;
    final tasks = b.tasks;
    final pending = tasks.where((t) => t.status != 'done').length;
    final done = tasks.length - pending;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (ctx, scrollController) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: colors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    b.crop.cropName,
                    style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$done/${tasks.length}',
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: tasks.isEmpty ? 0 : done / tasks.length,
                      minHeight: 6,
                      backgroundColor: colors.borderColor,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.brandDeep),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tabButton(
                    colors, loc, 0, Icons.checklist_rounded, loc.t('ws_tasks')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tabButton(
                    colors, loc, 1, Icons.timeline_rounded, loc.t('ws_stages')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _tab == 0
                ? _tasksView(colors, loc, tasks, scrollController)
                : _stagesView(colors, loc, b, scrollController),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(VidhAIColorsX colors, AppLocalizations loc, int index,
      IconData icon, String label) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? colors.brandDeep.withValues(alpha: 0.12) : colors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? colors.brandDeep : colors.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? colors.brandDeep : colors.onSurfaceMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? colors.brandDeep : colors.onSurfaceMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _tasksView(VidhAIColorsX colors, AppLocalizations loc,
      List<CropTask> tasks, ScrollController scrollController) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(loc.t('ws_tasks_empty'),
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
      );
    }
    final sorted = [...tasks]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final t = sorted[i];
        final done = t.status == 'done';
        final colors = VidhAIColorsX(context);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.borderColor),
          ),
          child: Row(
            children: [
              Checkbox(
                value: done,
                activeColor: colors.brandDeep,
                onChanged: (v) => widget.onToggle(t, v ?? false),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        color:
                            done ? colors.onSurfaceMuted : colors.onBackground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(_typeIcon(t.type),
                            color: colors.onSurfaceMuted, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${t.stage} · ${_fmtDate(t.dueDate)}',
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stagesView(VidhAIColorsX colors, AppLocalizations loc, _PlanBundle b,
      ScrollController scrollController) {
    final stages = b.plan?.stages ?? const <CropStage>[];
    if (stages.isEmpty) {
      return Center(
        child: Text(loc.t('ws_tasks_empty'),
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
      );
    }
    final now = DateTime.now();
    final todayDay =
        b.plan == null ? 0 : now.difference(b.plan!.startDate).inDays + 1;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: stages.length,
      itemBuilder: (context, i) {
        final s = stages[i];
        final isCurrent = todayDay >= s.startDay && todayDay <= s.endDay;
        final completed = todayDay > s.endDay;
        final colors = VidhAIColorsX(context);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed
                        ? colors.brandDeep
                        : isCurrent
                            ? colors.brandDeep.withValues(alpha: 0.2)
                            : colors.bg,
                    border: Border.all(
                        color: completed || isCurrent
                            ? colors.brandDeep
                            : colors.borderColor),
                  ),
                  child: completed
                      ? Icon(Icons.check, size: 13, color: Colors.white)
                      : isCurrent
                          ? Icon(Icons.circle, size: 8, color: colors.brandDeep)
                          : null,
                ),
                if (i != stages.length - 1)
                  Container(width: 2, height: 26, color: colors.borderColor),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Day ${s.startDay}–${s.endDay}${isCurrent ? ' · ${loc.t('ws_current')}' : ''}',
                      style: TextStyle(
                          color: isCurrent
                              ? colors.brandDeep
                              : colors.onSurfaceMuted,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'water':
        return Icons.water_drop_outlined;
      case 'nutrition':
        return Icons.eco_outlined;
      case 'weed':
        return Icons.grass_rounded;
      case 'pest':
        return Icons.bug_report_outlined;
      case 'land':
        return Icons.terrain_rounded;
      case 'planting':
        return Icons.spa_rounded;
      case 'harvest':
        return Icons.shopping_basket_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
