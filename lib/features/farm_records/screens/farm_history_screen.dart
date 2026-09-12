import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

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

  VidhAIColorsX get _colors => VidhAIColorsX(context);

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
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _colors.bg,
      appBar: AppBar(
        backgroundColor: _colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(directionalIcon(context, Icons.arrow_back_ios),
              color: _colors.onBackground, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.farmHistory,
          style: TextStyle(
              color: _colors.onBackground, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _colors.brandDeep))
          : RefreshIndicator(
              color: _colors.brandDeep,
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
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.overview,
            style: TextStyle(
              color: _colors.onBackground,
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
              _statItem(Icons.receipt_long, _expenses.length.toString(),
                  loc.previousExpenses),
              _statItem(Icons.bug_report, _pesticides.length.toString(),
                  loc.previousTreatments),
              _statItem(Icons.science, _fertilizers.length.toString(),
                  loc.fertilizerRecords),
              _statItem(
                  Icons.healing, _diseases.length.toString(), loc.diseases),
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
            color: _colors.brandDeep.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _colors.brandDeep, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count,
          style: TextStyle(
            color: _colors.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _colors.onSurfaceMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCropSection() {
    final loc = AppLocalizations.of(context);
    final appliedCrops = _fertilizers
        .where((f) => f.crop != null && f.crop!.isNotEmpty)
        .map((f) => f.crop!)
        .toSet()
        .toList()
      ..sort();

    return _buildExpandableSection(
      title: loc.previousCrops,
      icon: Icons.eco,
      isExpanded: _cropsExpanded,
      onToggle: () => setState(() => _cropsExpanded = !_cropsExpanded),
      count: appliedCrops.length,
      child: appliedCrops.isEmpty
          ? _emptySectionText(loc.noCropRecordsFound)
          : Column(
              children: appliedCrops.map((crop) {
                final count = _fertilizers.where((f) => f.crop == crop).length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.eco,
                        size: 16,
                        color: _colors.brandDeep,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        crop,
                        style: TextStyle(
                          color: _colors.onBackground,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        loc.recordCountLabel('$count'),
                        style: TextStyle(
                          color: _colors.onSurfaceMuted,
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
    final loc = AppLocalizations.of(context);
    return _buildExpandableSection(
      title: loc.previousTreatments,
      icon: Icons.bug_report,
      isExpanded: _pesticidesExpanded,
      onToggle: () =>
          setState(() => _pesticidesExpanded = !_pesticidesExpanded),
      count: _pesticides.length,
      child: _pesticides.isEmpty
          ? _emptySectionText(loc.noTreatmentRecordsFound)
          : Column(
              children: _pesticides.map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _colors.surfaceMuted,
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
                              style: TextStyle(
                                color: _colors.onBackground,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${p.purpose} - ${_formatDate(p.date)}',
                              style: TextStyle(
                                color: _colors.onSurfaceMuted,
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
    final loc = AppLocalizations.of(context);
    return _buildExpandableSection(
      title: loc.fertilizerRecords,
      icon: Icons.science,
      isExpanded: _fertilizersExpanded,
      onToggle: () =>
          setState(() => _fertilizersExpanded = !_fertilizersExpanded),
      count: _fertilizers.length,
      child: _fertilizers.isEmpty
          ? _emptySectionText(loc.noFertilizerRecordsFound)
          : Column(
              children: _fertilizers.map((f) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _colors.surfaceMuted,
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
                              style: TextStyle(
                                color: _colors.onBackground,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${f.quantity} - ${_formatDate(f.date)}',
                              style: TextStyle(
                                color: _colors.onSurfaceMuted,
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
    final loc = AppLocalizations.of(context);
    return _buildExpandableSection(
      title: loc.diseaseRecords,
      icon: Icons.healing,
      isExpanded: _diseasesExpanded,
      onToggle: () => setState(() => _diseasesExpanded = !_diseasesExpanded),
      count: _diseases.length,
      child: _diseases.isEmpty
          ? _emptySectionText(loc.noIrrigationRecordsFound)
          : Column(
              children: _diseases.map((d) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.healing,
                        size: 16,
                        color:
                            _severityColor(d.severity).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.problem,
                              style: TextStyle(
                                color: _colors.onBackground,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${d.severity.toUpperCase()} - ${d.status} - ${_formatDate(d.detectedDate)}',
                              style: TextStyle(
                                color: _colors.onSurfaceMuted,
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
    final loc = AppLocalizations.of(context);
    return _buildExpandableSection(
      title: loc.previousExpenses,
      icon: Icons.receipt_long,
      isExpanded: _expensesExpanded,
      onToggle: () => setState(() => _expensesExpanded = !_expensesExpanded),
      count: _expenses.length,
      child: _expenses.isEmpty
          ? _emptySectionText(loc.noExpenseRecordsFound)
          : Column(
              children: _expenses.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 16,
                        color: _colors.brandDeep,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.category} - \u20B9${e.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: _colors.onBackground,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _formatDate(e.date),
                              style: TextStyle(
                                color: _colors.onSurfaceMuted,
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
    final loc = AppLocalizations.of(context);
    final events = _diseases
        .where((d) => d.status == 'resolved' && d.resolutionDate != null)
        .toList()
      ..sort((a, b) => b.resolutionDate!.compareTo(a.resolutionDate!));

    return _buildExpandableSection(
      title: loc.importantEvents,
      icon: Icons.event,
      isExpanded: _eventsExpanded,
      onToggle: () => setState(() => _eventsExpanded = !_eventsExpanded),
      count: events.length,
      child: events.isEmpty
          ? _emptySectionText(loc.noImportantEventsRecorded)
          : Column(
              children: events.map((d) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _colors.brandDeep,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${loc.resolvedPrefix} ${d.problem}',
                              style: TextStyle(
                                color: _colors.onBackground,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${loc.detectedPrefix} ${_formatDate(d.detectedDate)} | ${loc.resolvedPrefix} ${_formatDate(d.resolutionDate!)}',
                              style: TextStyle(
                                color: _colors.onSurfaceMuted,
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
        return _colors.brandDeep;
      case 'medium':
        return const Color(0xFFFF9800);
      case 'high':
        return const Color(0xFFFF5722);
      case 'critical':
        return _colors.danger;
      default:
        return _colors.onSurfaceMuted;
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
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.borderColor),
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
                      color: _colors.brandDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: _colors.brandDeep, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: _colors.onBackground,
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
                      color: _colors.brandDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: _colors.brandDeep,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: _colors.onSurfaceMuted,
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
          color: _colors.onSurfaceMuted,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              color: _colors.onSurfaceMuted,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              loc.noHistoryRecordsYet,
              style: TextStyle(
                color: _colors.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.farmHistoryEmptyDesc,
              style: TextStyle(
                color: _colors.onSurfaceMuted,
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
