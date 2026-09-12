import 'package:flutter/material.dart';

import '../../core/routing/main_shell_controller.dart';
import '../tools/ai_tool.dart';

/// Opens an existing, real app screen. Navigation happens through the
/// existing shell/route structure only.
class NavigationTool extends VidhAITool {
  @override
  String get name => 'OPEN_SCREEN';

  @override
  String get description =>
      'Navigate the app to a real screen. screen values: home, farm, ai_chat, tools, '
      'profile, settings, market_prices, government_schemes, pest_detection, '
      'add_farm, crop_recommendation, edit_profile, crop_search. '
      'For farm_details pass the farmId argument. '
      'Returns which screen was opened.';

  @override
  Map<String, dynamic> get parameters => withRequired(
        ['screen'],
        {
          'screen': stringParam(),
          'farmId': stringParam(),
        },
      );

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final screen = (arguments['screen'] ?? '').toString().trim();
    final farmId = (arguments['farmId'] ?? '').toString().trim();
    final shell = MainShellController.instance;
    switch (screen) {
      case 'home':
        shell.switchTab(MainShellController.indexHome);
        return {'opened': screen};
      case 'farm':
        shell.switchTab(MainShellController.indexFarm);
        return {'opened': screen};
      case 'ai_chat':
        shell.switchTab(MainShellController.indexAi);
        return {'opened': screen};
      case 'tools':
        shell.switchTab(MainShellController.indexTools);
        return {'opened': screen};
      case 'profile':
        shell.switchTab(MainShellController.indexProfile);
        return {'opened': screen};
      case 'add_farm':
        shell.switchTab(MainShellController.indexFarm);
        if (navigatorKey?.currentState != null) {
          navigatorKey!.currentState!.pushNamed('/add_farm');
        }
        return {'opened': screen};
      default:
        if (navigatorKey?.currentState == null) {
          return {
            'error': 'Navigation not available right now. Please try again.'
          };
        }
        final path = _pathFor(screen);
        if (path == null) {
          return {
            'error':
                'Unknown screen "$screen". Must be one of home, farm, ai_chat, tools, profile, settings, market_prices, government_schemes, pest_detection, add_farm.'
          };
        }
        navigatorKey!.currentState!
            .pushNamed(path, arguments: farmId.isEmpty ? null : farmId);
        return {'opened': screen};
    }
  }

  String? _pathFor(String screen) {
    switch (screen) {
      case 'settings':
        return '/language-settings';
      case 'market_prices':
        return '/market-prices';
      case 'government_schemes':
        return '/government-schemes';
      case 'pest_detection':
        return '/pest-detection';
      case 'farm_details':
        return '/farm_details';
      case 'crop_recommendation':
        return '/crop_recommendation';
      case 'edit_profile':
        return '/edit-profile';
      case 'crop_search':
        return '/crop-search';
      default:
        return null;
    }
  }
}
