import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/services/data_service.dart';

class PesticideScreen extends StatefulWidget {
  final String farmId;
  const PesticideScreen({super.key, required this.farmId});

  @override
  State<PesticideScreen> createState() => _PesticideScreenState();
}

class _PesticideScreenState extends State<PesticideScreen> {
  final DataService _service = DataService();
  late String _farmId;
  List<PesticideRecord> _records = [];
  bool _isLoading = true;

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _greenAccent = Color(0xFF4CAF50);
  static const Color _dangerColor = Color(0xFFEF4444);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _farmId = widget.farmId;
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final records = await _service.loadPesticides(_farmId);
    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

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
          'Pesticide Records',
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

  Widget _buildItem(PesticideRecord record) {
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
                    color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bug_report,
                    color: Color(0xFFFF9800),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.productName,
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
                        _formatDate(record.date),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _infoChip(Icons.straighten, 'Qty', record.quantity),
                _infoChip(Icons.landscape, 'Area', record.applicationArea),
                _infoChip(Icons.track_changes, 'Purpose', record.purpose),
                if (record.crop != null && record.crop!.isNotEmpty)
                  _infoChip(Icons.eco, 'Crop', record.crop!),
              ],
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.notes!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$label: $value',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(PesticideRecord record) {
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
          'Delete pesticide record for "${record.productName}"?',
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
              await _service.deletePesticide(record.id, _farmId);
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

  void _showForm({PesticideRecord? existing}) {
    final nameCtrl = TextEditingController(text: existing?.productName ?? '');
    final dateCtrl = TextEditingController(
      text: existing != null ? _formatDate(existing.date) : '',
    );
    final qtyCtrl = TextEditingController(text: existing?.quantity ?? '');
    final areaCtrl = TextEditingController(
      text: existing?.applicationArea ?? '',
    );
    final purposeCtrl = TextEditingController(text: existing?.purpose ?? '');
    final cropCtrl = TextEditingController(text: existing?.crop ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime selectedDate = existing?.date ?? DateTime.now();

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
                        existing != null
                            ? 'Edit Pesticide Record'
                            : 'Add Pesticide Record',
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
                        _label('Product Name'),
                        const SizedBox(height: 8),
                        _input(nameCtrl, 'e.g. Cypermethrin 25 EC'),
                        const SizedBox(height: 16),
                        _label('Date'),
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
                        _label('Quantity'),
                        const SizedBox(height: 8),
                        _input(qtyCtrl, 'e.g. 500 ml'),
                        const SizedBox(height: 16),
                        _label('Application Area'),
                        const SizedBox(height: 8),
                        _input(areaCtrl, 'e.g. 2 acres, North Field'),
                        const SizedBox(height: 16),
                        _label('Purpose'),
                        const SizedBox(height: 8),
                        _input(purposeCtrl, 'e.g. Aphid control'),
                        const SizedBox(height: 16),
                        _label('Crop (optional)'),
                        const SizedBox(height: 8),
                        _input(cropCtrl, 'e.g. Wheat, Rice'),
                        const SizedBox(height: 16),
                        _label('Notes (optional)'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: notesCtrl,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: _inputDecoration('Additional notes'),
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
                        if (nameCtrl.text.isEmpty ||
                            qtyCtrl.text.isEmpty ||
                            areaCtrl.text.isEmpty ||
                            purposeCtrl.text.isEmpty) {
                          return;
                        }
                        if (existing != null) {
                          final updated = PesticideRecord(
                            id: existing.id,
                            farmId: _farmId,
                            productName: nameCtrl.text,
                            date: selectedDate,
                            quantity: qtyCtrl.text,
                            applicationArea: areaCtrl.text,
                            purpose: purposeCtrl.text,
                            crop: cropCtrl.text.isNotEmpty
                                ? cropCtrl.text
                                : null,
                            notes: notesCtrl.text.isNotEmpty
                                ? notesCtrl.text
                                : null,
                          );
                          await _service.savePesticide(updated);
                        } else {
                          final record = PesticideRecord(
                            id: _service.generateId(),
                            farmId: _farmId,
                            productName: nameCtrl.text,
                            date: selectedDate,
                            quantity: qtyCtrl.text,
                            applicationArea: areaCtrl.text,
                            purpose: purposeCtrl.text,
                            crop: cropCtrl.text.isNotEmpty
                                ? cropCtrl.text
                                : null,
                            notes: notesCtrl.text.isNotEmpty
                                ? notesCtrl.text
                                : null,
                          );
                          await _service.savePesticide(record);
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
              'No pesticide records',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track pesticide applications by tapping the + button.',
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
