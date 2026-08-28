import 'package:flutter/material.dart';
import 'package:vidhai/services/crop_knowledge_base.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/data_service.dart';

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
    'All', 'Cereals', 'Pulses', 'Vegetables', 'Fruits',
    'Spices', 'Flowers', 'Oilseeds', 'Plantation Crops',
    'Tree Crops', 'Medicinal/Aromatic', 'Leafy Vegetables',
  ];

  List<CropKnowledgeEntry> get _filteredCrops {
    return _knowledgeBase.allCrops.where((crop) {
      final matchesCategory = _selectedCategory == 'All' ||
          crop.category == _selectedCategory;
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
          'Crop Search',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search crop name, variety, category...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                          : const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredCrops.length} crop${_filteredCrops.length != 1 ? 's' : ''} found',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
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
                        Icon(Icons.search_off_rounded, color: Colors.white.withValues(alpha: 0.2), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No crops found',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
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

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Cereals':
        return const Color(0xFF8D6E63);
      case 'Pulses':
        return const Color(0xFFFF9800);
      case 'Vegetables':
        return const Color(0xFF4CAF50);
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
        return const Color(0xFF4CAF50);
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
    final color = _categoryColor(crop.category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    crop.variety,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    crop.category,
                    style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${crop.durationDays} days',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
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
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0A0F1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                crop.variety,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            crop.category,
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
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
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('Growth Details'),
                    const SizedBox(height: 10),
                    _infoGrid([
                      _infoTile(Icons.schedule_rounded, 'Duration', '${crop.durationDays} days'),
                      _infoTile(Icons.water_drop_rounded, 'Water', crop.waterRequirement),
                      _infoTile(Icons.thermostat_rounded, 'Temperature', crop.suitableTemperature),
                      _infoTile(Icons.wb_sunny_rounded, 'Season', crop.season),
                      _infoTile(Icons.calendar_today_rounded, 'Sowing', crop.bestPlantingMonth),
                      _infoTile(Icons.event_rounded, 'Harvest', crop.harvestMonth),
                    ]),
                    const SizedBox(height: 20),
                    _sectionTitle('Investment & Returns'),
                    const SizedBox(height: 10),
                    _financeRow(Icons.payments_rounded, 'Investment/acre', crop.investmentPerAcre, const Color(0xFFFF9800)),
                    _financeRow(Icons.trending_up_rounded, 'Expected Yield', crop.expectedYieldPerAcre, const Color(0xFF4CAF50)),
                    _financeRow(Icons.account_balance_rounded, 'Revenue/acre', crop.revenuePerAcre, const Color(0xFF2196F3)),
                    _financeRow(Icons.savings_rounded, 'Profit/acre', crop.profitPerAcre, const Color(0xFF4CAF50)),
                    const SizedBox(height: 20),
                    _sectionTitle('Suitable Regions'),
                    const SizedBox(height: 10),
                    _infoTile(Icons.landscape_rounded, 'Soils', crop.suitableSoils.join(', ')),
                    const SizedBox(height: 8),
                    _infoTile(Icons.map_rounded, 'States', crop.suitableStates.join(', ')),
                    const SizedBox(height: 8),
                    _infoTile(Icons.cloud_rounded, 'Agro-climatic', crop.agroClimaticZones),
                    const SizedBox(height: 20),
                    _sectionTitle('Market & Risk'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Market Demand',
                            crop.marketDemand,
                            crop.marketDemand == 'High' ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            'Risk Level',
                            crop.riskLevel,
                            crop.riskLevel == 'Low'
                                ? const Color(0xFF4CAF50)
                                : crop.riskLevel == 'Medium'
                                    ? const Color(0xFFFF9800)
                                    : const Color(0xFFEF4444),
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
                          Navigator.pop(context);
                          if (!context.mounted) return;

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Dialog(
                              backgroundColor: Color(0xFF111827),
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Color(0xFF4CAF50)),
                                    SizedBox(width: 16),
                                    Text(
                                      'Analyzing crop for your farm...',
                                      style: TextStyle(color: Colors.white),
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
                                  backgroundColor: const Color(0xFF111827),
                                  title: const Text('No Farms Found', style: TextStyle(color: Colors.white)),
                                  content: const Text(
                                    'Please add a farm profile first to get personalized AI analysis.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK', style: TextStyle(color: Color(0xFF4CAF50))),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            final farm = farms.first;
                            final farmDetails = StringBuffer()
                              ..writeln('Farm Name: ${farm.farmName}')
                              ..writeln('Size: ${farm.farmSize} ${farm.farmSizeUnit}')
                              ..writeln('Soil Type: ${farm.soilType}')
                              ..writeln('Irrigation: ${farm.irrigationType}')
                              ..writeln('Water Source: ${farm.waterSource}')
                              ..writeln('Farming Method: ${farm.farmingMethod}');

                            final prompt =
                                'Analyze how suitable ${crop.name} (${crop.variety}) is for my farm.\n'
                                'Farm Details:\n$farmDetails\n'
                                'Crop Details: Season ${crop.season}, Duration ${crop.durationDays} days, '
                                'Water requirement ${crop.waterRequirement}, Suitable temperature ${crop.suitableTemperature}, '
                                'Suitable soils: ${crop.suitableSoils.join(", ")}.\n'
                                'Give a suitability score out of 10, key risks, and actionable recommendations.';

                            final response = await AiService.instance.chat(prompt);

                            if (!context.mounted) return;

                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xFF111827),
                                title: Row(
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4CAF50), size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${crop.name} Analysis',
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                content: SingleChildScrollView(
                                  child: Text(
                                    response.success ? response.content : 'Error: ${response.error}',
                                    style: TextStyle(
                                      color: response.success ? Colors.white70 : const Color(0xFFEF4444),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close', style: TextStyle(color: Color(0xFF4CAF50))),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Analysis failed: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                        label: const Text(
                          'Analyze for My Farm',
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
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

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _financeRow(IconData icon, String label, String value, Color color) {
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
              child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            ),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
