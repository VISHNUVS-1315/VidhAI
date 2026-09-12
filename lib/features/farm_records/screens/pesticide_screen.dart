import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

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

  VidhAIColorsX get _colors => VidhAIColorsX(context);

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
          loc.pesticideRecords,
          style: TextStyle(
              color: _colors.onBackground, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _colors.brandDeep,
        onPressed: () => _showForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _colors.brandDeep))
          : RefreshIndicator(
              color: _colors.brandDeep,
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
    final loc = AppLocalizations.of(context);
    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsetsDirectional.only(end: 20),
        decoration: BoxDecoration(
          color: _colors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colors.borderColor),
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
                        style: TextStyle(
                          color: _colors.onBackground,
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
                          color: _colors.onSurfaceMuted,
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
                _infoChip(Icons.straighten, loc.qty, record.quantity),
                _infoChip(Icons.landscape, loc.area, record.applicationArea),
                _infoChip(Icons.track_changes, loc.purpose, record.purpose),
                if (record.crop != null && record.crop!.isNotEmpty)
                  _infoChip(Icons.eco, loc.crop, record.crop!),
              ],
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.notes!,
                style: TextStyle(
                  color: _colors.onSurfaceMuted,
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
        color: _colors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _colors.onSurfaceMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$label: $value',
              style: TextStyle(
                color: _colors.onSurfaceMuted,
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
    final loc = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.deleteRecord,
          style: TextStyle(
              color: _colors.onBackground, fontWeight: FontWeight.w600),
        ),
        content: Text(
          loc
              .t('delete_pesticide_record_confirm')
              .replaceAll('{product}', record.productName),
          style: TextStyle(color: _colors.onBackground, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              loc.cancel,
              style: TextStyle(color: _colors.onSurfaceMuted),
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
            child: Text(loc.delete, style: TextStyle(color: _colors.danger)),
          ),
        ],
      ),
    );
  }

  void _showForm({PesticideRecord? existing}) {
    final loc = AppLocalizations.of(context);
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
            decoration: BoxDecoration(
              color: _colors.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _colors.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        existing != null
                            ? loc.editPesticideRecord
                            : loc.addPesticideRecord,
                        style: TextStyle(
                          color: _colors.onBackground,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: _colors.onSurfaceMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: _colors.borderColor, height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(loc.productName),
                        const SizedBox(height: 8),
                        _input(nameCtrl, loc.hintProductNamePesticide),
                        const SizedBox(height: 16),
                        _label(loc.date),
                        const SizedBox(height: 8),
                        TextField(
                          controller: dateCtrl,
                          readOnly: true,
                          style: TextStyle(color: _colors.onBackground),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.dark(
                                      primary: _colors.brandDeep,
                                      surface: _colors.surface,
                                    ),
                                    dialogTheme: DialogThemeData(
                                        backgroundColor: _colors.surface),
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
                          decoration: _inputDecoration(loc.selectDate),
                        ),
                        const SizedBox(height: 16),
                        _label(loc.quantity),
                        const SizedBox(height: 8),
                        _input(qtyCtrl, loc.hintQuantityMl),
                        const SizedBox(height: 16),
                        _label(loc.applicationArea),
                        const SizedBox(height: 8),
                        _input(areaCtrl, loc.hintApplicationArea),
                        const SizedBox(height: 16),
                        _label(loc.purpose),
                        const SizedBox(height: 8),
                        _input(purposeCtrl, loc.hintPurpose),
                        const SizedBox(height: 16),
                        _label(loc.cropOptional),
                        const SizedBox(height: 8),
                        _input(cropCtrl, loc.hintCropWheatRice),
                        const SizedBox(height: 16),
                        _label(loc.notesOptional),
                        const SizedBox(height: 8),
                        TextField(
                          controller: notesCtrl,
                          style: TextStyle(color: _colors.onBackground),
                          maxLines: 3,
                          decoration: _inputDecoration(loc.hintNotes),
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
                            crop:
                                cropCtrl.text.isNotEmpty ? cropCtrl.text : null,
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
                            crop:
                                cropCtrl.text.isNotEmpty ? cropCtrl.text : null,
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
                        backgroundColor: _colors.brandDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        existing != null ? loc.update : loc.save,
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
      style: TextStyle(
        color: _colors.onBackground,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: _colors.onBackground),
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _colors.onSurfaceMuted),
      filled: true,
      fillColor: _colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              Icons.bug_report,
              color: _colors.onSurfaceMuted,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              loc.noPesticideRecords,
              style: TextStyle(
                color: _colors.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.trackPesticideApplications,
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
