import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

/// Crop recommendation setup.
///
/// The AI recommendation needs only ~6 manual inputs from the farmer. All other
/// context (location, farm size, soil, water source, irrigation, farming type,
/// previous crops, season, weather and market prices) is collected
/// automatically from the stored farm profile, crop history and live sources.
class CropSetupScreen extends StatefulWidget {
  final String farmId;

  const CropSetupScreen({super.key, required this.farmId});

  @override
  State<CropSetupScreen> createState() => _CropSetupScreenState();
}

class _CropSetupScreenState extends State<CropSetupScreen> {
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _farmerPreferenceController = TextEditingController();

  FarmProfile? _profile;
  String _lastCropName = '';
  String _lastHarvestDate = '';
  String _landIdleMonths = '';
  String _previousCropSowingDate = '';
  String _previousCropDuration = '';

  String _waterAvailability = '';
  String _cropDurationPreference = '';
  String _cropCategoryPreference = '';
  String _farmingPriority = '';
  String _currentSeason = '';

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
    'Commercial/Cash Crops',
    'No preference',
  ];

  static const _waterLevels = [
    'High',
    'Medium',
    'Low',
    'Very Low',
    'No Water',
  ];

  /// Fixed English values that are stored in the questionnaire and sent to the
  /// AI backend. Display labels are localized (see `_farmingPriorityLabels`).
  static const _farmingPriorityValues = [
    'Max Profit',
    'Low Risk',
    'Quick Harvest',
    'Low Water',
    'Balanced',
  ];

  @override
  void initState() {
    super.initState();
    _currentSeason = _detectSeason();
    _loadFarmData();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _farmerPreferenceController.dispose();
    super.dispose();
  }

  String _detectSeason() {
    final month = DateTime.now().month;
    if (month >= 6 && month <= 9) return 'Kharif';
    if (month >= 10 || month <= 3) return 'Rabi';
    return 'Zaid';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _loadFarmData() async {
    try {
      final farms = await DataService().loadFarms();
      final match = farms.where((f) => f.farmId == widget.farmId);
      if (match.isEmpty) return;
      final profile = match.first;
      final crops = await DataService().loadCrops(widget.farmId);

      String lastCropName = '';
      String lastHarvestDate = '';
      String landIdleMonths = '';
      String prevSowing = '';
      String prevDuration = '';
      final records = crops.where((c) => c.status != 'active').toList()
        ..sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
      if (records.isNotEmpty) {
        final last = records.first;
        lastCropName = last.cropName;
        prevSowing = _formatDate(last.plantingDate);

        final harvestDate = last.endDate ?? last.expectedHarvestDate;
        if (harvestDate != null) {
          lastHarvestDate = _formatDate(harvestDate);
          final idleDays = DateTime.now().difference(harvestDate).inDays;
          if (idleDays >= 0) {
            landIdleMonths = (idleDays / 30).floor().toString();
          }
          final cropDays = harvestDate.difference(last.plantingDate).inDays;
          if (cropDays > 0) {
            prevDuration = cropDays.toString();
          }
        } else if (last.expectedHarvestDate != null) {
          prevDuration = last.expectedHarvestDate!
              .difference(last.plantingDate)
              .inDays
              .toString();
        }
      }

      setState(() {
        _profile = profile;
        _lastCropName = lastCropName;
        _lastHarvestDate = lastHarvestDate;
        _landIdleMonths = landIdleMonths;
        _previousCropSowingDate = prevSowing;
        _previousCropDuration = prevDuration;
        if (_waterAvailability.isEmpty && profile.waterAvailability.isNotEmpty) {
          _waterAvailability = profile.waterAvailability;
        }
      });
    } catch (_) {}
  }

  int? _parseBudget() {
    final cleaned = _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    final value = int.tryParse(cleaned);
    return (value == null || value <= 0) ? null : value;
  }

  List<({String value, String label})> _farmingPriorityLabels(AppLocalizations loc) {
    final labels = <String>[
      loc.farmingPriorityMaxProfit,
      loc.farmingPriorityLowRisk,
      loc.farmingPriorityQuickHarvest,
      loc.farmingPriorityLowWater,
      loc.farmingPriorityBalanced,
    ];
    return [
      for (var i = 0; i < _farmingPriorityValues.length; i++)
        (value: _farmingPriorityValues[i], label: labels[i]),
    ];
  }

  void _getRecommendations() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final profile = _profile;

    final questionnaire = CropSetupQuestionnaire(
      // ── Manual inputs (the only ones the farmer must provide) ──
      cropCategoryPreference: _cropCategoryPreference,
      cropDurationPreference: _cropDurationPreference,
      budgetInrPerAcre: _parseBudget(),
      waterAvailability: _waterAvailability,
      farmingPriority: _farmingPriority,
      farmerPreference: _farmerPreferenceController.text.trim(),
      // ── Auto-collected farm context ──
      lastCrop: _lastCropName,
      harvestDate: _lastHarvestDate,
      landIdleDuration: _landIdleMonths,
      previousCropSowingDate: _previousCropSowingDate,
      previousCropDuration: _previousCropDuration,
      soilType: profile?.soilType ?? '',
      irrigationSystem: profile?.irrigationType ?? '',
      waterSource: profile?.waterSource ?? '',
      farmLocation: profile?.farmLocation?.fullAddress ?? '',
      farmSize: profile?.farmSize.isNotEmpty == true
          ? '${profile!.farmSize} ${profile.farmSizeUnit}'
          : '',
      currentSeason: _currentSeason,
    );

    final missingFields = questionnaire.getMissingMandatoryFields(loc);
    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...missingFields.map((f) => Text('• $f',
                  style: TextStyle(color: colors.onBackground, fontSize: 13))),
            ],
          ),
          backgroundColor: colors.warning,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _buildInfoHeader(loc.cropSetupHelpText),
          const SizedBox(height: 20),
          _buildAutoContextCard(),
          const SizedBox(height: 24),
          _buildSectionTitle(loc.cropCategoryPreference, required: true),
          const SizedBox(height: 8),
          _buildDropdownField(
            value: _cropCategoryPreference.isEmpty ? null : _cropCategoryPreference,
            hint: loc.cropCategoryPreference,
            icon: Icons.category_outlined,
            items: _cropCategoryOptions,
            onChanged: (v) => setState(() => _cropCategoryPreference = v ?? ''),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle(loc.cropDurationPreference, required: true),
          const SizedBox(height: 8),
          _buildDropdownField(
            value: _cropDurationPreference.isEmpty ? null : _cropDurationPreference,
            hint: loc.cropDurationPreference,
            icon: Icons.timer_outlined,
            items: _cropDurationOptions,
            onChanged: (v) => setState(() => _cropDurationPreference = v ?? ''),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle(loc.cropBudgetPerAcre, required: true),
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
              prefixStyle:
                  TextStyle(color: colors.onSurfaceMuted, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.cropBudgetHelper,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle(loc.currentWaterAvailability, required: true),
          const SizedBox(height: 8),
          _buildWaterAvailabilityInput(),
          const SizedBox(height: 20),
          _buildSectionTitle(loc.farmingPriority, required: true),
          const SizedBox(height: 4),
          Text(
            loc.farmingPriorityHint,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _buildFarmingPriorityInput(),
          const SizedBox(height: 20),
          _buildSectionTitle(loc.farmerPreference),
          const SizedBox(height: 8),
          TextFormField(
            controller: _farmerPreferenceController,
            maxLines: 2,
            style: TextStyle(color: colors.onBackground, fontSize: 15),
            decoration: _fieldDecoration(
              hint: loc.farmerPreferenceHint,
              icon: Icons.edit_note_rounded,
            ),
          ),
          const SizedBox(height: 28),
          _buildGetRecommendationsButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(String text) {
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

  Widget _buildSectionTitle(String label, {bool required = false}) {
    final colors = VidhAIColorsX(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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

  Widget _buildWaterAvailabilityInput() {
    final colors = VidhAIColorsX(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _waterLevels.map((level) {
        final isSelected = _waterAvailability == level;
        final color = _waterLevelColor(level, colors);
        return GestureDetector(
          onTap: () => setState(() => _waterAvailability = level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFarmingPriorityInput() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final options = _farmingPriorityLabels(loc);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = _farmingPriority == option.value;
        return GestureDetector(
          onTap: () => setState(() => _farmingPriority = option.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              option.label,
              style: TextStyle(
                color: isSelected ? colors.brandDeep : colors.onSurfaceMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Read-only card explaining which farm facts are already included.
  Widget _buildAutoContextCard() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final profile = _profile;
    final rows = <(IconData, String, String)>[];

    final locationText = profile?.farmLocation?.fullAddress ?? '';
    if (locationText.trim().isNotEmpty) {
      rows.add((
        Icons.place_outlined,
        loc.farmDetails,
        locationText,
      ));
    }
    if (profile != null && profile.farmSize.isNotEmpty) {
      rows.add((
        Icons.square_foot_rounded,
        loc.farmSize,
        '${profile.farmSize} ${profile.farmSizeUnit}',
      ));
    }
    if (profile != null && profile.soilType.isNotEmpty) {
      rows.add((Icons.terrain_rounded, loc.soilType, profile.soilType));
    }
    if (profile != null && profile.waterAvailability.isNotEmpty) {
      rows.add((
        Icons.water_drop_outlined,
        loc.waterAvailability,
        profile.waterAvailability,
      ));
    }
    if (profile != null && profile.waterSource.isNotEmpty) {
      rows.add((
        Icons.water_outlined,
        loc.waterSource,
        profile.waterSource,
      ));
    }
    if (profile != null && profile.irrigationType.isNotEmpty) {
      rows.add((
        Icons.grain_rounded,
        loc.irrigationSystemAvailable,
        profile.irrigationType,
      ));
    }
    if (profile != null && profile.farmingMethod.isNotEmpty) {
      rows.add((
        Icons.agriculture_rounded,
        loc.farmingMethod,
        profile.farmingMethod,
      ));
    }
    if (_lastCropName.isNotEmpty) {
      rows.add((
        Icons.grass_rounded,
        loc.lastCropGrown,
        _lastCropName,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: colors.brandDeep, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.autoCollectedContext,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final (icon, label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: colors.onSurfaceMuted, size: 16),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.brandDeep.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_outlined,
                    color: colors.brandDeep, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    loc.ctxWeatherMarket,
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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