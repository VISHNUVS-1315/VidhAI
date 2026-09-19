import 'package:flutter/material.dart';
import '../../../data/models/market_selection.dart';
import '../../../locale/locale.dart';
import '../../../services/market_price_service.dart';

class MarketFilterSheet extends StatefulWidget {
  final List<String> states;
  final MarketSelection initial;
  const MarketFilterSheet({super.key, required this.states, required this.initial});
  @override
  State<MarketFilterSheet> createState() => _MarketFilterSheetState();
}
class _MarketFilterSheetState extends State<MarketFilterSheet> {
  late final Map<String, Set<String>> _selected = widget.initial.regions.map((s, d) => MapEntry(s, {...d}));
  final Map<String, List<String>> _districts = {};
  final Set<String> _loading = {};
  String _query = '';
  @override
  void initState() { super.initState(); for (final state in _selected.keys) { _load(state); } }
  Future<void> _load(String state) async {
    if (_districts.containsKey(state) || _loading.contains(state)) return;
    setState(() => _loading.add(state));
    final values = await MarketPriceService.instance.fetchDistricts(state);
    if (!mounted) return;
    setState(() { _loading.remove(state); _districts[state] = values; });
  }
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final states = {...widget.states, ..._selected.keys}.toList()..sort();
    return SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .85,
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Expanded(child: Text(loc.t('filter_by_location'), style: Theme.of(context).textTheme.titleLarge)),
          TextButton(onPressed: () => setState(() => _selected.clear()), child: Text(loc.t('all'))),
          IconButton(onPressed: () => Navigator.pop(context), tooltip: loc.cancel, icon: const Icon(Icons.close)),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: '${loc.t('state')} / ${loc.t('district')}'),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()))),
        Expanded(child: ListView(children: [for (final state in states)
          if (_query.isEmpty || state.toLowerCase().contains(_query) ||
            (_districts[state] ?? []).any((d) => d.toLowerCase().contains(_query)) || _selected.containsKey(state))
          ExpansionTile(key: ValueKey(state), initiallyExpanded: _selected.containsKey(state),
            onExpansionChanged: (open) { if (open) _load(state); },
            leading: Checkbox(value: _selected.containsKey(state), onChanged: (yes) {
              setState(() { if (yes == true) { _selected[state] = {}; } else { _selected.remove(state); } });
              if (yes == true) _load(state);
            }), title: Text(state), children: [
              if (_loading.contains(state)) const LinearProgressIndicator(),
              if (_districts[state]?.isEmpty == true) TextButton(
                onPressed: () { setState(() => _districts.remove(state)); _load(state); }, child: Text(loc.t('retry'))),
              CheckboxListTile(title: Text('${loc.t('all')} — ${loc.t('district')}'),
                value: _selected.containsKey(state) && _selected[state]!.isEmpty,
                onChanged: (_) => setState(() => _selected[state] = {})),
              for (final district in _districts[state] ?? <String>[])
                if (_query.isEmpty || state.toLowerCase().contains(_query) || district.toLowerCase().contains(_query))
                CheckboxListTile(title: Text(district), value: _selected[state]?.contains(district) ?? false,
                  onChanged: (yes) => setState(() {
                    final chosen = _selected.putIfAbsent(state, () => <String>{});
                    if (yes == true) { chosen.add(district); } else { chosen.remove(district); }
                  })),
            ]),
        ])),
        Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(context, MarketSelection(_selected)), child: Text(loc.t('apply'))))),
      ])));
  }
}
