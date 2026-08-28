import 'package:flutter/material.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/voice_service.dart';

class CropSetupScreen extends StatefulWidget {
  final String farmId;

  const CropSetupScreen({super.key, required this.farmId});

  @override
  State<CropSetupScreen> createState() => _CropSetupScreenState();
}

class _CropSetupScreenState extends State<CropSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final VoiceService _voiceService = VoiceService();
  final TextEditingController _lastCropController = TextEditingController();
  final TextEditingController _farmLocationController = TextEditingController();
  final TextEditingController _farmSizeController = TextEditingController();

  DateTime? _harvestDate;
  DateTime? _lastIrrigationDate;
  String _landIdleDuration = '';
  String _waterAvailability = '';
  String _soilType = '';
  String _soilCondition = '';
  String _irrigationSystem = '';
  String _currentSeason = '';
  String _cropDurationPreference = '';
  String _cropCategoryPreference = '';
  bool _isListeningLastCrop = false;

  static const _landIdleOptions = [
    '<1 month',
    '1-3 months',
    '3-6 months',
    '6-12 months',
    '>1 year',
  ];

  static const _soilTypeOptions = [
    'Clay',
    'Sandy',
    'Loamy',
    'Silt',
    'Peat',
    'Chalk',
    'Saline',
    'Black (Regur)',
    'Red',
    'Laterite',
  ];

  static const _soilConditionOptions = [
    'Good',
    'Average',
    'Poor',
    'Unknown',
  ];

  static const _irrigationSystemOptions = [
    'Drip',
    'Sprinkler',
    'Flood',
    'Rainfed',
    'Manual',
    'None',
    'Other',
  ];

  static const _waterLevels = [
    'High',
    'Medium',
    'Low',
    'Very Low',
    'No Water',
  ];

  static const _cropDurationOptions = [
    'Short-term',
    'Medium',
    'Long',
    'No preference',
  ];

  static const _cropCategoryOptions = [
    'Vegetables',
    'Fruits',
    'Flowers',
    'Cereals',
    'Pulses',
    'Oilseeds',
    'Spices',
    'Plantation',
    'Tree',
    'Leafy',
    'Medicinal',
    'No preference',
  ];

  @override
  void initState() {
    super.initState();
    _currentSeason = _detectSeason();
    _voiceService.initialize();
    _loadFarmData();
  }

  @override
  void dispose() {
    _lastCropController.dispose();
    _farmLocationController.dispose();
    _farmSizeController.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  String _detectSeason() {
    final month = DateTime.now().month;
    if (month >= 6 && month <= 9) return 'Kharif';
    if (month >= 10 && month <= 3) return 'Rabi';
    return 'Zaid';
  }

  Future<void> _loadFarmData() async {
    try {
      final farms = await DataService().loadFarms();
      final match = farms.where((f) => f.farmId == widget.farmId);
      if (match.isNotEmpty) {
        final profile = match.first;
        setState(() {
          _farmLocationController.text =
              profile.farmLocation?.fullAddress ?? '';
          _farmSizeController.text =
              '${profile.farmSize.isNotEmpty ? profile.farmSize : '-'} ${profile.farmSizeUnit}';
          if (profile.soilType.isNotEmpty) _soilType = profile.soilType;
          if (profile.waterAvailability.isNotEmpty) {
            _waterAvailability = profile.waterAvailability;
          }
          if (profile.irrigationType.isNotEmpty) {
            _irrigationSystem = profile.irrigationType;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _startVoiceInput() async {
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
      setState(() => _isListeningLastCrop = false);
      return;
    }

    final hasPermission = await _voiceService.initialize();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    setState(() => _isListeningLastCrop = true);

    await _voiceService.startListening(
      localeId: 'en_US',
      onResult: (text, confidence) {
        _lastCropController.text = text.trim();
      },
      onListeningComplete: () {
        if (mounted) setState(() => _isListeningLastCrop = false);
      },
    );
  }

  Future<void> _pickDate({required bool isHarvestDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              surface: Color(0xFF1A2332),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A2332),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isHarvestDate) {
          _harvestDate = picked;
        } else {
          _lastIrrigationDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _getRecommendations() {
    final questionnaire = CropSetupQuestionnaire(
      lastCrop: _lastCropController.text.trim(),
      harvestDate: _harvestDate != null ? _formatDate(_harvestDate!) : '',
      landIdleDuration: _landIdleDuration,
      lastIrrigation:
          _lastIrrigationDate != null ? _formatDate(_lastIrrigationDate!) : '',
      waterAvailability: _waterAvailability,
      soilType: _soilType,
      soilCondition: _soilCondition,
      irrigationSystem: _irrigationSystem,
      farmLocation: _farmLocationController.text.trim(),
      farmSize: _farmSizeController.text.trim(),
      currentSeason: _currentSeason,
      cropDurationPreference: _cropDurationPreference,
      cropCategoryPreference: _cropCategoryPreference,
    );

    Navigator.pushNamed(
      context,
      '/recommendation_loading',
      arguments: {
        'farmId': widget.farmId,
        'questionnaire': questionnaire,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crop Setup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _buildQuestionHeader(
              'Help us understand your farm history to get the best crop recommendations.'),
            const SizedBox(height: 20),

            _buildQuestion1(),
            const SizedBox(height: 16),

            _buildQuestion2(),
            const SizedBox(height: 16),

            _buildQuestion3(),
            const SizedBox(height: 16),

            _buildQuestion4(),
            const SizedBox(height: 16),

            _buildQuestion5(),
            const SizedBox(height: 16),

            _buildQuestion6(),
            const SizedBox(height: 16),

            _buildQuestion7(),
            const SizedBox(height: 16),

            _buildQuestion8(),
            const SizedBox(height: 16),

            _buildQuestion9(),
            const SizedBox(height: 16),

            _buildQuestion10(),
            const SizedBox(height: 16),

            _buildQuestion11(),
            const SizedBox(height: 16),

            _buildQuestion12(),
            const SizedBox(height: 16),

            _buildQuestion13(),
            const SizedBox(height: 24),

            _buildGetRecommendationsButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionHeader(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberBadge(int number) {
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

  Widget _buildFieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: Color(0xFFEF4444), fontSize: 14),
          ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1A2332),
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
    );
  }

  Widget _buildQuestion1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(1),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel('Last crop grown')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _lastCropController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _fieldDecoration(
                  hint: 'e.g., Paddy, Tomato, Cotton',
                  icon: Icons.grass_rounded,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _startVoiceInput,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isListeningLastCrop
                      ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                      : const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isListeningLastCrop ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListeningLastCrop
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF4CAF50),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestion2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(2),
            const SizedBox(width: 10),
            Expanded(
                child: _buildFieldLabel('When was it harvested?',
                    required: true)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickDate(isHarvestDate: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: Colors.white.withValues(alpha: 0.4), size: 20),
                const SizedBox(width: 12),
                Text(
                  _harvestDate != null
                      ? _formatDate(_harvestDate!)
                      : 'Select harvest date',
                  style: TextStyle(
                    color: _harvestDate != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_harvestDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _harvestDate = null),
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(3),
            const SizedBox(width: 10),
            Expanded(
                child: _buildFieldLabel('How long has the land been idle?')),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdownField(
          value: _landIdleDuration.isEmpty ? null : _landIdleDuration,
          hint: 'Select duration',
          icon: Icons.timer_outlined,
          items: _landIdleOptions,
          onChanged: (v) => setState(() => _landIdleDuration = v ?? ''),
        ),
      ],
    );
  }

  Widget _buildQuestion4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(4),
            const SizedBox(width: 10),
            Expanded(
                child: _buildFieldLabel('When was the last irrigation?')),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickDate(isHarvestDate: false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined,
                    color: Colors.white.withValues(alpha: 0.4), size: 20),
                const SizedBox(width: 12),
                Text(
                  _lastIrrigationDate != null
                      ? _formatDate(_lastIrrigationDate!)
                      : 'Select last irrigation date',
                  style: TextStyle(
                    color: _lastIrrigationDate != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_lastIrrigationDate != null)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _lastIrrigationDate = null),
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(5),
            const SizedBox(width: 10),
            Expanded(
                child: _buildFieldLabel('Current water availability')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _waterLevels.map((level) {
            final isSelected = _waterAvailability == level;
            final color = _waterLevelColor(level);
            return GestureDetector(
              onTap: () =>
                  setState(() => _waterAvailability = level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _waterLevelColor(String level) {
    switch (level) {
      case 'High':
        return const Color(0xFF2196F3);
      case 'Medium':
        return const Color(0xFF4CAF50);
      case 'Low':
        return const Color(0xFFFF9800);
      case 'Very Low':
        return const Color(0xFFFF5722);
      case 'No Water':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  Widget _buildQuestion6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(6),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel('Soil type')),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdownField(
          value: _soilType.isEmpty ? null : _soilType,
          hint: 'Select soil type',
          icon: Icons.terrain_rounded,
          items: _soilTypeOptions,
          onChanged: (v) => setState(() => _soilType = v ?? ''),
        ),
      ],
    );
  }

  Widget _buildQuestion7() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(7),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel('Soil condition')),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdownField(
          value: _soilCondition.isEmpty ? null : _soilCondition,
          hint: 'Select soil condition',
          icon: Icons.eco_rounded,
          items: _soilConditionOptions,
          onChanged: (v) => setState(() => _soilCondition = v ?? ''),
        ),
      ],
    );
  }

  Widget _buildQuestion8() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(8),
            const SizedBox(width: 10),
            Expanded(
                child: _buildFieldLabel('Irrigation system available')),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdownField(
          value: _irrigationSystem.isEmpty ? null : _irrigationSystem,
          hint: 'Select irrigation system',
          icon: Icons.water_outlined,
          items: _irrigationSystemOptions,
          onChanged: (v) => setState(() => _irrigationSystem = v ?? ''),
        ),
      ],
    );
  }

  Widget _buildQuestion9() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(9),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel('Farm location')),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _farmLocationController,
          readOnly: true,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _fieldDecoration(
            hint: 'Auto-filled from farm data',
            icon: Icons.location_on_outlined,
            suffix: _farmLocationController.text.isNotEmpty
                ? const Icon(Icons.verified, color: Color(0xFF4CAF50), size: 18)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion10() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(10),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel('Farm size')),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _farmSizeController,
          readOnly: true,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _fieldDecoration(
            hint: 'Auto-filled from farm data',
            icon: Icons.straighten_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion11() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(11),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel('Current season')),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 12),
              Text(
                _currentSeason,
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(auto-detected)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion12() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(12),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel('Crop duration preference')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cropDurationOptions.map((option) {
            final isSelected = _cropDurationPreference == option;
            return GestureDetector(
              onTap: () =>
                  setState(() => _cropDurationPreference = option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                      : const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuestion13() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(13),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel('Crop category preference')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cropCategoryOptions.map((option) {
            final isSelected = _cropCategoryPreference == option;
            return GestureDetector(
              onTap: () =>
                  setState(() => _cropCategoryPreference = option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                      : const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGetRecommendationsButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _getRecommendations,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text(
          'Get Recommendations',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      dropdownColor: const Color(0xFF1A2332),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.white.withValues(alpha: 0.4)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        prefixIcon:
            Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 20),
        filled: true,
        fillColor: const Color(0xFF1A2332),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
