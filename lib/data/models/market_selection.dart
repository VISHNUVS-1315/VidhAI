import 'market_price_models.dart';

/// A district always belongs to its state. Empty districts means the whole state.
class MarketSelection {
  final Map<String, Set<String>> regions;
  MarketSelection(Map<String, Set<String>> value)
      : regions = Map.unmodifiable(value.map((s, d) => MapEntry(s, Set<String>.unmodifiable(d))));

  List<({String state, String? district})> get queries => [
    for (final entry in regions.entries)
      if (entry.value.isEmpty) (state: entry.key, district: null)
      else for (final district in entry.value) (state: entry.key, district: district),
  ];
}

/// Classification is for display/search only; canonical provider names stay intact.
String marketCategory(String commodity) {
  final name = commodity.toLowerCase();
  const groups = {
    'vegetable': ['tomato', 'potato', 'onion', 'brinjal', 'eggplant', 'cabbage', 'cauliflower', 'carrot', 'beetroot', 'gourd', 'okra', 'bhindi', 'beans', 'cucumber', 'capsicum', 'peas', 'radish', 'drumstick', 'green chilli', 'spinach', 'amaranth'],
    'fruit': ['banana', 'mango', 'papaya', 'melon', 'pomegranate', 'grapes', 'apple', 'orange', 'guava', 'lemon', 'lime', 'pineapple', 'jackfruit', 'sapota', 'mosambi'],
    'cereal': ['paddy', 'rice', 'wheat', 'maize', 'barley', 'jowar', 'bajra', 'ragi', 'millet'],
    'pulse': ['gram', 'lentil', 'pigeon pea', 'arhar', 'masur', 'moong', 'urad'],
    'spice': ['turmeric', 'ginger', 'garlic', 'coriander', 'fenugreek', 'pepper', 'cardamom', 'chilli', 'chilly', 'cumin'],
    'flower': ['jasmine', 'rose', 'marigold', 'chrysanthemum', 'tuberose', 'lotus', 'lily'],
  };
  for (final group in groups.entries) {
    if (group.value.any(name.contains)) return group.key;
  }
  return 'other';
}

List<MarketPriceRecord> mergeMarketRecords(Iterable<MarketPricePayload> payloads) {
  final unique = <String, MarketPriceRecord>{};
  for (final payload in payloads) {
    for (final r in payload.prices) {
      final key = [r.state, r.district, r.market, r.commodity, r.variety ?? '', r.date, r.source, r.originalUnit].join('\u0000');
      unique[key] = r;
    }
  }
  return unique.values.toList()..sort((a, b) => b.date.compareTo(a.date));
}
