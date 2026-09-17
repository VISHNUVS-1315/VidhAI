import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/features/community/data/community_repository.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/screens/post_detail_screen.dart';
import 'package:vidhai/features/community/widgets/community_shared.dart';
import 'package:vidhai/locale/locale.dart';

/// My Activity: my posts, responses received on my posts, and the realtime
/// in-app activity feed (Firestore is the source of truth, FCM only delivers).
class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen>
    with SingleTickerProviderStateMixin {
  final CommunityRepository _repo = CommunityRepository.instance;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 2) {
        _repo.markAllActivityRead();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.onBackground,
        title: Text(
          loc.communityMyActivity,
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.brandDeep,
          unselectedLabelColor: colors.onSurfaceMuted,
          indicatorColor: colors.brand,
          tabs: [
            Tab(text: loc.communityTabPosts),
            Tab(text: loc.communityTabResponses),
            Tab(text: loc.communityTabActivity),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _postsTab(colors, loc, responsesOnly: false),
          _postsTab(colors, loc, responsesOnly: true),
          _activityTab(colors, loc),
        ],
      ),
    );
  }

  Widget _postsTab(FreshLeafColorsX colors, AppLocalizations loc,
      {required bool responsesOnly}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo.myPostsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var posts = snapshot.data!.docs.map(CommunityPost.fromFirestore).toList();
        if (responsesOnly) {
          posts = posts
              .where((p) =>
                  p.interestedCount > 0 ||
                  p.supplierCount > 0 ||
                  p.commentCount > 0)
              .toList();
        }
        if (posts.isEmpty) {
          return _empty(
            colors,
            responsesOnly ? loc.communityResponsesEmpty : loc.communityMyPostsEmpty,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 30),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return CommunityPostCard(
              post: post,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(postId: post.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _activityTab(FreshLeafColorsX colors, AppLocalizations loc) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo.myActivityStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!.docs
            .map(CommunityActivity.fromFirestore)
            .toList();
        if (items.isEmpty) {
          return _empty(colors, loc.communityActivityEmpty);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 30),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _activityTile(colors, loc, items[index]),
        );
      },
    );
  }

  Widget _activityTile(
      FreshLeafColorsX colors, AppLocalizations loc, CommunityActivity item) {
    final message = _message(loc, item);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: item.read
            ? colors.surface
            : colors.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.read
              ? colors.borderColor
              : colors.brand.withValues(alpha: 0.35),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _repo.markActivityRead(item.id);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(postId: item.postId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommunityAvatar(
                  photo: item.actorPhoto,
                  name: item.actorName,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight:
                              item.read ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                      if (item.postCrop.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.postCrop,
                          style: TextStyle(
                            color: colors.onSurfaceMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!item.read)
                  Container(
                    margin: const EdgeInsets.only(top: 6, left: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _message(AppLocalizations loc, CommunityActivity item) {
    final name = item.actorName.isEmpty ? loc.communityOwner : item.actorName;
    switch (item.type) {
      case CommunityActivityType.interestNew:
        return loc.communityActInterestNew(name, item.postCrop);
      case CommunityActivityType.supplierNew:
        return loc.communityActSupplierNew(name, item.postCrop);
      case CommunityActivityType.interestAccepted:
        return loc.communityActInterestAccepted(name);
      case CommunityActivityType.interestDeclined:
        return loc.communityActInterestDeclined(name);
      case CommunityActivityType.supplierAccepted:
        return loc.communityActSupplierAccepted(name);
      case CommunityActivityType.supplierDeclined:
        return loc.communityActSupplierDeclined(name);
      case CommunityActivityType.comment:
        return loc.communityActComment(name);
      case CommunityActivityType.statusChanged:
        return loc.communityActStatusChanged(
          item.postCrop,
          item.params['status'] ?? '',
        );
    }
  }

  Widget _empty(FreshLeafColorsX colors, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: colors.borderColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
