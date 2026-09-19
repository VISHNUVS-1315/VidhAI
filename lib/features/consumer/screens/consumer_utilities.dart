import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../locale/locale.dart';
import '../../../services/consumer/purchase_service.dart';

Future<void> recordConsumerPurchase(BuildContext context, {
  required String postId, required String crop, required String seller,
}) async {
  final accountId = FirebaseAuth.instance.currentUser?.uid;
  final loc = AppLocalizations.of(context);
  final quantity = TextEditingController();
  final total = TextEditingController();
  final form = GlobalKey<FormState>();
  final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text(loc.t('consumer_received')),
    content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(crop),
      TextFormField(controller: quantity,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: '${loc.t('quantity')} (${loc.t('community_kg_unit')})'),
        validator: (v) { final n = double.tryParse(v?.trim() ?? '');
          return n != null && n.isFinite && n > 0 ? null : loc.t('community_require_quantity'); }),
      TextFormField(controller: total,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: loc.t('consumer_paid')),
        validator: (v) { final n = double.tryParse(v?.trim() ?? '');
          return n != null && n.isFinite && n >= 0 ? null : loc.t('consumer_valid_amount'); }),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
      FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(loc.t('save')))],
  ));
  if (confirmed == true) {
    try {
      await PurchaseService.record(accountId: accountId, postId: postId, crop: crop, seller: seller,
        quantityKg: double.parse(quantity.text.trim()), totalPaid: double.parse(total.text.trim()));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('saved_successfully'))));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('consumer_save_error'))));
    }
  }
  // Controllers are not disposed while the dialog's exit animation is active.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  quantity.dispose(); total.dispose();
}

class ConsumerPurchaseHistoryScreen extends StatefulWidget {
  const ConsumerPurchaseHistoryScreen({super.key});
  @override
  State<ConsumerPurchaseHistoryScreen> createState() => _ConsumerPurchaseHistoryScreenState();
}
class _ConsumerPurchaseHistoryScreenState extends State<ConsumerPurchaseHistoryScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _stream =
    FirebaseAuth.instance.currentUser == null ? null : PurchaseService.records.orderBy('completedAt', descending: true).snapshots();
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(loc.t('purchase_history'))),
      body: _stream == null ? Center(child: Text(loc.t('consumer_sign_in'))) :
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _stream, builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(loc.t('consumer_load_error')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text(loc.t('consumer_purchases_empty'), textAlign: TextAlign.center)));
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
            final d = snapshot.data!.docs[index].data();
            final date = (d['completedAt'] as Timestamp?)?.toDate();
            final paid = (d['totalPaid'] as num?)?.toDouble();
            return Card(child: ListTile(leading: const Icon(Icons.receipt_long_outlined),
              title: Text(d['crop']?.toString() ?? ''),
              subtitle: Text('${d['seller'] ?? ''}\n${d['quantityKg'] ?? ''} ${loc.t('community_kg_unit')}'
                '${date == null ? '' : '\n${MaterialLocalizations.of(context).formatMediumDate(date)}'}'),
              trailing: Text(paid == null ? '—' : '₹${paid.toStringAsFixed(2)}')));
          });
      }));
  }
}

class ConsumerCalculatorScreen extends StatefulWidget {
  const ConsumerCalculatorScreen({super.key});
  @override
  State<ConsumerCalculatorScreen> createState() => _ConsumerCalculatorScreenState();
}
class _ConsumerCalculatorScreenState extends State<ConsumerCalculatorScreen> {
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  @override
  void dispose() { _quantity.dispose(); _price.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final q = double.tryParse(_quantity.text.trim());
    final p = double.tryParse(_price.text.trim());
    final valid = q != null && p != null && q.isFinite && p.isFinite && q >= 0 && p >= 0 && (q * p).isFinite;
    return Scaffold(appBar: AppBar(title: Text(loc.t('consumer_calculator'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(controller: _quantity, onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '${loc.t('quantity')} (${loc.t('community_kg_unit')})')),
        const SizedBox(height: 16),
        TextField(controller: _price, onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: loc.t('mk_price_per_kg'))),
        const SizedBox(height: 24),
        Text('${loc.t('consumer_total')}: ${valid ? '₹${(q * p).toStringAsFixed(2)}' : '—'}',
          style: Theme.of(context).textTheme.headlineSmall),
        if (!valid && (_quantity.text.isNotEmpty || _price.text.isNotEmpty))
          Text(loc.t('consumer_valid_amount')),
      ]));
  }
}

/// Consumer-only, account-scoped notes. Stored locally for offline access.
class ConsumerNotesScreen extends StatefulWidget {
  const ConsumerNotesScreen({super.key});
  @override
  State<ConsumerNotesScreen> createState() => _ConsumerNotesScreenState();
}
class _ConsumerNotesScreenState extends State<ConsumerNotesScreen> {
  final _text = TextEditingController();
  late final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  List<String> _notes = [];
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      if (_uid != null) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('consumer_notes_$_uid');
        if (raw != null) _notes = (jsonDecode(raw) as List).whereType<String>().toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }
  Future<void> _save(List<String> next) async {
    if (_saving || _uid == null || FirebaseAuth.instance.currentUser?.uid != _uid) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('consumer_notes_$_uid', jsonEncode(next))) throw StateError('Save failed');
      if (mounted) setState(() { _notes = next; _text.clear(); });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('consumer_save_error'))));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(loc.t('consumer_notes'))),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
      _uid == null ? Center(child: Text(loc.t('consumer_sign_in'))) : ListView(padding: const EdgeInsets.all(20), children: [
        Text(loc.t('consumer_notes_local')),
        TextField(controller: _text, minLines: 2, maxLines: 6,
          decoration: InputDecoration(hintText: loc.t('workspace_note_content_hint'))),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _saving ? null : () { final t = _text.text.trim(); if (t.isNotEmpty) _save([t, ..._notes]); },
          icon: const Icon(Icons.add), label: Text(loc.t('save'))),
        if (_notes.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(loc.t('workspace_notes_empty'))),
        for (var i = 0; i < _notes.length; i++) Card(child: ListTile(title: Text(_notes[i]),
          trailing: IconButton(tooltip: loc.delete, icon: const Icon(Icons.delete_outline), onPressed: _saving ? null : () async {
            final index = i;
            final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              content: Text(loc.t('workspace_delete_note_confirm')), actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.delete))]));
            if (yes == true && mounted) { final next = [..._notes]..removeAt(index); await _save(next); }
          }))),
      ]));
  }
}
