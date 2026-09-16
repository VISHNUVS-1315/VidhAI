import 'package:flutter/material.dart';
import 'package:vidhai/features/community/screens/community_feed_screen.dart';

/// Entry point used by the Tools page for the Community module.
/// Kept with the old class name so existing navigation does not break.
class CommunityPlaceholderScreen extends StatelessWidget {
  const CommunityPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CommunityFeedScreen();
  }
}
