import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/community_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _cropController = TextEditingController();
  final _stageController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _districtController = TextEditingController();
  final CommunityService _communityService = CommunityService();

  String _selectedCategory = 'general';
  String _buyerType = 'Consumer';
  DateTime? _selectedDate;
  bool _isPosting = false;

  @override
  void dispose() {
    _contentController.dispose();
    _cropController.dispose();
    _stageController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  bool get _isMarketPost =>
      _selectedCategory == 'available_soon' || _selectedCategory == 'demand';

  String get _dateLabel => _selectedCategory == 'demand'
      ? 'Required by date'
      : 'Expected harvest date';

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Post',
          style: TextStyle(
            color: colors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Post Type'),
            const SizedBox(height: 8),
            _buildPostTypeChips(),
            const SizedBox(height: 20),
            if (_selectedCategory != 'general') ...[
              _field(
                controller: _cropController,
                label: _selectedCategory == 'demand'
                    ? 'Product / Crop needed'
                    : 'Crop',
                hint: 'e.g. Tomato',
              ),
              const SizedBox(height: 12),
            ],
            if (_selectedCategory == 'problem' ||
                _selectedCategory == 'experience') ...[
              _field(
                controller: _stageController,
                label: 'Crop Stage (optional)',
                hint: 'e.g. Flowering stage',
              ),
              const SizedBox(height: 12),
            ],
            if (_isMarketPost) ...[
              _field(
                controller: _quantityController,
                label: 'Approx Quantity (kg)',
                hint: 'e.g. 350',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _priceController,
                label: _selectedCategory == 'demand'
                    ? 'Expected Price (₹/kg)'
                    : 'Expected Price (₹/kg) - optional',
                hint: 'e.g. 30',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _inputDecoration(_dateLabel),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18, color: colors.brandDeep),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedDate == null
                              ? 'Select date'
                              : DateFormat('dd MMM yyyy')
                                  .format(_selectedDate!),
                          style: TextStyle(
                            color: _selectedDate == null
                                ? colors.onSurfaceMuted
                                : colors.onBackground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _districtController,
                label: 'District',
                hint: 'e.g. Tiruppur',
              ),
              const SizedBox(height: 12),
              if (_selectedCategory == 'demand')
                DropdownButtonFormField<String>(
                  initialValue: _buyerType,
                  decoration: _inputDecoration('Buyer Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Consumer', child: Text('Consumer')),
                    DropdownMenuItem(
                        value: 'Retailer', child: Text('Retailer')),
                    DropdownMenuItem(
                        value: 'Trader', child: Text('Trader')),
                    DropdownMenuItem(
                        value: 'Restaurant', child: Text('Restaurant')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _buyerType = value);
                  },
                ),
              if (_selectedCategory == 'demand') const SizedBox(height: 12),
            ],
            _field(
              controller: _contentController,
              label: 'Description',
              hint: _descriptionHint(),
              minLines: 4,
              maxLines: 7,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isPosting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brandDeep,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isPosting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isPosting ? 'Posting...' : 'Post',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTypeChips() {
    final colors = VidhAIColorsX(context);
    const types = [
      ('general', 'General'),
      ('problem', 'Problem'),
      ('experience', 'Experience'),
      ('available_soon', 'Available Soon'),
      ('demand', 'Demand'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((item) {
        final selected = _selectedCategory == item.$1;
        return ChoiceChip(
          label: Text(item.$2),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _selectedCategory = item.$1;
              _selectedDate = null;
            });
          },
          selectedColor: colors.brandDeep,
          backgroundColor: colors.surface,
          labelStyle: TextStyle(
            color: selected ? Colors.white : colors.onBackground,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
          side: BorderSide(
            color: selected ? colors.brandDeep : colors.borderColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionLabel(String text) {
    final colors = VidhAIColorsX(context);
    return Text(
      text,
      style: TextStyle(
        color: colors.onBackground,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final colors = VidhAIColorsX(context);
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.onBackground),
      decoration: _inputDecoration(label).copyWith(
        hintText: hint,
        hintStyle: TextStyle(color: colors.onSurfaceMuted),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    final colors = VidhAIColorsX(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.onSurfaceMuted),
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.brandDeep, width: 1.5),
      ),
    );
  }

  String _descriptionHint() {
    switch (_selectedCategory) {
      case 'problem':
        return 'Explain the crop problem and what you observed...';
      case 'experience':
        return 'Share what worked, what you tried, and the result...';
      case 'available_soon':
        return 'Tell buyers when the crop will be ready and any quality details...';
      case 'demand':
        return 'Describe the quality or variety you need...';
      default:
        return 'Share something useful with the farming community...';
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    final crop = _cropController.text.trim();

    if (content.isEmpty) {
      _showMessage('Please add a description.');
      return;
    }
    if (_selectedCategory != 'general' && crop.isEmpty) {
      _showMessage('Please enter the crop or product.');
      return;
    }
    if (_isMarketPost &&
        (_quantityController.text.trim().isEmpty || _selectedDate == null)) {
      _showMessage('Please add quantity and date.');
      return;
    }

    setState(() => _isPosting = true);

    final post = await _communityService.createPost(
      content: content,
      category: _selectedCategory,
      district: _districtController.text.trim(),
      crop: crop,
      cropStage: _stageController.text.trim(),
      quantityKg: double.tryParse(_quantityController.text.trim()),
      expectedPricePerKg: double.tryParse(_priceController.text.trim()),
      expectedHarvestDate:
          _selectedCategory == 'available_soon' ? _selectedDate : null,
      requiredByDate: _selectedCategory == 'demand' ? _selectedDate : null,
      buyerType: _selectedCategory == 'demand' ? _buyerType : '',
    );

    if (!mounted) return;

    if (post != null) {
      Navigator.pop(context);
    } else {
      setState(() => _isPosting = false);
      _showMessage('Could not publish the post. Please try again.');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
