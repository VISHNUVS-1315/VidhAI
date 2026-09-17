import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/features/community/data/community_repository.dart';
import 'package:vidhai/services/ai/secure_api_client.dart';

/// District-topic push + realtime notification helpers for the Community.
///
/// Security model:
///  - Topic *subscription* happens client-side for the HOME district only.
///  - Topic *dispatch* (sending) happens ONLY on the authenticated backend
///    (`POST /community/notify`), which verifies the Firebase ID token and the
///    post's owner before publishing. No FCM server key ever ships in the app.
///  - Firestore (community_activity) is the source of truth; FCM is delivery.
class CommunityNotificationService {
  CommunityNotificationService._();
  static final CommunityNotificationService instance =
      CommunityNotificationService._();

  static const _subscribedKey = 'community_subscribed_topics';

  static String districtTopic(String district) {
    final slug = district
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'district_$slug';
  }

  /// Subscribes the device to the HOME-district FCM topic and unsubscribes any
  /// stale topics from an earlier home district. Browsing changes never reach
  /// this method.
  Future<void> ensureTopicSubscribed() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final subscribed = (prefs.getStringList(_subscribedKey) ?? const []).toSet();

    final (_, homeDistrict) =
        await CommunityRepository.instance.getUserStateDistrict();
    if (homeDistrict.trim().isEmpty) return;

    final topic = districtTopic(homeDistrict);
    try {
      final messaging = FirebaseMessaging.instance;
      if (!subscribed.contains(topic)) {
        await messaging.subscribeToTopic(topic);
        subscribed.add(topic);
      }
      final stale = subscribed
          .where((t) => t != topic && t.startsWith('district_'))
          .toList();
      for (final old in stale) {
        try {
          await messaging.unsubscribeFromTopic(old);
        } catch (_) {}
        subscribed.remove(old);
      }
      await prefs.setStringList(_subscribedKey, subscribed.toList());
    } catch (e) {
      debugPrint('[CommunityNotify] topic subscribe failed: $e');
    }
  }

  /// Best-effort push after a harvest/demand post is published. The backend
  /// re-derives everything from the stored post and rejects strangers.
  Future<void> notifyPostCreated(String postId) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await SecureApiClient.instance.post(
        '/community/notify',
        {'postId': postId},
        debugTag: 'CommunityNotify',
      );
    } catch (e) {
      debugPrint('[CommunityNotify] push dispatch failed: $e');
    }
  }
}