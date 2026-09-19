import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/vidhai_theme.dart';
import '../../../data/models/market_price_models.dart';
import '../../../locale/locale.dart';
import '../../../services/data_service.dart';
import '../../../services/market_price_service.dart';
import '../../assistant/assistant_button.dart';
import 'market_price_detail_screen.dart';

enum _ConsumerMarketSort { latest, lowest, highest, commodity }

class _MarketQuery {
  final String? state;
  final String? district;

  const _MarketQuery({this.state, this.district});
}

class _ConsumerMarketFilterResult {
  final Set<String> states;
  final Map<String, Set<String>> districtsByState;

  const _ConsumerMarketFilterResult(this.states, this.districtsByState);
}

/// Consumer-focused live mandi explorer.
///
/// It reuses the existing secure VidhAI market backend and never fabricates
/// prices. Multi-state / multi-district filtering is implemented as bounded
/// client-side batches of the existing single-region backend request.
class ConsumerMarketPricesScreen extends StatefulWidget {
  const ConsumerMarketPricesScreen({super.key});

  @override
  State<ConsumerMarketPricesScreen> createState() =>
      _ConsumerMarketPricesScreenState();
}

class _ConsumerMarketPricesScreenState
    extends State<ConsumerMarketPricesScreen> {
  static const _prefsKey = 'consumer_market_filters_v1';
  static const _categories = <String>[
    'Vegetables',
    'Fruits',
    'Grains',
    'Pulses',
    'Oilseeds',
    'Spices',
    'Other',
  ];

  final MarketPriceService _service = MarketPriceService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<String> _knownStates = const [];
  Set<String> _selectedStates = <String>{};
  Map<String, Set<String>> _selectedDistricts = <String, Set<String>>{};
  List<MarketPriceRecord> _records = const [];

  bool _loading = true;
  bool _fromCache = false;
  String? _error;
  String? _category;
  _ConsumerMarketSort _sort = _ConsumerMarketSort.latest;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final states = await _service.fetchStates();
      _knownStates =
          states.map((state) => state.name).where((name) => name.isNotEmpty).toList()
            ..sort();

      final restored = await _restoreFilters();
      if (!restored) {
        try {
          final profile = await DataService().loadProfile();
          final state = profile?.address?.state?.trim() ?? '';
          final district = profile?.address?.district?.trim() ?? '';
          if (state.isNotEmpty && _knownStates.contains(state)) {
            _selectedStates = {state};
            if (district.isNotEmpty) {
              _selectedDistricts = {
                state: {district}
              };
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    if (mounted) await _loadMarketData();
  }

  Future<bool> _restoreFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded.cast<String, dynamic>());
      final states = (map['states'] as List? ?? const [])
          .map((item) => item.toString())
          .where((state) => state.isNotEmpty)
          .toSet();
      final districts = <String, Set<String>>{};
      final rawDistricts = map['districts'];
      if (rawDistricts is Map) {
        for (final entry in rawDistricts.entries) {
          final value = entry.value;
          if (value is List) {
            districts[entry.key.toString()] = value
                .map((item) => item.toString())
                .where((item) => item.isNotEmpty)
                .toSet();
          }
        }
      }
      _selectedStates = states;
      _selectedDistricts = districts;
      return states.isNotEmpty || districts.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'states': _selectedStates.toList(),
          'districts': {
            for (final entry in _selectedDistricts.entries)
              entry.key: entry.value.toList(),
          },
        }),
      );
    } catch (_) {}
  }

  Future<void> _loadMarketData({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final queries = <_MarketQuery>[];
      if (_selectedStates.isEmpty) {
        queries.add(const _MarketQuery());
      } else {
        for (final state in _selectedStates) {
          final districts = _selectedDistricts[state] ?? const <String>{};
          if (districts.isEmpty) {
            queries.add(_MarketQuery(state: state));
          } else {
            for (final district in districts) {
              queries.add(_MarketQuery(state: state, district: district));
            }
          }
        }
      }

      final payloads = <MarketPricePayload>[];
      for (var start = 0; start < queries.length; start += 4) {
        final end =
            (start + 4) > queries.length ? queries.length : (start + 4);
        final batch = queries.sublist(start, end);
        final results = await Future.wait(
          batch.map((query) {
            if (query.state == null) {
              return _service.fetchSummary();
            }
            return _service.fetchPrices(
              state: query.state,
              district: query.district,
              refresh: refresh,
            );
          }),
        );
        payloads.addAll(results);
      }

      final unique = <String, MarketPriceRecord>{};
      var fromCache = false;
      for (final payload in payloads) {
        fromCache = fromCache || payload.fromCache || payload.stale;
        for (final record in payload.prices) {
          final key = [
            record.commodity,
            record.variety ?? '',
            record.market,
            record.district,
            record.state,
            record.date,
          ].join('|').toLowerCase();
          unique[key] = record;
        }
      }

      if (!mounted) return;
      setState(() {
        _records = unique.values.toList();
        _fromCache = fromCache;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<MarketPriceRecord> get _visibleRecords {
    final query = _searchController.text.trim().toLowerCase();
    var records = _records.where((record) {
      if (_category != null && _categoryFor(record.commodity) != _category) {
        return false;
      }
      if (query.isEmpty) return true;
      return record.commodity.toLowerCase().contains(query) ||
          (record.variety?.toLowerCase().contains(query) ?? false) ||
          record.market.toLowerCase().contains(query) ||
          record.district.toLowerCase().contains(query) ||
          record.state.toLowerCase().contains(query);
    }).toList();

    int comparePrice(MarketPriceRecord a, MarketPriceRecord b) {
      final ap = a.normalizedPricePerKg;
      final bp = b.normalizedPricePerKg;
      if (ap == null && bp == null) return 0;
      if (ap == null) return 1;
      if (bp == null) return -1;
      return ap.compareTo(bp);
    }

    switch (_sort) {
      case _ConsumerMarketSort.latest:
        records.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _ConsumerMarketSort.lowest:
        records.sort(comparePrice);
        break;
      case _ConsumerMarketSort.highest:
        records.sort((a, b) => comparePrice(b, a));
        break;
      case _ConsumerMarketSort.commodity:
        records.sort(
          (a, b) => a.commodity.toLowerCase().compareTo(
                b.commodity.toLowerCase(),
              ),
        );
        break;
    }
    return records;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_ConsumerMarketFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConsumerMarketFilterSheet(
        service: _service,
        states: _knownStates,
        selectedStates: _selectedStates,
        selectedDistricts: _selectedDistricts,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedStates = result.states;
      _selectedDistricts = result.districtsByState;
    });
    await _persistFilters();
    await _loadMarketData();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedStates = <String>{};
      _selectedDistricts = <String, Set<String>>{};
      _category = null;
      _searchController.clear();
    });
    await _persistFilters();
    await _loadMarketData();
  }

  String _statusLabel(AppLocalizations loc) {
    if (_fromCache || !_service.wasLastCallOnline) {
      return loc.t('consumer_market_last_available');
    }
    return loc.t('consumer_market_live');
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final records = _visibleRecords;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          loc.marketPrices,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: loc.filterByLocation,
            onPressed: _openFilters,
            icon: Icon(Icons.tune_rounded, color: colors.onBackground),
          ),
          IconButton(
            tooltip: loc.t('refresh'),
            onPressed: _loading ? null : () => _loadMarketData(refresh: true),
            icon: Icon(Icons.refresh_rounded, color: colors.onBackground),
          ),
          const VidhAIAssistantButton(
            screen: 'consumer_market_prices',
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadMarketData(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _buildSearch(colors, loc),
            const SizedBox(height: 10),
            _buildFilterSummary(colors, loc),
            const SizedBox(height: 10),
            _buildCategoryRow(colors, loc),
            const SizedBox(height: 10),
            _buildSortRow(colors, loc),
            const SizedBox(height: 14),
            if (_loading)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: colors.brandDeep),
                ),
              )
            else if (_error != null && _records.isEmpty)
              _buildEmpty(
                colors,
                loc.t('consumer_market_temporarily_unavailable'),
                Icons.cloud_off_rounded,
              )
            else if (records.isEmpty)
              _buildEmpty(
                colors,
                loc.t('consumer_market_no_results'),
                Icons.search_off_rounded,
              )
            else ...[
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _fromCache ? colors.onSurfaceMuted : colors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _statusLabel(loc),
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${records.length} ${loc.t('consumer_market_records')}',
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildPriceCard(colors, loc, record),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(VidhAIColorsX colors, AppLocalizations loc) {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: colors.onBackground),
      decoration: InputDecoration(
        hintText: loc.marketSearchHint,
        hintStyle: TextStyle(color: colors.onSurfaceMuted),
        prefixIcon: Icon(Icons.search_rounded, color: colors.onSurfaceMuted),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: Icon(Icons.close_rounded, color: colors.onSurfaceMuted),
              ),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.brandDeep, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFilterSummary(VidhAIColorsX colors, AppLocalizations loc) {
    final districtCount =
        _selectedDistricts.values.fold<int>(0, (sum, set) => sum + set.length);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: colors.brandDeep, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedStates.isEmpty
                  ? loc.t('consumer_market_all_india')
                  : '${_selectedStates.length} ${loc.state} • '
                      '$districtCount ${loc.district}',
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_selectedStates.isNotEmpty)
            TextButton(
              onPressed: _clearFilters,
              child: Text(loc.clearFilters),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(VidhAIColorsX colors, AppLocalizations loc) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(loc.all),
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null),
            ),
          ),
          ..._categories.map(
            (category) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(loc.t('consumer_category_${category.toLowerCase()}')),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortRow(VidhAIColorsX colors, AppLocalizations loc) {
    String label(_ConsumerMarketSort sort) {
      return switch (sort) {
        _ConsumerMarketSort.latest => loc.t('consumer_sort_latest'),
        _ConsumerMarketSort.lowest => loc.t('consumer_sort_lowest'),
        _ConsumerMarketSort.highest => loc.t('consumer_sort_highest'),
        _ConsumerMarketSort.commodity => loc.t('consumer_sort_commodity'),
      };
    }

    return Row(
      children: [
        Icon(Icons.sort_rounded, color: colors.onSurfaceMuted, size: 18),
        const SizedBox(width: 8),
        Text(
          loc.t('consumer_sort_by'),
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
        ),
        const Spacer(),
        PopupMenuButton<_ConsumerMarketSort>(
          initialValue: _sort,
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (_) => _ConsumerMarketSort.values
              .map(
                (sort) => PopupMenuItem(
                  value: sort,
                  child: Text(label(sort)),
                ),
              )
              .toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label(_sort),
                style: TextStyle(
                  color: colors.brandDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.brandDeep,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(
    VidhAIColorsX colors,
    AppLocalizations loc,
    MarketPriceRecord record,
  ) {
    final perKg = record.hasReliablePerKg
        ? MarketFormat.inr(record.normalizedPricePerKg, decimals: 2)
        : loc.marketPriceUnitUnavailable;

    String range(double? value) {
      if (value == null ||
          record.conversionFactor == null ||
          record.conversionFactor == 0) {
        return '—';
      }
      return MarketFormat.inr(
        value / record.conversionFactor!,
        decimals: 2,
      );
    }

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MarketPriceDetailScreen(record: record),
          ),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.shopping_basket_outlined,
                      color: colors.brandDeep,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.commodity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((record.variety ?? '').isNotEmpty)
                          Text(
                            record.variety!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceMuted,
                              fontSize: 11,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          [record.market, record.district, record.state]
                              .where((item) => item.trim().isNotEmpty)
                              .join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        perKg,
                        style: TextStyle(
                          color: colors.brandDeep,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        loc.marketPricePerKg,
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _priceStat(colors, loc.marketMinPrice, range(record.minPrice)),
                  const SizedBox(width: 8),
                  _priceStat(
                    colors,
                    loc.marketModalPrice,
                    range(record.modalPrice),
                  ),
                  const SizedBox(width: 8),
                  _priceStat(colors, loc.marketMaxPrice, range(record.maxPrice)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: colors.onSurfaceMuted,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    record.date.isEmpty
                        ? loc.t('consumer_market_date_unavailable')
                        : record.date,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 10.5,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      record.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceStat(VidhAIColorsX colors, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 9.5),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(VidhAIColorsX colors, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, color: colors.onSurfaceMuted, size: 44),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _categoryFor(String commodity) {
    final name = commodity.toLowerCase();
    const fruits = {
      'banana', 'mango', 'papaya', 'watermelon', 'pomegranate',
      'grapes', 'apple', 'orange',
    };
    const grains = {
      'paddy', 'rice', 'wheat', 'maize', 'barley', 'jowar', 'bajra', 'ragi',
    };
    const pulses = {
      'chickpea', 'bengal gram', 'green gram', 'black gram', 'red gram',
      'pigeon pea',
    };
    const oilseeds = {'groundnut', 'soybean', 'mustard', 'sunflower', 'sesame'};
    const spices = {
      'turmeric', 'ginger', 'garlic', 'coriander', 'fenugreek',
      'black pepper', 'cardamom',
    };
    const vegetables = {
      'tomato', 'potato', 'onion', 'chilli', 'brinjal', 'cabbage',
      'cauliflower', 'carrot', 'beetroot', 'bottle gourd', 'bitter gourd',
      'ridge gourd',
    };

    bool matches(Set<String> values) =>
        values.any((value) => name == value || name.contains(value));
    if (matches(vegetables)) return 'Vegetables';
    if (matches(fruits)) return 'Fruits';
    if (matches(grains)) return 'Grains';
    if (matches(pulses)) return 'Pulses';
    if (matches(oilseeds)) return 'Oilseeds';
    if (matches(spices)) return 'Spices';
    return 'Other';
  }
}

class _ConsumerMarketFilterSheet extends StatefulWidget {
  final MarketPriceService service;
  final List<String> states;
  final Set<String> selectedStates;
  final Map<String, Set<String>> selectedDistricts;

  const _ConsumerMarketFilterSheet({
    required this.service,
    required this.states,
    required this.selectedStates,
    required this.selectedDistricts,
  });

  @override
  State<_ConsumerMarketFilterSheet> createState() =>
      _ConsumerMarketFilterSheetState();
}

class _ConsumerMarketFilterSheetState
    extends State<_ConsumerMarketFilterSheet> {
  late Set<String> _states;
  late Map<String, Set<String>> _districts;
  final Map<String, List<String>> _options = {};
  final Set<String> _loadingStates = {};

  @override
  void initState() {
    super.initState();
    _states = {...widget.selectedStates};
    _districts = {
      for (final entry in widget.selectedDistricts.entries)
        entry.key: {...entry.value},
    };
    for (final state in _states) {
      _ensureDistricts(state);
    }
  }

  Future<void> _ensureDistricts(String state) async {
    if (_options.containsKey(state) || _loadingStates.contains(state)) return;
    setState(() => _loadingStates.add(state));
    final result = await widget.service.fetchDistricts(state);
    if (!mounted) return;
    setState(() {
      _loadingStates.remove(state);
      _options[state] = result;
    });
  }

  void _toggleState(String state, bool selected) {
    setState(() {
      if (selected) {
        _states.add(state);
      } else {
        _states.remove(state);
        _districts.remove(state);
      }
    });
    if (selected) _ensureDistricts(state);
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.86,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.t('consumer_market_filters'),
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _states.clear();
                        _districts.clear();
                      });
                    },
                    child: Text(loc.clearFilters),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                children: [
                  Text(
                    loc.state,
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: widget.states
                        .map(
                          (state) => FilterChip(
                            label: Text(state),
                            selected: _states.contains(state),
                            onSelected: (selected) =>
                                _toggleState(state, selected),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  if (_states.isNotEmpty)
                    Text(
                      loc.district,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ..._states.map((state) {
                    final options = _options[state] ?? const <String>[];
                    final selected = _districts[state] ?? <String>{};
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state,
                            style: TextStyle(
                              color: colors.brandDeep,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_loadingStates.contains(state))
                            const LinearProgressIndicator(minHeight: 2)
                          else if (options.isEmpty)
                            Text(
                              loc.t('consumer_market_no_districts'),
                              style: TextStyle(
                                color: colors.onSurfaceMuted,
                                fontSize: 12,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: options
                                  .map(
                                    (district) => FilterChip(
                                      label: Text(district),
                                      selected: selected.contains(district),
                                      onSelected: (value) {
                                        setState(() {
                                          final set = _districts.putIfAbsent(
                                            state,
                                            () => <String>{},
                                          );
                                          if (value) {
                                            set.add(district);
                                          } else {
                                            set.remove(district);
                                          }
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _ConsumerMarketFilterResult(
                      {..._states},
                      {
                        for (final entry in _districts.entries)
                          if (_states.contains(entry.key))
                            entry.key: {...entry.value},
                      },
                    ),
                  ),
                  child: Text(loc.apply),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
