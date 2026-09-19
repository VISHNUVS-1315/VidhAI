import 'package:flutter_test/flutter_test.dart';

import 'package:vidhai/services/crop_backend_service.dart';

void main() {
  group('CropBackendService.mapAIRecommendations', () {
    test('maps a strictly-validated AI payload onto standard results', () {
      final raw = [
        {
          'cropName': 'Tomato',
          'localName': 'टमाटर',
          'category': 'Vegetables',
          'confidence': 92,
          'suitabilityScore': 88,
          'riskLevel': 'Low',
          'estimatedDurationDays': 110,
          'estimatedInvestment': {'min': 18000, 'max': 24000},
          'estimatedRevenue': {'min': 60000, 'max': 90000},
          'estimatedProfit': {'min': 35000, 'max': 55000},
          'waterRequirement': 'Moderate',
          'sowingWindow': 'Oct - Dec',
          'estimatedHarvestWindow': 'Jan - Mar',
          'soilMatch': 'Loamy soil ideal',
          'waterMatch': 'Adequate for tomato',
          'seasonMatch': 'Cool season match',
          'rotationMatch': 'Good after legumes',
          'whySuitable': ['High market demand', 'Short cycle'],
          'majorRisks': ['Blossom end rot', 'Whitefly pressure'],
          'marketOutlook': 'Strong kharif demand',
        },
        {
          'cropName': 'Wheat',
          'localName': '',
          'category': 'Cereal',
          'confidence': 0,
          'suitabilityScore': 74,
          'riskLevel': 'High',
          'estimatedDurationDays': 130,
          'estimatedInvestment': {'min': 9000},
          'estimatedRevenue': {'min': 20000, 'max': 28000},
          'estimatedProfit': {'max': 12000},
          'sowingWindow': 'Nov - Dec',
          'soilMatch': 'Adequate',
          'waterMatch': '',
          'seasonMatch': '',
          'rotationMatch': '',
          'whySuitable': ['Staple demand'],
          'majorRisks': ['Lodging risk'],
          'marketOutlook': '',
        },
        // invalid — no cropName → skipped
        {
          'cropName': '   ',
          'suitabilityScore': 50,
        },
        // invalid — not a map → skipped
        42,
      ];

      final results = CropBackendService.mapAIRecommendations(raw);

      expect(results, hasLength(2));
      final tomato = results[0];
      expect(tomato.rank, 1);
      expect(tomato.cropName, 'Tomato');
      expect(tomato.cropId, '_ai_Tomato');
      expect(tomato.score, 88);
      expect(tomato.category, 'Vegetables');
      expect(tomato.confidence, 'High');
      expect(tomato.confidencePct, 92.0);
      expect(tomato.durationMin, 110);
      expect(tomato.durationMax, 110);
      expect(tomato.budget.cultivationCostMin, 18000);
      expect(tomato.budget.cultivationCostMax, 24000);
      expect(tomato.money.revenueMin, 60000);
      expect(tomato.money.revenueMax, 90000);
      expect(tomato.money.profitMin, 35000);
      expect(tomato.money.profitMax, 55000);
      expect(tomato.factors.map((f) => f.name), containsAll(['soil', 'water', 'season', 'rotation']));
      expect(tomato.strengths, ['High market demand', 'Short cycle']);
      expect(tomato.concerns, ['Blossom end rot', 'Whitefly pressure']);
      expect(tomato.risks, ['Blossom end rot', 'Whitefly pressure']);
      expect(tomato.plantingWindow, 'Oct - Dec');
      expect(tomato.harvestHint, 'Jan - Mar');
      expect(tomato.waterNotes, 'Moderate');
      expect(tomato.marketDemand, 'Strong kharif demand');
      expect(tomato.riskLevel, 'Low');
      expect(tomato.estimatedLabel, isTrue);
      expect(tomato.dataSources, ['Groq GPT-OSS via secure backend']);

      final wheat = results[1];
      expect(wheat.rank, 2);
      expect(wheat.cropName, 'Wheat');
      expect(wheat.score, 74);
      expect(wheat.confidence, 'Medium'); // 60 <= score < 80
      expect(wheat.confidencePct, 74.0); // confidence 0 → falls back to score
      expect(wheat.riskLevel, 'High');
      // missing max → clamped to min / 0
      expect(wheat.budget.cultivationCostMin, 9000);
      expect(wheat.budget.cultivationCostMax, 9000);
      expect(wheat.money.revenueMin, 20000);
      expect(wheat.money.profitMax, 12000);
    });

    test('empty or junk input yields no results without throwing', () {
      expect(CropBackendService.mapAIRecommendations(const []), isEmpty);
      expect(CropBackendService.mapAIRecommendations(const [null, 'x']),
          isEmpty);
    });
  });
}