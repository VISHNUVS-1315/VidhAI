import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class ExpensesScreen extends StatefulWidget {
  final String farmId;
  const ExpensesScreen({super.key, required this.farmId});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final DataService _service = DataService();
  final ImagePicker _picker = ImagePicker();
  late String _farmId;
  List<ExpenseRecord> _expenses = [];
  bool _isLoading = true;
  String? _selectedCategory;
  File? _receiptFile;

  VidhAIColorsX get _colors => VidhAIColorsX(context);

  static const List<String> _categories = [
    'Seeds',
    'Fertilizer',
    'Labor',
    'Equipment',
    'Irrigation',
    'Transport',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _farmId = widget.farmId;
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await _service.loadExpenses(_farmId);
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    }
  }

  double get _totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  String _formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  String _formatCurrency(double v) => '₹${v.toStringAsFixed(2)}';

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Seeds':
        return const Color(0xFF8BC34A);
      case 'Fertilizer':
        return const Color(0xFFFF9800);
      case 'Labor':
        return const Color(0xFF2196F3);
      case 'Equipment':
        return const Color(0xFF9C27B0);
      case 'Irrigation':
        return const Color(0xFF00BCD4);
      case 'Transport':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFF607D8B);
    }
  }

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
          loc.expenses,
          style: TextStyle(
              color: _colors.onBackground, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _colors.brandDeep,
        onPressed: () => _showExpenseForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _colors.brandDeep))
          : RefreshIndicator(
              color: _colors.brandDeep,
              onRefresh: _loadExpenses,
              child: _expenses.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildTotalSummary(),
                        const SizedBox(height: 16),
                        ..._expenses.map((e) => _buildExpenseItem(e)),
                      ],
                    ),
            ),
    );
  }

  Widget _buildTotalSummary() {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _colors.brandDeep.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long, color: _colors.brandDeep, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.expenseCountLabel(_expenses.length.toString()),
                  style: TextStyle(
                    color: _colors.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(_totalExpenses),
                  style: TextStyle(
                    color: _colors.onBackground,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(ExpenseRecord expense) {
    return Dismissible(
      key: Key(expense.id),
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
      confirmDismiss: (_) => _confirmDelete(expense),
      child: GestureDetector(
        onTap: () => _showExpenseForm(expense: expense),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _colors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      _categoryColor(expense.category).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _categoryIcon(expense.category),
                  color: _categoryColor(expense.category),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryColor(expense.category)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            expense.category,
                            style: TextStyle(
                              color: _categoryColor(expense.category),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (expense.description.isNotEmpty)
                      Text(
                        expense.description,
                        style: TextStyle(
                          color: _colors.onBackground,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(expense.date),
                      style: TextStyle(
                        color: _colors.onSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCurrency(expense.amount),
                      style: TextStyle(
                        color: _colors.onBackground,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (expense.vendor != null && expense.vendor!.isNotEmpty)
                      Text(
                        expense.vendor!,
                        style: TextStyle(
                          color: _colors.onSurfaceMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Seeds':
        return Icons.spa;
      case 'Fertilizer':
        return Icons.science;
      case 'Labor':
        return Icons.people;
      case 'Equipment':
        return Icons.build;
      case 'Irrigation':
        return Icons.water_drop;
      case 'Transport':
        return Icons.local_shipping;
      default:
        return Icons.more_horiz;
    }
  }

  Future<bool?> _confirmDelete(ExpenseRecord expense) {
    final loc = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.deleteExpense,
          style: TextStyle(
              color: _colors.onBackground, fontWeight: FontWeight.w600),
        ),
        content: Text(
          loc.deleteExpenseConfirm(
              expense.category, _formatCurrency(expense.amount)),
          style: TextStyle(color: _colors.onBackground, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              loc.cancel,
              style: TextStyle(
                color: _colors.onSurfaceMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _service.deleteExpense(expense.id, _farmId);
              if (ctx.mounted) {
                Navigator.pop(ctx, true);
              }
              _loadExpenses();
            },
            child: Text(
              loc.delete,
              style: TextStyle(color: _colors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExpenseForm({ExpenseRecord? expense}) async {
    final crops = await _service.loadCrops(_farmId);
    if (!mounted) return;

    _selectedCategory = expense?.category;
    _receiptFile = null;
    final loc = AppLocalizations.of(context);
    final amountCtrl = TextEditingController(
      text: expense != null ? expense.amount.toString() : '',
    );
    final dateCtrl = TextEditingController(
      text: expense != null ? _formatDate(expense.date) : '',
    );
    final descCtrl = TextEditingController(text: expense?.description ?? '');
    final vendorCtrl = TextEditingController(text: expense?.vendor ?? '');
    DateTime selectedDate = expense?.date ?? DateTime.now();

    String? selectedCropId = expense?.cropId;
    if (selectedCropId != null &&
        !crops.any((crop) => crop.id == selectedCropId)) {
      selectedCropId = null;
    }
    if (selectedCropId == null && crops.isNotEmpty) {
      CropRecord? bestMatch;
      for (final crop in crops) {
        final expenseDay =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        final start = DateTime(
          crop.plantingDate.year,
          crop.plantingDate.month,
          crop.plantingDate.day,
        );
        final rawEnd =
            crop.endDate ?? (crop.isActive ? null : crop.expectedHarvestDate);
        final end = rawEnd == null
            ? null
            : DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
        final fits = !expenseDay.isBefore(start) &&
            (end == null || !expenseDay.isAfter(end));
        if (fits &&
            (bestMatch == null ||
                crop.plantingDate.isAfter(bestMatch.plantingDate))) {
          bestMatch = crop;
        }
      }
      if (bestMatch == null) {
        for (final crop in crops) {
          if (crop.isActive) {
            bestMatch = crop;
            break;
          }
        }
      }
      bestMatch ??= crops.first;
      selectedCropId = bestMatch.id;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).size.height * 0.9
                : MediaQuery.of(context).size.height * 0.75,
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
                        expense != null ? loc.editExpense : loc.addExpense,
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
                        if (crops.isNotEmpty) ...[
                          Text(
                            loc.crop,
                            style: TextStyle(
                              color: _colors.onBackground,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: _colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _colors.borderColor,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedCropId,
                                hint: Text(
                                  loc.crop,
                                  style: TextStyle(
                                    color: _colors.onSurfaceMuted,
                                  ),
                                ),
                                dropdownColor: _colors.surface,
                                style: TextStyle(
                                  color: _colors.onBackground,
                                  fontSize: 14,
                                ),
                                items: crops
                                    .map(
                                      (crop) => DropdownMenuItem<String>(
                                        value: crop.id,
                                        child: Text(
                                          crop.cropName.trim().isEmpty
                                              ? loc.crop
                                              : crop.cropName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setModalState(
                                  () => selectedCropId = value,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          loc.category,
                          style: TextStyle(
                            color: _colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _colors.borderColor,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedCategory,
                              hint: Text(
                                loc.selectCategoryHint,
                                style: TextStyle(
                                  color: _colors.onSurfaceMuted,
                                ),
                              ),
                              dropdownColor: _colors.surface,
                              style: TextStyle(
                                color: _colors.onBackground,
                                fontSize: 14,
                              ),
                              items: _categories
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setModalState(() => _selectedCategory = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.amount,
                          style: TextStyle(
                            color: _colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: _colors.onBackground),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: _colors.onSurfaceMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.currency_rupee,
                              color: _colors.brandDeep,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: _colors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.date,
                          style: TextStyle(
                            color: _colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                          decoration: InputDecoration(
                            hintText: loc.selectDate,
                            hintStyle: TextStyle(
                              color: _colors.onSurfaceMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.calendar_today,
                              color: _colors.brandDeep,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: _colors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.description,
                          style: TextStyle(
                            color: _colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descCtrl,
                          style: TextStyle(color: _colors.onBackground),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: loc.hintDescription,
                            hintStyle: TextStyle(
                              color: _colors.onSurfaceMuted,
                            ),
                            filled: true,
                            fillColor: _colors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.vendorOptional,
                          style: TextStyle(
                            color: _colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: vendorCtrl,
                          style: TextStyle(color: _colors.onBackground),
                          decoration: InputDecoration(
                            hintText: loc.hintVendor,
                            hintStyle: TextStyle(
                              color: _colors.onSurfaceMuted,
                            ),
                            filled: true,
                            fillColor: _colors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.receiptPhotoOptional,
                          style: TextStyle(
                            color: _colors.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final source =
                                await showModalBottomSheet<ImageSource>(
                              context: ctx,
                              backgroundColor: _colors.surface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (_) => SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Icon(
                                          Icons.camera_alt,
                                          color: _colors.brandDeep,
                                        ),
                                        title: Text(
                                          loc.camera,
                                          style: TextStyle(
                                            color: _colors.onBackground,
                                          ),
                                        ),
                                        onTap: () => Navigator.pop(
                                          ctx,
                                          ImageSource.camera,
                                        ),
                                      ),
                                      ListTile(
                                        leading: Icon(
                                          Icons.photo_library,
                                          color: _colors.brandDeep,
                                        ),
                                        title: Text(
                                          loc.gallery,
                                          style: TextStyle(
                                            color: _colors.onBackground,
                                          ),
                                        ),
                                        onTap: () => Navigator.pop(
                                          ctx,
                                          ImageSource.gallery,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            if (source != null) {
                              final picked = await _picker.pickImage(
                                source: source,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  _receiptFile = File(picked.path);
                                });
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: _receiptFile != null ? 120 : 80,
                            decoration: BoxDecoration(
                              color: _colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _colors.borderColor,
                              ),
                              image: _receiptFile != null
                                  ? DecorationImage(
                                      image: FileImage(_receiptFile!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _receiptFile == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        color: _colors.onSurfaceMuted,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        loc.tapToAddReceipt,
                                        style: TextStyle(
                                          color: _colors.onSurfaceMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                : Align(
                                    alignment: AlignmentDirectional.topEnd,
                                    child: Container(
                                      margin: const EdgeInsets.all(6),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: _colors.danger,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                          ),
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
                        if (_selectedCategory == null ||
                            amountCtrl.text.isEmpty) {
                          return;
                        }
                        final amount = double.tryParse(amountCtrl.text) ?? 0;
                        if (amount <= 0) return;

                        if (expense != null) {
                          final updated = expense.copyWith(
                            category: _selectedCategory,
                            cropId: selectedCropId,
                            amount: amount,
                            date: selectedDate,
                            description: descCtrl.text,
                            vendor: vendorCtrl.text,
                          );
                          await _service.saveExpense(updated);
                        } else {
                          final record = ExpenseRecord(
                            id: _service.generateId(),
                            farmId: _farmId,
                            category: _selectedCategory!,
                            cropId: selectedCropId,
                            amount: amount,
                            date: selectedDate,
                            description: descCtrl.text,
                            vendor: vendorCtrl.text,
                          );
                          await _service.saveExpense(record);
                        }
                        if (mounted && ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadExpenses();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colors.brandDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        expense != null ? loc.update : loc.save,
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

  Widget _buildEmptyState() {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              color: _colors.onSurfaceMuted,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              loc.noExpensesYet,
              style: TextStyle(
                color: _colors.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.trackFarmExpenses,
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
