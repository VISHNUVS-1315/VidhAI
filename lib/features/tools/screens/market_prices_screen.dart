import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/vidhai_theme.dart';
import '../../../core/widgets/vidhai_widgets.dart';
import '../../../data/models/market_price_models.dart';
import '../../../locale/locale.dart';
import '../../../services/market_price_service.dart';
import '../../assistant/assistant_button.dart';
import 'market_price_detail_screen.dart';

/// Full market-price dashboard.
///
/// Navigation is server-filtered (never loads all-India into memory beyond the
/// aggregate summary). Every price shown keeps its source, date, market and
/// original unit; ₹/kg is only highlighted when the backend reports a reliable
/// conversion factor, otherwise "Price unit unavailable" is shown.
///
/// When opened from the farm tools the optional `initialState` /
/// `initialDistrict` / `initialCommodity` (suggested from the farm's location
/// and active crop) are pre-selected.
class MarketPricesScreen extends StatefulWidget {
  final String? initialState;
  final String? initialDistrict;
  final String? initialCommodity;
  const MarketPricesScreen({
    super.key,
    this.initialState,
    this.initialDistrict,
    this.initialCommodity,
  });

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen> {
  final MarketPriceService _service = MarketPriceService.instance;

  List<String> _knownStates = [];
  String? _state;
  String? _district;
  String? _commodity;

  MarketPricePayload _payload = const MarketPricePayload(prices: []);
  List<String> _districts = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  String? _insight;
  bool _insightLoading = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _district = widget.initialDistrict;
    _commodity = widget.initialCommodity;
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final states = await _service.fetchStates();
    _knownStates = states.map((s) => s.name).where((n) => n.isNotEmpty).toList()
      ..sort();
    if (mounted) await _load();
  }

  bool get _isIndia => _state == null || _state!.isEmpty;

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _insight = null;
    });
    try {
      final st = _state;
      final district = _district;
      final commodity = _commodity;
      MarketPricePayload payload;
      if (commodity != null && commodity.isNotEmpty) {
        payload = await _service.fetchPrices(
          state: st,
          district: district,
          commodity: commodity,
          refresh: refresh,
        );
      } else if (district != null && district.isNotEmpty) {
        payload = await _service.fetchPrices(
          state: st,
          district: district,
          refresh: refresh,
        );
      } else {
        payload = await _service.fetchSummary(
          state: st,
          commodity: commodity,
        );
      }
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _isLoading = false;
      });
      await _loadDistricts();
      if (mounted) _maybeLoadInsight();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDistricts() async {
    if (_isIndia) {
      if (_districts.isNotEmpty) setState(() => _districts = []);
      return;
    }
    final fromData = _payload.prices
        .map((p) => p.district)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (fromData.isEmpty) {
      final fetched = await _service.fetchDistricts(_state!);
      if (mounted) setState(() => _districts = fetched);
    } else if (!listEquals(fromData, _districts)) {
      if (mounted) setState(() => _districts = fromData);
    }
  }

  Future<void> _maybeLoadInsight() async {
    if (_isIndia) return;
    await _loadInsight();
  }

  Future<void> _loadInsight() async {
    if (_insightLoading) return;
    final loc = AppLocalizations.of(context);
    setState(() => _insightLoading = true);
    final insight = await _service.fetchInsight(
      state: _state,
      district: _district,
      commodity: _commodity,
      language: loc.languageCode,
    );
    if (!mounted) return;
    setState(() {
      _insight = insight;
      _insightLoading = false;
    });
  }

  // ── navigation ────────────────────────────────────────────────────────────

  void _goIndia() {
    setState(() {
      _state = null;
      _district = null;
      _commodity = null;
      _searchQuery = '';
    });
    _load();
  }

  void _goState() {
    setState(() {
      _district = null;
      _commodity = null;
      _searchQuery = '';
    });
    _load();
  }

  void _selectState(String name) {
    setState(() {
      _state = name;
      _district = null;
      _commodity = null;
      _searchQuery = '';
    });
    _load();
  }

  void _selectDistrict(String name) {
    setState(() {
      _district = name;
      _commodity = null;
      _searchQuery = '';
    });
    _load();
  }

  void _selectCommodity(String name) {
    setState(() {
      _commodity = name;
      _searchQuery = '';
    });
    _load();
  }

  // ── filtering ─────────────────────────────────────────────────────────────

  bool _matchesRecord(MarketPriceRecord r) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.commodity.toLowerCase().contains(q) ||
        r.market.toLowerCase().contains(q) ||
        r.district.toLowerCase().contains(q) ||
        r.state.toLowerCase().contains(q) ||
        (r.variety?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(directionalIcon(context, Icons.arrow_back_ios_rounded),
              color: colors.onBackground, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.marketPrices,
          style: TextStyle(
              color: colors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: colors.onBackground, size: 22),
            onPressed: () => _load(refresh: true),
          ),
          const VidhAIAssistantButton(
              screen: 'market_prices', size: 36, iconSize: 18),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              style: TextStyle(color: colors.onBackground, fontSize: 15),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: loc.marketSearchHint,
                hintStyle: TextStyle(color: colors.onSurfaceMuted),
                prefixIcon: Icon(Icons.search_rounded,
                    color: colors.onSurfaceMuted, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: colors.onSurfaceMuted, size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.brandDeep, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_payload.stale || _payload.fromCache)
            _OfflineBanner(text: loc.marketOfflineBanner),
          const SizedBox(height: 4),
          _ModeTrail(
            state: _state,
            district: _district,
            commodity: _commodity,
            onIndia: _goIndia,
            onState: _goState,
          ),
          if (!_isIndia) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: _InsightCard(
                insight: _insight,
                loading: _insightLoading,
                onRefresh: _loadInsight,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (widget.initialCommodity != null && _commodity != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grass_rounded,
                        color: colors.brandDeep, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${loc.marketFarmContext}: ${_commodity!}',
                        style: TextStyle(
                            color: colors.brandDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Expanded(child: _buildBody(loc, colors)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations loc, VidhAIColorsX colors) {
    if (_isLoading) {
      return Center(
        child:
            CircularProgressIndicator(color: colors.brandDeep, strokeWidth: 2),
      );
    }
    if (_error != null && _payload.prices.isEmpty) {
      return _ErrorView(error: _error!, onRetry: _load);
    }
    if (_payload.prices.isEmpty) {
      return _EmptyView();
    }

    final records = _payload.prices.where(_matchesRecord).toList();

    if (_isIndia && _commodity == null) {
      return _IndiaOverview(
        payload: _payload,
        knownStates: _knownStates,
        searchQuery: _searchQuery,
        onSelectState: _selectState,
        onSelectCommodity: _selectCommodity,
      );
    }
    if (_commodity != null) {
      return _CommodityView(
        records: records,
        payload: _payload,
        state: _state,
        district: _district,
        onSelectState: _selectState,
        onSelectDistrict: _selectDistrict,
        onOpenDetail: _openDetail,
      );
    }
    if (_district != null && _district!.isNotEmpty) {
      return _DistrictView(
        records: records,
        district: _district!,
        state: _state!,
        payload: _payload,
        onSelectCommodity: _selectCommodity,
        onOpenDetail: _openDetail,
      );
    }
    return _StateDashboard(
      records: records,
      payload: _payload,
      state: _state!,
      districts: _districts,
      selectedDistrict: _district,
      onSelectDistrict: _selectDistrict,
      onSelectCommodity: _selectCommodity,
      onOpenDetail: _openDetail,
    );
  }

  void _openDetail(MarketPriceRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketPriceDetailScreen(record: record),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final String text;
  const _OfflineBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: colors.onSurfaceMuted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String? insight;
  final bool loading;
  final VoidCallback onRefresh;
  const _InsightCard({
    required this.insight,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.brandDeep.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: colors.brandDeep, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(loc.marketInsightHeading,
                    style: TextStyle(
                        color: colors.brandDeep,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: loading ? null : onRefresh,
                child: Icon(
                  loading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                  color: colors.brandDeep,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            LinearProgressIndicator(
                color: colors.brandDeep,
                backgroundColor: colors.brandDeep.withValues(alpha: 0.1),
                minHeight: 2)
          else if (insight != null && insight!.isNotEmpty)
            Text(insight!,
                style: TextStyle(
                    color: colors.onBackground, fontSize: 12, height: 1.4))
          else
            Text(loc.marketInsightEmpty,
                style: TextStyle(
                    color: colors.onSurfaceMuted, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

class _ModeTrail extends StatelessWidget {
  final String? state;
  final String? district;
  final String? commodity;
  final VoidCallback onIndia;
  final VoidCallback onState;
  const _ModeTrail({
    required this.state,
    required this.district,
    required this.commodity,
    required this.onIndia,
    required this.onState,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final crumbs = <({String label, VoidCallback onTap, bool last})>[];
    crumbs
        .add((label: loc.marketAllIndia, onTap: onIndia, last: state == null));
    if (state != null) {
      crumbs.add((
        label: state!,
        onTap: onState,
        last: district == null && commodity == null,
      ));
    }
    if (district != null && commodity == null) {
      crumbs.add((
        label: district!,
        onTap: () {},
        last: true,
      ));
    }
    if (commodity != null) {
      crumbs.add((
        label: commodity!,
        onTap: () {},
        last: true,
      ));
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: crumbs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final crumb = crumbs[index];
          return GestureDetector(
            onTap: crumb.last ? null : crumb.onTap,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: crumb.last
                      ? colors.brandDeep.withValues(alpha: 0.12)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: crumb.last ? colors.brandDeep : colors.borderColor,
                  ),
                ),
                child: Text(
                  crumb.label,
                  style: TextStyle(
                    color:
                        crumb.last ? colors.brandDeep : colors.onSurfaceMuted,
                    fontSize: 12,
                    fontWeight:
                        crumb.last ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.onSurfaceMuted, size: 48),
          const SizedBox(height: 12),
          Text(loc.failedToLoadPrices,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14)),
          const SizedBox(height: 4),
          Text(error,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(loc.retry),
            style: TextButton.styleFrom(foregroundColor: colors.brandDeep),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              color: colors.onSurfaceMuted, size: 48),
          const SizedBox(height: 12),
          Text(loc.marketNoPrices,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── India overview ────────────────────────────────────────────────────────────

class _IndiaOverview extends StatelessWidget {
  final MarketPricePayload payload;
  final List<String> knownStates;
  final String searchQuery;
  final ValueChanged<String> onSelectState;
  final ValueChanged<String> onSelectCommodity;
  const _IndiaOverview({
    required this.payload,
    required this.knownStates,
    required this.searchQuery,
    required this.onSelectState,
    required this.onSelectCommodity,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final statesWithData = payload.statesWithData.isNotEmpty
        ? payload.statesWithData
        : knownStates;
    final states = statesWithData.where((s) {
      final q = searchQuery.trim().toLowerCase();
      return q.isEmpty || s.toLowerCase().contains(q);
    }).toList();
    final commodities = payload.commodities.where((c) {
      final q = searchQuery.trim().toLowerCase();
      return q.isEmpty || c.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {},
      color: colors.brandDeep,
      backgroundColor: colors.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Text(loc.marketOverview,
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(loc.marketPricesSubtitle,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                label: loc.marketStatesCovered,
                value:
                    '${payload.statesWithData.isNotEmpty ? payload.statesWithData.length : knownStates.length}',
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: loc.marketDataPoints,
                value: '${payload.totalPriceRecords}',
              ),
            ],
          ),
          Row(
            children: [
              _StatCard(
                label: loc.marketLatestUpdate,
                value: payload.latestDate?.isNotEmpty == true
                    ? payload.latestDate!
                    : loc.unknown,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: loc.marketCommoditiesAvailable,
                value: '${payload.commodities.length}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionLabel(title: loc.marketStates, count: states.length),
          const SizedBox(height: 8),
          _WrapGrid(
            items: states,
            onTap: onSelectState,
            accent: (s) => colors.brandDeep,
          ),
          const SizedBox(height: 18),
          _SectionLabel(
              title: loc.marketCommodity,
              count: commodities.length,
              hint: loc.marketTapCommodity),
          const SizedBox(height: 8),
          _WrapGrid(
            items: commodities,
            onTap: onSelectCommodity,
            accent: (c) => colors.onSurfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  final String? hint;
  const _SectionLabel({required this.title, required this.count, this.hint});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text('$count',
                style: TextStyle(color: colors.brandDeep, fontSize: 12)),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
        ],
      ],
    );
  }
}

class _WrapGrid extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onTap;
  final Color Function(String) accent;
  const _WrapGrid({
    required this.items,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final col = accent(item);
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: col == colors.brandDeep
                      ? colors.brandDeep.withValues(alpha: 0.5)
                      : colors.borderColor),
            ),
            child: Text(
              item,
              style: TextStyle(
                  color: col == colors.brandDeep
                      ? colors.brandDeep
                      : colors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── State dashboard ───────────────────────────────────────────────────────────

class _StateDashboard extends StatelessWidget {
  final List<MarketPriceRecord> records;
  final MarketPricePayload payload;
  final String state;
  final List<String> districts;
  final String? selectedDistrict;
  final ValueChanged<String> onSelectDistrict;
  final ValueChanged<String> onSelectCommodity;
  final ValueChanged<MarketPriceRecord> onOpenDetail;
  const _StateDashboard({
    required this.records,
    required this.payload,
    required this.state,
    required this.districts,
    required this.selectedDistrict,
    required this.onSelectDistrict,
    required this.onSelectCommodity,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final groups = _groupByCommodity(records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Row(
            children: [
              Icon(Icons.map_rounded, color: colors.brandDeep, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${loc.marketStateDashboard}: $state',
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Text('${records.length} ${loc.marketDataPoints}',
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {},
            color: colors.brandDeep,
            backgroundColor: colors.surface,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                if (districts.isNotEmpty) ...[
                  _SectionLabel(
                      title: loc.marketDistricts, count: districts.length),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: districts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final d = districts[index];
                        final isSel = selectedDistrict == d;
                        return GestureDetector(
                          onTap: () => onSelectDistrict(d),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? colors.brandDeep.withValues(alpha: 0.2)
                                    : colors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: isSel
                                        ? colors.brandDeep
                                        : colors.borderColor),
                              ),
                              child: Text(d,
                                  style: TextStyle(
                                      color: isSel
                                          ? colors.brandDeep
                                          : colors.onSurfaceMuted,
                                      fontSize: 12,
                                      fontWeight: isSel
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _SectionLabel(
                    title: loc.marketLatestPrices, count: groups.length),
                const SizedBox(height: 8),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: _EmptyView(),
                  )
                else
                  ...groups.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CommodityGroupCard(
                        commodity: g.commodity,
                        variety: g.variety,
                        countMarkets: g.markets,
                        minKg: g.minKg,
                        modalKg: g.modalKg,
                        maxKg: g.maxKg,
                        display: g.display,
                        originalUnit: g.originalUnit,
                        onTap: () => onSelectCommodity(g.commodity),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── grouping helpers (pure, reused by several views) ─────────────────────────

class _CommodityGroup {
  final String commodity;
  final String? variety;
  final int markets;
  final double? minKg;
  final double? modalKg;
  final double? maxKg;
  final double? display;
  final String? originalUnit;
  const _CommodityGroup({
    required this.commodity,
    this.variety,
    required this.markets,
    this.minKg,
    this.modalKg,
    this.maxKg,
    this.display,
    this.originalUnit,
  });
}

List<_CommodityGroup> _groupByCommodity(List<MarketPriceRecord> records) {
  final byKey = <String, List<MarketPriceRecord>>{};
  for (final r in records) {
    byKey.putIfAbsent(r.commodity, () => []).add(r);
  }
  final keys = byKey.keys.toList()..sort();
  return keys.map((key) {
    final list = byKey[key]!;
    final markets = list.map((r) => r.market).toSet().length;
    final kgVals = list
        .where((r) => r.hasReliablePerKg && r.normalizedPricePerKg != null)
        .map((r) => r.normalizedPricePerKg!)
        .toList();
    double? minKg, maxKg, modalKg;
    if (kgVals.isNotEmpty) {
      kgVals.sort();
      minKg = kgVals.first;
      maxKg = kgVals.last;
      modalKg = kgVals[kgVals.length ~/ 2];
    }
    final first = list.first;
    return _CommodityGroup(
      commodity: key,
      variety: list
          .map((r) => r.variety)
          .where((v) => v != null && v.isNotEmpty)
          .toSet()
          .firstOrNull,
      markets: markets,
      minKg: minKg,
      modalKg: modalKg,
      maxKg: maxKg,
      display: first.modalPrice,
      originalUnit: first.unitLabel,
    );
  }).toList();
}

class _CommodityGroupCard extends StatelessWidget {
  final String commodity;
  final String? variety;
  final int countMarkets;
  final double? minKg;
  final double? modalKg;
  final double? maxKg;
  final double? display;
  final String? originalUnit;
  final VoidCallback onTap;
  const _CommodityGroupCard({
    required this.commodity,
    required this.variety,
    required this.countMarkets,
    required this.minKg,
    required this.modalKg,
    required this.maxKg,
    required this.display,
    required this.originalUnit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final subTitle = variety == null
        ? '$countMarkets ${loc.marketMarket}'
        : '$variety  •  $countMarkets ${loc.marketMarket}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(commodity,
                      style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.onSurfaceMuted, fontSize: 11)),
                  if (minKg != null && maxKg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${loc.marketMinPrice} ${MarketFormat.inr(minKg)}  •  '
                      '${loc.marketMaxPrice} ${MarketFormat.inr(maxKg)}  ${loc.marketPricePerKg}',
                      style:
                          TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  modalKg != null
                      ? MarketFormat.inr(modalKg)
                      : (display != null ? MarketFormat.inr(display) : '—'),
                  style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                Text(loc.marketPricePerKg,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 10)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.marketViewDetails,
                        style:
                            TextStyle(color: colors.brandDeep, fontSize: 11)),
                    Icon(Icons.chevron_right_rounded,
                        color: colors.brandDeep, size: 14),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── District view ─────────────────────────────────────────────────────────────

class _DistrictView extends StatelessWidget {
  final List<MarketPriceRecord> records;
  final String district;
  final String state;
  final MarketPricePayload payload;
  final ValueChanged<String> onSelectCommodity;
  final ValueChanged<MarketPriceRecord> onOpenDetail;
  const _DistrictView({
    required this.records,
    required this.district,
    required this.state,
    required this.payload,
    required this.onSelectCommodity,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final groups = _groupByCommodity(records);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      itemCount: groups.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      color: colors.brandDeep, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${loc.marketDistrictPrices}: $district',
                      style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('${records.length}',
                      style: TextStyle(
                          color: colors.onSurfaceMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        }
        final g = groups[index - 1];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${g.commodity} · ${loc.marketMarket}',
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            ...records.where((r) => r.commodity == g.commodity).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _PriceRow(record: r, onTap: () => onOpenDetail(r)),
                  ),
                ),
          ],
        );
      },
    );
  }
}

// ── Commodity view (all-India / in-state / in-district) ─────────────────────

class _CommodityView extends StatelessWidget {
  final List<MarketPriceRecord> records;
  final MarketPricePayload payload;
  final String? state;
  final String? district;
  final ValueChanged<String> onSelectState;
  final ValueChanged<String> onSelectDistrict;
  final ValueChanged<MarketPriceRecord> onOpenDetail;
  const _CommodityView({
    required this.records,
    required this.payload,
    required this.state,
    required this.district,
    required this.onSelectState,
    required this.onSelectDistrict,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final header = district != null && district!.isNotEmpty
        ? '$district · ${state ?? ''}'
        : state != null && state!.isNotEmpty
            ? state!
            : loc.marketAllIndiaDetail;

    final byRegion = <String, List<MarketPriceRecord>>{};
    for (final r in records) {
      final key =
          district != null && district!.isNotEmpty ? r.market : r.district;
      byRegion.putIfAbsent(key, () => []).add(r);
    }
    final regionKeys = byRegion.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      children: [
        Row(
          children: [
            Icon(Icons.insights_rounded, color: colors.brandDeep, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$_commodityTitle · $header',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Text('${records.length}',
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        ...regionKeys.map(
          (region) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: colors.brandDeep, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(region,
                          style: TextStyle(
                              color: colors.onBackground,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...byRegion[region]!.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _PriceRow(
                        record: r,
                        showRegion: true,
                        onTap: () => onOpenDetail(r)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _commodityTitle => records.isEmpty ? '' : records.first.commodity;
}

// ── Price row ────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final MarketPriceRecord record;
  final bool showRegion;
  final VoidCallback onTap;
  const _PriceRow({
    required this.record,
    this.showRegion = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final trend = record.trend;
    final trendColor = trend == 'up'
        ? colors.success
        : trend == 'down'
            ? colors.danger
            : colors.onSurfaceMuted;
    final trendIcon = trend == 'up'
        ? Icons.arrow_upward_rounded
        : trend == 'down'
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    final kgLabel = record.hasReliablePerKg
        ? MarketFormat.inr(record.normalizedPricePerKg)
        : loc.marketPriceUnitUnavailable;

    final subtitle = showRegion
        ? '${record.market}  •  ${record.district}  •  ${record.state}'
        : record.market;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(trendIcon, color: trendColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.commodity,
                        style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      if (record.variety != null && record.variety!.isNotEmpty)
                        Text(record.variety!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: colors.onSurfaceMuted, fontSize: 11)),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.onSurfaceMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(kgLabel,
                        style: TextStyle(
                            color: record.hasReliablePerKg
                                ? colors.brandDeep
                                : colors.onSurfaceMuted,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text(loc.marketPricePerKg,
                        style: TextStyle(
                            color: colors.onSurfaceMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _miniChip(
                    colors,
                    loc.marketMinPrice,
                    record.minPrice != null
                        ? '₹${_compact(record.minPrice!)}'
                        : '—'),
                const SizedBox(width: 8),
                _miniChip(
                    colors,
                    loc.marketModalPrice,
                    record.modalPrice != null
                        ? '₹${_compact(record.modalPrice!)}'
                        : '—'),
                const SizedBox(width: 8),
                _miniChip(
                    colors,
                    loc.marketMaxPrice,
                    record.maxPrice != null
                        ? '₹${_compact(record.maxPrice!)}'
                        : '—'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.scale_rounded,
                    color: colors.onSurfaceMuted, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${loc.marketOriginalUnit}: ${record.unitLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
                  ),
                ),
                SizedBox(
                  width: 16,
                  child: Icon(Icons.chevron_right_rounded,
                      color: colors.onSurfaceMuted, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(VidhAIColorsX colors, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  static String _compact(double price) {
    final p = price.round();
    if (p >= 1000) {
      final thousands = p ~/ 1000;
      final remainder = p % 1000;
      if (remainder == 0) return '${thousands}k';
      return '$thousands.${(remainder / 100).floor()}k';
    }
    return '$p';
  }
}
