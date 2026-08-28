import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/community_service.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final CommunityService _communityService = CommunityService();
  late CommunityPost _post;

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _accent = Color(0xFF4CAF50);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = _post.likedBy.contains(currentUser?.uid);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Post', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPostHeader(),
                const SizedBox(height: 12),
                Text(
                  _post.content,
                  style: const TextStyle(color: _textPrimary, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 16),
                _buildActions(isLiked),
                const Divider(color: Colors.white10, height: 32),
                const Text(
                  'Comments',
                  style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildCommentsList(),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _accent.withValues(alpha: 0.2),
          child: Text(
            _post.authorName.isNotEmpty ? _post.authorName[0].toUpperCase() : '?',
            style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _post.authorName,
                style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
              ),
              Text(
                _formatDateTime(_post.createdAt),
                style: TextStyle(color: _textSecondary.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool isLiked) {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            await _communityService.toggleLike(_post);
            setState(() {
              final likedBy = List<String>.from(_post.likedBy);
              if (isLiked) {
                likedBy.remove(FirebaseAuth.instance.currentUser?.uid);
              } else {
                likedBy.add(FirebaseAuth.instance.currentUser?.uid ?? '');
              }
              _post = _post.copyWith(likes: likedBy.length, likedBy: likedBy);
            });
          },
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? const Color(0xFFEF4444) : _textSecondary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '${_post.likes}',
                style: TextStyle(
                  color: isLiked ? const Color(0xFFEF4444) : _textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: _textSecondary, size: 20),
            const SizedBox(width: 6),
            Text(
              '${_post.commentCount}',
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<List<CommunityComment>>(
      stream: _communityService.getCommentsStream(_post.postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: _accent)),
          );
        }

        final comments = snapshot.data ?? [];

        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No comments yet. Start the conversation!',
                style: TextStyle(color: _textSecondary.withValues(alpha: 0.5)),
              ),
            ),
          );
        }

        return Column(
          children: comments.map((comment) => _buildCommentCard(comment)).toList(),
        );
      },
    );
  }

  Widget _buildCommentCard(CommunityComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _accent.withValues(alpha: 0.15),
            child: Text(
              comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : '?',
              style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeAgo(comment.createdAt),
                      style: TextStyle(color: _textSecondary.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(color: _textPrimary, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: _textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _submitComment,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    _commentController.clear();

    final comment = await _communityService.addComment(
      postId: _post.postId,
      content: content,
    );

    if (comment != null) {
      setState(() {
        _post = _post.copyWith(commentCount: _post.commentCount + 1);
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}
