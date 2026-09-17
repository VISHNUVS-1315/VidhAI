import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/features/community/data/community_repository.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/screens/create_post_screen.dart';
import 'package:vidhai/features/community/screens/my_activity_screen.dart';
import 'package:vidhai/features/community/screens/post_detail_screen.dart';
import 'package:vidhai/features/community/services/community_controller.dart';
import 'package:vidhai/features/community/widgets/community_shared.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/market_price_service.dart';

/// District-wise, real-time Open Agriculture Community.
///
/// Three categories in a single collection: Experience / Harvest Soon / Demand.
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final CommunityController _controller = CommunityController.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.ensureLoaded();
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final district = _controller.selectedDistrict.trim().isEmpty
            ? null
            : _controller.selectedDistrict;
        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              loc.community,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onBackground,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              _districtPill(colors, loc, district),
              _activityBell(colors),
              const SizedBox(width: 6),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _segmentedTabs(colors, loc),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _PostListTab(
                key: ValueKey('exp_$district'),
                type: CommunityPostType.experience,
                district: district,
              ),
              _PostListTab(
                key: ValueKey('har_$district'),
                type: CommunityPostType.harvest,
                district: district,
              ),
              _PostListTab(
                key: ValueKey('dem_$district'),
                type: CommunityPostType.demand,
                district: district,
              ),
            ],
          ),
          floatingActionButton: _buildCreateFab(colors, loc),
        );
      },
    );
  }

  Widget _buildCreateFab(FreshLeafColorsX colors, AppLocalizations loc) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    if (narrow) {
      return FloatingActionButton(
        onPressed: () => _openCreateChooser(context),
        backgroundColor: colors.brand,
        foregroundColor: Colors.white,
        tooltip: loc.communityNewPost,
        child: const Icon(Icons.add),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => _openCreateChooser(context),
      backgroundColor: colors.brand,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Text(
          loc.communityNewPost,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _segmentedTabs(FreshLeafColorsX colors, AppLocalizations loc) {
    Widget tabLabel(String label) => Tab(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1),
            ),
          ),
        );

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderColor),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicator: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
            ),
          ],
        ),
        labelColor: colors.brandDeep,
        unselectedLabelColor: colors.onSurfaceMuted,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        tabs: [
          tabLabel(loc.communityTabExperience),
          tabLabel(loc.communityTabHarvestSoon),
          tabLabel(loc.communityTabDemand),
        ],
      ),
    );
  }

  Widget _districtPill(
      FreshLeafColorsX colors, AppLocalizations loc, String? district) {
    final label = district ?? loc.nearestCommunity;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: colors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDistrictPicker(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: colors.brandDeep),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down,
                    size: 16, color: colors.brandDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityBell(FreshLeafColorsX colors) {
    return StreamBuilder<int>(
      stream: CommunityRepository.instance.unreadActivityCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          tooltip: AppLocalizations.of(context).communityMyActivity,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyActivityScreen()),
          ),
          icon: count > 0
              ? Badge.count(
                  count: count,
                  backgroundColor: colors.error,
                  child: Icon(Icons.notifications_none,
                      color: colors.onBackground),
                )
              : Icon(Icons.notifications_none, color: colors.onBackground),
        );
      },
    );
  }

  Future<void> _openDistrictPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DistrictPickerSheet(),
    );
  }

  Future<void> _openCreateChooser(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final colors = FreshLeafColorsX(context);
    final type = await showModalBottomSheet<CommunityPostType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  loc.communityChooseType,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _typeOption(
                colors,
                type: CommunityPostType.experience,
                icon: Icons.lightbulb_outline,
                label: loc.communityTypeExperience,
                desc: loc.communityExperienceDesc,
              ),
              _typeOption(
                colors,
                type: CommunityPostType.harvest,
                icon: Icons.agriculture_outlined,
                label: loc.communityTypeHarvest,
                desc: loc.communityHarvestDesc,
              ),
              _typeOption(
                colors,
                type: CommunityPostType.demand,
                icon: Icons.shopping_basket_outlined,
                label: loc.communityTypeDemand,
                desc: loc.communityDemandDesc,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (type == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreatePostScreen(type: type)),
    );
  }

  Widget _typeOption(
    FreshLeafColorsX colors, {
    required CommunityPostType type,
    required IconData icon,
    required String label,
    required String desc,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: postTypeColor(context, type).withValues(alpha: 0.14),
        child: Icon(icon, color: postTypeColor(context, type), size: 20),
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.onBackground,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        desc,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12.5),
      ),
      onTap: () => Navigator.of(context).pop(type),
    );
  }
}

class _PostListTab extends StatefulWidget {
  const _PostListTab({
    super.key,
    required this.type,
    required this.district,
  });

  final CommunityPostType type;
  final String? district;

  @override
  State<_PostListTab> createState() => _PostListTabState();
}

class _PostListTabState extends State<_PostListTab> {
  final CommunityRepository _repo = CommunityRepository.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<CommunityPost> _posts = const [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = true;
  bool _error = false;
  bool _hasMore = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _PostListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.district != widget.district ||
        oldWidget.type != widget.type) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    switch (widget.type) {
      case CommunityPostType.experience:
        return _repo.experienceStream(district: widget.district);
      case CommunityPostType.harvest:
        return _repo.harvestStream(district: widget.district);
      case CommunityPostType.demand:
        return _repo.demandStream(district: widget.district);
    }
  }

  void _subscribe() {
    _sub?.cancel();
    setState(() {
      _loading = true;
      _error = false;
      _posts = const [];
      _cursor = null;
      _hasMore = false;
    });
    _sub = _stream().listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _posts = snap.docs.map(CommunityPost.fromFirestore).toList();
          _cursor = snap.docs.isNotEmpty ? snap.docs.last : null;
          _hasMore = snap.docs.length >= CommunityRepository.pageSize;
          _loading = false;
          _error = false;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = true;
        });
      },
    );
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final (more, last) = await _repo.loadMore(
        type: widget.type,
        district: widget.district,
        after: _cursor,
      );
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...more];
        _cursor = last ?? _cursor;
        _hasMore = last != null;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);

    if (_loading) {
      return ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 90),
        children: const [_SkeletonCard(), _SkeletonCard(), _SkeletonCard()],
      );
    }

    if (_error && _posts.isEmpty) {
      return _centeredNotice(
        colors,
        icon: Icons.wifi_off_outlined,
        message: loc.communityLoadFailed,
        actionLabel: loc.communityLoadMore,
        onAction: _subscribe,
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _subscribe(),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            _emptyState(context, colors, loc),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _subscribe(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _posts.length + (_hasMore ? 1 : 0) + (_error ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            if (index == _posts.length && _hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: _loadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(loc.communityLoadMore, maxLines: 1),
                        ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                loc.communityWaitingConnection,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
              ),
            );
          }
          final post = _posts[index];
          return CommunityPostCard(
            post: post,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(postId: post.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(
      BuildContext context, FreshLeafColorsX colors, AppLocalizations loc) {
    final String message;
    final IconData icon;
    switch (widget.type) {
      case CommunityPostType.experience:
        message = loc.communityExperienceEmpty;
        icon = Icons.lightbulb_outline;
      case CommunityPostType.harvest:
        message = loc.communityHarvestEmpty;
        icon = Icons.agriculture_outlined;
      case CommunityPostType.demand:
        message = loc.communityDemandEmpty;
        icon = Icons.shopping_basket_outlined;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 54, color: colors.borderColor),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc.communityFirstPost,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _centeredNotice(
    FreshLeafColorsX colors, {
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: colors.borderColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(actionLabel, maxLines: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _bar(colors, 40, 40, radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(colors, 120, 12),
                    const SizedBox(height: 6),
                    _bar(colors, 80, 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _bar(colors, double.infinity, 14),
          const SizedBox(height: 8),
          _bar(colors, double.infinity, 12),
          const SizedBox(height: 8),
          _bar(colors, 180, 12),
        ],
      ),
    );
  }

  Widget _bar(FreshLeafColorsX colors, double w, double h, {double radius = 6}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _DistrictPickerSheet extends StatefulWidget {
  const _DistrictPickerSheet();

  @override
  State<_DistrictPickerSheet> createState() => _DistrictPickerSheetState();
}

class _DistrictPickerSheetState extends State<_DistrictPickerSheet> {
  final CommunityController _controller = CommunityController.instance;
  final MarketPriceService _market = MarketPriceService.instance;

  List<MarketStateInfo> _states = const [];
  bool _loadingStates = true;
  bool _statesError = false;

  MarketStateInfo? _pickedState;
  List<String> _districts = const [];
  bool _loadingDistricts = false;
  bool _districtsError = false;

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  Future<void> _loadStates() async {
    setState(() {
      _loadingStates = true;
      _statesError = false;
    });
    final states = await _market.fetchStates();
    if (!mounted) return;
    setState(() {
      _states = states;
      _loadingStates = false;
      _statesError = states.isEmpty;
    });
  }

  Future<void> _pickState(MarketStateInfo state) async {
    setState(() {
      _pickedState = state;
      _loadingDistricts = true;
      _districtsError = false;
      _districts = const [];
    });
    final districts = await _market.fetchDistricts(state.name);
    if (!mounted) return;
    setState(() {
      _districts = districts;
      _loadingDistricts = false;
      _districtsError = districts.isEmpty;
    });
  }

  Future<void> _choose(String state, String district) async {
    await _controller.setDistrict(state, district);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                if (_pickedState != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _pickedState = null;
                      _districts = const [];
                    }),
                  ),
                Expanded(
                  child: Text(
                    _pickedState == null
                        ? loc.communityBrowseByDistrict
                        : loc.communitySelectDistrict,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: _content(colors, loc)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _content(FreshLeafColorsX colors, AppLocalizations loc) {
    if (_pickedState == null) return _statesList(colors, loc);
    return _districtsList(colors, loc);
  }

  Widget _statesList(FreshLeafColorsX colors, AppLocalizations loc) {
    if (_loadingStates) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_statesError) {
      return _notice(
        colors,
        loc.communityStatesLoadFailed,
        onRetry: _loadStates,
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        if (_controller.homeDistrict.isNotEmpty)
          ListTile(
            leading: Icon(Icons.my_location, color: colors.brand),
            title: Text(
              loc.communityMyDistrict,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _controller.homeDistrict,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12.5),
            ),
            onTap: () => _choose(
              _controller.homeState,
              _controller.homeDistrict,
            ),
          ),
        const Divider(height: 1),
        ..._states.map(
          (state) => ListTile(
            leading: Icon(Icons.map_outlined, color: colors.onSurfaceMuted),
            title: Text(
              state.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onBackground),
            ),
            trailing: state.districtCount > 0
                ? Text(
                    '${state.districtCount}',
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  )
                : null,
            onTap: () => _pickState(state),
          ),
        ),
      ],
    );
  }

  Widget _districtsList(FreshLeafColorsX colors, AppLocalizations loc) {
    if (_loadingDistricts) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_districtsError) {
      return _notice(
        colors,
        loc.communityDistrictsLoadFailed,
        onRetry: () => _pickState(_pickedState!),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: _districts
          .map(
            (district) => ListTile(
              leading: Icon(Icons.location_on_outlined,
                  color: colors.onSurfaceMuted),
              title: Text(
                district,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onBackground),
              ),
              onTap: () => _choose(_pickedState!.name, district),
            ),
          )
          .toList(),
    );
  }

  Widget _notice(FreshLeafColorsX colors, String message,
      {required VoidCallback onRetry}) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: colors.borderColor),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(loc.communityLoadMore, maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }
}
