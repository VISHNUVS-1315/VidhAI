import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/features/community/data/community_repository.dart';
import 'package:vidhai/features/community/services/community_notification_service.dart';

/// Central Community state: the farmer's home district (never modified) vs the
/// district currently being browsed (persisted locally). Changing the browsing
/// district must NOT change the FCM topic subscription.
class CommunityController extends ChangeNotifier {
  CommunityController._();
  static final CommunityController instance = CommunityController._();

  static const _selStateKey = 'community_sel_state';
  static const _selDistrictKey = 'community_sel_district';

  String homeState = '';
  String homeDistrict = '';

  String selectedState = '';
  String selectedDistrict = '';
  bool loaded = false;

  bool get isHomeDistrict =>
      loaded &&
      selectedState.isNotEmpty &&
      selectedState == homeState &&
      selectedDistrict.isNotEmpty &&
      selectedDistrict == homeDistrict;

  /// Loads persisted browsing district; falls back to the profile (home)
  /// district when nothing was chosen yet.
  Future<void> ensureLoaded() async {
    if (loaded) return;
    loaded = true;

    final (profileState, profileDistrict) =
        await CommunityRepository.instance.getUserStateDistrict();
    homeState = profileState;
    homeDistrict = profileDistrict;

    final prefs = await SharedPreferences.getInstance();
    selectedState = prefs.getString(_selStateKey) ?? profileState;
    selectedDistrict = prefs.getString(_selDistrictKey) ?? profileDistrict;

    notifyListeners();

    // FCM topic follows the HOME district only, never the browsing one.
    unawaited(CommunityNotificationService.instance.ensureTopicSubscribed());
  }

  /// Saves a browsing district choice (persisted; does not touch FCM topics).
  Future<void> setDistrict(String state, String district) async {
    selectedState = state;
    selectedDistrict = district;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selStateKey, state);
    await prefs.setString(_selDistrictKey, district);
  }

  Future<void> useHomeDistrict() async {
    if (homeDistrict.isNotEmpty) {
      await setDistrict(homeState, homeDistrict);
    }
  }
}