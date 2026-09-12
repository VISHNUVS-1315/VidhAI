import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/crop_knowledge_base.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class CropSearchScreen extends StatefulWidget {
  const CropSearchScreen({super.key});

  @override
  State<CropSearchScreen> createState() => _CropSearchScreenState();
}

class _CropSearchScreenState extends State<CropSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CropKnowledgeBase _knowledgeBase = CropKnowledgeBase();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  static const List<String> _categories = [
    'All',
    'Cereals',
    'Pulses',
    'Vegetables',
    'Fruits',
    'Spices',
    'Flowers',
    'Oilseeds',
    'Plantation Crops',
    'Tree Crops',
    'Medicinal/Aromatic',
    'Leafy Vegetables',
  ];

  List<CropKnowledgeEntry> get _filteredCrops {
    return _knowledgeBase.allCrops.where((crop) {
      final matchesCategory =
          _selectedCategory == 'All' || crop.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          crop.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          crop.variety.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          crop.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCropDetail(CropKnowledgeEntry crop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CropDetailSheet(crop: crop),
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
          loc.cropSearchTitle,
          style: TextStyle(
              color: colors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          const VidhAIAssistantButton(
              screen: 'crop_search', size: 36, iconSize: 18),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: colors.onBackground, fontSize: 15),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: loc.cropSearchHint,
                hintStyle: TextStyle(color: colors.onSurfaceMuted),
                prefixIcon: Icon(Icons.search_rounded,
                    color: colors.onSurfaceMuted, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: colors.onSurfaceMuted, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
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
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.brandDeep.withValues(alpha: 0.2)
                          : colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? colors.brandDeep : colors.borderColor,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? colors.brandDeep
                            : colors.onSurfaceMuted,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                loc.cropSearchCount
                    .replaceAll('{count}', _filteredCrops.length.toString()),
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredCrops.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            color: colors.onSurfaceMuted, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          loc.noCropsFound,
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filteredCrops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final crop = _filteredCrops[index];
                      return _CropCard(
                        crop: crop,
                        onTap: () => _showCropDetail(crop),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final CropKnowledgeEntry crop;
  final VoidCallback onTap;

  const _CropCard({required this.crop, required this.onTap});

  Color _categoryColor(String cat, VidhAIColorsX colors) {
    switch (cat) {
      case 'Cereals':
        return const Color(0xFF8D6E63);
      case 'Pulses':
        return const Color(0xFFFF9800);
      case 'Vegetables':
        return colors.brandDeep;
      case 'Fruits':
        return const Color(0xFFE91E63);
      case 'Spices':
        return const Color(0xFFFF5722);
      case 'Flowers':
        return const Color(0xFF9C27B0);
      case 'Oilseeds':
        return const Color(0xFFFFC107);
      case 'Plantation Crops':
        return const Color(0xFF009688);
      case 'Tree Crops':
        return const Color(0xFF795548);
      case 'Medicinal/Aromatic':
        return const Color(0xFF3F51B5);
      case 'Leafy Vegetables':
        return const Color(0xFF66BB6A);
      default:
        return colors.brandDeep;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Cereals':
        return Icons.grain_rounded;
      case 'Pulses':
        return Icons.circle_rounded;
      case 'Vegetables':
        return Icons.eco_rounded;
      case 'Fruits':
        return Icons.apple_rounded;
      case 'Spices':
        return Icons.local_fire_department_rounded;
      case 'Flowers':
        return Icons.local_florist_rounded;
      case 'Oilseeds':
        return Icons.water_drop_rounded;
      case 'Plantation Crops':
        return Icons.park_rounded;
      case 'Tree Crops':
        return Icons.forest_rounded;
      case 'Medicinal/Aromatic':
        return Icons.medical_services_rounded;
      case 'Leafy Vegetables':
        return Icons.grass_rounded;
      default:
        return Icons.eco_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final color = _categoryColor(crop.category, colors);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_categoryIcon(crop.category), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crop.name,
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    crop.variety,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    crop.category,
                    style: TextStyle(
                        color: color, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${crop.durationDays} days',
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CropDetailSheet extends StatelessWidget {
  final CropKnowledgeEntry crop;

  const _CropDetailSheet({required this.crop});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                crop.name,
                                style: TextStyle(
                                  color: colors.onBackground,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                crop.variety,
                                style: TextStyle(
                                    color: colors.onSurfaceMuted, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.brandDeep.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            crop.category,
                            style: TextStyle(
                              color: colors.brandDeep,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      crop.description,
                      style:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(loc.growthDetailsHeading, colors),
                    const SizedBox(height: 10),
                    _infoGrid([
                      _infoTile(Icons.schedule_rounded, loc.duration,
                          '${crop.durationDays} days', colors),
                      _infoTile(Icons.water_drop_rounded, loc.water,
                          crop.waterRequirement, colors),
                      _infoTile(Icons.thermostat_rounded, loc.temperature,
                          crop.suitableTemperature, colors),
                      _infoTile(Icons.wb_sunny_rounded, loc.season, crop.season,
                          colors),
                      _infoTile(Icons.calendar_today_rounded, loc.sowing,
                          crop.bestPlantingMonth, colors),
                      _infoTile(Icons.event_rounded, loc.harvest,
                          crop.harvestMonth, colors),
                    ]),
                    const SizedBox(height: 20),
                    _sectionTitle(loc.investmentReturnsHeading, colors),
                    const SizedBox(height: 10),
                    _financeRow(Icons.payments_rounded, loc.investmentPerAcre,
                        crop.investmentPerAcre, colors.warning, colors),
                    _financeRow(Icons.trending_up_rounded, loc.expectedYield,
                        crop.expectedYieldPerAcre, colors.brandDeep, colors),
                    _financeRow(
                        Icons.account_balance_rounded,
                        loc.revenuePerAcre,
                        crop.revenuePerAcre,
                        colors.info,
                        colors),
                    _financeRow(Icons.savings_rounded, loc.profitPerAcre,
                        crop.profitPerAcre, colors.brandDeep, colors),
                    const SizedBox(height: 20),
                    _sectionTitle(loc.suitableRegionsHeading, colors),
                    const SizedBox(height: 10),
                    _infoTile(Icons.landscape_rounded, loc.suitableSoilsLabel,
                        crop.suitableSoils.join(', '), colors),
                    const SizedBox(height: 8),
                    _infoTile(Icons.map_rounded, loc.suitableStatesLabel,
                        crop.suitableStates.join(', '), colors),
                    const SizedBox(height: 8),
                    _infoTile(Icons.cloud_rounded, loc.agroClimaticLabel,
                        crop.agroClimaticZones, colors),
                    const SizedBox(height: 20),
                    _sectionTitle(loc.marketRiskHeading, colors),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            loc.marketDemand,
                            crop.marketDemand,
                            crop.marketDemand == 'High'
                                ? colors.brandDeep
                                : colors.warning,
                            colors,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            loc.riskLevel,
                            crop.riskLevel,
                            crop.riskLevel == 'Low'
                                ? colors.brandDeep
                                : crop.riskLevel == 'Medium'
                                    ? colors.warning
                                    : colors.danger,
                            colors,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final loc = AppLocalizations.of(context);
                          Navigator.pop(context);
                          if (!context.mounted) return;

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => Dialog(
                              backgroundColor: colors.surface,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                        color: colors.brandDeep),
                                    const SizedBox(width: 16),
                                    Text(
                                      loc.cropAnalysisLoading,
                                      style:
                                          TextStyle(color: colors.onBackground),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          try {
                            final farms = await DataService().loadFarms();
                            if (!context.mounted) return;
                            Navigator.pop(context);

                            if (farms.isEmpty) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: colors.surface,
                                  title: Text(loc.noFarmsFoundTitle,
                                      style: TextStyle(
                                          color: colors.onBackground)),
                                  content: Text(
                                    loc.noFarmsFoundBody,
                                    style:
                                        TextStyle(color: colors.onSurfaceMuted),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(loc.ok,
                                          style: TextStyle(
                                              color: colors.brandDeep)),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            final farm = farms.first;
                            final farmDetails = StringBuffer()
                              ..writeln('Farm Name: ${farm.farmName}')
                              ..writeln(
                                  'Size: ${farm.farmSize} ${farm.farmSizeUnit}')
                              ..writeln('Soil Type: ${farm.soilType}')
                              ..writeln('Irrigation: ${farm.irrigationType}')
                              ..writeln('Water Source: ${farm.waterSource}')
                              ..writeln(
                                  'Farming Method: ${farm.farmingMethod}');

                            final prompt =
                                'Analyze how suitable ${crop.name} (${crop.variety}) is for my farm.\n'
                                'Farm Details:\n$farmDetails\n'
                                'Crop Details: Season ${crop.season}, Duration ${crop.durationDays} days, '
                                'Water requirement ${crop.waterRequirement}, Suitable temperature ${crop.suitableTemperature}, '
                                'Suitable soils: ${crop.suitableSoils.join(", ")}.\n'
                                'Give a suitability score out of 10, key risks, and actionable recommendations.';

                            final response =
                                await AiService.instance.chat(prompt);

                            if (!context.mounted) return;

                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: colors.surface,
                                title: Row(
                                  children: [
                                    Icon(Icons.auto_awesome_rounded,
                                        color: colors.brandDeep, size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        loc.cropAnalysisTitle
                                            .replaceAll('{crop}', crop.name),
                                        style: TextStyle(
                                            color: colors.onBackground,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                content: SingleChildScrollView(
                                  child: Text(
                                    response.success
                                        ? response.content
                                        : '${loc.errorPrefix} ${response.error}',
                                    style: TextStyle(
                                      color: response.success
                                          ? colors.onSurfaceMuted
                                          : colors.danger,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(loc.close,
                                        style:
                                            TextStyle(color: colors.brandDeep)),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${loc.analysisFailed} $e'),
                                backgroundColor: colors.danger,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                        label: Text(
                          loc.analyzeForMyFarm,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, VidhAIColorsX colors) {
    return Text(
      title,
      style: TextStyle(
        color: colors.onBackground,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _infoGrid(List<Widget> children) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }

  Widget _infoTile(
      IconData icon, String label, String value, VidhAIColorsX colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.brandDeep, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(color: colors.onBackground, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _financeRow(IconData icon, String label, String value, Color color,
      VidhAIColorsX colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
            ),
            Text(
              value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      String label, String value, Color color, VidhAIColorsX colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
