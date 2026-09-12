import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/services/ai/realtime_crop_ranking.dart';

CropRecommendationResult _rec(String name, {int score = 70}) {
  return CropRecommendationResult(
    rank: 1,
    cropId: name,
    cropName: name,
    varieties: const [],
    category: 'Vegetable',
    season: 'Rabi',
    durationMin: 90,
    durationMax: 110,
    score: score,
    confidence: 'High',
    budget: const CropBudgetEstimate(
      classification: 'Not Specified',
      cultivationCostMin: 0,
      cultivationCostMax: 0,
      seedCostMin: 0,
      seedCostMax: 0,
    ),
    money: const CropMoneyEstimate(
      yieldMin: 0,
      yieldMax: 0,
      yieldUnit: '',
      revenueMin: 0,
      revenueMax: 0,
      profitMin: 0,
      profitMax: 0,
    ),
    factors: const [],
    strengths: const [],
    concerns: const [],
    waterNotes: '',
    plantingWindow: 'Nov-Jan',
    harvestHint: '',
    risks: const [],
    pests: const [],
    diseases: const [],
    marketDemand: '',
    riskLevel: 'Low',
    description: '',
    estimatedLabel: true,
  );
}

const _allowed = {'Rice', 'Wheat', 'Tomato', 'Onion', 'Soybean'};

void main() {
  group('RealtimeCropRankingParser.buildPrompt', () {
    test('lists every candidate by name and score', () {
      final prompt = RealtimeCropRankingParser.buildPrompt(
          [_rec('Rice'), _rec('Tomato')], 'en');
      expect(prompt, contains('Rice'));
      expect(prompt, contains('Tomato'));
      expect(prompt, contains('score 70'));
    });
  });

  group('RealtimeCropRankingParser.parseResponse', () {
    test('parses clean JSON, validates against allowed names, keeps order', () {
      final raw = '''
{"rankedCrops":[
  {"cropName":"Tomato","reason":"Drip irrigation keeps it cheap."},
  {"cropName":"Soybean","reason":"Field nitrogen improves soil."}
],"farmNote":"Start with the water-thrifty crop."}''';
      final parsed = RealtimeCropRankingParser.parseResponse(raw, _allowed);
      expect(parsed, isNotNull);
      expect(parsed!.rankedCrops, hasLength(2));
      expect(parsed.rankedCrops[0].cropName, 'Tomato');
      expect(parsed.rankedCrops[1].cropName, 'Soybean');
      expect(parsed.farmNote, 'Start with the water-thrifty crop.');
    });

    test('drops hallucinated crops not in the engine shortlist', () {
      final raw = '''
{"rankedCrops":[
  {"cropName":"Dragonfruit","reason":"Fancy."},
  {"cropName":"Onion","reason":"Strong local demand."}
]}''';
      final parsed = RealtimeCropRankingParser.parseResponse(raw, _allowed);
      expect(parsed, isNotNull);
      expect(parsed!.rankedCrops, hasLength(1));
      expect(parsed.rankedCrops.single.cropName, 'Onion');
    });

    test('no valid crops at all yields null', () {
      final raw = '{"rankedCrops":[{"cropName":"Dragonfruit","reason":"X"}]}';
      expect(RealtimeCropRankingParser.parseResponse(raw, _allowed), isNull);
    });

    test('delivers the engine casing even when the model changes case', () {
      final raw =
          '{"rankedCrops":[{"cropName":"tomato","reason":"Case insensitive."}]}';
      final parsed = RealtimeCropRankingParser.parseResponse(raw, _allowed);
      expect(parsed!.rankedCrops.single.cropName, 'Tomato');
    });

    test('handles markdown fences and prose around the JSON', () {
      final raw = '''
Here are my recommendations:

```json
{
  "rankedCrops": [
    {"cropName": "Wheat", "reason": "Fits the rabi window."}
  ],
  "farmNote": "Prefer short-cycle crops."
}
```''';
      final parsed = RealtimeCropRankingParser.parseResponse(raw, _allowed);
      expect(parsed, isNotNull);
      expect(parsed!.rankedCrops.single.cropName, 'Wheat');
    });

    test('caps the list at ten and deduplicates repeated names', () {
      final items = <String>[
        for (var i = 1; i <= 9; i++) '{"cropName":"Crop$i","reason":"r"}',
        '{"cropName":"Rice","reason":"first"}',
        '{"cropName":"rice","reason":"duplicate casing"}',
        '{"cropName":"Crop10","reason":"r"}',
        '{"cropName":"Crop11","reason":"r"}',
        '{"cropName":"Crop12","reason":"r"}',
      ];
      final raw = '{"rankedCrops":[${items.join(',')}]}';
      final allowed = {for (var i = 1; i <= 12; i++) 'Crop$i', 'Rice'};
      final parsed = RealtimeCropRankingParser.parseResponse(raw, allowed);
      expect(parsed, isNotNull);
      expect(parsed!.rankedCrops, hasLength(10));
      final names = parsed.rankedCrops.map((c) => c.cropName).toList();
      expect(names.take(10), contains('Rice'));
      expect(names.toSet().length, names.length, reason: 'dupes removed');
    });

    test('garbage or missing rankedCrops yields null', () {
      expect(RealtimeCropRankingParser.parseResponse('not json', _allowed),
          isNull);
      expect(
          RealtimeCropRankingParser.parseResponse(
              '{"farmNote":"only a note"}', _allowed),
          isNull);
      expect(
          RealtimeCropRankingParser.parseResponse(
              '{"rankedCrops":[{"cropName":42,"reason":"nope"}]}', _allowed),
          isNull);
      expect(RealtimeCropRankingParser.parseResponse('', _allowed), isNull);
    });
  });
}
