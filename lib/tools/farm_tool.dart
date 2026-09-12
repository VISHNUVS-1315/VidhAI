import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../tools/ai_tool.dart';

/// Reads the farmer's own saved farm/crop records via the real data service.
class FarmTool extends VidhAITool {
  FarmTool();
  final DataService _data = DataService();

  @override
  String get name => 'GET_FARM_DETAILS';

  @override
  String get description =>
      'Get details about the farmer\'s own farms and their active crops '
      '(farm name, size, soil type, water availability, irrigation, crops). '
      'Returns only real saved data; never invents farms or crops.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'farmId': stringParam(),
        },
        'required': <String>[],
      };

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final farms = await _data.loadFarms();
    if (farms.isEmpty) {
      return {
        'farms': <Object>[],
        'note': 'No farms saved yet. The farmer has not added any farm.',
      };
    }

    final farmId = (arguments['farmId'] ?? '').toString();
    final farmsJson = <Map<String, dynamic>>[];
    for (final farm in farms) {
      final map = farm.toMap();
      if (farmId.isEmpty || (map['farmId'] ?? map['id'] ?? '') == farmId) {
        farmsJson.add(map);
      }
    }

    final selected = farmsJson.isNotEmpty ? farmsJson : null;
    if (selected == null) {
      return {'error': 'Farm not found.'};
    }

    // Attach real crops for the requested/selected farm.
    final result = <String, dynamic>{'farms': selected};
    final targetFarmId =
        (selected.first['farmId'] ?? selected.first['id'] ?? '').toString();
    if (targetFarmId.isNotEmpty) {
      try {
        final crops = await _data.loadCrops(targetFarmId);
        result['crops'] = crops.map((c) => c.toMap()).toList();
      } catch (_) {
        result['crops'] = [];
      }
    }
    return result;
  }
}
