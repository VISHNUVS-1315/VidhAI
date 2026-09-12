import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/pest_analysis.dart';
import 'package:vidhai/data/models/workspace_note.dart';
import 'package:vidhai/features/tools/screens/fertilizer_guide_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/ai/gemini_vision_service.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/pest_analysis_service.dart';
import 'package:vidhai/services/task_service.dart';
import 'package:vidhai/services/workspace_service.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

/// Pest & Diseases module: farm-aware photo analysis with a structured,
/// safety-first result and optional farm-history + task integration.
class PestDiseaseScreen extends StatefulWidget {
  /// Test seam: override the analyzer used for image analysis.
  final PestDiseaseAnalyzer? analyzeOverride;

  /// When set and matching an existing farm, this farm is preselected.
  final String? initialFarmId;

  const PestDiseaseScreen({
    super.key,
    this.analyzeOverride,
    this.initialFarmId,
  });

  @override
  State<PestDiseaseScreen> createState() => _PestDiseaseScreenState();
}

class _PestDiseaseScreenState extends State<PestDiseaseScreen> {
  static const String _selectionPrefKey = 'pest_selected_farm_id';
  static const int _maxImages = 5;

  final DataService _dataService = DataService();
  final PestAnalysisService _pestService = PestAnalysisService.instance;
  final TaskService _taskService = TaskService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _cropController = TextEditingController();

  List<FarmProfile> _farms = [];
  List<CropRecord> _farmCrops = [];
  String _selectedFarmId = '';
  String? _autoCrop;
  final List<File> _images = [];
  bool _loading = true;
  bool _analyzing = false;
  PestAnalysisRecord? _result;

  bool get _isTempMode => _selectedFarmId.isEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<FarmProfile> farms = [];
    try {
      farms = await _dataService.loadFarms();
    } catch (_) {}

    String restoreId = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      restoreId = prefs.getString(_selectionPrefKey) ?? '';
    } catch (_) {}

    String selected = '';
    if (farms.isNotEmpty) {
      if (widget.initialFarmId != null &&
          widget.initialFarmId!.isNotEmpty &&
          farms.any((f) => f.farmId == widget.initialFarmId)) {
        selected = widget.initialFarmId!;
      } else if (restoreId.isNotEmpty &&
          farms.any((f) => f.farmId == restoreId)) {
        selected = restoreId;
      } else {
        selected = farms.first.farmId;
      }
    }

    if (!mounted) return;
    setState(() {
      _farms = farms;
      _selectedFarmId = selected;
      _loading = false;
    });
    await _loadFarmCrops(selected);
  }

  Future<void> _loadFarmCrops(String farmId) async {
    String? autoCrop;
    var crops = <CropRecord>[];
    if (farmId.isNotEmpty) {
      try {
        crops = await _dataService.loadCrops(farmId);
      } catch (_) {}
      if (crops.isNotEmpty) autoCrop = crops.first.cropName;
    }
    if (!mounted) return;
    setState(() {
      _farmCrops = crops;
      _autoCrop = autoCrop;
    });
  }

  void _selectFarm(String farmId) async {
    if (_analyzing) return;
    setState(() {
      _selectedFarmId = farmId;
      _result = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectionPrefKey, farmId);
    } catch (_) {}
    await _loadFarmCrops(farmId);
  }

  Future<void> _pickImages(ImageSource source) async {
    final loc = AppLocalizations.of(context);
    if (_images.length >= _maxImages) {
      _showWarning(
        '${loc.pestPhotosSelected.replaceAll('{count}', '$_maxImages')} '
        '${loc.pestMaxHint.replaceAll('{count}', '$_maxImages')}',
      );
      return;
    }
    try {
      final remaining = _maxImages - _images.length;
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(imageQuality: 85);
        if (picked.isNotEmpty) {
          final toAdd =
              picked.take(remaining).map((e) => File(e.path)).toList();
          setState(() => _images.addAll(toAdd));
        }
      } else {
        final image = await _picker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (image != null) {
          setState(() => _images.add(File(image.path)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showWarning('${AppLocalizations.of(context).pestPickImageFailed} $e');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _clearImages() {
    setState(() => _images.clear());
  }

  void _showWarning(String message) {
    if (!mounted) return;
    final colors = VidhAIColorsX(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: colors.warning),
    );
  }

  Future<void> _analyze() async {
    final loc = AppLocalizations.of(context);
    final crop = (_autoCrop ?? _cropController.text.trim()).trim();
    if (crop.isEmpty || _images.isEmpty) {
      _showWarning(loc.pestValidateMessage);
      return;
    }

    setState(() {
      _analyzing = true;
      _result = null;
    });

    try {
      final images = <Uint8ListLike>[];
      for (final f in _images) {
        images.add(Uint8ListLike(
          bytes: await f.readAsBytes(),
          mimeType: f.path.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
        ));
      }

      final farm = _selectedFarm.isSelected ? _selectedFarm.farm : null;
      final analyzer = widget.analyzeOverride ?? _pestService.analyzeWithGemini;
      final record = await analyzer(
        images: images,
        crop: crop,
        farmingMethod: farm?.farmingMethod ?? '',
        language: loc.languageCode,
        farmId: farm?.farmId ?? '',
        farmName: farm?.farmName ?? '',
      );

      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _result = record;
      });

      if (_isTempMode) {
        _showWarning(loc.pestTempNotSaved);
      } else {
        await _pestService.save(record);
        if (mounted) _showSuccess(loc.pestHistorySaved);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      final colors = VidhAIColorsX(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context).pestAnalyzeFailed} $e'),
          backgroundColor: colors.danger,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    final colors = VidhAIColorsX(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: colors.success),
    );
  }

  Future<void> _addToTasks() async {
    final loc = AppLocalizations.of(context);
    final record = _result;
    final farm = _selectedFarm.isSelected ? _selectedFarm.farm : null;
    if (record == null || farm == null) return;

    final task = FarmTask(
      id: 'pest_${farm.farmId}_${DateTime.now().millisecondsSinceEpoch}',
      farmName: farm.farmName,
      farmIndex: farm.index,
      title: loc.pestFarmTaskTitle.replaceAll('{crop}', record.crop),
      category: 'pest',
      scheduledTime: '6:00 AM',
      createdAt: DateTime.now(),
    );

    try {
      final tasks = await _taskService.loadTasks();
      tasks.add(task);
      await _taskService.saveTasks(tasks);
      _showSuccess(loc.pestTaskAdded);
    } catch (e) {
      if (!mounted) return;
      _showWarning('${AppLocalizations.of(context).pestAnalyzeFailed} $e');
    }
  }

  Future<void> _saveToWorkspace() async {
    final loc = AppLocalizations.of(context);
    final record = _result;
    if (record == null) return;
    final note = WorkspaceNote.fromAnalysis(record);
    await WorkspaceService.instance.save(note);
    if (!mounted) return;
    _showSuccess(loc.workspacePestSaved);
  }

  void _resetAnalysis() {
    setState(() {
      _result = null;
      _autoCrop = null;
      _farmCrops = [];
      _images.clear();
    });
    _loadFarmCrops(_selectedFarmId);
  }

  _SelectedFarm get _selectedFarm {
    for (final f in _farms) {
      if (f.farmId == _selectedFarmId) return _SelectedFarm(true, f);
    }
    return const _SelectedFarm(false, null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final selected = _selectedFarm;
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
          loc.pestDetection,
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_isTempMode) _buildTempBanner(colors, loc),
                _buildFarmSelector(colors, loc),
                const SizedBox(height: 16),
                _buildCropSection(colors, loc),
                const SizedBox(height: 16),
                _buildPhotoSection(colors, loc),
                const SizedBox(height: 20),
                _buildAnalyzeButton(colors, loc),
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  _buildResultSection(colors, loc, selected),
                ],
              ],
            ),
    );
  }

  Widget _buildTempBanner(dynamic colors, AppLocalizations loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loc.pestFarmNoneHint,
              style: TextStyle(color: colors.onBackground, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmSelector(dynamic colors, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.pestSelectFarmLabel,
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
                title: loc.pestFarmNone,
                selected: _isTempMode,
                onTap: () => _selectFarm(''),
              ),
              for (final farm in _farms)
                _farmChip(
                  colors,
                  title: farm.farmName,
                  selected: _selectedFarmId == farm.farmId,
                  onTap: () => _selectFarm(farm.farmId),
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

  Widget _buildCropSection(dynamic colors, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                loc.pestStepCropTitle,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_farmCrops.isNotEmpty) ...[
              Icon(Icons.check_circle_rounded, color: colors.success, size: 16),
              const SizedBox(width: 4),
              Text(
                loc.pestCropAutoHint,
                style: TextStyle(color: colors.success, fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_farmCrops.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _farmCrops)
                _cropChip(colors, c.cropName,
                    selected: _autoCrop == c.cropName),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isTempMode == false)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    loc.pestNoCropsFound,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                  ),
                ),
              TextField(
                controller: _cropController,
                style: TextStyle(color: colors.onBackground, fontSize: 15),
                decoration: InputDecoration(
                  hintText: loc.pestCropHint,
                  hintStyle: TextStyle(color: colors.onSurfaceMuted),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.borderColor),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _cropChip(dynamic colors, String name, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _autoCrop = name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.brandDeep : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.brandDeep : colors.borderColor,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: selected ? Colors.white : colors.onSurfaceMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(dynamic colors, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                loc.pestStepPhotosTitle,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_images.isNotEmpty)
              GestureDetector(
                onTap: _clearImages,
                child: Text(
                  loc.pestClearPhotos,
                  style: TextStyle(color: colors.brandDeep, fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_images.isEmpty)
          _buildEmptyPhotos(colors, loc)
        else
          Column(
            children: [
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < _images.length; i++)
                      _photoThumb(colors, i),
                    if (_images.length < _maxImages) _addPhotoTile(colors, loc),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                loc.pestPhotosSelected
                    .replaceAll('{count}', '${_images.length}'),
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
              ),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          loc.pestPhotoHint,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEmptyPhotos(dynamic colors, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.add_a_photo_outlined,
              color: colors.onSurfaceMuted, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.pestNoPhotosYet,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
            ),
          ),
          _pickButton(colors, loc, Icons.photo_library_outlined,
              loc.chooseFromGallery, () => _pickImages(ImageSource.gallery)),
          const SizedBox(width: 8),
          _pickButton(colors, loc, Icons.camera_alt_outlined, loc.takePhoto,
              () => _pickImages(ImageSource.camera)),
        ],
      ),
    );
  }

  Widget _pickButton(dynamic colors, AppLocalizations loc, IconData icon,
      String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.brandDeep.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.brandDeep, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: colors.brandDeep, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addPhotoTile(dynamic colors, AppLocalizations loc) {
    return GestureDetector(
      onTap: () => _showPhotoSourceSheet(colors, loc),
      child: Container(
        width: 84,
        margin: const EdgeInsetsDirectional.only(end: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: colors.brandDeep, size: 26),
            Text(
              loc.pestAddAnotherPhoto,
              style: TextStyle(color: colors.brandDeep, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoThumb(dynamic colors, int index) {
    return Stack(
      children: [
        Container(
          width: 84,
          margin: const EdgeInsetsDirectional.only(end: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(_images[index]),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 6,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPhotoSourceSheet(
      dynamic colors, AppLocalizations loc) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: colors.brandDeep),
              title: Text(loc.takePhoto,
                  style: TextStyle(color: colors.onBackground)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: colors.brandDeep),
              title: Text(loc.chooseFromGallery,
                  style: TextStyle(color: colors.onBackground)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton(dynamic colors, AppLocalizations loc) {
    return GestureDetector(
      onTap: _analyzing ? null : _analyze,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.brandDeep,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _analyzing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      loc.pestAnalyzingBody,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    loc.pestAnalyzeNow,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ==================== RESULT ====================

  Widget _buildResultSection(
      dynamic colors, AppLocalizations loc, _SelectedFarm selected) {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildConditionCard(colors, loc, r),
        if (!r.imageQualityGood) ...[
          const SizedBox(height: 10),
          _buildWarningCard(colors, Icons.image_not_supported_outlined,
              loc.pestUnclearPhotoWarning),
        ],
        if (r.confidence < 0.55 && !r.isHealthy) ...[
          const SizedBox(height: 10),
          _buildWarningCard(colors, Icons.warning_amber_rounded,
              loc.pestLowConfidenceWarning),
        ],
        if (r.symptoms.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildListCard(colors, loc, Icons.grain_rounded,
              loc.pestSymptomsLabel, r.symptoms),
        ],
        if (r.causes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildListCard(
              colors, loc, Icons.hub_outlined, loc.pestCausesLabel, r.causes),
        ],
        if (!r.remedy.isEmpty) ...[
          const SizedBox(height: 16),
          _buildRemedyCard(colors, loc, r),
        ],
        if (r.prevention.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildListCard(colors, loc, Icons.shield_outlined,
              loc.pestPreventionLabel, r.prevention),
        ],
        const SizedBox(height: 20),
        _buildActionButton(colors, Icons.bookmark_add_outlined,
            loc.workspaceSavePest, _saveToWorkspace),
        const SizedBox(height: 10),
        Row(
          children: [
            if (selected.isSelected) ...[
              Expanded(
                child: _buildActionButton(
                    colors, Icons.task_alt, loc.pestAddToTasks, _addToTasks),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _buildActionButton(colors, Icons.refresh_rounded,
                  loc.pestAnalyzeNow, _resetAnalysis),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionCard(
      dynamic colors, AppLocalizations loc, PestAnalysisRecord r) {
    final healthy = r.isHealthy;
    final accent = healthy ? colors.success : colors.warning;
    final severityColor = r.severity == 'high'
        ? colors.danger
        : r.severity == 'medium'
            ? colors.warning
            : colors.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  healthy
                      ? Icons.health_and_safety_rounded
                      : Icons.error_outline_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      healthy ? loc.pestHealthy : loc.pestIssueDetected,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      healthy ? r.crop : (r.issue.isEmpty ? r.crop : r.issue),
                      style:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!r.isHealthy)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _severityLabel(loc, r.severity),
                    style: TextStyle(
                        color: severityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${loc.pestConfidence} '
                  '${(r.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: colors.onBackground, fontSize: 13),
                ),
              ),
              if (r.imageQualityGood && r.confidence >= 0.55)
                Icon(Icons.verified_rounded, color: colors.success, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: r.confidence,
              minHeight: 6,
              backgroundColor: colors.bg,
              valueColor: AlwaysStoppedAnimation(
                  r.confidence >= 0.55 ? colors.success : colors.warning),
            ),
          ),
          if (r.farmName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.agriculture_rounded,
                    color: colors.onSurfaceMuted, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${loc.crop}: ${r.crop}  |  ${r.farmName}',
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildWarningCard(dynamic colors, IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onBackground, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(dynamic colors, AppLocalizations loc, IconData icon,
      String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.brandDeep, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ',
                      style: TextStyle(color: colors.brandDeep, fontSize: 13)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemedyCard(
      dynamic colors, AppLocalizations loc, PestAnalysisRecord r) {
    final adv = r.remedy;
    final isOrganic = adv.inputType == 'organic';
    final accent = isOrganic ? colors.success : colors.info;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_rounded, color: colors.brandDeep, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.pestRemedyLabel,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (adv.inputType != 'none')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOrganic ? loc.remedyOrganic : loc.remedyChemical,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (adv.input.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              adv.input,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (adv.action.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              adv.action,
              style: TextStyle(
                  color: colors.onBackground, fontSize: 13, height: 1.4),
            ),
          ],
          if (adv.frequency.isNotEmpty || adv.duration.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [adv.frequency, adv.duration]
                  .where((s) => s.isNotEmpty)
                  .join('  •  '),
              style: TextStyle(
                  color: colors.onSurfaceMuted, fontSize: 12, height: 1.4),
            ),
          ],
          if (adv.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              adv.reason,
              style: TextStyle(
                  color: colors.onSurfaceMuted, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            loc.pestRemedyNote,
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FertilizerGuideScreen(
                    initialSearch: adv.input,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: colors.brandDeep, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    loc.pestViewFertilizerGuide,
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      dynamic colors, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.brandDeep,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFarm {
  final bool isSelected;
  final FarmProfile? farm;

  const _SelectedFarm(this.isSelected, this.farm);
}
