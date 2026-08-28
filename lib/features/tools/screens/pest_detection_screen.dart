import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/services/ai/domain_services.dart';

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
    'Paddy', 'Wheat', 'Tomato', 'Potato', 'Chilli',
    'Brinjal', 'Onion', 'Cotton', 'Sugarcane', 'Groundnut',
    'Banana', 'Mango', 'Grapes', 'Coconut', 'Turmeric',
    'Black Gram', 'Green Gram', 'Chickpea', 'Sesame',
    'Okra', 'Coriander', 'Mint', 'Spinach',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: const Color(0xFFEF4444),
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
    if (_selectedImages.isEmpty || _cropController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a crop and add at least one photo'),
          backgroundColor: Color(0xFFFF9800),
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
      if (immediate.isNotEmpty) treatmentParts.add('Immediate: ${immediate.join(', ')}');
      if (biological.isNotEmpty) treatmentParts.add('Biological: ${biological.join(', ')}');
      if (chemical.isNotEmpty) treatmentParts.add('Chemical: ${chemical.join(', ')}');

      final preventionList = (result['prevention'] as List?) ?? [];

      final severityRaw = (result['severity'] as String?) ?? 'Unknown';
      final severityScore = (result['severityScore'] as num?) ?? 0;

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisComplete = true;
          _pestName = (result['detectedIssue'] as String?) ?? 'Unknown';
          final conf = (result['confidence'] as num?) ?? 0;
          _confidence = '${(conf * 100).toStringAsFixed(0)}%';
          _severity = severityRaw;
          _treatment = treatmentParts.isNotEmpty ? treatmentParts.join('\n') : 'Consult an agricultural expert.';
          _prevention = preventionList.isNotEmpty ? preventionList.join('\n') : 'Regular field scouting and crop hygiene.';
          _details = 'Severity score: $severityScore/10 | Crop: ${_cropController.text.trim()}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisComplete = true;
          _pestName = 'Analysis Error';
          _confidence = '0%';
          _severity = 'Unknown';
          _treatment = 'Failed to analyze: $e';
          _prevention = '';
          _details = '';
        });
      }
    }
  }

  Future<void> _saveToRecords() async {
    final farms = await _dataService.loadFarms();
    if (farms.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No farm found. Add a farm first.'),
            backgroundColor: Color(0xFFFF9800),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to farm disease records'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pest Detection',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.camera_alt_rounded, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Take a photo of your plant to detect diseases or pests',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1CropSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStepBadge(1),
            const SizedBox(width: 10),
            const Text(
              'Select Plant / Crop',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return _commonCrops;
            return _commonCrops.where(
              (crop) => crop.toLowerCase().contains(textEditingValue.text.toLowerCase()),
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
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (val) => _cropController.text = val,
              decoration: InputDecoration(
                hintText: 'e.g., Tomato, Paddy, Cotton...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.eco_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: const Color(0xFF111827),
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
                        leading: const Icon(Icons.eco_rounded, color: Color(0xFF4CAF50), size: 18),
                        title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 14)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStepBadge(2),
            const SizedBox(width: 10),
            const Text(
              'Add Photos',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildImageSourceButton(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildImageSourceButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
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
                  padding: const EdgeInsets.only(right: 8),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
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
            '${_selectedImages.length} photo(s) selected',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50), size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBadge(int number) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Color(0xFF4CAF50),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return Column(
      children: [
        Row(
          children: [
            _buildStepBadge(3),
            const SizedBox(width: 10),
            const Text(
              'AI Analysis',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
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
            label: const Text(
              'Analyze Images',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Color(0xFF4CAF50),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Analyzing images...',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'AI is examining your plant photos for signs of pests or diseases',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults() {
    final severityColor = _severity == 'High'
        ? const Color(0xFFEF4444)
        : _severity == 'Medium'
            ? const Color(0xFFFF9800)
            : const Color(0xFF4CAF50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStepBadge(3),
            const SizedBox(width: 10),
            const Text(
              'AI Analysis',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          '$_severity Risk',
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
                    'Based on visual analysis',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
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
                  color: const Color(0xFF0A0F1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.image_rounded, color: Color(0xFF4CAF50), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pestName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Confidence: $_confidence',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
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
                    color: const Color(0xFF0A0F1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.analytics_rounded, color: Color(0xFF60A5FA), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _details,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
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
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.healing_rounded, color: Color(0xFF4CAF50), size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Treatment',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
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
                          color: Colors.white.withValues(alpha: 0.6),
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
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: Color(0xFF60A5FA), size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Prevention',
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
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
                          color: Colors.white.withValues(alpha: 0.6),
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
                  color: const Color(0xFFFF9800).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFFF9800), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Results are indicative. Always consult an agricultural expert for critical decisions.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
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
                    _saved ? 'Saved to Farm Records' : 'Save to Farm Records',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saved
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFF4CAF50),
                    foregroundColor: _saved
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
