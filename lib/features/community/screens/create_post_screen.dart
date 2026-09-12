import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/community_service.dart';
import 'package:vidhai/locale/locale.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final CommunityService _communityService = CommunityService();
  String _selectedCategory = 'general';
  bool _isPosting = false;
  bool _isAIAssisted = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
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
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.newPost,
          style: TextStyle(
              color: colors.onBackground, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: ElevatedButton(
              onPressed: _isPosting || _contentController.text.trim().isEmpty
                  ? null
                  : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brandDeep,
                disabledBackgroundColor:
                    colors.brandDeep.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(loc.postBtn,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _contentController,
              maxLines: 8,
              minLines: 5,
              style: TextStyle(color: colors.onBackground, fontSize: 15),
              decoration: InputDecoration(
                hintText: loc.postContentHint,
                hintStyle: TextStyle(
                    color: colors.onSurfaceMuted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 12),
            _buildAIAssistToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.category,
            style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CommunityPost.categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? colors.brandDeep : colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colors.brandDeep : colors.borderColor,
                  ),
                ),
                child: Text(
                  _formatCategory(cat, loc),
                  style: TextStyle(
                    color: isSelected ? Colors.white : colors.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAIAssistToggle() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              color: colors.brandDeep.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loc.aiAssisted,
              style: TextStyle(color: colors.onBackground, fontSize: 13),
            ),
          ),
          Switch(
            value: _isAIAssisted,
            onChanged: (v) => setState(() => _isAIAssisted = v),
            activeThumbColor: colors.brandDeep,
          ),
        ],
      ),
    );
  }

  String _formatCategory(String cat, AppLocalizations loc) {
    switch (cat) {
      case 'general':
        return loc.communityCategoryGeneral;
      case 'crops':
        return loc.communityCategoryCrops;
      case 'pest_control':
        return loc.communityCategoryPestControl;
      case 'irrigation':
        return loc.communityCategoryIrrigation;
      case 'market_prices':
        return loc.communityCategoryMarket;
      case 'equipment':
        return loc.communityCategoryEquipment;
      case 'organic':
        return loc.communityCategoryOrganic;
      case 'weather':
        return loc.communityCategoryWeather;
      case 'government_schemes':
        return loc.communityCategorySchemes;
      default:
        return cat;
    }
  }

  Future<void> _submitPost() async {
    setState(() => _isPosting = true);

    final post = await _communityService.createPost(
      content: _contentController.text.trim(),
      category: _selectedCategory,
      isAIAssisted: _isAIAssisted,
    );

    if (mounted) {
      final colors = VidhAIColorsX(context);
      final loc = AppLocalizations.of(context);
      if (post != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(loc.postPublished),
              backgroundColor: colors.brandDeep),
        );
        Navigator.pop(context);
      } else {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(loc.postFailed), backgroundColor: colors.danger),
        );
      }
    }
  }
}
