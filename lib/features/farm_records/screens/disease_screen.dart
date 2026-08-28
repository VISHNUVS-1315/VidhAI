import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/services/data_service.dart';

class DiseaseScreen extends StatefulWidget {
  final String farmId;
  const DiseaseScreen({super.key, required this.farmId});

  @override
  State<DiseaseScreen> createState() => _DiseaseScreenState();
}

class _DiseaseScreenState extends State<DiseaseScreen> {
  final DataService _service = DataService();
  late String _farmId;
  List<DiseaseRecord> _records = [];
  bool _isLoading = true;
  String? _selectedSeverity;
  String? _selectedStatus;

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _greenAccent = Color(0xFF4CAF50);
  static const Color _dangerColor = Color(0xFFEF4444);

  static const List<String> _severities = ['low', 'medium', 'high', 'critical'];
  static const List<String> _statuses = ['open', 'treating', 'resolved'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _farmId = widget.farmId;
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final records = await _service.loadDiseases(_farmId);
    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

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

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return const Color(0xFFEF4444);
      case 'treating':
        return const Color(0xFFFF9800);
      case 'resolved':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF607D8B);
    }
  }

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
          'Disease & Pest Records',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _greenAccent,
        onPressed: () => _showForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _greenAccent))
          : RefreshIndicator(
              color: _greenAccent,
              onRefresh: _loadRecords,
              child: _records.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (_, i) => _buildItem(_records[i]),
                    ),
            ),
    );
  }

  Widget _buildItem(DiseaseRecord record) {
    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _dangerColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(record),
      child: GestureDetector(
        onTap: () => _showForm(existing: record),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _severityColor(record.severity).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.bug_report,
                      color: _severityColor(record.severity),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.problem,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(record.detectedDate),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _severityColor(record.severity).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record.severity.toUpperCase(),
                          style: TextStyle(
                            color: _severityColor(record.severity),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(record.status).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.status,
                          style: TextStyle(
                            color: _statusColor(record.status),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (record.crop != null && record.crop!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.eco,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        record.crop!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (record.treatment != null && record.treatment!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: 12,
                      color: _greenAccent.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        record.treatment!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(DiseaseRecord record) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Record',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Delete disease/pest record for "${record.problem}"?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _service.deleteDisease(record.id, _farmId);
              if (ctx.mounted) {
                Navigator.pop(ctx, true);
              }
              _loadRecords();
            },
            child: const Text('Delete', style: TextStyle(color: _dangerColor)),
          ),
        ],
      ),
    );
  }

  void _showForm({DiseaseRecord? existing}) {
    _selectedSeverity = existing?.severity;
    _selectedStatus = existing?.status;
    final problemCtrl = TextEditingController(text: existing?.problem ?? '');
    final dateCtrl = TextEditingController(
      text: existing != null ? _formatDate(existing.detectedDate) : '',
    );
    final cropCtrl = TextEditingController(text: existing?.crop ?? '');
    final treatmentCtrl = TextEditingController(
      text: existing?.treatment ?? '',
    );
    DateTime selectedDate = existing?.detectedDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).size.height * 0.9
                : MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        existing != null ? 'Edit Record' : 'Add Disease / Pest',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Detected Date'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: dateCtrl,
                          readOnly: true,
                          style: const TextStyle(color: Colors.white),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: _greenAccent,
                                      surface: _cardColor,
                                    ),
                                    dialogBackgroundColor: _cardColor,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() {
                                selectedDate = picked;
                                dateCtrl.text = _formatDate(picked);
                              });
                            }
                          },
                          decoration: _inputDecoration('Select date'),
                        ),
                        const SizedBox(height: 16),
                        _label('Crop (optional)'),
                        const SizedBox(height: 8),
                        _input(cropCtrl, 'e.g. Rice, Wheat'),
                        const SizedBox(height: 16),
                        _label('Problem'),
                        const SizedBox(height: 8),
                        _input(problemCtrl, 'e.g. Brown spot, Aphid attack'),
                        const SizedBox(height: 16),
                        _label('Severity'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedSeverity,
                              hint: Text(
                                'Select severity',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              dropdownColor: _cardColor,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              items: _severities
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: _severityColor(s),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              s[0].toUpperCase() +
                                                  s.substring(1),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setModalState(() => _selectedSeverity = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _label('Treatment (optional)'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: treatmentCtrl,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: _inputDecoration(
                            'Describe treatment applied or planned',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _label('Status'),
                        const SizedBox(height: 8),
                        Row(
                          children: _statuses.map((s) {
                            final isSelected = _selectedStatus == s;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setModalState(() => _selectedStatus = s),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _statusColor(s).withValues(alpha: 0.2)
                                        : _cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? _statusColor(s)
                                          : Colors.white.withValues(alpha: 0.08),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      s[0].toUpperCase() + s.substring(1),
                                      style: TextStyle(
                                        color: isSelected
                                            ? _statusColor(s)
                                            : Colors.white.withValues(alpha: 0.5),
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (problemCtrl.text.isEmpty ||
                            _selectedSeverity == null ||
                            _selectedStatus == null) {
                          return;
                        }
                        if (existing != null) {
                          final updated = DiseaseRecord(
                            id: existing.id,
                            farmId: _farmId,
                            detectedDate: selectedDate,
                            crop: cropCtrl.text.isNotEmpty
                                ? cropCtrl.text
                                : null,
                            problem: problemCtrl.text,
                            severity: _selectedSeverity!,
                            evidencePath: existing.evidencePath,
                            treatment: treatmentCtrl.text.isNotEmpty
                                ? treatmentCtrl.text
                                : null,
                            status: _selectedStatus!,
                            resolutionDate: _selectedStatus == 'resolved'
                                ? DateTime.now()
                                : existing.resolutionDate,
                          );
                          await _service.saveDisease(updated);
                        } else {
                          final record = DiseaseRecord(
                            id: _service.generateId(),
                            farmId: _farmId,
                            detectedDate: selectedDate,
                            crop: cropCtrl.text.isNotEmpty
                                ? cropCtrl.text
                                : null,
                            problem: problemCtrl.text,
                            severity: _selectedSeverity!,
                            treatment: treatmentCtrl.text.isNotEmpty
                                ? treatmentCtrl.text
                                : null,
                            status: _selectedStatus!,
                            resolutionDate: _selectedStatus == 'resolved'
                                ? DateTime.now()
                                : null,
                          );
                          await _service.saveDisease(record);
                        }
                        if (mounted && ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadRecords();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _greenAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        existing != null ? 'Update' : 'Save',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      filled: true,
      fillColor: _cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              Icons.bug_report,
              color: Colors.white.withValues(alpha: 0.15),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No disease records',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track diseases and pests by tapping the + button.',
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
