import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vidhai/core/bloc/auth_bloc.dart';
import 'package:vidhai/core/theme/theme_controller.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/ai/tts_service.dart';
import 'package:vidhai/services/ai/voice_preferences_service.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/features/account/screens/edit_profile_screen.dart';
import 'package:vidhai/features/account/screens/language_settings_screen.dart';
import 'package:vidhai/features/assistant/assistant_button.dart';
import 'package:vidhai/features/notifications/screens/notification_center_screen.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final DataService _dataService = DataService();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _loadFailed = false;

  static const Color _danger = Color(0xFFEF4444);

  Color get _bgColor => VidhAIColorsX(context).bg;
  Color get _cardColor => VidhAIColorsX(context).surface;
  Color get _accent => VidhAIColorsX(context).brandDeep;
  Color get _muted => VidhAIColorsX(context).onSurfaceMuted;
  Color get _text => VidhAIColorsX(context).onBackground;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    AiVoicePreferences.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadProfile() async {
    debugPrint('[AccountScreen] LOADING STATE=START');
    if (mounted) {
      setState(() {
        _isLoading = _profile == null;
        _loadFailed = false;
      });
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    debugPrint('[AccountScreen] AUTH UID=${uid.isEmpty ? "NONE" : uid}');
    final docPath = uid.isNotEmpty ? 'users/$uid' : 'users/<none>';
    debugPrint('[AccountScreen] DOC PATH=$docPath');

    // Offline-first: render the cached profile immediately if we have one.
    UserProfile? cached;
    try {
      cached = await _dataService.loadCachedProfile();
    } catch (e) {
      debugPrint('[AccountScreen] CACHE ERROR=${e.runtimeType} msg=$e');
    }
    debugPrint('[AccountScreen] DOC EXISTS(CACHE)=${cached != null}');
    if (mounted && cached != null && _profile == null) {
      setState(() => _profile = cached);
    }

    // Sync: refresh from Firestore users/{uid} (source of truth) so any
    // onboarded profile data is auto-filled on top of the cached view.
    var fetchError = false;
    if (uid.isNotEmpty) {
      try {
        final fetched = await _dataService.loadProfile();
        debugPrint(
            '[AccountScreen] FETCH RESULT=${fetched == null ? "EMPTY" : "SUCCESS"}');
        if (fetched != null && mounted) {
          setState(() => _profile = fetched);
        }
      } catch (e) {
        fetchError = true;
        debugPrint('[AccountScreen] ERROR CODE=${e.runtimeType} msg=$e');
        debugPrint(
            '[AccountScreen] FETCH RESULT=ERROR (falling back to cache)');
      }
    } else {
      debugPrint('[AccountScreen] FETCH RESULT=SKIPPED (no auth uid)');
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loadFailed = fetchError && _profile == null;
    });
    debugPrint(
        '[AccountScreen] LOADING STATE=END loading=$_isLoading failed=$_loadFailed');
  }

  Widget _buildLoadError() {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: _muted, size: 40),
            const SizedBox(height: 12),
            Text(
              loc.errorUnavailable,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadProfile,
              icon: Icon(Icons.refresh, color: _accent, size: 18),
              label: Text(loc.retry, style: TextStyle(color: _accent)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _accent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitial() {
    final name = _profile?.displayName ?? '';
    if (name.isNotEmpty) return name[0].toUpperCase();
    final email = _profile?.email ?? '';
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(
          loc.account,
          style: TextStyle(color: _text, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          const VidhAIAssistantButton(screen: 'account'),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : _loadFailed
              ? _buildLoadError()
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: _cardColor,
                        child: Text(
                          _getInitial(),
                          style: TextStyle(
                            color: _accent,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _profile?.displayName.isNotEmpty == true
                            ? _profile!.displayName
                            : loc.userFallback,
                        style: TextStyle(
                          color: _text,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _profile?.email ?? '',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildMenuItem(
                      Icons.person_outline,
                      loc.editProfile,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                        _loadProfile();
                      },
                    ),
                    _buildMenuItem(
                      Icons.language,
                      loc.language,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageSettingsScreen(),
                        ),
                      ),
                    ),
                    _buildMenuItem(
                      Icons.record_voice_over_outlined,
                      loc.t('change_ai_voice'),
                      subtitle: loc.t(
                        AiVoicePreferences.instance.selected.titleKey,
                      ),
                      onTap: () => _showAiVoiceSheet(context),
                    ),
                    _buildMenuItem(
                      Icons.brightness_6_outlined,
                      loc.appearance,
                      onTap: () => _showAppearanceSheet(context),
                    ),
                    _buildMenuItem(
                      Icons.notifications_outlined,
                      loc.notifications,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationCenterScreen(),
                        ),
                      ),
                    ),
                    _buildMenuItem(
                      Icons.help_outline,
                      loc.helpSupport,
                      onTap: () => _showHelpSheet(context),
                    ),
                    _buildMenuItem(
                      Icons.info_outline,
                      loc.aboutVidhai,
                      onTap: () => _showAboutDialog(context),
                    ),
                    _buildMenuItem(
                      Icons.terminal,
                      loc.console,
                      onTap: () => _showConsoleDialog(context),
                    ),
                    _buildMenuItem(
                      Icons.g_mobiledata,
                      loc.linkGoogleAccount,
                      onTap: () => _showGoogleLinkDialog(context),
                    ),
                    const SizedBox(height: 16),
                    _buildLogoutButton(context),
                  ],
                ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String label, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: _muted),
        title: Text(
          label,
          style: TextStyle(color: _text, fontSize: 15),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
        trailing: Icon(
          directionalIcon(context, Icons.chevron_right),
          color: _muted,
        ),
      ),
    );
  }

  Future<void> _showAiVoiceSheet(BuildContext context) async {
    final preferences = AiVoicePreferences.instance;
    await preferences.ensureLoaded();
    if (!context.mounted) return;

    final loc = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.78,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      loc.t('change_ai_voice'),
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.t('change_ai_voice_desc'),
                      style: TextStyle(color: _muted, fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: AiVoicePreferences.profiles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final profile =
                              AiVoicePreferences.profiles[index];
                          final selected =
                              preferences.selectedId == profile.id;
                          return InkWell(
                            onTap: () async {
                              await TtsService.instance.stop();
                              await preferences.select(profile.id);
                              if (mounted) setState(() {});
                              setSheetState(() {});
                              await TtsService.instance.speak(
                                loc.t('ai_voice_preview'),
                                language: loc.languageCode,
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _accent.withValues(alpha: 0.11)
                                    : _bgColor.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? _accent
                                      : _muted.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _accent.withValues(alpha: 0.10),
                                    ),
                                    child: Icon(
                                      Icons.graphic_eq_rounded,
                                      color: _accent,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc.t(profile.titleKey),
                                          style: TextStyle(
                                            color: _text,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          loc.t(profile.subtitleKey),
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 12,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      await TtsService.instance.stop();
                                      if (preferences.selectedId !=
                                          profile.id) {
                                        await preferences.select(profile.id);
                                        if (mounted) setState(() {});
                                        setSheetState(() {});
                                      }
                                      await TtsService.instance.speak(
                                        loc.t('ai_voice_preview'),
                                        language: loc.languageCode,
                                      );
                                    },
                                    icon: Icon(
                                      Icons.play_circle_outline_rounded,
                                      color: _accent,
                                    ),
                                    tooltip: loc.t('preview_voice'),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: _accent,
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  void _showAppearanceSheet(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final current = ThemeController.instance.mode;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _muted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loc.appearance,
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.appearanceDesc,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _appearanceOption(
                  ctx,
                  setSheetState,
                  Icons.light_mode_outlined,
                  loc.lightMode,
                  loc.mintTheme,
                  ThemeMode.light,
                  current,
                ),
                _appearanceOption(
                  ctx,
                  setSheetState,
                  Icons.dark_mode_outlined,
                  loc.darkMode,
                  loc.pistachioTheme,
                  ThemeMode.dark,
                  current,
                ),
                _appearanceOption(
                  ctx,
                  setSheetState,
                  Icons.settings_suggest_outlined,
                  loc.systemDefault,
                  loc.followDeviceSetting,
                  ThemeMode.system,
                  current,
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _appearanceOption(
      BuildContext ctx,
      StateSetter setSheetState,
      IconData icon,
      String title,
      String subtitle,
      ThemeMode mode,
      ThemeMode current) {
    final isSelected = mode == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          ThemeController.instance.setMode(mode);
          setSheetState(() {});
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? _accent.withValues(alpha: 0.12)
                : _bgColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _accent : _muted.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? _accent : _muted, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: _accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: _cardColor,
              title: Text(loc.logout, style: TextStyle(color: _text)),
              content: Text(
                loc.logoutConfirmation,
                style: TextStyle(color: _muted),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(loc.cancel, style: TextStyle(color: _muted)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(loc.logout,
                      style: const TextStyle(color: Color(0xFFEF4444))),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            context.read<AuthBloc>().logout();
            Navigator.of(context).pushReplacementNamed('/language_selection');
          }
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _danger, width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          loc.logout,
          style: TextStyle(
            color: _danger,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              loc.helpSupport,
              style: TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _helpItem(Icons.email_outlined, loc.emailUs, 'support@vidhai.com'),
            _helpItem(Icons.phone_outlined, loc.callUs, '+91 1800-VIDHAI'),
            _helpItem(Icons.chat_bubble_outline, loc.liveChat,
                loc.liveChatAvailability),
            _helpItem(Icons.article_outlined, loc.faq, loc.helpCenter),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: _accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showAboutDialog(
      context: context,
      applicationName: 'VidhAI',
      applicationVersion: '1.0.0',
      applicationLegalese: loc.copyrightNotice,
      children: [
        const SizedBox(height: 16),
        Text(
          loc.aboutDescription,
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  void _showConsoleDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final currentConsole = await _dataService.getSelectedConsole();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          loc.switchConsole,
          style: TextStyle(color: _text),
        ),
        content: RadioGroup<String>(
          groupValue: currentConsole,
          onChanged: (val) async {
            if (val == null || val == currentConsole) return;
            await _dataService.setSelectedConsole(val);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              _loadProfile();
              final consoleName =
                  val == 'farmer' ? loc.farmerConsole : loc.consumerConsole;
              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  backgroundColor: _cardColor,
                  title:
                      Text(loc.consoleSwitched, style: TextStyle(color: _text)),
                  content: Text(
                    loc.consoleSwitchedMessage
                        .replaceAll('{console}', consoleName),
                    style: TextStyle(color: _muted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dCtx);
                        if (mounted) setState(() {});
                      },
                      child: Text(loc.ok, style: TextStyle(color: _accent)),
                    ),
                  ],
                ),
              );
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _consoleOption(ctx, loc.farmerConsole, 'farmer', currentConsole),
              _consoleOption(
                  ctx, loc.consumerConsole, 'consumer', currentConsole),
            ],
          ),
        ),
      ),
    );
  }

  Widget _consoleOption(
      BuildContext ctx, String title, String value, String current) {
    final isSelected = value == current;
    return RadioListTile<String>(
      value: value,
      title: Text(
        title,
        style: TextStyle(color: _text, fontSize: 15),
      ),
      activeColor: _accent,
      secondary: Icon(
        value == 'farmer' ? Icons.agriculture : Icons.shopping_cart,
        color: isSelected ? _accent : _muted,
      ),
    );
  }

  void _showGoogleLinkDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isGoogleLinked =
        user.providerData.any((p) => p.providerId == 'google.com');
    if (isGoogleLinked) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardColor,
          title: Text(loc.googleAccount, style: TextStyle(color: _text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: _accent, size: 48),
              const SizedBox(height: 16),
              Text(
                loc.googleAlreadyLinked,
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: _text, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.ok, style: TextStyle(color: _accent))),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(loc.linkGoogleAccount, style: TextStyle(color: _text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.g_mobiledata, size: 64, color: _accent),
            const SizedBox(height: 16),
            Text(
              loc.linkGoogleDescription,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel, style: TextStyle(color: _muted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.linkNow, style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final googleProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.currentUser
            ?.linkWithProvider(googleProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(loc.googleLinkedSuccess),
                backgroundColor: _accent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          );
          _loadProfile();
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          String msg = loc.googleLinkFailed;
          if (e.code == 'provider-already-linked') {
            msg = loc.googleAlreadyLinkedMsg;
          } else if (e.code == 'credential-already-in-use') {
            msg = loc.googleLinkedOtherUser;
          } else if (e.code == 'invalid-credential') {
            msg = loc.invalidGoogleCredentials;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(msg),
                backgroundColor: _danger,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(loc.googleSigninCancelled),
                backgroundColor: _danger,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          );
        }
      }
    }
  }
}
