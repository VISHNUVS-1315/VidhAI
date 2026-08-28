import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/services/data_service.dart';

class FarmHistoryScreen extends StatefulWidget {
  final String farmId;
  const FarmHistoryScreen({super.key, required this.farmId});

  @override
  State<FarmHistoryScreen> createState() => _FarmHistoryScreenState();
}

class _FarmHistoryScreenState extends State<FarmHistoryScreen> {
  final DataService _service = DataService();
  late String _farmId;
  bool _isLoading = true;

  List<ExpenseRecord> _expenses = [];
  List<PesticideRecord> _pesticides = [];
  List<FertilizerRecord> _fertilizers = [];
  List<DiseaseRecord> _diseases = [];

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _greenAccent = Color(0xFF4CAF50);

  bool _expensesExpanded = false;
  bool _pesticidesExpanded = false;
  bool _fertilizersExpanded = false;
  bool _diseasesExpanded = false;
  bool _cropsExpanded = false;
  bool _eventsExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _farmId = widget.farmId;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.loadExpenses(_farmId),
      _service.loadPesticides(_farmId),
      _service.loadFertilizers(_farmId),
      _service.loadDiseases(_farmId),
    ]);
    if (mounted) {
      setState(() {
        _expenses = results[0] as List<ExpenseRecord>;
        _pesticides = results[1] as List<PesticideRecord>;
        _fertilizers = results[2] as List<FertilizerRecord>;
        _diseases = results[3] as List<DiseaseRecord>;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  bool get _hasAnyData =>
      _expenses.isNotEmpty ||
      _pesticides.isNotEmpty ||
      _fertilizers.isNotEmpty ||
      _diseases.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Farm History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _greenAccent))
          : RefreshIndicator(
              color: _greenAccent,
              onRefresh: _loadAll,
              child: _hasAnyData
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryHeader(),
                        const SizedBox(height: 12),
                        _buildCropSection(),
                        _buildPesticideSection(),
                        _buildFertilizerSection(),
                        _buildDiseaseSection(),
                        _buildExpenseSection(),
                        _buildEventsSection(),
                      ],
                    )
                  : _buildEmptyState(),
            ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _statItem(Icons.receipt_long, _expenses.length.toString(), 'Expenses'),
              _statItem(Icons.bug_report, _pesticides.length.toString(), 'Pesticides'),
              _statItem(Icons.science, _fertilizers.length.toString(), 'Fertilizers'),
              _statItem(Icons.healing, _diseases.length.toString(), 'Diseases'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String count, String label) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _greenAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _greenAccent, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCropSection() {
    final appliedCrops = _fertilizers
        .where((f) => f.crop != null && f.crop!.isNotEmpty)
        .map((f) => f.crop!)
        .toSet()
        .toList()
      ..sort();

    return _buildExpandableSection(
      title: 'Previous Crops',
      icon: Icons.eco,
      isExpanded: _cropsExpanded,
      onToggle: () => setState(() => _cropsExpanded = !_cropsExpanded),
      count: appliedCrops.length,
      child: appliedCrops.isEmpty
          ? _emptySectionText('No crop records found')
          : Column(
              children: appliedCrops.map((crop) {
                final count = _fertilizers
                    .where((f) => f.crop == crop)
                    .length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.eco,
                        size: 16,
                        color: _greenAccent.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        crop,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$count record${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPesticideSection() {
    return _buildExpandableSection(
      title: 'Previous Treatments',
      icon: Icons.bug_report,
      isExpanded: _pesticidesExpanded,
      onToggle: () =>
          setState(() => _pesticidesExpanded = !_pesticidesExpanded),
      count: _pesticides.length,
      child: _pesticides.isEmpty
          ? _emptySectionText('No treatment records found')
          : Column(
              children: _pesticides.map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bug_report,
                        size: 16,
                        color: const Color(0xFFFF9800).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.productName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${p.purpose} - ${_formatDate(p.date)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildFertilizerSection() {
    return _buildExpandableSection(
      title: 'Fertilizer Records',
      icon: Icons.science,
      isExpanded: _fertilizersExpanded,
      onToggle: () =>
          setState(() => _fertilizersExpanded = !_fertilizersExpanded),
      count: _fertilizers.length,
      child: _fertilizers.isEmpty
          ? _emptySectionText('No fertilizer records found')
          : Column(
              children: _fertilizers.map((f) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.science,
                        size: 16,
                        color: const Color(0xFF2196F3).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${f.product} (${f.type})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${f.quantity} - ${_formatDate(f.date)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildDiseaseSection() {
    return _buildExpandableSection(
      title: 'Disease Records',
      icon: Icons.healing,
      isExpanded: _diseasesExpanded,
      onToggle: () =>
          setState(() => _diseasesExpanded = !_diseasesExpanded),
      count: _diseases.length,
      child: _diseases.isEmpty
          ? _emptySectionText('No irrigation records found')
          : Column(
              children: _diseases.map((d) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.healing,
                        size: 16,
                        color: _severityColor(d.severity).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.problem,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${d.severity.toUpperCase()} - ${d.status} - ${_formatDate(d.detectedDate)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildExpenseSection() {
    return _buildExpandableSection(
      title: 'Previous Expenses',
      icon: Icons.receipt_long,
      isExpanded: _expensesExpanded,
      onToggle: () =>
          setState(() => _expensesExpanded = !_expensesExpanded),
      count: _expenses.length,
      child: _expenses.isEmpty
          ? _emptySectionText('No expense records found')
          : Column(
              children: _expenses.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 16,
                        color: _greenAccent.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.category} - ₹${e.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _formatDate(e.date),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEventsSection() {
    final events = _diseases
        .where((d) =>
            d.status == 'resolved' && d.resolutionDate != null)
        .toList()
      ..sort((a, b) => b.resolutionDate!.compareTo(a.resolutionDate!));

    return _buildExpandableSection(
      title: 'Important Events',
      icon: Icons.event,
      isExpanded: _eventsExpanded,
      onToggle: () =>
          setState(() => _eventsExpanded = !_eventsExpanded),
      count: events.length,
      child: events.isEmpty
          ? _emptySectionText('No important events recorded')
          : Column(
              children: events.map((d) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resolved: ${d.problem}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Detected: ${_formatDate(d.detectedDate)} | Resolved: ${_formatDate(d.resolutionDate!)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'low':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'high':
        return const Color(0xFFFF5722);
      case 'critical':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required int count,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _greenAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: _greenAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _greenAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: _greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _emptySectionText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              color: Colors.white.withValues(alpha: 0.15),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No history records yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your farm history will appear here once you start logging expenses, treatments, and other records.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
