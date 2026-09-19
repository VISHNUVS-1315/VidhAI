import '../../consumer/screens/consumer_utilities.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/features/community/data/community_repository.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/screens/create_post_screen.dart';
import 'package:vidhai/features/community/services/price_risk_service.dart';
import 'package:vidhai/features/community/widgets/community_shared.dart';
import 'package:vidhai/locale/locale.dart';

/// Full post view with like / comment (experience), interest (harvest) and
/// supply (demand). The post owner can accept/decline responses and manage the
/// lifecycle status. All data loads in realtime from Firestore.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final CommunityRepository _repo = CommunityRepository.instance;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = FreshLeafColorsX(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : colors.brandDeep,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      _snack(loc.communityWaitingConnection, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _repo.postDocStream(widget.postId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _scaffold(
            colors,
            body: _notice(colors, AppLocalizations.of(context).communityLoadFailed),
          );
        }
        if (!snapshot.hasData) {
          return _scaffold(
            colors,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!.exists) {
          return _scaffold(
            colors,
            body: _notice(colors, AppLocalizations.of(context).communityPostDeleted),
          );
        }

        final post = CommunityPost.fromFirestore(snapshot.data!);
        final isOwner = post.authorId == _uid;
        return _scaffold(
          colors,
          title: postTypeLabel(AppLocalizations.of(context), post.type),
          actions: isOwner ? _ownerMenu(post) : null,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40, top: 8),
            children: [
              CommunityPostCard(post: post),
              if (post.isHarvest) _priceSection(colors, post),
              _actionSection(colors, post, isOwner),
              if (isOwner && !post.isExperience) _responsesSection(colors, post),
              if (post.isExperience) _commentsSection(colors, post),
            ],
          ),
        );
      },
    );
  }

  Widget _scaffold(
    FreshLeafColorsX colors, {
    required Widget body,
    String? title,
    List<Widget>? actions,
  }) {
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.onBackground,
        title: Text(
          title ?? AppLocalizations.of(context).communityViewDetails,
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: actions,
      ),
      body: body,
    );
  }

  List<Widget> _ownerMenu(CommunityPost post) {
    final loc = AppLocalizations.of(context);
    return [
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreatePostScreen(type: post.type, editing: post),
              ),
            );
          } else if (value == 'delete') {
            _confirmDelete(post);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: 10),
                Text(loc.communityEditTitle),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 18),
                const SizedBox(width: 10),
                Text(loc.communityDeletePost),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    final loc = AppLocalizations.of(context);
    final colors = FreshLeafColorsX(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.communityDeletePost),
        content: Text(loc.communityDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.communityDecline),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: Text(loc.communityDeletePost),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _repo.deletePost(post.id);
      if (!mounted) return;
      _snack(loc.communityPostDeleted);
      Navigator.of(context).pop();
    });
  }

  Widget _priceSection(FreshLeafColorsX colors, CommunityPost post) {
    final loc = AppLocalizations.of(context);
    final ref = post.marketReferencePerKg;
    if (ref == null) return const SizedBox.shrink();
    final risk = PriceRiskService.evaluate(post.askingPricePerKg, ref);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${loc.communityMarketPriceLabel}: '
            '${MarketFormat.inr(ref, decimals: 1)}/${loc.communityKgUnit}',
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (post.suggestedMinPrice != null && post.suggestedMaxPrice != null) ...[
            const SizedBox(height: 4),
            Text(
              '${loc.communitySuggestedLabel}: '
              '${MarketFormat.inr(post.suggestedMinPrice, decimals: 1)} – '
              '${MarketFormat.inr(post.suggestedMaxPrice, decimals: 1)}',
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 12),
          PriceRiskBar(risk: risk),
        ],
      ),
    );
  }

  Widget _actionSection(FreshLeafColorsX colors, CommunityPost post, bool isOwner) {
    final loc = AppLocalizations.of(context);
    final uid = _uid;
    if (uid == null) return const SizedBox.shrink();

    if (post.isExperience) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _repo.likeDocStream(post.id, uid),
        builder: (context, snap) {
          final liked = snap.data?.exists ?? false;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => _repo.toggleLike(post.id)),
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                  ),
                  label: Text(loc.communityLikes('${post.likeCount}')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        liked ? colors.error : colors.surfaceMuted,
                    foregroundColor: liked ? Colors.white : colors.onBackground,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (isOwner) return _ownerStatusControls(colors, post);

    final isHarvest = post.isHarvest;
    final docStream = isHarvest
        ? _repo.interestDocStream(post.id, uid)
        : _repo.supplyDocStream(post.id, uid);
    final closed = post.status == CommunityStatus.closed;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docStream,
      builder: (context, snap) {
        final responded = snap.data?.exists ?? false;
        final accepted = snap.data?.data()?['status'] == 'accepted';
        if (isHarvest && accepted && post.status == CommunityStatus.fulfilled) {
          return Padding(padding: const EdgeInsets.all(16), child: FilledButton.icon(
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(loc.t('consumer_received')),
            onPressed: _busy ? null : () => _run(() => recordConsumerPurchase(context,
              postId: post.id, crop: post.cropName, seller: post.authorName)),
          ));
        }

        final doneLabel =
            isHarvest ? loc.communityInterestedDone : loc.communitySuppliedDone;
        final actionLabel =
            isHarvest ? loc.communityImInterested : loc.communityICanSupply;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (closed || _busy)
                  ? null
                  : () => _run(() async {
                        if (responded) {
                          if (isHarvest) {
                            await _repo.withdrawInterest(post.id);
                          } else {
                            await _repo.withdrawSupply(post.id);
                          }
                        } else {
                          final sent = isHarvest
                              ? await _repo.sendInterest(post.id)
                              : await _repo.sendSupply(post.id);
                          if (sent) {
                            _snack(isHarvest
                                ? loc.communityInterestSent
                                : loc.communitySupplySent);
                          }
                        }
                      }),
              icon: Icon(
                responded ? Icons.check_circle : Icons.handshake_outlined,
                size: 18,
              ),
              label: Text(responded ? doneLabel : actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: responded ? colors.success : colors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ownerStatusControls(FreshLeafColorsX colors, CommunityPost post) {
    final loc = AppLocalizations.of(context);
    final actions = <(String, CommunityStatus, bool)>[];
    if (post.status == CommunityStatus.active) {
      actions.add((loc.communityMarkReserved, CommunityStatus.reserved, true));
      actions.add((loc.communityMarkFulfilled, CommunityStatus.fulfilled, true));
      actions.add((loc.communityMarkClosed, CommunityStatus.closed, false));
    } else if (post.status == CommunityStatus.reserved) {
      actions.add((loc.communityMarkFulfilled, CommunityStatus.fulfilled, true));
      actions.add((loc.communityMarkClosed, CommunityStatus.closed, false));
    } else {
      actions.add((loc.communityReopen, CommunityStatus.active, false));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (a) => OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => _repo.updatePostStatus(
                          post.id,
                          a.$2,
                          notifyMembers: a.$3,
                        )),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.brandDeep,
                  side: BorderSide(color: colors.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(a.$1),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _responsesSection(FreshLeafColorsX colors, CommunityPost post) {
    final loc = AppLocalizations.of(context);
    final isHarvest = post.isHarvest;
    final stream = isHarvest
        ? _repo.interestsStream(post.id)
        : _repo.suppliersStream(post.id);
    final emptyLabel =
        isHarvest ? loc.communityInterestedEmpty : loc.communitySuppliersEmpty;
    final title =
        isHarvest ? loc.communityViewInterested : loc.communityViewSuppliers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(
            title,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        StreamBuilder<List<CommunityMember>>(
          stream: stream,
          builder: (context, snap) {
            final members = snap.data ?? const [];
            if (members.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  emptyLabel,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                ),
              );
            }
            return Column(
              children: members
                  .map((m) => _memberTile(colors, post, m, isHarvest))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _memberTile(FreshLeafColorsX colors, CommunityPost post,
      CommunityMember member, bool isHarvest) {
    final loc = AppLocalizations.of(context);
    final statusColor = switch (member.status) {
      CommunityMemberStatus.accepted => colors.success,
      CommunityMemberStatus.declined => colors.error,
      CommunityMemberStatus.interested => colors.warning,
    };
    final statusText = switch (member.status) {
      CommunityMemberStatus.accepted => loc.communityAccepted,
      CommunityMemberStatus.declined => loc.communityDeclined,
      CommunityMemberStatus.interested => loc.communityPending,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
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
              CommunityAvatar(
                photo: member.userPhoto,
                name: member.userName,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  member.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              CommunityChip(label: statusText, color: statusColor, filled: true),
            ],
          ),
          if (!isHarvest && post.status == CommunityStatus.fulfilled &&
              member.status == CommunityMemberStatus.accepted)
            TextButton.icon(icon: const Icon(Icons.receipt_long_outlined),
              label: Text(loc.t('consumer_received')),
              onPressed: _busy ? null : () => _run(() => recordConsumerPurchase(context,
                postId: '${post.id}_${member.userId}', crop: post.cropName, seller: member.userName))),
          if (member.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              member.note,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            ),
          ],
          if (member.status == CommunityMemberStatus.interested) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => isHarvest
                            ? _repo.respondInterest(post.id, member.userId, false)
                            : _repo.respondSupplier(
                                post.id, member.userId, false)),
                    child: Text(loc.communityDecline),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => isHarvest
                            ? _repo.respondInterest(post.id, member.userId, true)
                            : _repo.respondSupplier(
                                post.id, member.userId, true)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(loc.communityAccept),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _commentsSection(FreshLeafColorsX colors, CommunityPost post) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(
            loc.communityComments('${post.commentCount}'),
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        StreamBuilder<List<CommunityComment>>(
          stream: _repo.commentsStream(post.id),
          builder: (context, snap) {
            final comments = snap.data ?? const [];
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  loc.communityActivityEmpty,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
                ),
              );
            }
            return Column(
              children: comments
                  .map((c) => _commentTile(colors, post, c))
                  .toList(),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: loc.communityCommentHint,
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
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
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final text = _commentCtrl.text.trim();
                          if (text.isEmpty) return;
                          await _repo.addComment(post.id, text);
                          _commentCtrl.clear();
                        }),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commentTile(
      FreshLeafColorsX colors, CommunityPost post, CommunityComment comment) {
    final uid = _uid;
    final canDelete = comment.authorId == uid || post.authorId == uid;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityAvatar(
            photo: comment.authorPhoto,
            name: comment.authorName,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorName,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              iconSize: 18,
              splashRadius: 18,
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _repo.deleteComment(post.id, comment.id)),
              icon: Icon(Icons.close, color: colors.onSurfaceMuted),
            ),
        ],
      ),
    );
  }

  Widget _notice(FreshLeafColorsX colors, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 44, color: colors.borderColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}
