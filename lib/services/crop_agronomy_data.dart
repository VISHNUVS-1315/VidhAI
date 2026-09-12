import 'crop_analytics.dart';
import 'crop_knowledge_base.dart';

/// Companion agronomy facts for the offline knowledge base, keyed by crop id.
///
/// Nothing here is invented on the fly: families, nutrient demand, pest
/// pressure and cost splits are static curated values. Cost splits express how
/// the total per-acre cultivation investment divides across input buckets and
/// are always labelled as estimates in the UI.
class CropAgronomyInfo {
  final String family;
  final String nutrientDemand; // Low | Medium | High
  final String pestPressure; // Low | Medium | High
  final List<CostSplitLine> costSplit;

  const CropAgronomyInfo({
    required this.family,
    required this.nutrientDemand,
    required this.pestPressure,
    required this.costSplit,
  });
}

class CropAgronomyData {
  CropAgronomyData._();

  // ── Cost-split groups (share of total cultivation cost per acre) ─────────────

  static const List<CostSplitLine> _fieldSplit = [
    CostSplitLine('seed', 15),
    CostSplitLine('fertilizer', 26),
    CostSplitLine('pesticide', 12),
    CostSplitLine('labour', 25),
    CostSplitLine('irrigation', 17),
    CostSplitLine('machinery', 5),
  ];

  static const List<CostSplitLine> _legumeSplit = [
    CostSplitLine('seed', 18),
    CostSplitLine('fertilizer', 18),
    CostSplitLine('pesticide', 10),
    CostSplitLine('labour', 28),
    CostSplitLine('irrigation', 16),
    CostSplitLine('machinery', 10),
  ];

  static const List<CostSplitLine> _vegSplit = [
    CostSplitLine('seed', 20),
    CostSplitLine('fertilizer', 22),
    CostSplitLine('pesticide', 14),
    CostSplitLine('labour', 28),
    CostSplitLine('irrigation', 12),
    CostSplitLine('machinery', 4),
  ];

  static const List<CostSplitLine> _spiceSplit = [
    CostSplitLine('seed', 16),
    CostSplitLine('fertilizer', 22),
    CostSplitLine('pesticide', 12),
    CostSplitLine('labour', 30),
    CostSplitLine('irrigation', 15),
    CostSplitLine('machinery', 5),
  ];

  static const List<CostSplitLine> _flowerSplit = [
    CostSplitLine('seed', 18),
    CostSplitLine('fertilizer', 20),
    CostSplitLine('pesticide', 15),
    CostSplitLine('labour', 32),
    CostSplitLine('irrigation', 11),
    CostSplitLine('machinery', 4),
  ];

  static const List<CostSplitLine> _plantationSplit = [
    CostSplitLine('seed', 25),
    CostSplitLine('fertilizer', 20),
    CostSplitLine('pesticide', 10),
    CostSplitLine('labour', 25),
    CostSplitLine('irrigation', 16),
    CostSplitLine('machinery', 4),
  ];

  static const List<CostSplitLine> _medicinalSplit = [
    CostSplitLine('seed', 20),
    CostSplitLine('fertilizer', 18),
    CostSplitLine('pesticide', 8),
    CostSplitLine('labour', 30),
    CostSplitLine('irrigation', 18),
    CostSplitLine('machinery', 6),
  ];

  // ── Per-crop enrichment (id -> info) ────────────────────────────────────────

  static const Map<String, CropAgronomyInfo> _byId = {
    // CEREALS
    'CR001': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'High', pestPressure: 'Medium', costSplit: _fieldSplit),
    'CR002': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'High', pestPressure: 'Medium', costSplit: _fieldSplit),
    'CR003': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'High', pestPressure: 'Medium', costSplit: _fieldSplit),
    'CR004': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'High', pestPressure: 'Medium', costSplit: _fieldSplit),
    'CR005': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'High', pestPressure: 'Medium', costSplit: _fieldSplit),
    'CR006': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _fieldSplit),
    'CR007': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _fieldSplit),
    'CR008': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _fieldSplit),
    'CR009': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _fieldSplit),
    'CR010': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _fieldSplit),
    // PULSES
    'CR011': CropAgronomyInfo(
        family: 'Fabaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _legumeSplit),
    'CR012': CropAgronomyInfo(
        family: 'Fabaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _legumeSplit),
    'CR013': CropAgronomyInfo(
        family: 'Fabaceae', nutrientDemand: 'Low', pestPressure: 'Medium', costSplit: _legumeSplit),
    'CR014': CropAgronomyInfo(
        family: 'Fabaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _legumeSplit),
    // SPICES
    'CR015': CropAgronomyInfo(
        family: 'Apiaceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _spiceSplit),
    'CR016': CropAgronomyInfo(
        family: 'Lamiaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _spiceSplit),
    'CR029': CropAgronomyInfo(
        family: 'Zingiberaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _spiceSplit),
    'CR030': CropAgronomyInfo(
        family: 'Piperaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _spiceSplit),
    'CR031': CropAgronomyInfo(
        family: 'Zingiberaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _spiceSplit),
    // LEAFY VEGETABLES
    'CR017': CropAgronomyInfo(
        family: 'Amaranthaceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _vegSplit),
    // VEGETABLES
    'CR018': CropAgronomyInfo(
        family: 'Solanaceae', nutrientDemand: 'High', pestPressure: 'High', costSplit: _vegSplit),
    'CR019': CropAgronomyInfo(
        family: 'Solanaceae', nutrientDemand: 'High', pestPressure: 'High', costSplit: _vegSplit),
    'CR020': CropAgronomyInfo(
        family: 'Solanaceae', nutrientDemand: 'High', pestPressure: 'High', costSplit: _vegSplit),
    'CR021': CropAgronomyInfo(
        family: 'Malvaceae', nutrientDemand: 'High', pestPressure: 'High', costSplit: _vegSplit),
    'CR022': CropAgronomyInfo(
        family: 'Amaryllidaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _vegSplit),
    'CR023': CropAgronomyInfo(
        family: 'Solanaceae', nutrientDemand: 'High', pestPressure: 'High', costSplit: _vegSplit),
    // FRUITS
    'CR024': CropAgronomyInfo(
        family: 'Anacardiaceae', nutrientDemand: 'Low', pestPressure: 'Medium', costSplit: _plantationSplit),
    'CR025': CropAgronomyInfo(
        family: 'Musaceae', nutrientDemand: 'High', pestPressure: 'Medium', costSplit: _plantationSplit),
    'CR027': CropAgronomyInfo(
        family: 'Caricaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _plantationSplit),
    'CR028': CropAgronomyInfo(
        family: 'Vitaceae', nutrientDemand: 'Medium', pestPressure: 'High', costSplit: _plantationSplit),
    // PLANTATION CROPS
    'CR026': CropAgronomyInfo(
        family: 'Arecaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _plantationSplit),
    'CR038': CropAgronomyInfo(
        family: 'Theaceae', nutrientDemand: 'Low', pestPressure: 'Medium', costSplit: _plantationSplit),
    // OILSEEDS
    'CR032': CropAgronomyInfo(
        family: 'Fabaceae', nutrientDemand: 'Low', pestPressure: 'Medium', costSplit: _legumeSplit),
    'CR033': CropAgronomyInfo(
        family: 'Pedaliaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _legumeSplit),
    'CR034': CropAgronomyInfo(
        family: 'Brassicaceae', nutrientDemand: 'Low', pestPressure: 'Medium', costSplit: _legumeSplit),
    // FLOWERS
    'CR035': CropAgronomyInfo(
        family: 'Asteraceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _flowerSplit),
    'CR036': CropAgronomyInfo(
        family: 'Oleaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _flowerSplit),
    'CR037': CropAgronomyInfo(
        family: 'Rosaceae', nutrientDemand: 'Low', pestPressure: 'High', costSplit: _flowerSplit),
    // TREE CROPS
    'CR039': CropAgronomyInfo(
        family: 'Moringaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _plantationSplit),
    'CR040': CropAgronomyInfo(
        family: 'Meliaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _plantationSplit),
    // MEDICINAL / AROMATIC
    'CR041': CropAgronomyInfo(
        family: 'Asphodelaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _medicinalSplit),
    'CR042': CropAgronomyInfo(
        family: 'Solanaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _medicinalSplit),
    'CR043': CropAgronomyInfo(
        family: 'Poaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _medicinalSplit),
  };

  /// info for a knowledge-base entry, falling back to category defaults.
  static CropAgronomyInfo infoFor(CropKnowledgeEntry entry) {
    final known = _byId[entry.id];
    if (known != null) return known;
    final byCategory = {
      'Cereals': const CropAgronomyInfo(
          family: 'Poaceae', nutrientDemand: 'High', pestPressure: 'Medium', costSplit: _fieldSplit),
      'Pulses': const CropAgronomyInfo(
          family: 'Fabaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _legumeSplit),
      'Oilseeds': const CropAgronomyInfo(
          family: 'Fabaceae', nutrientDemand: 'Low', pestPressure: 'Medium', costSplit: _legumeSplit),
      'Spices': const CropAgronomyInfo(
          family: 'Zingiberaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _spiceSplit),
      'Leafy Vegetables': const CropAgronomyInfo(
          family: 'Amaranthaceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _vegSplit),
      'Vegetables': const CropAgronomyInfo(
          family: 'Solanaceae', nutrientDemand: 'High', pestPressure: 'High', costSplit: _vegSplit),
      'Flowers': const CropAgronomyInfo(
          family: 'Asteraceae', nutrientDemand: 'Medium', pestPressure: 'Low', costSplit: _flowerSplit),
      'Plantation Crops': const CropAgronomyInfo(
          family: 'Arecaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _plantationSplit),
      'Tree Crops': const CropAgronomyInfo(
          family: 'Meliaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _plantationSplit),
      'Medicinal/Aromatic': const CropAgronomyInfo(
          family: 'Apiaceae', nutrientDemand: 'Low', pestPressure: 'Low', costSplit: _medicinalSplit),
      'Fruits': const CropAgronomyInfo(
          family: 'Anacardiaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _plantationSplit),
    };
    return byCategory[entry.category] ??
        const CropAgronomyInfo(
            family: 'Poaceae', nutrientDemand: 'Medium', pestPressure: 'Medium', costSplit: _fieldSplit);
  }

  /// Best-effort botanical family for an arbitrary crop name (used to classify
  /// the farm's previous crops for rotation analysis).
  static String familyOf(String cropName) {
    final key = cropName.trim().toLowerCase();
    const aliases = <String, String>{
      'paddy': 'Poaceae',
      'rice': 'Poaceae',
      'wheat': 'Poaceae',
      'ragi': 'Poaceae',
      'finger millet': 'Poaceae',
      'bajra': 'Poaceae',
      'pearl millet': 'Poaceae',
      'jowar': 'Poaceae',
      'sorghum': 'Poaceae',
      'foxtail millet': 'Poaceae',
      'little millet': 'Poaceae',
      'maize': 'Poaceae',
      'corn': 'Poaceae',
      'sugarcane': 'Poaceae',
      'lemongrass': 'Poaceae',
      'moong': 'Fabaceae',
      'green gram': 'Fabaceae',
      'urad': 'Fabaceae',
      'black gram': 'Fabaceae',
      'chana': 'Fabaceae',
      'chickpea': 'Fabaceae',
      'toor': 'Fabaceae',
      'arhar': 'Fabaceae',
      'pigeon pea': 'Fabaceae',
      'soybean': 'Fabaceae',
      'groundnut': 'Fabaceae',
      'sunflower': 'Asteraceae',
      'marigold': 'Asteraceae',
      'cotton': 'Malvaceae',
      'okra': 'Malvaceae',
      'lady finger': 'Malvaceae',
      'tomato': 'Solanaceae',
      'brinjal': 'Solanaceae',
      'eggplant': 'Solanaceae',
      'chilli': 'Solanaceae',
      'chili': 'Solanaceae',
      'potato': 'Solanaceae',
      'ashwagandha': 'Solanaceae',
      'onion': 'Amaryllidaceae',
      'garlic': 'Amaryllidaceae',
      'cabbage': 'Brassicaceae',
      'cauliflower': 'Brassicaceae',
      'mustard': 'Brassicaceae',
      'carrot': 'Apiaceae',
      'coriander': 'Apiaceae',
      'cumin': 'Apiaceae',
      'turmeric': 'Zingiberaceae',
      'ginger': 'Zingiberaceae',
      'cardamom': 'Zingiberaceae',
      'pepper': 'Piperaceae',
      'mint': 'Lamiaceae',
      'mango': 'Anacardiaceae',
      'banana': 'Musaceae',
      'papaya': 'Caricaceae',
      'grapes': 'Vitaceae',
      'grape': 'Vitaceae',
      'coconut': 'Arecaceae',
      'tea': 'Theaceae',
      'drumstick': 'Moringaceae',
      'neem': 'Meliaceae',
      'aloe vera': 'Asphodelaceae',
      'sesame': 'Pedaliaceae',
      'til': 'Pedaliaceae',
      'spinach': 'Amaranthaceae',
      'jasmine': 'Oleaceae',
      'rose': 'Rosaceae',
    };
    for (final entry in aliases.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return '';
  }

  /// Maps the survey's category options to knowledge-base categories.
  /// Returns null when the option should not restrict candidates.
  static String? categoryToKb(String option) {
    switch (option.trim().toLowerCase()) {
      case 'vegetables':
        return 'Vegetables';
      case 'leafy':
      case 'leafy vegetables':
        return 'Leafy Vegetables';
      case 'plantation':
      case 'plantation crops':
        return 'Plantation Crops';
      case 'tree':
      case 'tree crops':
        return 'Tree Crops';
      case 'medicinal':
      case 'medicinal/aromatic':
        return 'Medicinal/Aromatic';
      case 'cereals':
        return 'Cereals';
      case 'pulses':
        return 'Pulses';
      case 'oilseeds':
        return 'Oilseeds';
      case 'spices':
        return 'Spices';
      case 'flowers':
        return 'Flowers';
      case 'fruits':
        return 'Fruits';
      case 'no preference':
      case 'other':
      case 'fibre':
      case 'fibre crops':
      default:
        return null;
    }
  }

  /// True when [month] falls inside the candidate's sowing window.
  static bool isInSowingWindow(CropKnowledgeEntry entry, int month) {
    final windows = CropAnalytics.parseMonthWindows(entry.bestPlantingMonth);
    return windows.isNotEmpty && windows.any((w) => w.contains(month));
  }
}