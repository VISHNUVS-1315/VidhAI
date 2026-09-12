import 'package:flutter/material.dart';

/// Global navigator key used by AI tools and other non-widget code to push
/// real app routes.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get state => key.currentState;

  static Future<T?>? pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return state?.pushNamed<T>(routeName, arguments: arguments);
  }
}
