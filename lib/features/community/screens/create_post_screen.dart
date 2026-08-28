import 'package:flutter/material.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/community_service.dart';

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

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _accent = Color(0xFF4CAF50);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF9CA3AF);

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Post',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isPosting || _contentController.text.trim().isEmpty
                  ? null
                  : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Share your farming experience, ask questions, or help others...',
                hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.5)),
                filled: true,
                fillColor: _cardColor,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CommunityPost.categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _accent : _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? _accent : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  _formatCategory(cat),
                  style: TextStyle(
                    color: isSelected ? Colors.white : _textSecondary,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: _accent.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AI Assisted',
              style: TextStyle(color: _textPrimary, fontSize: 13),
            ),
          ),
          Switch(
            value: _isAIAssisted,
            onChanged: (v) => setState(() => _isAIAssisted = v),
            activeThumbColor: _accent,
          ),
        ],
      ),
    );
  }

  String _formatCategory(String cat) {
    return cat.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Future<void> _submitPost() async {
    setState(() => _isPosting = true);

    final post = await _communityService.createPost(
      content: _contentController.text.trim(),
      category: _selectedCategory,
      isAIAssisted: _isAIAssisted,
    );

    if (mounted) {
      if (post != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published!'), backgroundColor: _accent),
        );
        Navigator.pop(context);
      } else {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post. Try again.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }
}
