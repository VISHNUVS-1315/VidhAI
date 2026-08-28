import 'package:flutter/material.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/locale/locale.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCode = 'en';
  String _searchQuery = '';
  bool _isLoading = true;

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _accent = Color(0xFF4CAF50);

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'pa', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
    {'code': 'or', 'name': 'Odia', 'native': 'ଓଡ଼ିଆ'},
    {'code': 'as', 'name': 'Assamese', 'native': 'অসমীয়া'},
    {'code': 'ur', 'name': 'Urdu', 'native': 'اردو'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLanguage() async {
    final code = await _dataService.getSelectedLanguage();
    if (mounted) {
      setState(() {
        _selectedCode = code;
        _isLoading = false;
      });
    }
  }

  List<Map<String, String>> get _filteredLanguages {
    if (_searchQuery.isEmpty) return _languages;
    final query = _searchQuery.toLowerCase();
    return _languages.where((lang) {
      return lang['name']!.toLowerCase().contains(query) ||
          lang['native']!.toLowerCase().contains(query) ||
          lang['code']!.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _changeLanguage(String code) async {
    if (code == _selectedCode) return;

    setState(() => _selectedCode = code);
    await _dataService.setSelectedLanguage(code);
    if (mounted) {
      AppLocalizationsProvider.of(context).setLanguage(code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Language changed to ${_languages.firstWhere((l) => l['code'] == code)['name']}',
          ),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Language',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search languages...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: _cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _accent, width: 1),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredLanguages.isEmpty
                      ? Center(
                          child: Text(
                            'No languages found',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          itemCount: _filteredLanguages.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withValues(alpha: 0.05),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final lang = _filteredLanguages[index];
                            final isSelected = lang['code'] == _selectedCode;
                            return _buildLanguageTile(lang, isSelected);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLanguageTile(Map<String, String> lang, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? _accent.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _changeLanguage(lang['code']!),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? _accent.withValues(alpha: 0.2)
                : _cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            lang['native']![0],
            style: TextStyle(
              color: isSelected ? _accent : Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          lang['name']!,
          style: TextStyle(
            color: isSelected ? _accent : Colors.white,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          lang['native']!,
          style: TextStyle(
            color: isSelected
                ? _accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
        trailing: Radio<String>(
          value: lang['code']!,
          groupValue: _selectedCode,
          onChanged: (value) {
            if (value != null) _changeLanguage(value);
          },
          activeColor: _accent,
        ),
      ),
    );
  }
}
