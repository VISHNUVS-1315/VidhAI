import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          'Community',
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
        },
        backgroundColor: colors.brandDeep,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search posts, crops, or questions...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: colors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.borderColor),
                ),
              ),
            ),
          ),
          _buildCategoryChips(),
          Expanded(
            child: StreamBuilder<List<CommunityPost>>(
              stream: _communityService.getPostsStream(
                category: _selectedCategory == 'all'
                    ? null
                    : _selectedCategory,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: colors.brandDeep),
                  );
                }

                final allPosts = snapshot.data ?? [];
                final posts = _query.isEmpty
                    ? allPosts
                    : allPosts.where((post) {
                        final text =
                            '${post.authorName} ${post.content} ${post.crop} ${post.district}'
                                .toLowerCase();
                        return text.contains(_query);
                      }).toList();

                if (posts.isEmpty) {
                  return _emptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => _buildPostCard(posts[index]),
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
    const categories = [
      ('all', 'All'),
      ('problem', 'Problems'),
      ('experience', 'Experience'),
      ('available_soon', 'Available Soon'),
      ('demand', 'Demand'),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final selected = _selectedCategory == item.$1;
          return ChoiceChip(
            label: Text(item.$2),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = item.$1),
            selectedColor: colors.brandDeep,
            backgroundColor: colors.surface,
            labelStyle: TextStyle(
              color: selected ? Colors.white : colors.onBackground,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(
              color: selected ? colors.brandDeep : colors.borderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    final colors = VidhAIColorsX(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_2_outlined,
              size: 62,
              color: colors.onSurfaceMuted.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              'No community posts yet',
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create the first post and start helping the farming community.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post) {
    final colors = VidhAIColorsX(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = post.likedBy.contains(currentUser?.uid);
    final categoryLabel = _categoryLabel(post.category);
    final categoryColor = _categoryColor(post.category, colors);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.brandDeep.withValues(alpha: 0.12),
                  backgroundImage: post.authorAvatar.isNotEmpty
                      ? NetworkImage(post.authorAvatar)
                      : null,
                  child: post.authorAvatar.isEmpty
                      ? Text(
                          post.authorName.isNotEmpty
                              ? post.authorName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: colors.brandDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
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
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (post.district.isNotEmpty) post.district,
                          _timeAgo(post.createdAt),
                        ].join(' • '),
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded),
              ],
            ),
            const SizedBox(height: 12),
            if (post.crop.isNotEmpty)
              Row(
                children: [
                  Text(
                    _cropEmoji(post.crop),
                    style: const TextStyle(fontSize: 17),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        post.crop,
                        if (post.cropStage.isNotEmpty) post.cropStage,
                      ].join(' • '),
                      style: TextStyle(
                        color: colors.onBackground,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (post.category == 'available_soon' &&
                      post.expectedHarvestDate != null)
                    _daysLeftBadge(post.expectedHarvestDate!),
                ],
              ),
            if (post.crop.isNotEmpty) const SizedBox(height: 9),
            Text(
              post.content,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            if (post.category == 'available_soon' ||
                post.category == 'demand') ...[
              const SizedBox(height: 12),
              _buildMarketDetails(post),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    categoryLabel,
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                _iconCount(
                  icon: isLiked
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  count: post.likes,
                  color: isLiked ? colors.brandDeep : colors.onSurfaceMuted,
                  onTap: () => _communityService.toggleLike(post),
                ),
                const SizedBox(width: 14),
                _iconCount(
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
              ],
            ),
            if (post.category == 'available_soon' ||
                post.category == 'demand') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showInterestSheet(post),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brandDeep,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    post.category == 'demand'
                        ? 'I Can Supply'
                        : "I'm Interested",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (post.interestedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    '${post.interestedCount} interested',
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarketDetails(CommunityPost post) {
    final colors = VidhAIColorsX(context);
    final date = post.category == 'demand'
        ? post.requiredByDate
        : post.expectedHarvestDate;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          if (post.quantityKg != null)
            _detailItem('Quantity', '${_number(post.quantityKg!)} kg'),
          if (post.expectedPricePerKg != null)
            _detailItem(
                'Price', '₹${_number(post.expectedPricePerKg!)}/kg'),
          if (date != null)
            _detailItem(
              post.category == 'demand' ? 'Required by' : 'Harvest',
              DateFormat('dd MMM').format(date),
            ),
          if (post.buyerType.isNotEmpty)
            _detailItem('Buyer', post.buyerType),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    final colors = VidhAIColorsX(context);
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _daysLeftBadge(DateTime date) {
    final colors = VidhAIColorsX(context);
    final days = date.difference(DateTime.now()).inDays + 1;
    final text = days <= 0 ? 'Today' : '$days days left';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.brandDeep.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.brandDeep,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _iconCount({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _showInterestSheet(CommunityPost post) async {
    final colors = VidhAIColorsX(context);
    final quantityController = TextEditingController();
    final messageController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.category == 'demand'
                    ? 'Supply this demand'
                    : "I'm Interested",
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                post.crop.isEmpty ? 'Community post' : post.crop,
                style: TextStyle(color: colors.onSurfaceMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantity (kg)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: post.category == 'demand'
                      ? 'Tell the buyer about your produce...'
                      : 'Ask about quality, pickup, or delivery...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final ok = await _communityService.expressInterest(
                      post: post,
                      quantityKg:
                          double.tryParse(quantityController.text.trim()),
                      message: messageController.text.trim(),
                    );
                    if (!mounted || !sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Interest sent successfully'
                              : 'Could not send interest. Please try again.',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brandDeep,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    quantityController.dispose();
    messageController.dispose();
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'problem':
        return 'Problem';
      case 'experience':
        return 'Experience';
      case 'available_soon':
        return 'Available Soon';
      case 'demand':
        return 'Demand';
      default:
        return 'General';
    }
  }

  Color _categoryColor(String category, dynamic colors) {
    switch (category) {
      case 'problem':
        return colors.danger;
      case 'experience':
        return colors.brandDeep;
      case 'available_soon':
        return colors.brandDeep;
      case 'demand':
        return colors.brandDeep;
      default:
        return colors.onSurfaceMuted;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(date);
  }

  String _number(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  String _cropEmoji(String crop) {
    final c = crop.toLowerCase();
    if (c.contains('tomato')) return '🍅';
    if (c.contains('chilli') || c.contains('pepper')) return '🌶️';
    if (c.contains('paddy') || c.contains('rice')) return '🌾';
    if (c.contains('banana')) return '🍌';
    if (c.contains('brinjal') || c.contains('eggplant')) return '🍆';
    if (c.contains('groundnut')) return '🥜';
    return '🌱';
  }
}
