import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/voice_service.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

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
  final TextEditingController _budgetController = TextEditingController();

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

  int? _parseBudget() {
    final cleaned = _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    final value = int.tryParse(cleaned);
    return (value == null || value <= 0) ? null : value;
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
        final colors = VidhAIColorsX(context);
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.permissionDenied),
            backgroundColor: colors.danger,
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
    final colors = VidhAIColorsX(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.brandDeep,
              onPrimary: Colors.white,
              surface: colors.surface,
              onSurface: colors.onBackground,
            ),
            dialogTheme: DialogThemeData(backgroundColor: colors.surface),
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
      budgetInrPerAcre: _parseBudget(),
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
          loc.cropSetup,
          style: TextStyle(
            color: colors.onBackground,
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
            _buildQuestionHeader(loc.cropSetupHelpText),
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
            const SizedBox(height: 16),
            _buildQuestion14(),
            const SizedBox(height: 24),
            _buildGetRecommendationsButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionHeader(String text) {
    final colors = VidhAIColorsX(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.brandDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.brandDeep.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.brandDeep, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberBadge(int number) {
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

  Widget _buildFieldLabel(String label, {bool required = false}) {
    final colors = VidhAIColorsX(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: TextStyle(color: colors.danger, fontSize: 14),
          ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final colors = VidhAIColorsX(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.onSurfaceMuted),
      prefixIcon: Icon(icon, color: colors.onSurfaceMuted, size: 20),
      suffixIcon: suffix,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildQuestion1() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(1),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.lastCropGrown)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _lastCropController,
                style: TextStyle(color: colors.onBackground, fontSize: 15),
                decoration: _fieldDecoration(
                  hint: loc.hintLastCrop,
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
                      ? colors.danger.withValues(alpha: 0.2)
                      : colors.brandDeep.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isListeningLastCrop ? Icons.mic : Icons.mic_none_rounded,
                  color:
                      _isListeningLastCrop ? colors.danger : colors.brandDeep,
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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(2),
            const SizedBox(width: 10),
            Expanded(
                child:
                    _buildFieldLabel(loc.whenWasItHarvested, required: true)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickDate(isHarvestDate: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: colors.onSurfaceMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  _harvestDate != null
                      ? _formatDate(_harvestDate!)
                      : loc.selectHarvestDate,
                  style: TextStyle(
                    color: _harvestDate != null
                        ? colors.onBackground
                        : colors.onSurfaceMuted,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_harvestDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _harvestDate = null),
                    child: Icon(Icons.close,
                        color: colors.onSurfaceMuted, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion3() {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(3),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.howLongLandIdle)),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdownField(
          value: _landIdleDuration.isEmpty ? null : _landIdleDuration,
          hint: loc.selectDuration,
          icon: Icons.timer_outlined,
          items: _landIdleOptions,
          onChanged: (v) => setState(() => _landIdleDuration = v ?? ''),
        ),
      ],
    );
  }

  Widget _buildQuestion4() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(4),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.whenLastIrrigation)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickDate(isHarvestDate: false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined,
                    color: colors.onSurfaceMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  _lastIrrigationDate != null
                      ? _formatDate(_lastIrrigationDate!)
                      : loc.selectLastIrrigationDate,
                  style: TextStyle(
                    color: _lastIrrigationDate != null
                        ? colors.onBackground
                        : colors.onSurfaceMuted,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_lastIrrigationDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _lastIrrigationDate = null),
                    child: Icon(Icons.close,
                        color: colors.onSurfaceMuted, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion5() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(5),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.currentWaterAvailability)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _waterLevels.map((level) {
            final isSelected = _waterAvailability == level;
            final color = _waterLevelColor(level, colors);
            return GestureDetector(
              onTap: () => setState(() => _waterAvailability = level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : colors.borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: isSelected ? color : colors.onSurfaceMuted,
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

  Color _waterLevelColor(String level, VidhAIColorsX colors) {
    switch (level) {
      case 'High':
        return colors.info;
      case 'Medium':
        return colors.brandDeep;
      case 'Low':
        return colors.warning;
      case 'Very Low':
        return const Color(0xFFFF5722);
      case 'No Water':
        return colors.danger;
      default:
        return colors.brandDeep;
    }
  }

  Widget _buildQuestion6() {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(6),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.soilType)),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdownField(
          value: _soilType.isEmpty ? null : _soilType,
          hint: loc.selectSoilType,
          icon: Icons.terrain_rounded,
          items: _soilTypeOptions,
          onChanged: (v) => setState(() => _soilType = v ?? ''),
        ),
      ],
    );
  }

  Widget _buildQuestion7() {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(7),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.soilCondition)),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdownField(
          value: _soilCondition.isEmpty ? null : _soilCondition,
          hint: loc.selectSoilCondition,
          icon: Icons.eco_rounded,
          items: _soilConditionOptions,
          onChanged: (v) => setState(() => _soilCondition = v ?? ''),
        ),
      ],
    );
  }

  Widget _buildQuestion8() {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(8),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.irrigationSystemAvailable)),
          ],
        ),
        const SizedBox(height: 8),
        _buildDropdownField(
          value: _irrigationSystem.isEmpty ? null : _irrigationSystem,
          hint: loc.selectIrrigationSystem,
          icon: Icons.water_outlined,
          items: _irrigationSystemOptions,
          onChanged: (v) => setState(() => _irrigationSystem = v ?? ''),
        ),
      ],
    );
  }

  Widget _buildQuestion9() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(9),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.farmLocation)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _farmLocationController,
          readOnly: true,
          style: TextStyle(color: colors.onBackground, fontSize: 15),
          decoration: _fieldDecoration(
            hint: loc.autoFilledFromFarmData,
            icon: Icons.location_on_outlined,
            suffix: _farmLocationController.text.isNotEmpty
                ? Icon(Icons.verified, color: colors.brandDeep, size: 18)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion10() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(10),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.farmSize)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _farmSizeController,
          readOnly: true,
          style: TextStyle(color: colors.onBackground, fontSize: 15),
          decoration: _fieldDecoration(
            hint: loc.autoFilledFromFarmData,
            icon: Icons.straighten_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion11() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(11),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.currentSeason)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.brandDeep.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: colors.brandDeep, size: 20),
              const SizedBox(width: 12),
              Text(
                _currentSeason,
                style: TextStyle(
                  color: colors.brandDeep,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                loc.autoDetected,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(12),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.cropDurationPreference)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cropDurationOptions.map((option) {
            final isSelected = _cropDurationPreference == option;
            return GestureDetector(
              onTap: () => setState(() => _cropDurationPreference = option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.brandDeep.withValues(alpha: 0.2)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? colors.brandDeep : colors.borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color:
                        isSelected ? colors.brandDeep : colors.onSurfaceMuted,
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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(13),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.cropCategoryPreference)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cropCategoryOptions.map((option) {
            final isSelected = _cropCategoryPreference == option;
            return GestureDetector(
              onTap: () => setState(() => _cropCategoryPreference = option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.brandDeep.withValues(alpha: 0.2)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? colors.brandDeep : colors.borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color:
                        isSelected ? colors.brandDeep : colors.onSurfaceMuted,
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

  Widget _buildQuestion14() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge(14),
            const SizedBox(width: 10),
            Expanded(child: _buildFieldLabel(loc.cropBudgetPerAcre)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: colors.onBackground, fontSize: 15),
          decoration: _fieldDecoration(
            hint: loc.cropBudgetHint,
            icon: Icons.account_balance_wallet_outlined,
          ).copyWith(
            prefixText: '₹ ',
            prefixStyle: TextStyle(color: colors.onSurfaceMuted, fontSize: 15),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc.cropBudgetHelper,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildGetRecommendationsButton() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _getRecommendations,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: Text(
          loc.getRecommendations,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brandDeep,
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
    final colors = VidhAIColorsX(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: TextStyle(color: colors.onBackground, fontSize: 15),
      dropdownColor: colors.surface,
      icon:
          Icon(Icons.keyboard_arrow_down_rounded, color: colors.onSurfaceMuted),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.onSurfaceMuted),
        prefixIcon: Icon(icon, color: colors.onSurfaceMuted, size: 20),
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
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
