import 'package:flutter/material.dart';

import '../../../core/theme/vidhai_theme.dart';
import '../../../core/widgets/vidhai_widgets.dart';
import '../../../data/models/market_price_models.dart';
import '../../../locale/locale.dart';
import '../../../services/data_service.dart';
import '../../../services/market_price_service.dart';
import '../../assistant/assistant_button.dart';
import 'market_price_detail_screen.dart';

/// Organized market-price browser.
///
/// Keeps administrative navigation separate from price data:
/// State -> District -> Category -> Commodity -> Market -> Details.
/// Districts always come from the backend's administrative master list instead
/// of being inferred from the current 500-row price response.
class MarketPricesScreen extends StatefulWidget {
  final String? initialState;
  final String? initialDistrict;
  final String? initialCommodity;
  final String? titleOverride;

  const MarketPricesScreen({
    super.key,
    this.initialState,
    this.initialDistrict,
    this.initialCommodity,
    this.titleOverride,
  });

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen> {
  final MarketPriceService _service = MarketPriceService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<MarketStateInfo> _stateInfos = const [];
  List<String> _districts = const [];
  List<String> _catalogCommodities = const [];

  String? _state;
  String? _district;
  String? _commodity;
  String _selectedCategory = _MarketCategory.all;
  String _searchQuery = '';

  MarketPricePayload _payload = const MarketPricePayload(prices: []);
  List<PriceHistoryPoint> _history = const [];

  bool _isLoading = true;
  bool _historyLoading = false;
  bool _insightLoading = false;
  String? _error;
  String? _insight;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _state = _clean(widget.initialState);
    _district = _clean(widget.initialDistrict);
    _commodity = _clean(widget.initialCommodity);
    _prepare();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String? _clean(String? value) {
    final cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _prepare() async {
    await _resolveSavedLocation();

    final states = await _service.fetchStates();
    if (!mounted) return;

    final sorted = [...states]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final canonicalState = _canonicalValue(
      _state,
      sorted.map((item) => item.name).toList(),
    );

    setState(() {
      _stateInfos = sorted;
      _state = canonicalState ?? _state;
    });

    await _reloadCatalogsAndPrices();
  }

  /// Farm location remains the first default. Consumer accounts fall back to
  /// the saved personal-profile location, matching the previous market screen.
  Future<void> _resolveSavedLocation() async {
    if (_state != null) return;
    try {
      final farms = await DataService().loadFarms();
      if (farms.isNotEmpty) {
        final location = farms.first.farmLocation;
        final state = _clean(location?.state);
        if (state != null) {
          _state = state;
          _district = _clean(location?.district);
          return;
        }
      }

      final profile = await DataService().loadProfile();
      final state = _clean(profile?.address?.state);
      if (state != null) {
        _state = state;
        _district = _clean(profile?.address?.district);
      }
    } catch (_) {
      // Saved location is a convenience only. Market prices must still open.
    }
  }

  String? _canonicalValue(String? value, List<String> options) {
    final query = _clean(value)?.toLowerCase();
    if (query == null) return null;
    for (final option in options) {
      if (option.toLowerCase() == query) return option;
    }
    return null;
  }

  Future<void> _reloadCatalogsAndPrices({bool refresh = false}) async {
    final activeState = _state;

    List<String> districts = const [];
    if (activeState != null) {
      districts = await _service.fetchDistricts(activeState);
    }
    final commodities = await _service.fetchCommodities(state: activeState);
    if (!mounted || activeState != _state) return;

    final districtList = {...districts}.where((item) => item.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final canonicalDistrict = _canonicalValue(_district, districtList);
    final commodityList = {...commodities}
        .where((item) => item.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    setState(() {
      _districts = districtList;
      if (_district != null) _district = canonicalDistrict ?? _district;
      _catalogCommodities = commodityList;
    });

    await _loadPrices(refresh: refresh);
  }

  Future<void> _loadPrices({bool refresh = false}) async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final payload = await _service.fetchPrices(
        state: _state,
        district: _district,
        commodity: _commodity,
        refresh: refresh,
      );
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _payload = payload;
        _isLoading = false;
      });

      if (_commodity != null) {
        await Future.wait<void>([
          _loadInsight(),
          _loadHistory(),
        ]);
      } else if (mounted) {
        setState(() {
          _insight = null;
          _history = const [];
          _historyLoading = false;
          _insightLoading = false;
        });
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInsight() async {
    final commodity = _commodity;
    if (commodity == null) return;

    setState(() => _insightLoading = true);
    final language = AppLocalizations.of(context).languageCode;
    final result = await _service.fetchInsight(
      state: _state,
      district: _district,
      commodity: commodity,
      language: language,
    );
    if (!mounted || commodity != _commodity) return;
    setState(() {
      _insight = _clean(result);
      _insightLoading = false;
    });
  }

  Future<void> _loadHistory() async {
    final state = _state;
    final commodity = _commodity;
    if (state == null || commodity == null) {
      if (mounted) setState(() => _history = const []);
      return;
    }

    setState(() => _historyLoading = true);
    final points = await _service.fetchHistory(
      state: state,
      commodity: commodity,
      days: 7,
    );
    if (!mounted || state != _state || commodity != _commodity) return;
    setState(() {
      _history = points;
      _historyLoading = false;
    });
  }

  Future<void> _refresh() async {
    await _reloadCatalogsAndPrices(refresh: true);
  }

  Future<void> _pickState() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet(
        title: _text('state', 'Select state'),
        allLabel: _text('market_all_india', 'All India'),
        items: _stateInfos.map((item) => item.name).toList(),
        selected: _state,
      ),
    );
    if (selected == null) return;

    setState(() {
      _state = selected == _allToken ? null : selected;
      _district = null;
      _commodity = null;
      _selectedCategory = _MarketCategory.all;
      _clearSearch();
      _insight = null;
      _history = const [];
    });
    await _reloadCatalogsAndPrices();
  }

  Future<void> _pickDistrict() async {
    if (_state == null) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet(
        title: _text('district', 'Select district'),
        allLabel: _text('market_all_districts', 'All Districts'),
        items: _districts,
        selected: _district,
      ),
    );
    if (selected == null) return;

    setState(() {
      _district = selected == _allToken ? null : selected;
      _commodity = null;
      _clearSearch();
      _insight = null;
      _history = const [];
    });
    await _loadPrices();
  }

  Future<void> _pickCommodity() async {
    final items = _catalogForSelectedCategory;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet(
        title: _text('commodity', 'Select commodity'),
        items: items,
        selected: _commodity,
      ),
    );
    if (selected == null || selected == _allToken) return;
    await _selectCommodity(selected);
  }

  Future<void> _selectCommodity(String commodity) async {
    setState(() {
      _commodity = commodity;
      _selectedCategory = _categoryForCommodity(commodity);
      _clearSearch();
      _insight = null;
      _history = const [];
    });
    await _loadPrices();
  }

  Future<void> _backToCommodities() async {
    setState(() {
      _commodity = null;
      _insight = null;
      _history = const [];
      _clearSearch();
    });
    await _loadPrices();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
  }

  String _text(String key, String fallback) {
    final loc = AppLocalizations.of(context);
    return AppLocalizations.rawLookup(loc.languageCode, key) ?? fallback;
  }

  List<String> get _catalogForSelectedCategory {
    final query = _searchQuery.trim().toLowerCase();
    return _catalogCommodities.where((commodity) {
      if (_selectedCategory != _MarketCategory.all &&
          _categoryForCommodity(commodity) != _selectedCategory) {
        return false;
      }
      return query.isEmpty || commodity.toLowerCase().contains(query);
    }).toList();
  }

  List<_CommoditySummary> get _commoditySummaries {
    final grouped = <String, List<MarketPriceRecord>>{};
    for (final record in _payload.prices) {
      final name = record.commodity.trim();
      if (name.isEmpty) continue;
      grouped.putIfAbsent(name, () => []).add(record);
    }

    final query = _searchQuery.trim().toLowerCase();
    final summaries = grouped.entries.map((entry) {
      return _CommoditySummary.fromRecords(entry.key, entry.value);
    }).where((summary) {
      if (_selectedCategory != _MarketCategory.all &&
          _categoryForCommodity(summary.name) != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return summary.name.toLowerCase().contains(query) ||
          summary.varietyLabel.toLowerCase().contains(query);
    }).toList();

    summaries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return summaries;
  }

  List<MarketPriceRecord> get _marketRecords {
    final query = _searchQuery.trim().toLowerCase();
    final seen = <String>{};
    final records = <MarketPriceRecord>[];

    for (final record in _payload.prices) {
      final key = [
        record.state,
        record.district,
        record.market,
        record.commodity,
        record.variety ?? '',
        record.date,
        record.minPrice,
        record.modalPrice,
        record.maxPrice,
      ].join('|').toLowerCase();
      if (!seen.add(key)) continue;

      if (query.isNotEmpty) {
        final matches = record.market.toLowerCase().contains(query) ||
            record.district.toLowerCase().contains(query) ||
            (record.variety?.toLowerCase().contains(query) ?? false);
        if (!matches) continue;
      }
      records.add(record);
    }

    records.sort((a, b) {
      final districtCompare =
          a.district.toLowerCase().compareTo(b.district.toLowerCase());
      if (districtCompare != 0) return districtCompare;
      final marketCompare = a.market.toLowerCase().compareTo(b.market.toLowerCase());
      if (marketCompare != 0) return marketCompare;
      return _compareDatesDesc(a.date, b.date);
    });
    return records;
  }

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            directionalIcon(context, Icons.arrow_back_ios_rounded),
            color: colors.onBackground,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.titleOverride ?? loc.marketPrices,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refresh,
            icon: Icon(Icons.refresh_rounded, color: colors.onBackground),
          ),
          const VidhAIAssistantButton(
            screen: 'market_prices',
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: colors.brandDeep,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _buildSearch(colors, loc),
            const SizedBox(height: 12),
            _buildLocationFilters(colors),
            const SizedBox(height: 12),
            _buildDataStatus(colors),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _InlineError(message: _error!, onRetry: _refresh),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                minHeight: 2,
                color: colors.brandDeep,
                backgroundColor: colors.brandDeep.withValues(alpha: 0.1),
              ),
            ],
            const SizedBox(height: 14),
            if (_commodity == null)
              ..._buildCommodityBrowser(colors, loc)
            else
              ..._buildCommodityMarkets(colors, loc),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(FreshLeafColorsX colors, AppLocalizations loc) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: colors.onBackground, fontSize: 15),
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: _commodity == null
            ? loc.marketSearchHint
            : _text('market_search_market', 'Search market or variety...'),
        hintStyle: TextStyle(color: colors.onSurfaceMuted),
        prefixIcon: Icon(Icons.search_rounded, color: colors.onSurfaceMuted),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(_clearSearch),
                icon: Icon(Icons.close_rounded, color: colors.onSurfaceMuted),
              ),
        filled: true,
        fillColor: colors.surface,
        border: _inputBorder(colors.borderColor),
        enabledBorder: _inputBorder(colors.borderColor),
        focusedBorder: _inputBorder(colors.brandDeep, width: 1.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _buildLocationFilters(FreshLeafColorsX colors) {
    return Row(
      children: [
        Expanded(
          child: _FilterButton(
            icon: Icons.map_outlined,
            label: _text('state', 'State'),
            value: _state ?? _text('market_all_india', 'All India'),
            onTap: _pickState,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FilterButton(
            icon: Icons.location_city_outlined,
            label: _text('district', 'District'),
            value: _state == null
                ? _text('market_select_state_first', 'Select state first')
                : (_district ?? _text('market_all_districts', 'All Districts')),
            onTap: _state == null ? null : _pickDistrict,
          ),
        ),
      ],
    );
  }

  Widget _buildDataStatus(FreshLeafColorsX colors) {
    final date = _payload.latestDate;
    final isCached = _payload.stale || _payload.fromCache;
    final text = date == null || date.trim().isEmpty
        ? (isCached
            ? _text('market_offline_banner', 'Showing last available market prices')
            : _text('market_latest_available', 'Latest available market data'))
        : '${isCached ? _text('market_offline_banner', 'Showing last available market prices') : _text('market_latest_available', 'Latest available market data')} • $date';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isCached ? Icons.wifi_off_rounded : Icons.schedule_rounded,
            size: 17,
            color: colors.onSurfaceMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
            ),
          ),
          if (_payload.totalPriceRecords > 0)
            Text(
              '${_payload.totalPriceRecords}',
              style: TextStyle(
                color: colors.brandDeep,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCommodityBrowser(
    FreshLeafColorsX colors,
    AppLocalizations loc,
  ) {
    final summaries = _commoditySummaries;
    final catalogMatches = _catalogForSelectedCategory;

    return [
      _SectionHeader(
        icon: Icons.category_outlined,
        title: _text('category', 'Categories'),
      ),
      const SizedBox(height: 10),
      _CategorySelector(
        selected: _selectedCategory,
        onChanged: (value) => setState(() => _selectedCategory = value),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: catalogMatches.isEmpty ? null : _pickCommodity,
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          label: Text(
            '${_text('market_browse_commodities', 'Browse commodities')} (${catalogMatches.length})',
          ),
          style: TextButton.styleFrom(foregroundColor: colors.brandDeep),
        ),
      ),
      const SizedBox(height: 8),
      _SectionHeader(
        icon: Icons.trending_up_rounded,
        title: _text('market_latest_prices', 'Latest market prices'),
        trailing: '${summaries.length}',
      ),
      const SizedBox(height: 10),
      if (!_isLoading && summaries.isEmpty)
        _EmptyMarketCard(
          title: loc.marketNoPrices,
          subtitle: catalogMatches.isEmpty
              ? _text(
                  'market_try_another_filter',
                  'Try another state, district or category.',
                )
              : _text(
                  'market_select_commodity_hint',
                  'Choose a commodity to check its latest available markets.',
                ),
          actionLabel: catalogMatches.isEmpty
              ? null
              : _text('market_browse_commodities', 'Browse commodities'),
          onAction: catalogMatches.isEmpty ? null : _pickCommodity,
        )
      else
        ...summaries.map(
          (summary) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CommodityCard(
              summary: summary,
              onTap: () => _selectCommodity(summary.name),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildCommodityMarkets(
    FreshLeafColorsX colors,
    AppLocalizations loc,
  ) {
    final records = _marketRecords;
    final byDistrict = <String, List<MarketPriceRecord>>{};
    for (final record in records) {
      final name = record.district.trim().isEmpty
          ? _text('district', 'District')
          : record.district.trim();
      byDistrict.putIfAbsent(name, () => []).add(record);
    }

    final widgets = <Widget>[
      InkWell(
        onTap: _backToCommodities,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                directionalIcon(context, Icons.arrow_back_rounded),
                color: colors.brandDeep,
                size: 19,
              ),
              const SizedBox(width: 6),
              Text(
                _text('market_back_to_commodities', 'Back to commodities'),
                style: TextStyle(
                  color: colors.brandDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      _CommodityHeaderCard(
        commodity: _commodity!,
        state: _state,
        district: _district,
        records: records,
      ),
      const SizedBox(height: 12),
      _InsightCard(
        commodity: _commodity!,
        state: _state,
        district: _district,
        insight: _insight,
        loading: _insightLoading,
        latestDate: _payload.latestDate,
        onRefresh: _loadInsight,
      ),
      if (_state != null) ...[
        const SizedBox(height: 12),
        _HistoryCard(points: _history, loading: _historyLoading),
      ],
      const SizedBox(height: 16),
      _SectionHeader(
        icon: Icons.storefront_outlined,
        title: _text('market_markets', 'Markets'),
        trailing: '${records.length}',
      ),
      const SizedBox(height: 10),
    ];

    if (!_isLoading && records.isEmpty) {
      widgets.add(
        _EmptyMarketCard(
          title: loc.marketNoPrices,
          subtitle: _text(
            'market_no_matching_records',
            'No matching market records for the selected filters.',
          ),
        ),
      );
      return widgets;
    }

    for (final entry in byDistrict.entries) {
      if (_district == null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: colors.brandDeep, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${entry.value.length}',
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }

      for (final record in entry.value) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MarketRecordCard(
              record: record,
              onTap: () => _openDetail(record),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  void _openDetail(MarketPriceRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketPriceDetailScreen(record: record),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.borderColor),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: enabled ? colors.brandDeep : colors.onSurfaceMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? colors.onBackground : colors.onSurfaceMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.expand_more_rounded, color: colors.onSurfaceMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const _SectionHeader({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    return Row(
      children: [
        Icon(icon, color: colors.brandDeep, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: colors.brandDeep,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _MarketCategory.items.map((category) {
        final active = selected == category.id;
        return ChoiceChip(
          selected: active,
          onSelected: (_) => onChanged(category.id),
          avatar: Icon(
            category.icon,
            size: 16,
            color: active ? colors.brandDeep : colors.onSurfaceMuted,
          ),
          label: Text(category.label),
          labelStyle: TextStyle(
            color: active ? colors.brandDeep : colors.onSurfaceMuted,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
          selectedColor: colors.brandDeep.withValues(alpha: 0.12),
          backgroundColor: colors.surface,
          side: BorderSide(color: active ? colors.brandDeep : colors.borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}

class _CommodityCard extends StatelessWidget {
  final _CommoditySummary summary;
  final VoidCallback onTap;

  const _CommodityCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final hasKg = summary.modalPerKg != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.name,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.varietyLabel} • ${summary.marketCount} market${summary.marketCount == 1 ? '' : 's'}',
                      style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 9),
                    if (hasKg)
                      Text(
                        'Min ${_money(summary.minPerKg)}  •  Max ${_money(summary.maxPerKg)} / kg',
                        style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                      )
                    else
                      Text(
                        'Per-kg conversion unavailable',
                        style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                      ),
                    if (summary.latestDate.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Latest: ${summary.latestDate}',
                        style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
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
                    hasKg ? _money(summary.modalPerKg) : '—',
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    hasKg ? 'Modal / kg' : 'Price / kg',
                    style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right_rounded, color: colors.brandDeep, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommodityHeaderCard extends StatelessWidget {
  final String commodity;
  final String? state;
  final String? district;
  final List<MarketPriceRecord> records;

  const _CommodityHeaderCard({
    required this.commodity,
    required this.state,
    required this.district,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final locations = <String>[
      if (state != null) state!,
      if (district != null) district!,
    ];
    final scope = locations.isEmpty ? 'All India' : locations.reversed.join(' • ');
    final markets = records.map((record) => '${record.district}|${record.market}').toSet().length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.brandDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brandDeep.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.brandDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.grass_rounded, color: colors.brandDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commodity,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$scope • $markets markets',
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String commodity;
  final String? state;
  final String? district;
  final String? insight;
  final bool loading;
  final String? latestDate;
  final VoidCallback onRefresh;

  const _InsightCard({
    required this.commodity,
    required this.state,
    required this.district,
    required this.insight,
    required this.loading,
    required this.latestDate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    final place = district ?? state ?? loc.marketAllIndia;

    return Container(
      width: double.infinity,
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
              Icon(Icons.auto_awesome_rounded, color: colors.brandDeep, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  loc.marketInsightHeading,
                  style: TextStyle(
                    color: colors.brandDeep,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: loading ? null : onRefresh,
                icon: Icon(Icons.refresh_rounded, color: colors.brandDeep, size: 18),
              ),
            ],
          ),
          Text(
            '$commodity • $place',
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            LinearProgressIndicator(
              minHeight: 2,
              color: colors.brandDeep,
              backgroundColor: colors.brandDeep.withValues(alpha: 0.1),
            )
          else
            Text(
              insight ?? loc.marketInsightEmpty,
              style: TextStyle(color: colors.onBackground, fontSize: 12, height: 1.45),
            ),
          if ((latestDate ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Based on latest available market data • $latestDate',
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final List<PriceHistoryPoint> points;
  final bool loading;

  const _HistoryCard({required this.points, required this.loading});

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
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
              Icon(Icons.show_chart_rounded, color: colors.brandDeep, size: 18),
              const SizedBox(width: 7),
              Text(
                AppLocalizations.rawLookup(loc.languageCode, 'market_7_day_history') ??
                    '7-day price history',
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            LinearProgressIndicator(
              minHeight: 2,
              color: colors.brandDeep,
              backgroundColor: colors.brandDeep.withValues(alpha: 0.1),
            )
          else if (points.isEmpty)
            Text(
              'History is not available for the selected commodity yet.',
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: points.map((point) {
                  return Container(
                    width: 82,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _shortDate(point.date),
                          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _money(point.normalizedPricePerKg),
                          style: TextStyle(
                            color: colors.brandDeep,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '/kg',
                          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketRecordCard extends StatelessWidget {
  final MarketPriceRecord record;
  final VoidCallback onTap;

  const _MarketRecordCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final modal = record.hasReliablePerKg ? record.normalizedPricePerKg : null;
    final min = _perKg(record, record.minPrice);
    final max = _perKg(record, record.maxPrice);
    final unit = record.unitLabel.trim().isEmpty ? record.originalUnit : record.unitLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.storefront_rounded, color: colors.brandDeep, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.market.isEmpty ? 'Market' : record.market,
                          style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if ((record.variety ?? '').trim().isNotEmpty) record.variety!.trim(),
                            record.district,
                            record.state,
                          ].where((item) => item.trim().isNotEmpty).join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        modal == null ? '—' : _money(modal),
                        style: TextStyle(
                          color: colors.brandDeep,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        modal == null ? 'Unit unavailable' : 'Modal / kg',
                        style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(child: _MiniPrice(label: 'Minimum', value: min)),
                  const SizedBox(width: 7),
                  Expanded(child: _MiniPrice(label: 'Modal', value: modal)),
                  const SizedBox(width: 7),
                  Expanded(child: _MiniPrice(label: 'Maximum', value: max)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.scale_outlined, color: colors.onSurfaceMuted, size: 15),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Original: ${_money(record.modalPrice)} / ${unit.isEmpty ? 'reported unit' : unit}',
                      style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
                    ),
                  ),
                  if (record.date.trim().isNotEmpty)
                    Text(
                      record.date,
                      style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    directionalIcon(context, Icons.chevron_right_rounded),
                    color: colors.onSurfaceMuted,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPrice extends StatelessWidget {
  final String label;
  final double? value;

  const _MiniPrice({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: colors.onSurfaceMuted, fontSize: 9)),
          const SizedBox(height: 3),
          Text(
            value == null ? '—' : '${_money(value)} /kg',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMarketCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyMarketCard({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: colors.onSurfaceMuted, size: 34),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 9),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, color: colors.brandDeep, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SearchPickerSheet extends StatefulWidget {
  final String title;
  final String? allLabel;
  final List<String> items;
  final String? selected;

  const _SearchPickerSheet({
    required this.title,
    required this.items,
    this.allLabel,
    this.selected,
  });

  @override
  State<_SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<_SearchPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final filtered = widget.items.where((item) {
      return _query.isEmpty || item.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.72,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: colors.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(color: colors.onBackground),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search_rounded, color: colors.onSurfaceMuted),
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
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                children: [
                  if (widget.allLabel != null)
                    _PickerTile(
                      label: widget.allLabel!,
                      selected: widget.selected == null,
                      onTap: () => Navigator.of(context).pop(_allToken),
                    ),
                  ...filtered.map(
                    (item) => _PickerTile(
                      label: item,
                      selected: widget.selected == item,
                      onTap: () => Navigator.of(context).pop(item),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? colors.brandDeep : colors.onSurfaceMuted,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? colors.brandDeep : colors.onBackground,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _CommoditySummary {
  final String name;
  final String varietyLabel;
  final int marketCount;
  final double? modalPerKg;
  final double? minPerKg;
  final double? maxPerKg;
  final String latestDate;

  const _CommoditySummary({
    required this.name,
    required this.varietyLabel,
    required this.marketCount,
    required this.modalPerKg,
    required this.minPerKg,
    required this.maxPerKg,
    required this.latestDate,
  });

  factory _CommoditySummary.fromRecords(
    String name,
    List<MarketPriceRecord> records,
  ) {
    final modalValues = <double>[];
    final minValues = <double>[];
    final maxValues = <double>[];
    final varieties = <String>{};
    final markets = <String>{};
    String latest = '';

    for (final record in records) {
      if (record.normalizedPricePerKg != null && record.hasReliablePerKg) {
        modalValues.add(record.normalizedPricePerKg!);
      }
      final min = _perKg(record, record.minPrice);
      final max = _perKg(record, record.maxPrice);
      if (min != null) minValues.add(min);
      if (max != null) maxValues.add(max);

      final variety = record.variety?.trim() ?? '';
      if (variety.isNotEmpty && variety.toLowerCase() != 'other') {
        varieties.add(variety);
      }
      markets.add('${record.district}|${record.market}'.toLowerCase());
      if (latest.isEmpty || _compareDatesDesc(record.date, latest) < 0) {
        latest = record.date;
      }
    }

    final varietyLabel = varieties.isEmpty
        ? 'Mixed varieties'
        : varieties.length == 1
            ? varieties.first
            : '${varieties.length} varieties';

    return _CommoditySummary(
      name: name,
      varietyLabel: varietyLabel,
      marketCount: markets.length,
      modalPerKg: _average(modalValues),
      minPerKg: _minimum(minValues),
      maxPerKg: _maximum(maxValues),
      latestDate: latest,
    );
  }
}

class _MarketCategory {
  final String id;
  final String label;
  final IconData icon;

  const _MarketCategory(this.id, this.label, this.icon);

  static const all = 'all';
  static const vegetables = 'vegetables';
  static const fruits = 'fruits';
  static const grains = 'grains';
  static const pulses = 'pulses';
  static const oilseeds = 'oilseeds';
  static const spices = 'spices';
  static const flowers = 'flowers';
  static const plantation = 'plantation';
  static const others = 'others';

  static const items = <_MarketCategory>[
    _MarketCategory(all, 'All', Icons.apps_rounded),
    _MarketCategory(vegetables, 'Vegetables', Icons.eco_outlined),
    _MarketCategory(fruits, 'Fruits', Icons.local_grocery_store_outlined),
    _MarketCategory(grains, 'Cereals / Grains', Icons.grass_rounded),
    _MarketCategory(pulses, 'Pulses', Icons.spa_outlined),
    _MarketCategory(oilseeds, 'Oilseeds', Icons.water_drop_outlined),
    _MarketCategory(spices, 'Spices', Icons.local_fire_department_outlined),
    _MarketCategory(flowers, 'Flowers', Icons.local_florist_outlined),
    _MarketCategory(plantation, 'Plantation', Icons.park_outlined),
    _MarketCategory(others, 'Others', Icons.more_horiz_rounded),
  ];
}

String _categoryForCommodity(String commodity) {
  final value = commodity.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');

  bool containsAny(List<String> words) => words.any(value.contains);

  if (containsAny(const [
    'chickpea', 'bengal gram', 'green gram', 'black gram', 'red gram',
    'pigeon pea', 'tur dal', 'toor', 'arhar', 'lentil', 'masur', 'moong',
    'mung', 'urad', 'horse gram', 'cowpea', 'field pea',
  ])) {
    return _MarketCategory.pulses;
  }
  if (containsAny(const [
    'tomato', 'potato', 'onion', 'brinjal', 'eggplant', 'cabbage',
    'cauliflower', 'carrot', 'beetroot', 'bottle gourd', 'bitter gourd',
    'ridge gourd', 'snake gourd', 'ash gourd', 'pumpkin', 'okra', 'bhindi',
    'cucumber', 'capsicum', 'radish', 'drumstick', 'beans', 'green peas',
  ])) {
    return _MarketCategory.vegetables;
  }
  if (containsAny(const [
    'banana', 'mango', 'papaya', 'watermelon', 'pomegranate', 'grape',
    'apple', 'orange', 'guava', 'pineapple', 'lemon', 'lime', 'mosambi',
    'sweet lime', 'sapota', 'chikoo', 'jackfruit', 'pear', 'plum', 'peach',
  ])) {
    return _MarketCategory.fruits;
  }
  if (containsAny(const [
    'paddy', 'rice', 'wheat', 'maize', 'corn', 'barley', 'jowar', 'sorghum',
    'bajra', 'pearl millet', 'ragi', 'finger millet', 'millet', 'oats',
  ])) {
    return _MarketCategory.grains;
  }
  if (containsAny(const [
    'groundnut', 'peanut', 'soybean', 'mustard', 'sunflower', 'sesame',
    'til', 'castor', 'safflower', 'linseed', 'flaxseed', 'rapeseed',
  ])) {
    return _MarketCategory.oilseeds;
  }
  if (containsAny(const [
    'turmeric', 'ginger', 'garlic', 'coriander', 'fenugreek', 'pepper',
    'cardamom', 'cumin', 'jeera', 'chilli', 'chili', 'clove', 'cinnamon',
    'nutmeg', 'fennel',
  ])) {
    return _MarketCategory.spices;
  }
  if (containsAny(const [
    'rose', 'jasmine', 'marigold', 'chrysanthemum', 'tuberose', 'lotus',
    'crossandra', 'flower',
  ])) {
    return _MarketCategory.flowers;
  }
  if (containsAny(const [
    'coconut', 'copra', 'coffee', 'tea', 'rubber', 'arecanut', 'areca nut',
    'cashewnut', 'cashew', 'cocoa',
  ])) {
    return _MarketCategory.plantation;
  }
  return _MarketCategory.others;
}

const String _allToken = '__all__';

double? _perKg(MarketPriceRecord record, double? reported) {
  final factor = record.conversionFactor;
  if (reported == null || factor == null || factor <= 0) return null;
  return reported / factor;
}

double? _average(List<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

double? _minimum(List<double> values) {
  if (values.isEmpty) return null;
  var result = values.first;
  for (final value in values.skip(1)) {
    if (value < result) result = value;
  }
  return result;
}

double? _maximum(List<double> values) {
  if (values.isEmpty) return null;
  var result = values.first;
  for (final value in values.skip(1)) {
    if (value > result) result = value;
  }
  return result;
}

String _money(double? value) {
  if (value == null || !value.isFinite) return '—';
  final decimals = value < 10 && value % 1 != 0 ? 1 : 0;
  return MarketFormat.inr(value, decimals: decimals);
}

DateTime? _parseMarketDate(String raw) {
  final clean = raw.trim();
  if (clean.isEmpty) return null;
  final direct = DateTime.tryParse(clean);
  if (direct != null) return direct;

  final slash = clean.split('/');
  if (slash.length == 3) {
    final a = int.tryParse(slash[0]);
    final b = int.tryParse(slash[1]);
    final c = int.tryParse(slash[2]);
    if (a != null && b != null && c != null) {
      if (c > 31) return DateTime(c, b, a);
      if (a > 31) return DateTime(a, b, c);
    }
  }
  return null;
}

int _compareDatesDesc(String a, String b) {
  final da = _parseMarketDate(a);
  final db = _parseMarketDate(b);
  if (da != null && db != null) return db.compareTo(da);
  if (da != null) return -1;
  if (db != null) return 1;
  return b.compareTo(a);
}

String _shortDate(String raw) {
  final date = _parseMarketDate(raw);
  if (date == null) return raw;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
