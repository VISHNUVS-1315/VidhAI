import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/data/models/market_selection.dart';
import 'package:vidhai/data/models/market_price_models.dart';

void main() {
  test('multi-state districts never cross state boundaries', () {
    final original = <String, Set<String>>{
      'Tamil Nadu': {'Chennai', 'Madurai'},
      'Kerala': {'Kollam'},
      'Karnataka': {},
    };
    final selection = MarketSelection(original);
    original['Tamil Nadu']!.clear();
    expect(selection.queries, unorderedEquals([
      (state: 'Tamil Nadu', district: 'Chennai'),
      (state: 'Tamil Nadu', district: 'Madurai'),
      (state: 'Kerala', district: 'Kollam'),
      (state: 'Karnataka', district: null),
    ]));
    expect(() => selection.regions['Kerala']!.add('Chennai'), throwsUnsupportedError);
  });
  test('merging overlapping regions removes duplicates, keeps distinct markets', () {
    const a = MarketPriceRecord(commodity: 'Tomato', state: 'Tamil Nadu',
      district: 'Chennai', market: 'A', date: '2026-09-19', source: 'Official');
    const b = MarketPriceRecord(commodity: 'Tomato', state: 'Tamil Nadu',
      district: 'Chennai', market: 'B', date: '2026-09-18', source: 'Official');
    final merged = mergeMarketRecords([
      const MarketPricePayload(prices: [a, b]),
      const MarketPricePayload(prices: [a]),
    ]);
    expect(merged, [a, b]);
  });
  test('category matching is case insensitive with a safe other category', () {
    expect(marketCategory('TOMATO'), 'vegetable');
    expect(marketCategory('Green Gram'), 'pulse');
    expect(marketCategory('Jasmine'), 'flower');
    expect(marketCategory('Unknown produce'), 'other');
  });
}
