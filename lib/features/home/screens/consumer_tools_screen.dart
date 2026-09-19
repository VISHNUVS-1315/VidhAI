import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/features/tools/screens/consumer_market_prices_screen.dart';
import 'package:vidhai/features/tools/screens/fertilizer_guide_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/consumer_purchase_service.dart';

class ConsumerToolsScreen extends StatelessWidget {
  const ConsumerToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        titleSpacing: 18,
        title: Text(
          loc.tools,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _ConsumerToolCard(
            colors: colors,
            icon: Icons.query_stats_rounded,
            title: loc.marketPrices,
            subtitle: loc.t('consumer_market_desc'),
            emphasized: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ConsumerMarketPricesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ConsumerToolCard(
            colors: colors,
            icon: Icons.receipt_long_rounded,
            title: loc.t('purchase_history'),
            subtitle: loc.t('consumer_purchase_history_desc'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _PurchaseHistoryScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ConsumerToolCard(
            colors: colors,
            icon: Icons.calculate_outlined,
            title: loc.t('budget_calculator'),
            subtitle: loc.t('budget_calculator_desc'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _BudgetCalculatorScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ConsumerToolCard(
            colors: colors,
            icon: Icons.sticky_note_2_outlined,
            title: loc.t('quick_notes'),
            subtitle: loc.t('quick_notes_desc'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _QuickNotesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ConsumerToolCard(
            colors: colors,
            icon: Icons.science_outlined,
            title: loc.t('fertilizer_prices'),
            subtitle: loc.fertilizerGuideDesc,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _FertilizerPricesScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumerToolCard extends StatelessWidget {
  const _ConsumerToolCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final VidhAIColorsX colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: emphasized
                  ? colors.brandDeep.withValues(alpha: 0.42)
                  : colors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.brandDeep.withValues(
                    alpha: emphasized ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.brandDeep, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseHistoryScreen extends StatefulWidget {
  const _PurchaseHistoryScreen();

  @override
  State<_PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<_PurchaseHistoryScreen> {
  final _service = ConsumerPurchaseService.instance;
  final _search = TextEditingController();
  List<ConsumerPurchaseRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final records = await _service.loadPurchases();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final query = _search.text.trim().toLowerCase();
    final visible = _records.where((record) {
      if (query.isEmpty) return true;
      return record.commodity.toLowerCase().contains(query) ||
          record.sellerName.toLowerCase().contains(query) ||
          record.market.toLowerCase().contains(query);
    }).toList();
    final total = visible.fold<double>(
      0,
      (sum, record) => sum + record.totalAmount,
    );

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          loc.t('purchase_history'),
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.brandDeep))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: loc.t('consumer_purchase_search'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            color: colors.brandDeep,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              loc.t('consumer_total_spending'),
                              style: TextStyle(
                                color: colors.onSurfaceMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: colors.onBackground,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (visible.isNotEmpty) const SizedBox(height: 12),
                  if (visible.isEmpty)
                    _emptyState(
                      colors,
                      loc.t('no_purchase_history'),
                      Icons.receipt_long_outlined,
                    )
                  else
                    ...visible.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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
                                children: [
                                  Expanded(
                                    child: Text(
                                      record.commodity,
                                      style: TextStyle(
                                        color: colors.onBackground,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${record.totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: colors.brandDeep,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${record.quantityKg.toStringAsFixed(2)} kg × '
                                '₹${record.pricePerKg.toStringAsFixed(2)}/kg',
                                style: TextStyle(
                                  color: colors.onSurfaceMuted,
                                  fontSize: 12,
                                ),
                              ),
                              if (record.market.isNotEmpty ||
                                  record.sellerName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  [record.sellerName, record.market]
                                      .where((item) => item.isNotEmpty)
                                      .join(' • '),
                                  style: TextStyle(
                                    color: colors.onSurfaceMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(record.purchasedAt),
                                style: TextStyle(
                                  color: colors.onSurfaceMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  static String _formatDate(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _BudgetLine {
  final commodity = TextEditingController();
  final quantity = TextEditingController();
  final price = TextEditingController();

  double get amount {
    final q = double.tryParse(quantity.text.trim()) ?? 0;
    final p = double.tryParse(price.text.trim()) ?? 0;
    return q * p;
  }

  void dispose() {
    commodity.dispose();
    quantity.dispose();
    price.dispose();
  }
}

class _BudgetCalculatorScreen extends StatefulWidget {
  const _BudgetCalculatorScreen();

  @override
  State<_BudgetCalculatorScreen> createState() =>
      _BudgetCalculatorScreenState();
}

class _BudgetCalculatorScreenState extends State<_BudgetCalculatorScreen> {
  final _budget = TextEditingController();
  final List<_BudgetLine> _lines = [_BudgetLine()];

  @override
  void dispose() {
    _budget.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _total =>
      _lines.fold<double>(0, (sum, line) => sum + line.amount);

  void _addLine() => setState(() => _lines.add(_BudgetLine()));

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final budget = double.tryParse(_budget.text.trim()) ?? 0;
    final remaining = budget - _total;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          loc.t('budget_calculator'),
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          TextField(
            controller: _budget,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: loc.t('consumer_budget'),
              prefixText: '₹ ',
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_lines.length, (index) {
            final line = _lines[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: line.commodity,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: loc.t('consumer_commodity'),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_lines.length > 1)
                        IconButton(
                          onPressed: () => _removeLine(index),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: line.quantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: loc.t('consumer_quantity_kg'),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: line.price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: loc.t('consumer_price_per_kg'),
                            prefixText: '₹ ',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '₹${line.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: colors.brandDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add_rounded),
            label: Text(loc.t('consumer_add_item')),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.borderColor),
            ),
            child: Column(
              children: [
                _summaryRow(
                  colors,
                  loc.t('consumer_total_cost'),
                  '₹${_total.toStringAsFixed(2)}',
                ),
                if (budget > 0) ...[
                  const SizedBox(height: 10),
                  _summaryRow(
                    colors,
                    loc.t('consumer_remaining_budget'),
                    '₹${remaining.toStringAsFixed(2)}',
                    highlight: remaining < 0,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    VidhAIColorsX colors,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colors.onSurfaceMuted),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? colors.danger : colors.onBackground,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _QuickNote {
  final String id;
  final String text;
  final bool pinned;
  final DateTime createdAt;

  const _QuickNote({
    required this.id,
    required this.text,
    required this.pinned,
    required this.createdAt,
  });

  factory _QuickNote.fromMap(Map<String, dynamic> map) => _QuickNote(
        id: (map['id'] ?? '').toString(),
        text: (map['text'] ?? '').toString(),
        pinned: map['pinned'] == true,
        createdAt:
            DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
                DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
      };

  _QuickNote copyWith({String? text, bool? pinned}) => _QuickNote(
        id: id,
        text: text ?? this.text,
        pinned: pinned ?? this.pinned,
        createdAt: createdAt,
      );
}

class _QuickNotesScreen extends StatefulWidget {
  const _QuickNotesScreen();

  @override
  State<_QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<_QuickNotesScreen> {
  static const _key = 'consumer_quick_notes_v1';
  List<_QuickNote> _notes = const [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || !mounted) return;
      setState(() {
        _notes = decoded
            .whereType<Map>()
            .map(
              (item) => _QuickNote.fromMap(
                Map<String, dynamic>.from(item.cast<String, dynamic>()),
              ),
            )
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_notes.map((note) => note.toMap()).toList()),
    );
  }

  Future<void> _edit({_QuickNote? existing}) async {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: existing?.text ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.t(existing == null ? 'consumer_add_note' : 'consumer_edit_note')),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: loc.t('consumer_note_hint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || !mounted) return;

    setState(() {
      if (existing == null) {
        _notes = [
          _QuickNote(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: text,
            pinned: false,
            createdAt: DateTime.now(),
          ),
          ..._notes,
        ];
      } else {
        _notes = _notes
            .map((note) => note.id == existing.id
                ? note.copyWith(text: text)
                : note)
            .toList();
      }
    });
    await _save();
  }

  Future<void> _togglePin(_QuickNote note) async {
    setState(() {
      _notes = _notes
          .map((item) => item.id == note.id
              ? item.copyWith(pinned: !item.pinned)
              : item)
          .toList();
    });
    await _save();
  }

  Future<void> _delete(_QuickNote note) async {
    setState(() {
      _notes = _notes.where((item) => item.id != note.id).toList();
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final query = _search.text.trim().toLowerCase();
    final visible = _notes
        .where((note) => query.isEmpty || note.text.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          loc.t('quick_notes'),
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: loc.t('consumer_search_notes'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            _emptyState(
              colors,
              loc.t('consumer_no_notes'),
              Icons.sticky_note_2_outlined,
            )
          else
            ...visible.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _edit(existing: note),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            note.pinned
                                ? Icons.push_pin_rounded
                                : Icons.notes_rounded,
                            color: note.pinned
                                ? colors.brandDeep
                                : colors.onSurfaceMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              note.text,
                              style: TextStyle(
                                color: colors.onBackground,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'pin') {
                                _togglePin(note);
                              } else if (value == 'edit') {
                                _edit(existing: note);
                              } else if (value == 'delete') {
                                _delete(note);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(
                                  loc.t(note.pinned
                                      ? 'consumer_unpin'
                                      : 'consumer_pin'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(loc.edit),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(loc.delete),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: Text(loc.t('consumer_add_note')),
      ),
    );
  }
}

Widget _emptyState(VidhAIColorsX colors, String text, IconData icon) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.brandDeep.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, color: colors.brandDeep, size: 32),
        ),
        const SizedBox(height: 14),
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

class _FertilizerPricesScreen extends StatelessWidget {
  const _FertilizerPricesScreen();

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          loc.t('fertilizer_prices'),
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science_outlined, color: colors.brandDeep, size: 48),
              const SizedBox(height: 14),
              Text(
                loc.marketPricesEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FertilizerGuideScreen(),
                  ),
                ),
                icon: const Icon(Icons.eco_outlined),
                label: Text(loc.fertilizerGuide),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
