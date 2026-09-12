import 'package:flutter/material.dart';

import '../services/mandi_service.dart';
import '../tools/ai_tool.dart';

/// Returns real mandi market prices from the existing mandi-api service.
class MandiPriceTool extends VidhAITool {
  MandiPriceTool();
  final MandiService _mandi = MandiService();

  @override
  String get name => 'GET_MANDI_PRICES';

  @override
  String get description =>
      'Get real wholesale market (mandi) prices for crops from the government '
      'mandi API. Returns crop, market, state, minimum/maximum/modal price in '
      'Rs per quintal and the price date. Optionally filter by commodity '
      '(e.g. "Tomato") or state (e.g. "Maharashtra"). Returns a clear message '
      'when no data is available.';

  @override
  Map<String, dynamic> get parameters => withRequired(
        <String>[],
        {
          'commodity': stringParam(),
          'state': stringParam(),
          'market': stringParam(),
        },
      );

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final state = (arguments['state'] ?? '').toString().trim();
    final commodity = (arguments['commodity'] ?? '').toString().trim();

    try {
      final prices = await _mandi.fetchPrices(
        state: state.isEmpty ? null : state.toLowerCase(),
        commodity: _normalize(commodity),
      );
      if (prices.isEmpty) {
        return {
          'prices': <Object>[],
          'note': 'No mandi prices found for the given filters right now.',
        };
      }
      return {
        'prices': prices.take(10).map((p) {
          return {
            'commodity': p.commodity,
            'variety': p.variety,
            'market': p.market,
            'state': p.state,
            'minPricePerQuintal': p.minPrice,
            'maxPricePerQuintal': p.maxPrice,
            'modalPricePerQuintal': p.modalPrice,
            'unit': p.unit,
            'date': p.date,
            'trend': p.trend,
          };
        }).toList(),
        'count': prices.length,
      };
    } catch (_) {
      return {
        'error':
            'Mandi prices are temporarily unavailable. Please try again later.',
      };
    }
  }

  /// Mandi API expects lowercase commodity names (e.g. "tomato").
  String _normalize(String commodity) {
    if (commodity.isEmpty) return commodity;
    return commodity.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }
}
