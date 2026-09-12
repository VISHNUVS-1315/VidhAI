import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class FertilizerGuideScreen extends StatefulWidget {
  const FertilizerGuideScreen({super.key, this.initialSearch});

  final String? initialSearch;

  @override
  State<FertilizerGuideScreen> createState() => _FertilizerGuideScreenState();
}

class _FertilizerGuideScreenState extends State<FertilizerGuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchQuery = widget.initialSearch!;
      _searchController.text = widget.initialSearch!;
    }
  }

  static const List<String> _categories = [
    'All',
    'NPK',
    'Organic',
    'Bio',
    'Micronutrient',
    'Other',
  ];

  static const List<Map<String, dynamic>> _fertilizers = [
    // NPK
    {
      'name': 'Urea',
      'type': 'NPK',
      'npk': '46-0-0',
      'useCase': 'Primary nitrogen source for vegetative growth',
      'targetCrops': 'Paddy, Wheat, Maize, Vegetables, Cotton',
      'applicationRate': '2-3 bags per acre (split into 2-3 doses)',
      'safetyNotes':
          'Avoid direct contact with seeds. Apply to moist soil. Store in dry place.',
      'description':
          'Most widely used nitrogen fertilizer in India. Contains 46% nitrogen. Essential for leaf and stem growth.',
    },
    {
      'name': 'DAP (Di-Ammonium Phosphate)',
      'type': 'NPK',
      'npk': '18-46-0',
      'useCase': 'Phosphorus for root development and flowering',
      'targetCrops': 'Wheat, Pulses, Oilseeds, Vegetables, Fruits',
      'applicationRate': '1-1.5 bags per acre at sowing time',
      'safetyNotes':
          'Apply at sowing or early growth. Do not mix with urea directly.',
      'description':
          'Second most used fertilizer in India. Excellent source of phosphorus for root establishment.',
    },
    {
      'name': 'MOP (Muriate of Potash)',
      'type': 'NPK',
      'npk': '0-0-60',
      'useCase': 'Potassium for disease resistance and fruit quality',
      'targetCrops': 'Potato, Tobacco, Vegetables, Fruits, Spices',
      'applicationRate': '1 bag per acre at sowing or early growth',
      'safetyNotes':
          'Apply in split doses. Avoid excess on chloride-sensitive crops.',
      'description':
          'Major potassium fertilizer. Improves crop quality, disease resistance, and water utilization.',
    },
    {
      'name': 'SSP (Single Super Phosphate)',
      'type': 'NPK',
      'npk': '0-16-0-11(S)',
      'useCase': 'Phosphorus and Sulphur for root and seed development',
      'targetCrops': 'Wheat, Pulses, Groundnut, Oilseeds, Cotton',
      'applicationRate': '3-4 bags per acre at sowing',
      'safetyNotes': 'Best applied as basal dose. Keep away from moisture.',
      'description':
          'Provides phosphorus along with sulphur and calcium. Affordable option for Indian farmers.',
    },
    {
      'name': 'NPK Complex (10-26-26)',
      'type': 'NPK',
      'npk': '10-26-26',
      'useCase': 'Balanced nutrition for grain crops',
      'targetCrops': 'Paddy, Wheat, Maize, Cotton, Sugarcane',
      'applicationRate': '2-3 bags per acre at sowing',
      'safetyNotes': 'Apply as basal dose. Store in dry place.',
      'description':
          'Balanced NPK complex suitable for grain crops. Common in rice-wheat systems.',
    },
    {
      'name': 'NPK Complex (20-20-0)',
      'type': 'NPK',
      'npk': '20-20-0',
      'useCase': 'Nitrogen-Phosphorus nutrition for pulses and oilseeds',
      'targetCrops': 'Chickpea, Groundnut, Soybean, Mustard',
      'applicationRate': '2-3 bags per acre',
      'safetyNotes':
          'Apply at sowing. Suitable for phosphorus-deficient soils.',
      'description':
          'Balanced NP fertilizer for crops that do not require high potassium.',
    },
    {
      'name': 'Ammonium Sulphate',
      'type': 'NPK',
      'npk': '21-0-0-24(S)',
      'useCase': 'Nitrogen and Sulphur for leafy crops',
      'targetCrops': 'Paddy, Tea, Vegetables, Oilseeds, Potato',
      'applicationRate': '3-4 bags per acre in split doses',
      'safetyNotes':
          'Can acidify soil. Use lime in acidic soils. Apply to moist soil.',
      'description':
          'Provides both nitrogen and sulphur. Particularly good for sulphur-deficient soils.',
    },

    // Organic
    {
      'name': 'FYM (Farm Yard Manure)',
      'type': 'Organic',
      'npk': '0.5-0.2-0.5',
      'useCase': 'Soil conditioning and organic matter improvement',
      'targetCrops': 'All crops',
      'applicationRate': '5-10 tonnes per acre before sowing',
      'safetyNotes':
          'Must be well decomposed (3-6 months). Apply 2-3 weeks before sowing.',
      'description':
          'Traditional organic manure from cattle dung, urine, and crop residues. Improves soil structure, water retention, and microbial activity.',
    },
    {
      'name': 'Vermicompost',
      'type': 'Organic',
      'npk': '1.5-0.4-0.8',
      'useCase': 'Premium organic fertilizer for high-value crops',
      'targetCrops': 'Vegetables, Fruits, Flowers, Spices, Medicinal herbs',
      'applicationRate': '2-4 tonnes per acre',
      'safetyNotes': 'Use well-screened vermicompost. Store in shade.',
      'description':
          'Produced by earthworm species (Eisenia fetida). Rich in humic acids, beneficial microbes, and plant growth hormones.',
    },
    {
      'name': 'Neem Cake',
      'type': 'Organic',
      'npk': '6-1-2',
      'useCase': 'Organic fertilizer with pest repellent properties',
      'targetCrops': 'Cotton, Pulses, Vegetables, Groundnut, Sugarcane',
      'applicationRate': '200-250 kg per acre',
      'safetyNotes':
          'Apply during sowing or early growth. Acts as slow-release fertilizer.',
      'description':
          'Byproduct of neem seed oil extraction. Provides nutrients while repelling soil pests like nematodes.',
    },
    {
      'name': 'Compost (Municipal/Household)',
      'type': 'Organic',
      'npk': '1.0-0.5-0.5',
      'useCase': 'General soil improvement and organic matter addition',
      'targetCrops': 'All crops',
      'applicationRate': '3-5 tonnes per acre',
      'safetyNotes': 'Ensure complete decomposition. Check for contaminants.',
      'description':
          'Decomposed organic waste. Good for soil biology. Quality varies based on source material.',
    },
    {
      'name': 'Panchagavya',
      'type': 'Organic',
      'npk': 'Varies',
      'useCase': 'Bio-stimulant and growth promoter',
      'targetCrops': 'All crops, especially organic farming',
      'applicationRate': '3-5 ml per liter as foliar spray',
      'safetyNotes':
          'Prepare fresh or within 1 week. Store in shade. Do not use metal containers.',
      'description':
          'Traditional organic preparation from five cow products (dung, urine, milk, curd, ghee) + jaggery, banana, and water.',
    },

    // Bio
    {
      'name': 'Rhizobium Culture',
      'type': 'Bio',
      'npk': 'N-fixing',
      'useCase': 'Biological nitrogen fixation for legumes',
      'targetCrops': 'Chickpea, Green Gram, Black Gram, Groundnut, Soybean',
      'applicationRate': '200g per acre seed treatment',
      'safetyNotes':
          'Do not expose treated seeds to direct sunlight. Apply on same day.',
      'description':
          'Symbiotic bacteria that fix atmospheric nitrogen in legume root nodules. Reduces nitrogen fertilizer need by 25-50%.',
    },
    {
      'name': 'PSB (Phosphate Solubilizing Bacteria)',
      'type': 'Bio',
      'npk': 'P-mobilizing',
      'useCase': 'Makes bound soil phosphorus available to plants',
      'targetCrops': 'Wheat, Rice, Mustard, Groundnut, Vegetables',
      'applicationRate':
          '200g per acre seed treatment or 1 kg/acre soil application',
      'safetyNotes': 'Apply in cool hours. Keep away from chemical fungicides.',
      'description':
          'Bacteria (Bacillus megaterium) that solubilize insoluble phosphorus, making it available to plant roots.',
    },
    {
      'name': 'Azotobacter',
      'type': 'Bio',
      'npk': 'N-fixing',
      'useCase': 'Free-living nitrogen fixation for non-legume crops',
      'targetCrops': 'Wheat, Rice, Maize, Vegetables, Cotton',
      'applicationRate': '200g per acre seed treatment',
      'safetyNotes': 'Apply with shade. Do not mix with fungicides.',
      'description':
          'Free-living soil bacterium that fixes 20-40 kg N/ha. Also produces growth hormones.',
    },
    {
      'name': 'Mycorrhiza (VAM)',
      'type': 'Bio',
      'npk': 'P-uptake enhancer',
      'useCase': 'Enhances phosphorus and micronutrient absorption',
      'targetCrops': 'Chilli, Tomato, Onion, Potato, Fruits',
      'applicationRate': '25 kg/acre soil application near roots',
      'safetyNotes':
          'Apply at transplanting. Requires living roots for colonization.',
      'description':
          'Fungal symbiont that extends root network. Improves water and nutrient uptake, especially phosphorus.',
    },

    // Micronutrient
    {
      'name': 'Zinc Sulphate (ZnSO4)',
      'type': 'Micronutrient',
      'npk': 'Zinc 33%',
      'useCase': 'Corrects zinc deficiency common in paddy and wheat',
      'targetCrops': 'Paddy, Wheat, Maize, Cotton, Citrus',
      'applicationRate': '25-50 kg per acre (foliar: 5g/L)',
      'safetyNotes': 'Apply to soil or as foliar spray. Do not mix with SSP.',
      'description':
          'Most commonly needed micronutrient in India. Deficiency is widespread in rice-wheat systems.',
    },
    {
      'name': 'Borax',
      'type': 'Micronutrient',
      'npk': 'Boron 11%',
      'useCase':
          'Critical for flowering, fruit setting, and cell wall formation',
      'targetCrops': 'Groundnut, Mustard, Cotton, Sugarcane, Cauliflower',
      'applicationRate': '10-15 kg per acre (foliar: 2g/L)',
      'safetyNotes':
          'Toxic in excess. Apply precisely. Avoid on Boron-sensitive crops like beans.',
      'description':
          'Essential micronutrient for reproductive growth. Deficiency causes hollow stem in cauliflower, poor pod filling in groundnut.',
    },
    {
      'name': 'Ferrous Sulphate (FeSO4)',
      'type': 'Micronutrient',
      'npk': 'Iron 20%',
      'useCase': 'Corrects iron chlorosis (yellowing of leaves)',
      'targetCrops': 'Groundnut, Sorghum, Citrus, Grapes, Paddy',
      'applicationRate': '50-100 kg per acre soil / 10g/L foliar',
      'safetyNotes':
          'Foliar spray more effective than soil application. Apply in evening.',
      'description':
          'Addresses iron deficiency causing interveinal chlorosis. Common in calcareous and alkaline soils.',
    },
    {
      'name': 'Copper Sulphate (CuSO4)',
      'type': 'Micronutrient',
      'npk': 'Copper 25%',
      'useCase': 'Important for enzyme activity and chlorophyll formation',
      'targetCrops': 'Wheat, Rice, Cotton, Citrus, Onion',
      'applicationRate': '5-10 kg per acre / 2-5g/L foliar',
      'safetyNotes':
          'Use in small quantities. Toxic to some crops if over-applied.',
      'description':
          'Copper deficiency is seen in organic and peaty soils. Affects grain filling in cereals.',
    },

    // Other
    {
      'name': 'Gypsum (Calcium Sulphate)',
      'type': 'Other',
      'npk': 'Ca 23%, S 18%',
      'useCase': 'Reclaims sodic soils, provides calcium and sulphur',
      'targetCrops': 'Paddy, Cotton, Groundnut, all crops in sodic soil',
      'applicationRate': '2-5 tonnes per acre for sodic soil reclamation',
      'safetyNotes':
          'Apply 3-4 months before sowing for reclamation. Wash field after application.',
      'description':
          'Natural mineral used for sodic soil reclamation. Also supplies calcium and sulphur nutrients.',
    },
    {
      'name': 'Lime (Calcium Carbonate)',
      'type': 'Other',
      'npk': 'Ca 40%',
      'useCase': 'Corrects soil acidity, supplies calcium',
      'targetCrops': 'All crops in acidic soils',
      'applicationRate': '1-3 tonnes per acre (based on pH)',
      'safetyNotes':
          'Apply 2-3 months before sowing. Do not apply with DAP or ammonium sulphate.',
      'description':
          'Raises soil pH to optimal range (6.0-7.5). Essential for acidic soils of NE India, Eastern Ghats.',
    },
    {
      'name': 'Potassium Sulphate (SOP)',
      'type': 'Other',
      'npk': '0-0-50-17(S)',
      'useCase': 'Premium potassium for chloride-sensitive crops',
      'targetCrops': 'Tobacco, Fruits, Vegetables, Tea, Coffee',
      'applicationRate': '1-1.5 bags per acre',
      'safetyNotes':
          'Preferred over MOP for sensitive crops. More expensive but better quality results.',
      'description':
          'Chloride-free potassium source. Produces better quality in tobacco, fruits, and vegetables compared to MOP.',
    },
  ];

  List<Map<String, dynamic>> get _filteredFertilizers {
    return _fertilizers.where((f) {
      final matchesCategory =
          _selectedCategory == 'All' || f['type'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          f['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f['type'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f['targetCrops'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Color _typeColor(String type, VidhAIColorsX colors) {
    switch (type) {
      case 'NPK':
        return colors.brandDeep;
      case 'Organic':
        return const Color(0xFF8D6E63);
      case 'Bio':
        return const Color(0xFF2196F3);
      case 'Micronutrient':
        return const Color(0xFFFF9800);
      case 'Other':
        return const Color(0xFF9E9E9E);
      default:
        return colors.brandDeep;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getAIRecommendation() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          color: colors.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    color: colors.brandDeep, strokeWidth: 2),
                const SizedBox(height: 16),
                Text(loc.aiRecommendationLoading,
                    style: TextStyle(color: colors.onSurfaceMuted)),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final farms = await DataService().loadFarms();
      final farm = farms.isNotEmpty ? farms.first : null;
      final farmContext = farm != null
          ? 'Farm: ${farm.farmName}, Size: ${farm.farmSize} ${farm.farmSizeUnit}, '
              'Soil: ${farm.soilType.isNotEmpty ? farm.soilType : "Unknown"}, '
              'Water: ${farm.waterAvailability.isNotEmpty ? farm.waterAvailability : "Unknown"}, '
              'Irrigation: ${farm.irrigationType.isNotEmpty ? farm.irrigationType : "Unknown"}'
          : 'No farm data available';
      final response = await AiService.instance.chat(
        'I am a farmer in India. Based on my farm profile ($farmContext), '
        'recommend the top 5 fertilizers I should use. For each, give: '
        'name, NPK ratio, application rate, best time to apply, and why it suits my farm. '
        'Be specific and practical.',
      );
      if (!mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: colors.brandDeep, size: 20),
              const SizedBox(width: 8),
              Text(loc.aiRecommendationTitle,
                  style: TextStyle(color: colors.onBackground, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              response.success ? response.content : loc.aiRecommendationFailed,
              style: TextStyle(
                  color: colors.onSurfaceMuted, fontSize: 13, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.close, style: TextStyle(color: colors.brandDeep)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${loc.errorPrefix} $e'),
        backgroundColor: colors.danger,
      ));
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
          loc.fertilizerGuide,
          style: TextStyle(
              color: colors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.auto_awesome_rounded,
                color: colors.brandDeep, size: 22),
            tooltip: loc.aiRecommendationTitle,
            onPressed: _getAIRecommendation,
          ),
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
                hintText: loc.searchFertilizersHint,
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
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.brandDeep.withValues(alpha: 0.2)
                          : colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? colors.brandDeep : colors.borderColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? colors.brandDeep
                            : colors.onSurfaceMuted,
                        fontSize: 13,
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
                loc.fertilizerCount.replaceAll(
                    '{count}', _filteredFertilizers.length.toString()),
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredFertilizers.isEmpty
                ? Center(
                    child: Text(
                      loc.noFertilizersFound,
                      style:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filteredFertilizers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _FertilizerCard(
                        fertilizer: _filteredFertilizers[index],
                        accentColor: _typeColor(
                            _filteredFertilizers[index]['type'], colors),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FertilizerCard extends StatefulWidget {
  final Map<String, dynamic> fertilizer;
  final Color accentColor;

  const _FertilizerCard({required this.fertilizer, required this.accentColor});

  @override
  State<_FertilizerCard> createState() => _FertilizerCardState();
}

class _FertilizerCardState extends State<_FertilizerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final f = widget.fertilizer;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? widget.accentColor.withValues(alpha: 0.3)
                : colors.borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _typeIcon(f['type']),
                    color: widget.accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f['name'],
                        style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              f['type'],
                              style: TextStyle(
                                color: widget.accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (f['npk'] != 'Varies' &&
                              f['npk'] != 'N-fixing' &&
                              f['npk'] != 'P-mobilizing' &&
                              f['npk'] != 'P-uptake enhancer' &&
                              !f['npk'].toString().contains('Zinc') &&
                              !f['npk'].toString().contains('Boron') &&
                              !f['npk'].toString().contains('Iron') &&
                              !f['npk'].toString().contains('Copper') &&
                              !f['npk'].toString().contains('Ca 23') &&
                              !f['npk'].toString().contains('Ca 40') &&
                              !f['npk'].toString().contains('0-0-50')) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${loc.npkPrefix} ${f['npk']}',
                              style: TextStyle(
                                color: colors.onSurfaceMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colors.onSurfaceMuted,
                    size: 22,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f['description'],
                            style: TextStyle(
                                color: colors.onSurfaceMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          _infoRow(loc.useCaseLabel, f['useCase'], colors),
                          _infoRow(
                              loc.targetCropsLabel, f['targetCrops'], colors),
                          _infoRow(loc.applicationRateLabel,
                              f['applicationRate'], colors),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: colors.warning, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    f['safetyNotes'],
                                    style: TextStyle(
                                      color: colors.onSurfaceMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, VidhAIColorsX colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: colors.onBackground, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'NPK':
        return Icons.science_rounded;
      case 'Organic':
        return Icons.eco_rounded;
      case 'Bio':
        return Icons.bloodtype_rounded;
      case 'Micronutrient':
        return Icons.local_florist_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }
}
