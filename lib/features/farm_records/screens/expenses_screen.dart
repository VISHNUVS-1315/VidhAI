import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/services/data_service.dart';

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

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _greenAccent = Color(0xFF4CAF50);
  static const Color _dangerColor = Color(0xFFEF4444);

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

  double get _totalExpenses =>
      _expenses.fold(0.0, (sum, e) => sum + e.amount);

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
          'Expenses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _greenAccent,
        onPressed: () => _showExpenseForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _greenAccent))
          : RefreshIndicator(
              color: _greenAccent,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _greenAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long, color: _greenAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_expenses.length} expense${_expenses.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(_totalExpenses),
                  style: const TextStyle(
                    color: Colors.white,
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
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _dangerColor,
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
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _categoryColor(expense.category).withValues(alpha: 0.15),
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
                            color:
                                _categoryColor(expense.category).withValues(alpha: 0.15),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(expense.date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (expense.vendor != null && expense.vendor!.isNotEmpty)
                      Text(
                        expense.vendor!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
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
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Expense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this ${expense.category} expense of ${_formatCurrency(expense.amount)}?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
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
            child: const Text(
              'Delete',
              style: TextStyle(color: _dangerColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseForm({ExpenseRecord? expense}) {
    _selectedCategory = expense?.category;
    _receiptFile = null;
    final amountCtrl = TextEditingController(
      text: expense != null ? expense.amount.toString() : '',
    );
    final dateCtrl = TextEditingController(
      text: expense != null ? _formatDate(expense.date) : '',
    );
    final descCtrl = TextEditingController(text: expense?.description ?? '');
    final vendorCtrl = TextEditingController(text: expense?.vendor ?? '');
    DateTime selectedDate = expense?.date ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).size.height * 0.9
                : MediaQuery.of(context).size.height * 0.75,
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
                        expense != null ? 'Edit Expense' : 'Add Expense',
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
                        const Text(
                          'Category',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                              value: _selectedCategory,
                              hint: Text(
                                'Select category',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              dropdownColor: _cardColor,
                              style: const TextStyle(
                                color: Colors.white,
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
                        const Text(
                          'Amount (₹)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            prefixIcon: const Icon(
                              Icons.currency_rupee,
                              color: _greenAccent,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: _cardColor,
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
                        const Text(
                          'Date',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                          decoration: InputDecoration(
                            hintText: 'Select date',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            prefixIcon: const Icon(
                              Icons.calendar_today,
                              color: _greenAccent,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: _cardColor,
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
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descCtrl,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'What was this expense for?',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            filled: true,
                            fillColor: _cardColor,
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
                        const Text(
                          'Vendor (optional)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: vendorCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Vendor name',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            filled: true,
                            fillColor: _cardColor,
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
                        const Text(
                          'Receipt Photo (optional)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final source = await showModalBottomSheet<ImageSource>(
                              context: ctx,
                              backgroundColor: _cardColor,
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
                                        leading: const Icon(
                                          Icons.camera_alt,
                                          color: _greenAccent,
                                        ),
                                        title: const Text(
                                          'Camera',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        onTap: () => Navigator.pop(
                                          ctx,
                                          ImageSource.camera,
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.photo_library,
                                          color: _greenAccent,
                                        ),
                                        title: const Text(
                                          'Gallery',
                                          style: TextStyle(
                                            color: Colors.white,
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
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
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
                                        color: Colors.white.withValues(alpha: 0.3),
                                        size: 28,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tap to add receipt',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                : Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      margin: const EdgeInsets.all(6),
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: _dangerColor,
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
                        backgroundColor: _greenAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        expense != null ? 'Update' : 'Save',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              color: Colors.white.withValues(alpha: 0.15),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No expenses yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your farm expenses by tapping the + button.',
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
