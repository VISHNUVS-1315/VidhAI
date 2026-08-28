import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidhai/features/schemes/models/scheme_model.dart';

class GovernmentSchemesScreen extends StatefulWidget {
  const GovernmentSchemesScreen({super.key});

  @override
  State<GovernmentSchemesScreen> createState() => _GovernmentSchemesScreenState();
}

class _GovernmentSchemesScreenState extends State<GovernmentSchemesScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GovernmentScheme> get _filteredSchemes {
    List<GovernmentScheme> schemes;
    if (_searchQuery.isNotEmpty) {
      schemes = GovernmentSchemeData.search(_searchQuery);
    } else {
      schemes = GovernmentSchemeData.getByCategory(_selectedCategory);
    }
    return schemes;
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Income Support': return const Color(0xFF4CAF50);
      case 'Crop Insurance': return const Color(0xFF2196F3);
      case 'Irrigation': return const Color(0xFF00BCD4);
      case 'Pension': return const Color(0xFF9C27B0);
      case 'Soil Health': return const Color(0xFF795548);
      case 'Market Access': return const Color(0xFFFF9800);
      case 'Credit': return const Color(0xFFE91E63);
      case 'Water Conservation': return const Color(0xFF03A9F4);
      case 'Organic Farming': return const Color(0xFF8BC34A);
      case 'Land Records': return const Color(0xFF607D8B);
      case 'Food Processing': return const Color(0xFFFF5722);
      default: return const Color(0xFF4CAF50);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Income Support': return Icons.account_balance_wallet_rounded;
      case 'Crop Insurance': return Icons.shield_rounded;
      case 'Irrigation': return Icons.water_drop_rounded;
      case 'Pension': return Icons.elderly_rounded;
      case 'Soil Health': return Icons.landscape_rounded;
      case 'Market Access': return Icons.store_rounded;
      case 'Credit': return Icons.credit_card_rounded;
      case 'Water Conservation': return Icons.waves_rounded;
      case 'Organic Farming': return Icons.eco_rounded;
      case 'Land Records': return Icons.map_rounded;
      case 'Food Processing': return Icons.restaurant_rounded;
      default: return Icons.account_balance_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemes = _filteredSchemes;
    final categories = GovernmentSchemeData.categories;

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
          'Government Schemes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search schemes...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.35), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.35), size: 18),
                        onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
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
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = categories[i];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat, style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  )),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4CAF50),
                  backgroundColor: const Color(0xFF111827),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.1),
                  ),
                  onSelected: (_) => setState(() { _selectedCategory = cat; _searchQuery = ''; _searchController.clear(); }),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          Expanded(
            child: schemes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text('No schemes found', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: schemes.length,
                    itemBuilder: (context, i) => _buildSchemeCard(schemes[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemeCard(GovernmentScheme scheme) {
    final color = _categoryColor(scheme.category);
    return GestureDetector(
      onTap: () => _showSchemeDetail(scheme),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon(scheme.category), color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scheme.name,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!scheme.isCentral)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('STATE', style: TextStyle(color: Color(0xFFFF9800), fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(scheme.category, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    scheme.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  void _showSchemeDetail(GovernmentScheme scheme) {
    final color = _categoryColor(scheme.category);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_categoryIcon(scheme.category), color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scheme.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(scheme.category, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _detailSection('About', scheme.description, Icons.info_outline_rounded),
            _detailSection('Eligibility', scheme.eligibility, Icons.person_outline_rounded),
            _detailSection('Benefits', scheme.benefits, Icons.card_giftcard_rounded),
            _detailSection('How to Apply', scheme.howToApply, Icons.app_registration_rounded),
            if (scheme.documents.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.description_outlined, color: color.withValues(alpha: 0.7), size: 18),
                  const SizedBox(width: 8),
                  Text('Required Documents', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: scheme.documents.map((doc) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(doc, style: TextStyle(color: color, fontSize: 12)),
                )).toList(),
              ),
            ],
            if (scheme.officialWebsite.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: scheme.officialWebsite));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Website URL copied: ${scheme.officialWebsite}'),
                        backgroundColor: const Color(0xFF4CAF50),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                  icon: Icon(Icons.open_in_new_rounded, color: color, size: 18),
                  label: Text('Visit Official Website', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            if (scheme.helpline.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: scheme.helpline));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Helpline number copied: ${scheme.helpline}'),
                        backgroundColor: const Color(0xFF4CAF50),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                  icon: const Icon(Icons.phone_rounded, color: Color(0xFF4CAF50), size: 18),
                  label: Text('Helpline: ${scheme.helpline}', style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, String content, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(content, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
