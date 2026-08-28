import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/community_service.dart';
import 'package:vidhai/features/community/screens/create_post_screen.dart';
import 'package:vidhai/features/community/screens/post_detail_screen.dart';

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

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _accent = Color(0xFF4CAF50);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Community',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: _textSecondary),
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
        backgroundColor: _accent,
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
                  return const Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forum_rounded, size: 64, color: _textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No posts yet',
                          style: TextStyle(color: _textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to share something!',
                          style: TextStyle(color: _textSecondary.withValues(alpha: 0.6), fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                color: isSelected ? _accent : _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _accent : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                _formatCategory(cat),
                style: TextStyle(
                  color: isSelected ? Colors.white : _textSecondary,
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

  String _formatCategory(String cat) {
    switch (cat) {
      case 'all': return 'All';
      case 'general': return 'General';
      case 'crops': return 'Crops';
      case 'pest_control': return 'Pest Control';
      case 'irrigation': return 'Irrigation';
      case 'market_prices': return 'Market';
      case 'equipment': return 'Equipment';
      case 'organic': return 'Organic';
      case 'weather': return 'Weather';
      case 'government_schemes': return 'Schemes';
      default: return cat;
    }
  }

  Widget _buildPostCard(CommunityPost post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = post.likedBy.contains(currentUser?.uid);
    final timeAgo = _getTimeAgo(post.createdAt);

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
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _accent.withValues(alpha: 0.2),
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                    style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$timeAgo${post.isAIAssisted ? ' · AI Assisted' : ''}',
                        style: TextStyle(
                          color: _textSecondary.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.district.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      post.district,
                      style: TextStyle(color: _accent, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: const TextStyle(
                color: _textPrimary,
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
                  icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  count: post.likes,
                  color: isLiked ? const Color(0xFFEF4444) : _textSecondary,
                  onTap: () async {
                    await _communityService.toggleLike(post);
                  },
                ),
                const SizedBox(width: 16),
                _buildAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: post.commentCount,
                  color: _textSecondary,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
                    );
                  },
                ),
                const SizedBox(width: 16),
                if (post.category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatCategory(post.category),
                      style: TextStyle(color: _textSecondary.withValues(alpha: 0.7), fontSize: 10),
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

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Location',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'District',
                      hintStyle: TextStyle(color: _textSecondary),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: _textPrimary),
                    onChanged: (v) => setModalState(() => _selectedDistrict = v.isEmpty ? null : v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'State',
                      hintStyle: TextStyle(color: _textSecondary),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: _textPrimary),
                    onChanged: (v) => setModalState(() => _selectedState = v.isEmpty ? null : v),
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
                          child: const Text('Clear Filters', style: TextStyle(color: _accent)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: _accent),
                          child: const Text('Apply', style: TextStyle(color: Colors.white)),
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
