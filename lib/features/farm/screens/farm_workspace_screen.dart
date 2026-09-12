import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/workspace_note.dart';
import 'package:vidhai/data/models/pest_photo_input.dart';
import 'package:vidhai/features/farm/screens/workspace_note_editor_screen.dart';
import 'package:vidhai/features/farm/widgets/crop_plan_section.dart';
import 'package:vidhai/features/tools/screens/multi_pest_detection_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/workspace_service.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

/// Farmer's persistent Workspace notepad: saved pest analysis results and
/// manual notes, grouped by day, stored on the device.
class FarmWorkspaceScreen extends StatefulWidget {
  const FarmWorkspaceScreen({super.key});

  @override
  State<FarmWorkspaceScreen> createState() => _FarmWorkspaceScreenState();
}

class _FarmWorkspaceScreenState extends State<FarmWorkspaceScreen> {
  final DataService _dataService = DataService();
  final WorkspaceService _workspaceService = WorkspaceService.instance;

  List<WorkspaceNote> _notes = [];
  List<FarmProfile> _farms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<WorkspaceNote> notes = [];
    List<FarmProfile> farms = [];
    try {
      notes = await _workspaceService.loadAll();
    } catch (_) {}
    try {
      farms = await _dataService.loadFarms();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _farms = farms;
      _loading = false;
    });
  }

  String _farmName(String farmId) {
    for (final f in _farms) {
      if (f.farmId == farmId) return f.farmName;
    }
    return '';
  }

  Future<void> _addNote() async {
    final saved = await Navigator.push<WorkspaceNote>(
      context,
      MaterialPageRoute(
        builder: (_) => const WorkspaceNoteEditorScreen(),
      ),
    );
    if (saved != null) _load();
  }

  Future<void> _editNote(WorkspaceNote note) async {
    final updated = await Navigator.push<WorkspaceNote>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkspaceNoteEditorScreen(existing: note),
      ),
    );
    if (updated != null) _load();
  }

  Future<bool> _confirmDelete(WorkspaceNote note) async {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              loc.deleteRecord,
              style: TextStyle(color: colors.onBackground),
            ),
            content: Text(
              loc.t('workspace_delete_note_confirm'),
              style: TextStyle(color: colors.onSurfaceMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(loc.cancel,
                    style: TextStyle(color: colors.onSurfaceMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(loc.delete, style: TextStyle(color: colors.danger)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openNote(WorkspaceNote note) {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (note.type == WorkspaceNoteType.manual)
                    IconButton(
                      tooltip: loc.workspaceEditNote,
                      icon: Icon(Icons.edit_outlined,
                          color: colors.brandDeep, size: 20),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editNote(note);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatDateTime(note.createdAt),
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _detailChip(
                    colors,
                    icon: Icons.edit_note_rounded,
                    label: note.type == WorkspaceNoteType.manual
                        ? loc.workspaceManualNote
                        : loc.workspacePestNote,
                  ),
                  if (note.crop.isNotEmpty)
                    _detailChip(
                      colors,
                      icon: Icons.eco_rounded,
                      label: note.crop,
                    ),
                  _detailChip(
                    colors,
                    icon: Icons.agriculture_rounded,
                    label: note.farmId.isEmpty
                        ? loc.workspaceNoFarm
                        : (_farmName(note.farmId).isEmpty
                            ? note.farmName
                            : _farmName(note.farmId)),
                  ),
                  if (note.type == WorkspaceNoteType.pest &&
                      note.issue.isNotEmpty)
                    _detailChip(
                      colors,
                      icon: note.isHealthy
                          ? Icons.health_and_safety_rounded
                          : Icons.error_outline_rounded,
                      label: note.isHealthy ? loc.pestHealthy : note.issue,
                    ),
                  if (note.type == WorkspaceNoteType.pest && !note.isHealthy)
                    _detailChip(
                      colors,
                      icon: Icons.warning_amber_rounded,
                      label: _severityLabel(loc, note.severity),
                    ),
                  for (final part in note.affectedParts)
                    if (part.isNotEmpty)
                      _detailChip(
                        colors,
                        icon: Icons.eco_outlined,
                        label: plantPartLabel(loc, part),
                      ),
                ],
              ),
              if (note.type == WorkspaceNoteType.pest) ...[
                const SizedBox(height: 14),
                _analysisSnapshot(colors, loc, note),
              ],
              if (note.type == WorkspaceNoteType.pest &&
                  note.photos.isNotEmpty) ...[
                const SizedBox(height: 14),
                _photosSnapshot(colors, loc, note),
              ],
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  note.body,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(dynamic colors,
      {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.brandDeep, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _analysisSnapshot(
      dynamic colors, AppLocalizations loc, WorkspaceNote note) {
    final children = <Widget>[];
    if (note.farmingMethod.isNotEmpty) {
      children.add(_snapshotRow(colors,
          icon: Icons.handyman_outlined,
          title: loc.farmingMethod,
          value: note.farmingMethod));
    }
    if (note.confidence > 0) {
      children.add(_snapshotRow(colors,
          icon: Icons.verified_outlined,
          title: loc.pestConfidence,
          value: '${(note.confidence * 100).toStringAsFixed(0)}%'));
    }
    if (note.symptoms.isNotEmpty) {
      children.add(_snapshotList(colors, loc.pestSymptomsLabel, note.symptoms));
    }
    if (note.causes.isNotEmpty) {
      children.add(_snapshotList(colors, loc.pestCausesLabel, note.causes));
    }
    if (!note.remedy.isEmpty) {
      final adv = note.remedy;
      children.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.brandDeep.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.brandDeep.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.healing_rounded, color: colors.brandDeep, size: 16),
                const SizedBox(width: 8),
                Text(
                  loc.pestRemedyLabel,
                  style: TextStyle(
                    color: colors.brandDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (adv.input.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                adv.input,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (adv.action.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                adv.action,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (adv.frequency.isNotEmpty || adv.duration.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [adv.frequency, adv.duration]
                    .where((s) => s.isNotEmpty)
                    .join('  •  '),
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ));
    }
    if (note.prevention.isNotEmpty) {
      children
          .add(_snapshotList(colors, loc.pestPreventionLabel, note.prevention));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          children[i],
        ],
      ],
    );
  }

  Widget _photosSnapshot(
      dynamic colors, AppLocalizations loc, WorkspaceNote note) {
    final sorted = [...note.photos]..sort((a, b) => a.order.compareTo(b.order));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.collections_rounded,
                  color: colors.brandDeep, size: 16),
              const SizedBox(width: 8),
              Text(
                loc.pestPhotosLabel,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final photo in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${photo.order + 1}',
                      style: TextStyle(
                        color: colors.brandDeep,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photo.plantPartCode.isNotEmpty)
                          Text(
                            plantPartLabel(loc, photo.plantPartCode),
                            style: TextStyle(
                              color: colors.onBackground,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (photo.observation.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            photo.observation,
                            style: TextStyle(
                              color: colors.onSurfaceMuted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _snapshotRow(dynamic colors,
      {required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Icon(icon, color: colors.onSurfaceMuted, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            ' $value',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onBackground, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _snapshotList(dynamic colors, String title, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '•  $item',
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _severityLabel(AppLocalizations loc, String severity) {
    switch (severity) {
      case 'high':
        return loc.severityHigh;
      case 'medium':
        return loc.severityMedium;
      default:
        return loc.severityLow;
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
          loc.farmWorkspace,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: loc.workspaceAddNote,
            icon: Icon(Icons.add_rounded, color: colors.brandDeep, size: 26),
            onPressed: _addNote,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: colors.brandDeep, strokeWidth: 2),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: colors.brandDeep,
              backgroundColor: colors.surface,
              child: _notes.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        const CropPlanSection(),
                        const SizedBox(height: 24),
                        _buildEmpty(colors, loc),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        const CropPlanSection(),
                        const SizedBox(height: 20),
                        ..._buildGroupedNotes(colors, loc),
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmpty(dynamic colors, AppLocalizations loc) {
    return Column(
      children: [
        Icon(Icons.sticky_note_2_outlined,
            color: colors.onSurfaceMuted, size: 56),
        const SizedBox(height: 16),
        Text(
          loc.workspaceNotesEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          loc.workspaceNotesEmptyHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _addNote,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: colors.brandDeep,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  loc.workspaceAddNote,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MultiPestDetectionScreen()),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: colors.brandDeep.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined,
                    color: colors.brandDeep, size: 18),
                const SizedBox(width: 8),
                Text(
                  loc.pestAnalyzeNow,
                  style: TextStyle(
                    color: colors.brandDeep,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroupedNotes(dynamic colors, AppLocalizations loc) {
    final now = DateTime.now();
    final groups = <WorkspaceDayGroup, List<WorkspaceNote>>{};
    for (final note in _notes) {
      groups
          .putIfAbsent(workspaceDayGroup(now, note.createdAt), () => [])
          .add(note);
    }
    final children = <Widget>[];
    void addSection(WorkspaceDayGroup group, String label) {
      final notes = groups[group];
      if (notes == null || notes.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          label,
          style: TextStyle(
            color: colors.onSurfaceMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ));
      for (final note in notes) {
        children.add(_buildNoteCard(colors, loc, note));
      }
    }

    addSection(WorkspaceDayGroup.today, loc.workspaceToday);
    addSection(WorkspaceDayGroup.yesterday, loc.workspaceYesterday);
    addSection(WorkspaceDayGroup.older, loc.workspaceOlder);
    return children;
  }

  Widget _buildNoteCard(
      dynamic colors, AppLocalizations loc, WorkspaceNote note) {
    final isPest = note.type == WorkspaceNoteType.pest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(note.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(note),
        onDismissed: (_) => _workspaceService.delete(note.id).then((_) {
          if (mounted) {
            setState(() => _notes.removeWhere((n) => n.id == note.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.workspaceNoteDeleted),
                backgroundColor: colors.success,
              ),
            );
          }
        }),
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: 20),
          decoration: BoxDecoration(
            color: colors.danger,
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
        ),
        child: GestureDetector(
          onTap: () => _openNote(note),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isPest ? colors.brandDeep : colors.success)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPest
                            ? (note.isHealthy
                                ? Icons.health_and_safety_rounded
                                : Icons.bug_report_rounded)
                            : Icons.sticky_note_2_outlined,
                        color: isPest ? colors.brandDeep : colors.success,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onBackground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(note.createdAt),
                            style: TextStyle(
                                color: colors.onSurfaceMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(directionalIcon(context, Icons.chevron_right_rounded),
                        color: colors.onSurfaceMuted, size: 20),
                  ],
                ),
                if (note.crop.isNotEmpty ||
                    note.farmId.isNotEmpty ||
                    isPest) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (note.crop.isNotEmpty)
                        _chip(colors, Icons.eco_rounded, note.crop),
                      if (note.farmId.isNotEmpty)
                        _chip(
                          colors,
                          Icons.agriculture_rounded,
                          _farmName(note.farmId).isEmpty
                              ? note.farmName
                              : _farmName(note.farmId),
                        ),
                      if (isPest && !note.isHealthy && note.severity != 'low')
                        _chip(
                          colors,
                          Icons.warning_amber_rounded,
                          _severityLabel(loc, note.severity),
                        ),
                    ],
                  ),
                ],
                if (note.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(dynamic colors, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.onSurfaceMuted, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    final m = '${d.day.toString().padLeft(2, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    return m;
  }
}
