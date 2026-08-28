import 'package:flutter/material.dart';
import 'package:vidhai/services/mandi_service.dart';

class MarketPricesScreen extends StatefulWidget {
  const MarketPricesScreen({super.key});

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen> {
  final MandiService _mandiService = MandiService();
  String _selectedState = 'All';
  String _searchQuery = '';
  List<MandiPrice> _prices = [];
  List<String> _states = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final states = await _mandiService.fetchStates();
      final prices = await _mandiService.fetchPrices();
      if (mounted) {
        setState(() {
          _states = ['All', ...states];
          _prices = prices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<MandiPrice> get _filteredData {
    return _prices.where((item) {
      final matchesState = _selectedState == 'All' || item.state == _selectedState;
      final matchesSearch = _searchQuery.isEmpty ||
          item.commodity.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.market.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.state.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesState && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Market Prices',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search commodity or market...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _states.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final state = _states[index];
                final isSelected = _selectedState == state;
                return GestureDetector(
                  onTap: () => setState(() => _selectedState = state),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                          : const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      state,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _isLoading
                  ? Text('Loading...', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12))
                  : Text(
                      '${_filteredData.length} commodity prices',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50), strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, color: Colors.white.withValues(alpha: 0.2), size: 48),
                            const SizedBox(height: 12),
                            Text('Failed to load prices', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(_error!, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF4CAF50)),
                            ),
                          ],
                        ),
                      )
                    : _filteredData.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, color: Colors.white.withValues(alpha: 0.2), size: 48),
                                const SizedBox(height: 12),
                                Text('No commodities found', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: const Color(0xFF4CAF50),
                            backgroundColor: const Color(0xFF111827),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _filteredData.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _PriceCard(item: _filteredData[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final MandiPrice item;
  const _PriceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final trend = item.trend;
    final trendColor = trend == 'up'
        ? const Color(0xFF4CAF50)
        : trend == 'down'
            ? const Color(0xFFEF4444)
            : const Color(0xFF9E9E9E);
    final trendIcon = trend == 'up'
        ? Icons.arrow_upward_rounded
        : trend == 'down'
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
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
                      item.commodity,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.market}  •  ${item.state}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(trendIcon, color: trendColor, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _priceChip('Min', '₹${_formatPrice(item.minPrice)}', Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              _priceChip('Modal', '₹${_formatPrice(item.modalPrice)}', const Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              _priceChip('Max', '₹${_formatPrice(item.maxPrice)}', Colors.white.withValues(alpha: 0.4)),
              const Spacer(),
              Text(
                '₹/Qtl',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
              ),
            ],
          ),
          if (item.date.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: Colors.white.withValues(alpha: 0.25), size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    item.date,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.store_rounded, color: Colors.white.withValues(alpha: 0.25), size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'data.gov.in',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceChip(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  static String _formatPrice(double price) {
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
