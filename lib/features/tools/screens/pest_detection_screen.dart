import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/services/ai/domain_services.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class PestDetectionScreen extends StatefulWidget {
  const PestDetectionScreen({super.key});

  @override
  State<PestDetectionScreen> createState() => _PestDetectionScreenState();
}

class _PestDetectionScreenState extends State<PestDetectionScreen> {
  final TextEditingController _cropController = TextEditingController();
  final DataService _dataService = DataService();
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  bool _isAnalyzing = false;
  bool _analysisComplete = false;
  bool _saved = false;
  String _severity = 'Medium';

  static const List<String> _commonCrops = [
    'Paddy',
    'Wheat',
    'Tomato',
    'Potato',
    'Chilli',
    'Brinjal',
    'Onion',
    'Cotton',
    'Sugarcane',
    'Groundnut',
    'Banana',
    'Mango',
    'Grapes',
    'Coconut',
    'Turmeric',
    'Black Gram',
    'Green Gram',
    'Chickpea',
    'Sesame',
    'Okra',
    'Coriander',
    'Mint',
    'Spinach',
  ];

  String _pestName = '';
  String _confidence = '';
  String _treatment = '';
  String _prevention = '';
  String _details = '';

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final images = await _picker.pickMultiImage(imageQuality: 85);
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images.map((e) => File(e.path)));
          });
        }
      } else {
        final image = await _picker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (image != null) {
          setState(() {
            _selectedImages.add(File(image.path));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final colors = VidhAIColorsX(context);
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.pestPickImageFailed} $e'),
            backgroundColor: colors.danger,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _analyzeImages() async {
    final loc = AppLocalizations.of(context);
    if (_selectedImages.isEmpty || _cropController.text.trim().isEmpty) {
      final colors = VidhAIColorsX(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pestValidateMessage),
          backgroundColor: colors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisComplete = false;
      _saved = false;
    });

    try {
      final imagePaths = _selectedImages.map((f) => f.path).toList();
      final result = await PestDetectionAI.instance.detectPest(
        cropName: _cropController.text.trim(),
        imagePaths: imagePaths,
      );

      final treatmentMap = result['treatment'] as Map<String, dynamic>? ?? {};
      final immediate = (treatmentMap['immediate'] as List?) ?? [];
      final biological = (treatmentMap['biological'] as List?) ?? [];
      final chemical = (treatmentMap['chemical'] as List?) ?? [];

      final treatmentParts = <String>[];
      if (immediate.isNotEmpty) {
        treatmentParts.add('${loc.treatmentImmediate} ${immediate.join(', ')}');
      }
      if (biological.isNotEmpty) {
        treatmentParts
            .add('${loc.treatmentBiological} ${biological.join(', ')}');
      }
      if (chemical.isNotEmpty) {
        treatmentParts.add('${loc.treatmentChemical} ${chemical.join(', ')}');
      }

      final preventionList = (result['prevention'] as List?) ?? [];

      final severityRaw = (result['severity'] as String?) ?? 'Unknown';
      final severityScore = (result['severityScore'] as num?) ?? 0;

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisComplete = true;
          _pestName = (result['detectedIssue'] as String?) ?? loc.unknown;
          final conf = (result['confidence'] as num?) ?? 0;
          _confidence = '${(conf * 100).toStringAsFixed(0)}%';
          _severity = severityRaw;
          _treatment = treatmentParts.isNotEmpty
              ? treatmentParts.join('\n')
              : loc.pestTreatmentFallback;
          _prevention = preventionList.isNotEmpty
              ? preventionList.join('\n')
              : loc.pestPreventionFallback;
          _details =
              '${loc.pestSeverityScore} $severityScore/10 | ${loc.crop}: ${_cropController.text.trim()}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisComplete = true;
          _pestName = loc.pestAnalysisErrorTitle;
          _confidence = '0%';
          _severity = 'Unknown';
          _treatment = '${loc.pestAnalyzeFailed} $e';
          _prevention = '';
          _details = '';
        });
      }
    }
  }

  Future<void> _saveToRecords() async {
    final loc = AppLocalizations.of(context);
    final farms = await _dataService.loadFarms();
    if (farms.isEmpty) {
      if (mounted) {
        final colors = VidhAIColorsX(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.pestNoFarmMessage),
            backgroundColor: colors.warning,
          ),
        );
      }
      return;
    }

    final record = DiseaseRecord(
      id: _dataService.generateId(),
      farmId: farms.first.farmId,
      detectedDate: DateTime.now(),
      crop: _cropController.text.trim(),
      problem: '$_pestName (${_selectedImages.length} photo(s))',
      severity: _severity.toLowerCase(),
      treatment: _treatment.isNotEmpty ? _treatment : null,
      status: 'open',
    );

    await _dataService.saveDisease(record);

    if (mounted) {
      setState(() => _saved = true);
      final colors = VidhAIColorsX(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pestSavedRecordsSnackbar),
          backgroundColor: colors.success,
        ),
      );
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
          loc.pestDetection,
          style: TextStyle(
              color: colors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          const VidhAIAssistantButton(
              screen: 'pest_detection', size: 36, iconSize: 18),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStep1CropSelection(),
          const SizedBox(height: 20),
          _buildStep2PhotoUpload(),
          const SizedBox(height: 20),
          if (_selectedImages.isNotEmpty && !_isAnalyzing && !_analysisComplete)
            _buildAnalyzeButton(),
          if (_isAnalyzing) _buildAnalyzingState(),
          if (_analysisComplete) _buildAnalysisResults(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.brandDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.brandDeep.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.camera_alt_rounded, color: colors.brandDeep, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.pestDetectHeader,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1CropSelection() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStepBadge(1),
            const SizedBox(width: 10),
            Text(
              loc.pestStepCropTitle,
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return _commonCrops;
            return _commonCrops.where(
              (crop) => crop
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()),
            );
          },
          onSelected: (value) {
            _cropController.text = value;
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            controller.text = _cropController.text;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: colors.onBackground, fontSize: 15),
              onChanged: (val) => _cropController.text = val,
              decoration: InputDecoration(
                hintText: loc.pestCropHint,
                hintStyle: TextStyle(color: colors.onSurfaceMuted),
                prefixIcon: Icon(Icons.eco_rounded,
                    color: colors.onSurfaceMuted, size: 20),
                filled: true,
                fillColor: colors.surface,
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
                  borderSide: BorderSide(color: colors.brandDeep, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.eco_rounded,
                            color: colors.brandDeep, size: 18),
                        title: Text(option,
                            style: TextStyle(
                                color: colors.onBackground, fontSize: 14)),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep2PhotoUpload() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStepBadge(2),
            const SizedBox(width: 10),
            Text(
              loc.pestStepPhotosTitle,
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildImageSourceButton(
                icon: Icons.camera_alt_rounded,
                label: loc.camera,
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildImageSourceButton(
                icon: Icons.photo_library_rounded,
                label: loc.gallery,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _selectedImages[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc.pestPhotosSelected
                .replaceAll('{count}', _selectedImages.length.toString()),
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = VidhAIColorsX(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.brandDeep, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBadge(int number) {
    final colors = VidhAIColorsX(context);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: colors.brandDeep.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: colors.brandDeep,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            _buildStepBadge(3),
            const SizedBox(width: 10),
            Text(
              loc.pestAiAnalysisTitle,
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _analyzeImages,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: Text(
              loc.analyzeImagesButton,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brandDeep,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingState() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brandDeep.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: colors.brandDeep,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.pestAnalyzingHeading,
            style: TextStyle(
                color: colors.onBackground,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            loc.pestAnalyzingBody,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final severityColor = _severity == 'High'
        ? colors.danger
        : _severity == 'Medium'
            ? colors.warning
            : colors.brandDeep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStepBadge(3),
            const SizedBox(width: 10),
            Text(
              loc.pestAiAnalysisTitle,
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _severity == 'High'
                              ? Icons.warning_amber_rounded
                              : _severity == 'Medium'
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                          color: severityColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_severity ${loc.riskSuffix}',
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    loc.pestBasedOnVisual,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.image_rounded,
                        color: colors.brandDeep, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pestName,
                            style: TextStyle(
                              color: colors.onBackground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${loc.pestConfidence} $_confidence',
                            style: TextStyle(
                              color: colors.onSurfaceMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.analytics_rounded,
                          color: colors.info, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _details,
                          style: TextStyle(
                            color: colors.onSurfaceMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_treatment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.brandDeep.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: colors.brandDeep.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.healing_rounded,
                              color: colors.brandDeep, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            loc.pestTreatmentLabel,
                            style: TextStyle(
                              color: colors.brandDeep,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _treatment,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_prevention.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.info.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: colors.info.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_rounded,
                              color: colors.info, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            loc.pestPreventionLabel,
                            style: TextStyle(
                              color: colors.info,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _prevention,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: colors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.pestDisclaimer,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saved ? null : _saveToRecords,
                  icon: Icon(
                    _saved ? Icons.check_circle_rounded : Icons.save_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _saved ? loc.pestSavedButton : loc.pestSaveButton,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _saved ? colors.surfaceMuted : colors.brandDeep,
                    foregroundColor:
                        _saved ? colors.onSurfaceMuted : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
