import 'package:flutter/material.dart';
import 'package:vidhai/features/tools/screens/pest_detection_screen.dart';
import 'package:vidhai/features/tools/screens/fertilizer_guide_screen.dart';
import 'package:vidhai/features/tools/screens/market_prices_screen.dart';
import 'package:vidhai/features/tools/screens/crop_search_screen.dart';
import 'package:vidhai/features/farm/screens/crop_setup_screen.dart';
import 'package:vidhai/features/home/screens/ai_chat_screen.dart';
import 'package:vidhai/features/community/screens/community_feed_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        title: const Text(
          'Tools',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Smart farming utilities at your fingertips',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _ToolCard(
                icon: Icons.bug_report_rounded,
                title: 'Pest Detection',
                description: 'Identify pests & diseases with AI',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PestDetectionScreen(),
                  ),
                ),
              ),
              _ToolCard(
                icon: Icons.grass_rounded,
                title: 'Fertilizer Guide',
                description: 'Complete fertilizer reference',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FertilizerGuideScreen(),
                  ),
                ),
              ),
              _ToolCard(
                icon: Icons.trending_up_rounded,
                title: 'Market Prices',
                description: 'Live mandi prices & trends',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MarketPricesScreen(),
                  ),
                ),
              ),
              _ToolCard(
                icon: Icons.search_rounded,
                title: 'Crop Search',
                description: 'Browse crop knowledge base',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CropSearchScreen(),
                  ),
                ),
              ),
              _ToolCard(
                icon: Icons.terrain_rounded,
                title: 'Soil Scanner',
                description: 'Analyze & setup your soil',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CropSetupScreen(farmId: ''),
                  ),
                ),
              ),
              _ToolCard(
                icon: Icons.auto_awesome_rounded,
                title: 'AI Assistant',
                description: 'Ask anything about farming',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiChatScreen(),
                  ),
                ),
              ),
              _ToolCard(
                icon: Icons.account_balance_rounded,
                title: 'Govt Schemes',
                description: 'Schemes & subsidies for farmers',
                onTap: () => Navigator.pushNamed(context, '/government-schemes'),
              ),
              _ToolCard(
                icon: Icons.forum_rounded,
                title: 'Community',
                description: 'Connect with farmers nearby',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CommunityFeedScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
