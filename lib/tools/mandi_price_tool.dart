import 'package:flutter/material.dart';

import '../services/market_price_service.dart';
import '../tools/ai_tool.dart';

/// Gives the NVIDIA assistant real AGMARKNET prices through the secure backend.
class MandiPriceTool extends VidhAITool {
  final MarketPriceService _market = MarketPriceService.instance;

  @override
  String get name => 'GET_MANDI_PRICES';

  @override
  String get description =>
      'Get real AGMARKNET/data.gov.in market prices. Optionally filter by '
      'commodity, state, or district. Returns only reported market data with '
      'source/date and ₹ per kg when the unit conversion is reliable.';

  @override
  Map<String, dynamic> get parameters => withRequired(
        <String>[],
        {
          'commodity': stringParam(),
          'state': stringParam(),
          'district': stringParam(),
        },
      );

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final state = (arguments['state'] ?? '').toString().trim();
    final district = (arguments['district'] ?? '').toString().trim();
    final commodity = (arguments['commodity'] ?? '').toString().trim();

    try {
      final payload = await _market.fetchPrices(
        state: state.isEmpty ? null : state,
        district: district.isEmpty ? null : district,
        commodity: commodity.isEmpty ? null : commodity,
      );

      if (payload.prices.isEmpty) {
        return {
          'prices': <Object>[],
          'source': 'AGMARKNET (data.gov.in)',
          'note': 'No reported market prices were found for those filters.',
        };
      }

      return {
        'prices': payload.prices.take(10).map((price) {
          return {
            'commodity': price.commodity,
            'variety': price.variety,
            'market': price.market,
            'district': price.district,
            'state': price.state,
            'modalPricePerKg': price.normalizedPricePerKg,
            'reportedModalPrice': price.modalPrice,
            'reportedUnit': price.unitLabel,
            'date': price.date,
            'source': price.source,
          };
        }).toList(),
        'count': payload.prices.length,
        'source': payload.source,
        'stale': payload.stale,
      };
    } catch (_) {
      return {
        'error': 'Market prices are temporarily unavailable. Please try again.',
      };
    }
  }
}
