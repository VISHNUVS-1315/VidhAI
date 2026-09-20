import 'package:flutter/material.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';

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
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc.language} ${loc.selectLanguage}: ${_languages.firstWhere((l) => l['code'] == code)['name']}',
          ),
          backgroundColor: VidhAIColorsX(context).brandDeep,
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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.selectLanguage,
          style: TextStyle(
              color: colors.onBackground, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.brandDeep))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    style: TextStyle(color: colors.onBackground, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: loc.languageSubtitle,
                      hintStyle: TextStyle(
                        color: colors.onSurfaceMuted,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colors.onSurfaceMuted,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: colors.onSurfaceMuted,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.surface,
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
                            BorderSide(color: colors.brandDeep, width: 1),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                Expanded(
                  child: RadioGroup<String>(
                    groupValue: _selectedCode,
                    onChanged: (value) {
                      if (value != null) _changeLanguage(value);
                    },
                    child: _filteredLanguages.isEmpty
                        ? Center(
                            child: Text(
                              loc.noLanguagesFound,
                              style: TextStyle(
                                color: colors.onSurfaceMuted,
                                fontSize: 15,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            itemCount: _filteredLanguages.length,
                            separatorBuilder: (_, __) => Divider(
                              color: colors.borderColor,
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final lang = _filteredLanguages[index];
                              final isSelected = lang['code'] == _selectedCode;
                              return _buildLanguageTile(
                                  colors, lang, isSelected);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLanguageTile(
    VidhAIColorsX colors,
    Map<String, String> lang,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? colors.brandDeep.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
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
                  ? colors.brandDeep.withValues(alpha: 0.2)
                  : colors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              lang['native']![0],
              style: TextStyle(
                color: isSelected ? colors.brandDeep : colors.onSurfaceMuted,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            lang['name']!,
            style: TextStyle(
              color: isSelected ? colors.brandDeep : colors.onBackground,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          subtitle: Text(
            lang['native']!,
            style: TextStyle(
              color: isSelected
                  ? colors.brandDeep.withValues(alpha: 0.7)
                  : colors.onSurfaceMuted,
              fontSize: 13,
            ),
          ),
          trailing: Radio<String>(
            value: lang['code']!,
            activeColor: colors.brandDeep,
          ),
        ),
      ),
    );
  }

}
