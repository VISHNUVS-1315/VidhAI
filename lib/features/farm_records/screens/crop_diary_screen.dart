import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/features/farm_records/screens/expenses_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/data_service.dart';

class CropDiaryScreen extends StatefulWidget {
  const CropDiaryScreen({super.key});

  @override
  State<CropDiaryScreen> createState() => _CropDiaryScreenState();
}

class _CropDiaryScreenState extends State<CropDiaryScreen> {
  final DataService _service = DataService();
  final NumberFormat _currency = NumberFormat('#,##,##0.##', 'en_IN');

  List<_CropDiaryEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final farms = await _service.loadFarms();
      final entries = <_CropDiaryEntry>[];

      for (final farm in farms) {
        final cropsFuture = _service.loadCrops(farm.farmId);
        final expensesFuture = _service.loadExpenses(farm.farmId);
        final crops = await cropsFuture;
        final expenses = await expensesFuture;

        final expensesByCrop = <String, List<ExpenseRecord>>{
          for (final crop in crops) crop.id: <ExpenseRecord>[],
        };

        for (final expense in expenses) {
          CropRecord? assigned;

          final linkedCropId = expense.cropId?.trim() ?? '';
          if (linkedCropId.isNotEmpty) {
            for (final crop in crops) {
              if (crop.id == linkedCropId) {
                assigned = crop;
                break;
              }
            }
          }

          assigned ??= _bestCropForExpense(expense, crops);
          if (assigned != null) {
            expensesByCrop[assigned.id]?.add(expense);
          }
        }

        for (final crop in crops) {
          final cropExpenses = expensesByCrop[crop.id] ?? <ExpenseRecord>[];
          cropExpenses.sort((a, b) => b.date.compareTo(a.date));
          entries.add(
            _CropDiaryEntry(
              farm: farm,
              crop: crop,
              expenses: cropExpenses,
            ),
          );
        }
      }

      entries.sort((a, b) {
        if (a.crop.isActive != b.crop.isActive) {
          return a.crop.isActive ? -1 : 1;
        }
        return b.crop.plantingDate.compareTo(a.crop.plantingDate);
      });

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  CropRecord? _bestCropForExpense(
    ExpenseRecord expense,
    List<CropRecord> crops,
  ) {
    CropRecord? best;
    for (final crop in crops) {
      final start = _startOfDay(crop.plantingDate);
      final expenseDate = _startOfDay(expense.date);
      if (expenseDate.isBefore(start)) continue;

      final rawEnd = crop.endDate ??
          (crop.isActive ? null : crop.expectedHarvestDate);
      if (rawEnd != null && expenseDate.isAfter(_startOfDay(rawEnd))) {
        continue;
      }

      if (best == null || crop.plantingDate.isAfter(best.plantingDate)) {
        best = crop;
      }
    }
    return best;
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  double get _totalExpenses => _entries.fold<double>(
        0,
        (total, entry) => total + entry.totalExpenses,
      );

  String _money(double value) => '₹${_currency.format(value)}';

  String _date(DateTime value) => DateFormat('dd MMM yyyy').format(value);

  String _statusLabel(CropRecord crop, AppLocalizations loc) {
    switch (crop.status) {
      case 'active':
        return loc.active;
      case 'harvested':
        return loc.t('fd_end_status_harvested');
      case 'completed':
        return loc.t('fd_end_status_completed');
      case 'stopped':
        return loc.t('fd_end_status_stopped');
      case 'abandoned':
        return loc.t('fd_end_status_abandoned');
      case 'failed':
        return loc.t('fd_end_status_failed');
      default:
        return crop.status;
    }
  }

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
          loc.t('crop_diary'),
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: colors.brandDeep),
            )
          : RefreshIndicator(
              color: colors.brandDeep,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _buildSummary(colors, loc),
                  const SizedBox(height: 18),
                  if (_error != null)
                    _buildError(colors, loc)
                  else if (_entries.isEmpty)
                    _buildEmpty(colors, loc)
                  else
                    ..._entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCropCard(entry, colors, loc),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummary(VidhAIColorsX colors, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.brandDeep,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.t('crop_diary_desc'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  icon: Icons.spa_rounded,
                  value: _entries.length.toString(),
                  label: loc.crop,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryMetric(
                  icon: Icons.account_balance_wallet_rounded,
                  value: _money(_totalExpenses),
                  label: loc.totalExpenses,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropCard(
    _CropDiaryEntry entry,
    VidhAIColorsX colors,
    AppLocalizations loc,
  ) {
    final crop = entry.crop;
    final farmName =
        entry.farm.farmName.trim().isEmpty ? loc.farm : entry.farm.farmName;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showCropExpenses(entry),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.brandDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: colors.brandDeep,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crop.cropName.trim().isEmpty
                              ? loc.crop
                              : crop.cropName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          farmName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: crop.isActive
                          ? colors.brandDeep.withValues(alpha: 0.12)
                          : colors.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(crop, loc),
                      style: TextStyle(
                        color: crop.isActive
                            ? colors.brandDeep
                            : colors.onSurfaceMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: colors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _date(crop.plantingDate),
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    _money(entry.totalExpenses),
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 15,
                    color: colors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    loc.expenseCountLabel(entry.expenses.length.toString()),
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(VidhAIColorsX colors, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 58,
            color: colors.onSurfaceMuted,
          ),
          const SizedBox(height: 14),
          Text(
            loc.t('no_crops_found'),
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.t('crop_diary_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(VidhAIColorsX colors, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.danger, size: 46),
          const SizedBox(height: 12),
          Text(
            loc.errorUnavailable,
            style: TextStyle(
              color: colors.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _load,
            child: Text(loc.retry),
          ),
        ],
      ),
    );
  }

  Future<void> _showCropExpenses(_CropDiaryEntry entry) async {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.crop.cropName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onBackground,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _money(entry.totalExpenses),
                            style: TextStyle(
                              color: colors.brandDeep,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (entry.expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Text(
                      loc.noExpensesYet,
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entry.expenses.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: colors.borderColor, height: 1),
                      itemBuilder: (_, index) {
                        final expense = entry.expenses[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  colors.brandDeep.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: colors.brandDeep,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            expense.description.trim().isEmpty
                                ? expense.category
                                : expense.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onBackground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${expense.category} • ${_date(expense.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceMuted,
                              fontSize: 11,
                            ),
                          ),
                          trailing: Text(
                            _money(expense.amount),
                            style: TextStyle(
                              color: colors.onBackground,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ExpensesScreen(farmId: entry.farm.farmId),
                        ),
                      ).then((_) => _load());
                    },
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: Text(loc.viewRecords),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brandDeep,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CropDiaryEntry {
  final FarmProfile farm;
  final CropRecord crop;
  final List<ExpenseRecord> expenses;

  const _CropDiaryEntry({
    required this.farm,
    required this.crop,
    required this.expenses,
  });

  double get totalExpenses =>
      expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
}
