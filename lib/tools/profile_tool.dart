import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../tools/ai_tool.dart';

/// Reads the farmer's own saved profile (never invents data).
class ProfileTool extends VidhAITool {
  ProfileTool();
  final DataService _data = DataService();

  @override
  String get name => 'GET_PROFILE';

  @override
  String get description =>
      'Get the farmer\'s own saved profile details (name, language role, '
      'location). Only real saved data is returned.';

  @override
  Map<String, dynamic> get parameters => withRequired(<String>[], {});

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final profile = await _data.loadCachedProfile();
    if (profile == null) {
      return {'error': 'Profile not available yet.'};
    }
    final map = profile.toMap();
    return {
      'profile': {
        'name': map['fullName'] ?? map['name'],
        'role': map['role'],
        'language': map['language'],
        'location': map['address'] ?? map['location'],
        'email': map['email'],
      },
    };
  }
}
