import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/pest_analysis.dart';
import 'package:vidhai/data/models/pest_photo_input.dart';
import 'package:vidhai/data/models/workspace_note.dart';
import 'package:vidhai/features/home/screens/voice_typing_overlay.dart';
import 'package:vidhai/features/tools/screens/fertilizer_guide_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/pest_analysis_service.dart';
import 'package:vidhai/services/workspace_service.dart';

/// Test seam equivalent of [WorkspaceService.save] for the screen.
typedef WorkspaceSaver = Future<void> Function(WorkspaceNote note);

/// Multi-photo Pest Detection: the farmer adds photos of DIFFERENT plant
/// parts, tags each with its plant part and an optional observation, and the
/// model analyzes them together as one case. The finished case is stored as a
/// structured Workspace entry (every photo keeps its part + observation).
class MultiPestDetectionScreen extends StatefulWidget {
  /// Test seam: override the analyzer used for the combined analysis.
  final MultiPestAnalyzer? analyzeOverride;

  /// Test seam: override the image picker (real device picker by default).
  final ImagePicker? pickerOverride;

  /// Test seam: override the Workspace save (local service by default).
  final WorkspaceSaver? workspaceSaverOverride;

  /// When set and matching an existing farm, this farm is preselected.
  final String? initialFarmId;

  const MultiPestDetectionScreen({
    super.key,
    this.analyzeOverride,
    this.pickerOverride,
    this.workspaceSaverOverride,
    this.initialFarmId,
  });

  @override
  State<MultiPestDetectionScreen> createState() =>
      _MultiPestDetectionScreenState();
}

class _MultiPestDetectionScreenState extends State<MultiPestDetectionScreen> {
  static const String _selectionPrefKey = 'pest_multi_selected_farm_id';

  final DataService _dataService = DataService();
  final PestAnalysisService _pestService = PestAnalysisService.instance;
  final WorkspaceService _workspaceService = WorkspaceService.instance;
  final TextEditingController _cropController = TextEditingController();

  List<FarmProfile> _farms = [];
  List<CropRecord> _farmCrops = [];
  String _selectedFarmId = '';
  String? _autoCrop;
  final List<PestPhotoInput> _photos = [];
  bool _loading = true;
  bool _analyzing = false;
  PestAnalysisRecord? _result;
  bool _workspaceSaveFailed = false;

  ImagePicker get _picker => widget.pickerOverride ?? ImagePicker();

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

  Future<void> _selectFarm(String farmId) async {
    if (_analyzing) return;
    setState(() {
      _selectedFarmId = farmId;
      _result = null;
      _workspaceSaveFailed = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectionPrefKey, farmId);
    } catch (_) {}
    await _loadFarmCrops(farmId);
  }

  _SelectedFarm get _selectedFarm {
    for (final f in _farms) {
      if (f.farmId == _selectedFarmId) return _SelectedFarm(true, f);
    }
    return const _SelectedFarm(false, null);
  }

  // ==================== PHOTO MANAGEMENT ====================

  PestPhotoInput _createSection() => PestPhotoInput(
        id: 'mp_${DateTime.now().microsecondsSinceEpoch}',
        imageBytes: const [],
        timestamp: DateTime.now().toUtc(),
      );

  void _addSection() {
    setState(() => _photos.add(_createSection()));
  }

  void _removeSection(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _pickForSection(int index, ImageSource source) async {
    final loc = AppLocalizations.of(context);
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!_isSupportedImage(bytes)) {
        _showWarning(loc.pestInvalidPhoto);
        return;
      }
      final name = file.name.toLowerCase();
      final mime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : name.endsWith('.gif')
                  ? 'image/gif'
                  : 'image/jpeg';
      setState(() {
        _photos[index] = _photos[index].copyWith(
          imageBytes: bytes,
          imagePath: file.path,
          mimeType: mime,
        );
      });
    } catch (e) {
      if (!mounted) return;
      _showWarning('${loc.pestPickImageFailed} $e');
    }
  }

  /// Accepts only common raster formats the model can read; rejects anything
  /// that would otherwise crash the preview.
  bool _isSupportedImage(List<int> bytes) {
    if (bytes.length < 12) return false;
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WebP (RIFF .... WEBP)
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  void _setPart(int index, PlantPart? part) {
    setState(() => _photos[index] = _photos[index].copyWith(part: part));
  }

  // ==================== ANALYSIS ====================

  List<PestPhotoInput> get _photosWithImage =>
      _photos.where((p) => p.hasImage).toList();

  Future<void> _analyze() async {
    final loc = AppLocalizations.of(context);
    final crop = (_autoCrop ?? _cropController.text.trim()).trim();
    if (crop.isEmpty) {
      _showWarning(loc.pestCropRequired);
      return;
    }
    final withImage = _photosWithImage;
    if (withImage.isEmpty) {
      _showWarning(loc.pestNoPhotoValidation);
      return;
    }
    if (withImage.any((p) => p.plantPart == null)) {
      _showWarning(loc.pestNoPartValidation);
      return;
    }

    setState(() {
      _analyzing = true;
      _result = null;
      _workspaceSaveFailed = false;
    });

    try {
      final farm = _selectedFarm.farm;
      final analyzer =
          widget.analyzeOverride ?? _pestService.analyzeMultiPhotos;
      final record = await analyzer(
        photos: withImage,
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
        try {
          await _pestService.save(record);
          if (mounted) _showSuccess(loc.pestHistorySaved);
        } catch (_) {}
      }

      await _saveToWorkspace(record, withImage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      final colors = VidhAIColorsX(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.pestAnalyzeFailed} $e'),
          backgroundColor: colors.danger,
        ),
      );
    }
  }

  Future<void> _saveToWorkspace(
    PestAnalysisRecord record,
    List<PestPhotoInput> photos,
  ) async {
    final loc = AppLocalizations.of(context);
    final workspacePhotos = <WorkspacePhoto>[];
    for (var i = 0; i < photos.length; i++) {
      final p = photos[i];
      final ref = record.imageRefs.isNotEmpty && i < record.imageRefs.length
          ? record.imageRefs[i]
          : 'photo_${i + 1}';
      workspacePhotos.add(WorkspacePhoto(
        plantPartCode: p.plantPart?.code ?? '',
        imageRef: ref,
        observation: p.observation.trim(),
        order: i,
      ));
    }
    try {
      final save = widget.workspaceSaverOverride ?? _workspaceService.save;
      await save(
          WorkspaceNote.fromPestCase(record: record, photos: workspacePhotos));
      if (!mounted) return;
      setState(() => _workspaceSaveFailed = false);
      _showSuccess(loc.workspacePestSaved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _workspaceSaveFailed = true);
      _showWarning(loc.pestWorkspaceSaveFailed);
    }
  }

  void _resetAnalysis() {
    setState(() {
      _result = null;
      _workspaceSaveFailed = false;
      _photos.clear();
    });
  }

  void _showWarning(String message) {
    if (!mounted) return;
    final colors = VidhAIColorsX(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: colors.warning),
    );
  }

  void _showSuccess(String message) {
    final colors = VidhAIColorsX(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: colors.success),
    );
  }

  // ==================== BUILD ====================

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
          loc.pestMultiTitle,
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
                _buildPhotosHeader(colors, loc),
                const SizedBox(height: 8),
                if (_photos.isEmpty)
                  _buildEmptySections(colors, loc)
                else
                  for (var i = 0; i < _photos.length; i++) ...[
                    _buildPartSection(colors, loc, i),
                    if (i < _photos.length - 1) const SizedBox(height: 10),
                  ],
                const SizedBox(height: 10),
                _buildAddSectionButton(colors, loc),
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
              if (!_isTempMode)
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

  Widget _buildPhotosHeader(dynamic colors, AppLocalizations loc) {
    return Row(
      children: [
        Expanded(
          child: Text(
            loc.pestPhotosLabel,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_photos.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _photos.clear()),
            child: Text(
              loc.pestClearPhotos,
              style: TextStyle(color: colors.brandDeep, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptySections(dynamic colors, AppLocalizations loc) {
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
              color: colors.onSurfaceMuted, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.pestMultiIntro,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartSection(dynamic colors, AppLocalizations loc, int index) {
    final photo = _photos[index];
    return Container(
      key: ValueKey('pest_part_card_$index'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.brandDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.pestPartLabel,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                key: ValueKey('pest_remove_section_$index'),
                onTap: () => _removeSection(index),
                child: Icon(Icons.delete_outline_rounded,
                    color: colors.danger, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPartDropdown(colors, loc, photo, index),
          const SizedBox(height: 10),
          if (photo.hasImage)
            _buildPhotoPreview(colors, loc, photo, index)
          else
            _buildUploadButton(colors, loc, index),
          const SizedBox(height: 10),
          _buildObservationField(colors, loc, photo, index),
        ],
      ),
    );
  }

  Widget _buildPartDropdown(
      dynamic colors, AppLocalizations loc, PestPhotoInput photo, int index) {
    return Container(
      key: ValueKey('pest_part_dropdown_$index'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PlantPart>(
          key: ValueKey('pest_part_value_$index'),
          value: photo.plantPart,
          isExpanded: true,
          dropdownColor: colors.surface,
          icon: Icon(Icons.arrow_drop_down_rounded, color: colors.brandDeep),
          hint: Text(
            loc.pestSelectPartHint,
            style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: 14,
                overflow: TextOverflow.ellipsis),
          ),
          items: [
            for (final part in PlantPart.values)
              DropdownMenuItem<PlantPart>(
                key: ValueKey('part_item_${part.code}'),
                value: part,
                child: Text(
                  part.label(loc),
                  style: TextStyle(color: colors.onBackground, fontSize: 14),
                ),
              ),
          ],
          onChanged: _analyzing ? null : (part) => _setPart(index, part),
        ),
      ),
    );
  }

  Widget _buildUploadButton(dynamic colors, AppLocalizations loc, int index) {
    return GestureDetector(
      key: ValueKey('pest_part_upload_$index'),
      onTap: () => _showPhotoSourceSheet(colors, loc, index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderColor, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.add_a_photo_outlined, color: colors.brandDeep, size: 26),
            const SizedBox(height: 6),
            Text(
              loc.pestUploadPhoto,
              style: TextStyle(
                color: colors.brandDeep,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(
      dynamic colors, AppLocalizations loc, PestPhotoInput photo, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              Uint8List.fromList(photo.imageBytes),
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: colors.bg,
                alignment: Alignment.center,
                child: Text(
                  loc.pestInvalidPhoto,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _miniAction(colors, Icons.camera_alt_outlined, loc.changePhoto,
                () => _showPhotoSourceSheet(colors, loc, index)),
            const SizedBox(height: 6),
            _miniAction(colors, Icons.refresh_rounded, loc.retry,
                () => _showPhotoSourceSheet(colors, loc, index)),
          ],
        ),
      ],
    );
  }

  Widget _miniAction(
      dynamic colors, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colors.brandDeep.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.brandDeep, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: colors.brandDeep, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservationField(
      dynamic colors, AppLocalizations loc, PestPhotoInput photo, int index) {
    final controller = TextEditingController(text: photo.observation);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: ValueKey('pest_observation_field_$index'),
            controller: controller,
            minLines: 1,
            maxLines: 3,
            style: TextStyle(color: colors.onBackground, fontSize: 14),
            decoration: InputDecoration(
              labelText: loc.pestObservationLabel,
              hintText: loc.pestObservationHint,
              labelStyle: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              hintStyle: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              filled: true,
              fillColor: colors.bg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.borderColor),
              ),
            ),
            onChanged: (v) {
              _photos[index] = _photos[index].copyWith(observation: v);
            },
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            showVoiceTypingOverlay(
              context,
              language: loc.languageCode,
            ).then((spoken) {
              if (spoken == null || spoken.isEmpty || !mounted) return;
              final merged = controller.text.trim().isEmpty
                  ? spoken
                  : '${controller.text.trim()} $spoken';
              controller.text = merged;
              controller.selection =
                  TextSelection.collapsed(offset: merged.length);
              _photos[index] = _photos[index].copyWith(observation: merged);
            });
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.brandDeep.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(Icons.mic_none_rounded, color: colors.brandDeep, size: 20),
          ),
        ),
      ],
    );
  }

  Future<void> _showPhotoSourceSheet(
      dynamic colors, AppLocalizations loc, int index) async {
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
                _pickForSection(index, ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: colors.brandDeep),
              title: Text(loc.chooseFromGallery,
                  style: TextStyle(color: colors.onBackground)),
              onTap: () {
                Navigator.pop(ctx);
                _pickForSection(index, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSectionButton(dynamic colors, AppLocalizations loc) {
    return GestureDetector(
      key: const ValueKey('pest_add_another_part'),
      onTap: _addSection,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: colors.brandDeep.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.brandDeep.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: colors.brandDeep, size: 20),
            const SizedBox(width: 6),
            Text(
              loc.pestAddAnotherPart,
              style: TextStyle(
                color: colors.brandDeep,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton(dynamic colors, AppLocalizations loc) {
    return GestureDetector(
      key: const ValueKey('pest_analyze_button'),
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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.brandDeep.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.brandDeep.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.collections_rounded,
                  color: colors.brandDeep, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${loc.pestCombinedAnalysis} · '
                  '${_photosWithImage.length}',
                  style: TextStyle(
                    color: colors.brandDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildConditionCard(colors, loc, r),
        if (r.affectedParts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildListCard(colors, loc, Icons.eco_outlined, loc.pestAffectedParts,
              _affectedLabels(loc, r.affectedParts)),
        ],
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
        const SizedBox(height: 16),
        _buildFarmerObservationsCard(colors, loc),
        const SizedBox(height: 20),
        if (_workspaceSaveFailed) ...[
          _buildActionButton(
            colors,
            Icons.refresh_rounded,
            loc.retry,
            () => _saveToWorkspace(r, _photosWithImage),
            key: const ValueKey('pest_save_retry'),
          ),
          const SizedBox(height: 10),
        ],
        _buildActionButton(
          colors,
          Icons.refresh_rounded,
          loc.pestAnalyzeNow,
          _resetAnalysis,
          key: const ValueKey('pest_analyze_again'),
        ),
      ],
    );
  }

  List<String> _affectedLabels(AppLocalizations loc, List<String> codes) =>
      codes.map((c) => plantPartLabel(loc, c)).toList();

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

  Widget _buildFarmerObservationsCard(dynamic colors, AppLocalizations loc) {
    final withImage = _photosWithImage;
    if (withImage.isEmpty) return const SizedBox.shrink();
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
              Icon(Icons.notes_rounded, color: colors.brandDeep, size: 18),
              const SizedBox(width: 8),
              Text(
                loc.pestFarmerObservations,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in withImage)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${withImage.indexOf(p) + 1}. ',
                    style: TextStyle(color: colors.brandDeep, fontSize: 13),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.plantPart == null
                              ? ''
                              : plantPartLabel(loc, p.plantPart!.code),
                          style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (p.observation.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              p.observation.trim(),
                              style: TextStyle(
                                color: colors.onSurfaceMuted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
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
                  builder: (_) =>
                      FertilizerGuideScreen(initialSearch: adv.input),
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
      dynamic colors, IconData icon, String label, VoidCallback onTap,
      {Key? key}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: key,
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
