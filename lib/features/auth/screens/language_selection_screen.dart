import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
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

  String? _selectedLanguage;

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: size.height * 0.06),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context).selectLanguage,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colors.onBackground,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).languageSubtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ..._languages.map((lang) => _buildLanguageTile(lang)),
                    SizedBox(height: bottomPadding + 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: colors.bg,
        padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding + 16),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _selectedLanguage != null
                ? () {
                    AppLocalizationsProvider.of(context)
                        .setLanguage(_selectedLanguage!);
                    Navigator.of(context)
                        .pushReplacementNamed('/domain_selection');
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brandDeep,
              disabledBackgroundColor: colors.surface,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              AppLocalizations.of(context).continueBtn,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _selectedLanguage != null
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile(Map<String, String> lang) {
    final colors = VidhAIColorsX(context);
    final isSelected = _selectedLanguage == lang['code'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _selectedLanguage = lang['code'];
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.brandDeep.withValues(alpha: 0.12)
                  : colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? colors.brandDeep : colors.borderColor,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.brandDeep.withValues(alpha: 0.2)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      lang['native']!.substring(0, 1),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? colors.brandDeep
                            : colors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang['name']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? colors.onBackground
                              : colors.onBackground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang['native']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? colors.brandDeep.withValues(alpha: 0.8)
                              : colors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: colors.brandDeep,
                    size: 22,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    color: colors.onSurfaceMuted.withValues(alpha: 0.3),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
