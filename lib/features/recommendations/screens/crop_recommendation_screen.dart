import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/ai/ai_config.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/farm_recommendation_service.dart';

class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<CropRecommendation> _allRecommendations = [];
  List<CropRecommendation> _filteredRecommendations = [];
  FarmProfile? _farm;
  CropSetupQuestionnaire? _questionnaire;

  String _selectedDuration = 'All';
  String _selectedCategory = 'All';
  int? _expandedIndex;

  late AnimationController _shimmerController;

  static const _durationFilters = [
    'All',
    'Short',
    'Medium',
    'Long',
  ];
  static const _categoryFilters = [
    'All',
    'Vegetable',
    'Fruit',
    'Cereal',
    'Pulse',
    'Spice',
    'Flower',
    'Leafy',
    'Tree',
    'Medicinal',
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecommendations());
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _farm = args['farm'] as FarmProfile?;
      _questionnaire = args['questionnaire'] as CropSetupQuestionnaire?;
      if (_farm == null && args['farmId'] != null) {
        final farms = await DataService().loadFarms();
        final match = farms.where((f) => f.farmId == args['farmId']);
        if (match.isNotEmpty) _farm = match.first;
      }
    } else if (args is FarmProfile) {
      _farm = args;
    }

    if (_farm != null) {
      final aiProvider = AiService.instance.config.provider;

      if (aiProvider == AIProvider.gemini || aiProvider == AIProvider.openai || aiProvider == AIProvider.backend) {
        try {
          final farmProfile = <String, dynamic>{
            'farmName': _farm!.farmName,
            'soilType': _farm!.soilType,
            'waterAvailability': _farm!.waterAvailability,
            'farmSize': _farm!.farmSize,
            'farmSizeUnit': _farm!.farmSizeUnit,
            'irrigationType': _farm!.irrigationType,
            'waterSource': _farm!.waterSource,
            'farmingMethod': _farm!.farmingMethod,
            'location': _farm!.farmLocation != null
                ? '${_farm!.farmLocation!.district}, ${_farm!.farmLocation!.state}'
                : '',
          };
          if (_questionnaire != null) {
            farmProfile.addAll(_questionnaire!.toMap());
          }

          final request = RecommendationRequest(
            farmProfile: farmProfile,
            season: _getCurrentSeason(),
            location: _farm!.farmLocation?.state,
            preferences: _questionnaire?.cropCategoryPreference.isNotEmpty == true
                ? 'Preferred categories: ${_questionnaire!.cropCategoryPreference}'
                : null,
          );

          final response = await AiService.instance.getCropRecommendation(request);

          if (response.success && response.jsonContent != null) {
            final data = response.jsonContent!;
            final List<dynamic> recs = data['recommendations'] ?? [];
            _allRecommendations = recs.map<CropRecommendation>((r) {
              return CropRecommendation(
                cropId: '',
                cropName: r['cropName'] ?? r['crop'] ?? '',
                variety: r['variety'] ?? r['cropName'] ?? '',
                category: r['category'] ?? 'Cereal',
                duration: r['daysToHarvest'] != null
                    ? '${r['daysToHarvest']} days'
                    : (r['duration'] ?? ''),
                suitableSoil: r['suitableSoil'] ?? _farm!.soilType,
                waterRequirement: r['waterRequirement'] ?? 'Medium',
                suitableClimate: r['suitableClimate'] ?? _getCurrentSeason(),
                expectedYield: r['expectedYield'] ?? '',
                estimatedInvestment: r['estimatedInvestment'] ?? r['investmentLevel'] ?? '',
                expectedRevenue: r['expectedRevenue'] ?? r['marketPrice'] ?? '',
                potentialProfit: r['potentialProfit'] ?? '',
                marketAvailability: r['marketDemand'] ?? r['marketAvailability'] ?? 'Medium',
                riskLevel: r['riskLevel'] ?? 'Medium',
                whyRecommended: r['reasoning'] ?? r['reason'] ?? '',
                bestPlantingPeriod: r['bestPlantingPeriod'] ?? _getCurrentSeason(),
                expectedHarvestPeriod: r['expectedHarvestPeriod'] ?? '',
                score: (r['suitabilityScore'] ?? r['profitabilityScore'] ?? 0).toDouble(),
              );
            }).toList();
          }
        } catch (_) {}
      }

      if (_allRecommendations.isEmpty) {
        final service = FarmRecommendationService();
        _allRecommendations = service.getRecommendations(
          farm: _farm!,
          questionnaire: _questionnaire,
        );
      }
      _applyFilters();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _applyFilters() {
    _filteredRecommendations = _allRecommendations.where((r) {
      bool matchDuration = _selectedDuration == 'All' ||
          r.duration.toLowerCase().contains(_selectedDuration.toLowerCase());
      bool matchCategory = _selectedCategory == 'All' ||
          r.category.toLowerCase() == _selectedCategory.toLowerCase();
      return matchDuration && matchCategory;
    }).toList();
  }

  Color _riskColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'high':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectCrop(CropRecommendation crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Crop',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Add ${crop.cropName} (${crop.variety}) to your farm?\n\n'
          'This crop will be added as an active crop in your farm profile.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && _farm != null && mounted) {
      final now = DateTime.now();
      final cropRecord = CropRecord(
        id: const Uuid().v4(),
        farmId: _farm!.farmName,
        cropName: crop.cropName,
        variety: crop.variety,
        category: crop.category,
        duration: crop.duration,
        plantingDate: now,
        status: 'active',
      );

      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('farm_crops_${_farm!.farmName}') ?? [];
      existing.add(
        '${DateTime.now().toIso8601String()}|||'
        '${crop.cropName}|||${crop.variety}|||${crop.category}|||${crop.duration}',
      );
      await prefs.setStringList('farm_crops_${_farm!.farmName}', existing);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${crop.cropName} added to your farm!'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.of(context).pop(cropRecord);
      }
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'VidhAI Crop Recommendations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _allRecommendations.isEmpty
              ? _buildEmptyState()
              : _buildRecommendationsList(),
    );
  }

  Widget _buildLoadingState() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _shimmerBox(height: 120),
              const SizedBox(height: 16),
              _shimmerBox(height: 80),
              const SizedBox(height: 16),
              Row(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _shimmerBox(height: 36, width: 70),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _shimmerBox(height: 320),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox({double height = 100, double? width}) {
    final brightness = 0.05 + (_shimmerController.value * 0.05);
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: brightness),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Color(0xFF4CAF50),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Recommendations Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We couldn\'t find matching crops for your farm profile. Try adjusting your questionnaire.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsList() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_farm != null) _buildFarmContextCard(),
                const SizedBox(height: 16),
                if (_questionnaire != null) _buildReasoningSection(),
                if (_questionnaire != null) const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 20),
                Text(
                  '${_filteredRecommendations.length} Recommendations',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(_filteredRecommendations.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildRecommendationCard(
                      _filteredRecommendations[index],
                      index,
                    ),
                  );
                }),
                if (_filteredRecommendations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No crops match the selected filters.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFarmContextCard() {
    final farm = _farm!;
    final location = farm.farmLocation != null
        ? '${farm.farmLocation!.district}, ${farm.farmLocation!.state}'
        : 'Not specified';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Farm Context',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _contextChip(Icons.location_on_outlined, 'Location', location),
              const SizedBox(width: 12),
              _contextChip(Icons.landscape_outlined, 'Soil', farm.soilType),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _contextChip(
                Icons.water_drop_outlined,
                'Water',
                farm.waterAvailability,
              ),
              const SizedBox(width: 12),
              _contextChip(
                Icons.sunny,
                'Season',
                _getCurrentSeason(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _contextChip(
                Icons.straighten,
                'Size',
                '${farm.farmSize} ${farm.farmSizeUnit}',
              ),
              const SizedBox(width: 12),
              _contextChip(
                Icons.plumbing_outlined,
                'Irrigation',
                farm.irrigationType,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contextChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasoningSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.psychology_rounded,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Based on your farm profile',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _reasoningItem('Region', 'Recommendations for ${_farm?.farmLocation?.state ?? "your area"}'),
          _reasoningItem('Soil', 'Suitable for ${_farm?.soilType ?? "your soil type"} soil'),
          _reasoningItem('Water', '${_farm?.waterAvailability ?? "Moderate"} water availability considered'),
          _reasoningItem(
            'Season',
            'Optimized for ${_getCurrentSeason()} season crops',
          ),
          if (_questionnaire?.lastCrop.isNotEmpty == true)
            _reasoningItem(
              'Rotation',
              'Excluded ${_questionnaire!.lastCrop} for crop rotation',
            ),
        ],
      ),
    );
  }

  Widget _reasoningItem(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: detail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
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

  Widget _buildFilterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duration',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _durationFilters.map((f) {
              final selected = _selectedDuration == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedDuration = f;
                      _applyFilters();
                    });
                  },
                  backgroundColor: const Color(0xFF1A2235),
                  selectedColor: const Color(0xFF4CAF50),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF4CAF50)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Category',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categoryFilters.map((f) {
              final selected = _selectedCategory == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = f;
                      _applyFilters();
                    });
                  },
                  backgroundColor: const Color(0xFF1A2235),
                  selectedColor: const Color(0xFF4CAF50),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF4CAF50)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(CropRecommendation crop, int index) {
    final isExpanded = _expandedIndex == index;
    final riskColor = _riskColor(crop.riskLevel);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crop.cropName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            crop.variety,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${crop.riskLevel} Risk',
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _infoTag(Icons.schedule, crop.duration),
                    _infoTag(Icons.category_outlined, crop.category),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _financialRow(
                        'Est. Investment',
                        crop.estimatedInvestment,
                        Icons.account_balance_wallet_outlined,
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      _financialRow(
                        'Est. Yield',
                        crop.expectedYield,
                        Icons.grass_rounded,
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      _financialRow(
                        'Est. Revenue',
                        crop.expectedRevenue,
                        Icons.trending_up_rounded,
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      _financialRow(
                        'Est. Profit',
                        crop.potentialProfit,
                        Icons.savings_rounded,
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedIndex = isExpanded ? null : index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2235),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFFFFC107),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Why recommended?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.expand_more,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      crop.whyRecommended,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _periodInfo(
                        Icons.calendar_today_outlined,
                        'Plant',
                        crop.bestPlantingPeriod,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _periodInfo(
                        Icons.event_available_outlined,
                        'Harvest',
                        crop.expectedHarvestPeriod,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white12, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showCropDetails(crop),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: const Center(
                        child: Text(
                          'View Details',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 32,
                  color: Colors.white12,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectCrop(crop),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: const Center(
                        child: Text(
                          'Select Crop',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
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

  Widget _infoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialRow(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? const Color(0xFF4CAF50) : Colors.white,
            fontSize: 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _periodInfo(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCropDetails(CropRecommendation crop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    crop.cropName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    crop.variety,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _detailRow('Category', crop.category),
                  _detailRow('Duration', crop.duration),
                  _detailRow('Risk Level', crop.riskLevel),
                  _detailRow('Suitable Soil', crop.suitableSoil),
                  _detailRow('Water Requirement', crop.waterRequirement),
                  _detailRow('Climate', crop.suitableClimate),
                  _detailRow('Market Demand', crop.marketAvailability),
                  _detailRow('Investment / Acre', crop.estimatedInvestment),
                  _detailRow('Yield / Acre', crop.expectedYield),
                  _detailRow('Revenue / Acre', crop.expectedRevenue),
                  _detailRow('Profit / Acre', crop.potentialProfit),
                  _detailRow('Planting Period', crop.bestPlantingPeriod),
                  _detailRow('Harvest Period', crop.expectedHarvestPeriod),
                  const SizedBox(height: 16),
                  const Text(
                    'Why Recommended',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    crop.whyRecommended,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 6 && month <= 9) return 'Kharif';
    if (month >= 10 && month <= 3) return 'Rabi';
    return 'Zaid';
  }
}
