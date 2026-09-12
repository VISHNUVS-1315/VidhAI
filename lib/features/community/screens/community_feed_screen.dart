import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/community_service.dart';
import 'package:vidhai/features/community/screens/create_post_screen.dart';
import 'package:vidhai/features/community/screens/post_detail_screen.dart';
import 'package:vidhai/locale/locale.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final CommunityService _communityService = CommunityService();
  String _selectedCategory = 'all';
  String? _selectedDistrict;
  String? _selectedState;

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          loc.community,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: colors.onSurfaceMuted),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
        },
        backgroundColor: colors.brandDeep,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildCategoryChips(),
          Expanded(
            child: StreamBuilder<List<CommunityPost>>(
              stream: _communityService.getPostsStream(
                category: _selectedCategory == 'all' ? null : _selectedCategory,
                district: _selectedDistrict,
                state: _selectedState,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: colors.brandDeep),
                  );
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forum_rounded,
                            size: 64,
                            color:
                                colors.onSurfaceMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          loc.communityNoPosts,
                          style: TextStyle(
                              color: colors.onSurfaceMuted, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.communityNoPostsHint,
                          style: TextStyle(
                              color:
                                  colors.onSurfaceMuted.withValues(alpha: 0.6),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _buildPostCard(posts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final categories = ['all', ...CommunityPost.categories];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.brandDeep : colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? colors.brandDeep : colors.borderColor,
                ),
              ),
              child: Text(
                _formatCategory(cat, loc),
                style: TextStyle(
                  color: isSelected ? Colors.white : colors.onSurfaceMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatCategory(String cat, AppLocalizations loc) {
    switch (cat) {
      case 'all':
        return loc.all;
      case 'general':
        return loc.communityCategoryGeneral;
      case 'crops':
        return loc.communityCategoryCrops;
      case 'pest_control':
        return loc.communityCategoryPestControl;
      case 'irrigation':
        return loc.communityCategoryIrrigation;
      case 'market_prices':
        return loc.communityCategoryMarket;
      case 'equipment':
        return loc.communityCategoryEquipment;
      case 'organic':
        return loc.communityCategoryOrganic;
      case 'weather':
        return loc.communityCategoryWeather;
      case 'government_schemes':
        return loc.communityCategorySchemes;
      default:
        return cat;
    }
  }

  Widget _buildPostCard(CommunityPost post) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = post.likedBy.contains(currentUser?.uid);
    final timeAgo = _getTimeAgo(post.createdAt, loc);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.brandDeep.withValues(alpha: 0.2),
                  child: Text(
                    post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: colors.brandDeep, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$timeAgo${post.isAIAssisted ? ' \u00B7 ${loc.aiAssisted}' : ''}',
                        style: TextStyle(
                          color: colors.onSurfaceMuted.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.district.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      post.district,
                      style: TextStyle(color: colors.brandDeep, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAction(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  count: post.likes,
                  color: isLiked ? colors.danger : colors.onSurfaceMuted,
                  onTap: () async {
                    await _communityService.toggleLike(post);
                  },
                ),
                const SizedBox(width: 16),
                _buildAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: post.commentCount,
                  color: colors.onSurfaceMuted,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: post)),
                    );
                  },
                ),
                const SizedBox(width: 16),
                if (post.category.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatCategory(post.category, loc),
                      style: TextStyle(
                          color: colors.onSurfaceMuted.withValues(alpha: 0.7),
                          fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            count > 0 ? '$count' : '',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime, AppLocalizations loc) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return loc.timeAgoJustNow;
    if (diff.inMinutes < 60) {
      return loc.timeAgoM.replaceAll('{count}', diff.inMinutes.toString());
    }
    if (diff.inHours < 24) {
      return loc.timeAgoH.replaceAll('{count}', diff.inHours.toString());
    }
    if (diff.inDays < 7) {
      return loc.timeAgoD.replaceAll('{count}', diff.inDays.toString());
    }
    return loc.timeAgoW
        .replaceAll('{count}', (diff.inDays / 7).floor().toString());
  }

  void _showFilterSheet() {
    final sheetColors = VidhAIColorsX(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: sheetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colors = VidhAIColorsX(context);
        final loc = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.filterByLocation,
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: loc.district,
                      hintStyle: TextStyle(color: colors.onSurfaceMuted),
                      filled: true,
                      fillColor: colors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: colors.onBackground),
                    onChanged: (v) => setModalState(
                        () => _selectedDistrict = v.isEmpty ? null : v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: loc.state,
                      hintStyle: TextStyle(color: colors.onSurfaceMuted),
                      filled: true,
                      fillColor: colors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: colors.onBackground),
                    onChanged: (v) => setModalState(
                        () => _selectedState = v.isEmpty ? null : v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedDistrict = null;
                              _selectedState = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(loc.clearFilters,
                              style: TextStyle(color: colors.brandDeep)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: colors.brandDeep),
                          child: Text(loc.apply,
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
