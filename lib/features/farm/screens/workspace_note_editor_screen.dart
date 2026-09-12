import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/workspace_note.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/workspace_service.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

/// Create or edit a manual note in the farmer's Workspace notepad.
///
/// Pops with the saved [WorkspaceNote] on success, or null when cancelled.
class WorkspaceNoteEditorScreen extends StatefulWidget {
  /// Existing manual note to edit (null = create new).
  final WorkspaceNote? existing;

  /// Pre-selected farm when opening from a specific farm's context.
  final String? initialFarmId;

  const WorkspaceNoteEditorScreen({
    super.key,
    this.existing,
    this.initialFarmId,
  });

  @override
  State<WorkspaceNoteEditorScreen> createState() =>
      _WorkspaceNoteEditorScreenState();
}

class _WorkspaceNoteEditorScreenState extends State<WorkspaceNoteEditorScreen> {
  final DataService _dataService = DataService();
  final WorkspaceService _workspaceService = WorkspaceService.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _cropController = TextEditingController();

  List<FarmProfile> _farms = [];
  String _selectedFarmId = '';
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _contentController.text = existing.body;
      _cropController.text = existing.crop;
      _selectedFarmId = existing.farmId;
    } else if (widget.initialFarmId != null) {
      _selectedFarmId = widget.initialFarmId!;
    }
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _cropController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<FarmProfile> farms = [];
    try {
      farms = await _dataService.loadFarms();
    } catch (_) {}
    if (_selectedFarmId.isNotEmpty &&
        !farms.any((f) => f.farmId == _selectedFarmId)) {
      _selectedFarmId = '';
    }
    if (!mounted) return;
    setState(() {
      _farms = farms;
      _loading = false;
    });
  }

  String get _farmName {
    for (final f in _farms) {
      if (f.farmId == _selectedFarmId) return f.farmName;
    }
    return '';
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.workspaceNoteTitleRequired),
          backgroundColor: VidhAIColorsX(context).warning,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final existing = widget.existing;
    setState(() => _saving = true);
    if (existing != null) {
      final updated = existing.copyWith(
        title: title,
        body: _contentController.text.trim(),
        farmId: _selectedFarmId,
        farmName: _farmName,
        crop: _cropController.text.trim(),
        updatedAt: now,
      );
      await _workspaceService.save(updated);
      if (!mounted) return;
      Navigator.pop(context, updated);
      return;
    }
    final note = WorkspaceNote(
      id: 'ws_manual_${now.millisecondsSinceEpoch}',
      type: WorkspaceNoteType.manual,
      title: title,
      body: _contentController.text.trim(),
      farmId: _selectedFarmId,
      farmName: _farmName,
      crop: _cropController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _workspaceService.save(note);
    if (!mounted) return;
    Navigator.pop(context, note);
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
          _isEdit ? loc.workspaceEditNote : loc.workspaceNewNote,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: colors.brandDeep, strokeWidth: 2),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: colors.onBackground, fontSize: 15),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: loc.workspaceNoteTitleHint,
                      labelStyle:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: colors.brandDeep, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFarmSelector(colors, loc),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cropController,
                    style: TextStyle(color: colors.onBackground, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: loc.workspaceNoteCrop,
                      labelStyle:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                      prefixIcon: Icon(Icons.eco_rounded,
                          color: colors.onSurfaceMuted, size: 20),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: colors.brandDeep, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    style: TextStyle(color: colors.onBackground, fontSize: 15),
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: loc.workspaceNoteContentHint,
                      hintStyle:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
                      filled: true,
                      fillColor: colors.surface,
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: colors.brandDeep, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.brandDeep,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _saving
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  loc.save,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFarmSelector(dynamic colors, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.workspaceNoteFarm,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _farmChip(
                colors,
                title: loc.workspaceNoFarm,
                selected: _selectedFarmId.isEmpty,
                onTap: () => setState(() => _selectedFarmId = ''),
              ),
              for (final farm in _farms)
                _farmChip(
                  colors,
                  title: farm.farmName,
                  selected: _selectedFarmId == farm.farmId,
                  onTap: () => setState(() => _selectedFarmId = farm.farmId),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _farmChip(
    dynamic colors, {
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.brandDeep : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.brandDeep : colors.borderColor,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : colors.onSurfaceMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
