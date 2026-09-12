import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/community_service.dart';
import 'package:vidhai/locale/locale.dart';

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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = _post.likedBy.contains(currentUser?.uid);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loc.postTitle,
            style: TextStyle(
                color: colors.onBackground, fontWeight: FontWeight.bold)),
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
                  style: TextStyle(
                      color: colors.onBackground, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 16),
                _buildActions(isLiked),
                Divider(color: colors.borderColor, height: 32),
                Text(
                  loc.comments,
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
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
    final colors = VidhAIColorsX(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colors.brandDeep.withValues(alpha: 0.2),
          child: Text(
            _post.authorName.isNotEmpty
                ? _post.authorName[0].toUpperCase()
                : '?',
            style: TextStyle(
                color: colors.brandDeep,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _post.authorName,
                style: TextStyle(
                    color: colors.onBackground, fontWeight: FontWeight.w600),
              ),
              Text(
                _formatDateTime(_post.createdAt, AppLocalizations.of(context)),
                style: TextStyle(
                    color: colors.onSurfaceMuted.withValues(alpha: 0.7),
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool isLiked) {
    final colors = VidhAIColorsX(context);
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
                isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isLiked ? colors.danger : colors.onSurfaceMuted,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '${_post.likes}',
                style: TextStyle(
                  color: isLiked ? colors.danger : colors.onSurfaceMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: colors.onSurfaceMuted, size: 20),
            const SizedBox(width: 6),
            Text(
              '${_post.commentCount}',
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return StreamBuilder<List<CommunityComment>>(
      stream: _communityService.getCommentsStream(_post.postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(color: colors.brandDeep)),
          );
        }

        final comments = snapshot.data ?? [];

        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                loc.noCommentsYet,
                style: TextStyle(
                    color: colors.onSurfaceMuted.withValues(alpha: 0.5)),
              ),
            ),
          );
        }

        return Column(
          children:
              comments.map((comment) => _buildCommentCard(comment)).toList(),
        );
      },
    );
  }

  Widget _buildCommentCard(CommunityComment comment) {
    final colors = VidhAIColorsX(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.brandDeep.withValues(alpha: 0.15),
            child: Text(
              comment.authorName.isNotEmpty
                  ? comment.authorName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: colors.brandDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
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
                      style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeAgo(
                          comment.createdAt, AppLocalizations.of(context)),
                      style: TextStyle(
                          color: colors.onSurfaceMuted.withValues(alpha: 0.5),
                          fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(
                      color: colors.onBackground, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: TextStyle(color: colors.onBackground, fontSize: 14),
              decoration: InputDecoration(
                hintText: loc.writeCommentHint,
                hintStyle: TextStyle(
                    color: colors.onSurfaceMuted.withValues(alpha: 0.4)),
                filled: true,
                fillColor: colors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _submitComment,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.brandDeep,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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

  String _formatDateTime(DateTime dt, AppLocalizations loc) {
    final now = DateTime.now();
    final diff = now.difference(dt);
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
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _getTimeAgo(DateTime dateTime, AppLocalizations loc) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return loc.timeAgoNow;
    if (diff.inMinutes < 60) {
      return loc.timeAgoShortM(diff.inMinutes.toString());
    }
    if (diff.inHours < 24) {
      return loc.timeAgoShortH(diff.inHours.toString());
    }
    if (diff.inDays < 7) {
      return loc.timeAgoShortD(diff.inDays.toString());
    }
    return loc.timeAgoShortW((diff.inDays / 7).floor().toString());
  }
}
