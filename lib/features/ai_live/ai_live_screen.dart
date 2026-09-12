import 'dart:async';

import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/vidhai_theme.dart';
import '../../core/widgets/vidhai_widgets.dart';
import '../../locale/locale.dart';
import '../../services/ai/realtime_transcription_service.dart';
import 'field_extractor.dart';

/// Online-only real-time speech-to-text UI ("AI Live").
///
/// Streams the microphone straight into a Deepgram realtime `/v1/listen`
/// session (Bearer JWT minted by the VidhAI backend) and shows live interim +
/// final transcripts. For the Personal Details flow, recognised
/// name / age / gender / address are suggested and must be reviewed (editable)
/// before poping back with the values. There is deliberately NO fallback to the
/// on-device SpeechRecognizer: this screen is online-only and surfaces errors.
class AiLiveScreen extends StatefulWidget {
  const AiLiveScreen({super.key, this.languageCode});

  /// VidhAI language code; defaults to the app's current language.
  final String? languageCode;

  @override
  State<AiLiveScreen> createState() => _AiLiveScreenState();
}

class _AiLiveScreenState extends State<AiLiveScreen>
    with WidgetsBindingObserver {
  final RealtimeTranscriptionService _service = RealtimeTranscriptionService();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _genderCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  final Set<String> _touchedFields = <String>{};
  bool _startFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_onServiceUpdate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startFailed) {
      unawaited(_begin());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Avoid bleeding mic audio while the app is backgrounded.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_service.stop());
    }
  }

  Future<void> _begin() async {
    _startFailed = true;
    final loc = AppLocalizations.of(context);
    final language = widget.languageCode ?? loc.languageCode;
    await _service.start(languageCode: language);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_onServiceUpdate);
    _service.dispose();
    _nameCtrl.dispose();
    _genderCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    final s = extractAiLiveSuggestions(_service.liveTranscript);
    setState(() {
      _fillIfUnedited(_nameCtrl, s.name, 'name');
      _fillIfUnedited(_genderCtrl, s.gender, 'gender');
      _fillIfUnedited(_ageCtrl, s.age, 'age');
      _fillIfUnedited(_addressCtrl, s.address, 'address');
    });
  }

  void _fillIfUnedited(
      TextEditingController ctrl, String? value, String field) {
    if (_touchedFields.contains(field)) return;
    if (value == null || value.isEmpty) return;
    if (ctrl.text == value) return;
    ctrl.text = value;
  }

  Future<void> _toggleListen() async {
    final loc = AppLocalizations.of(context);
    if (_service.isRunning) {
      await _service.stop();
      return;
    }
    _service.clearError();
    var granted = await _microphoneGranted();
    if (!granted) {
      granted = await _requestMicrophone();
    }
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.aiLiveMicPermission),
          backgroundColor: FreshLeafColors.danger,
        ));
      }
      return;
    }
    final language = widget.languageCode ?? loc.languageCode;
    await _service.start(languageCode: language);
  }

  Future<bool> _microphoneGranted() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  Future<bool> _requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _retry() {
    _service.clearError();
    unawaited(_begin());
  }

  void _apply() {
    final values = <String, String>{};
    final name = _nameCtrl.text.trim();
    final gender = _genderCtrl.text.trim();
    final age = _ageCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (name.isNotEmpty) values['name'] = name;
    if (gender.isNotEmpty) values['gender'] = gender;
    if (age.isNotEmpty) values['age'] = age;
    if (address.isNotEmpty) values['address'] = address;
    if (values.isEmpty) return;
    Navigator.of(context).pop(values);
  }

  String _statusLabel(AppLocalizations loc, AiLiveState state) {
    switch (state) {
      case AiLiveState.connecting:
        return loc.aiLiveConnecting;
      case AiLiveState.listening:
        return loc.listening;
      case AiLiveState.processing:
        return loc.processing;
      case AiLiveState.reconnecting:
        return loc.aiLiveReconnecting;
      case AiLiveState.offline:
        return loc.aiLiveOffline;
      case AiLiveState.error:
        return _errorLabel(loc);
      case AiLiveState.idle:
        return loc.aiLiveHint;
    }
  }

  String _errorLabel(AppLocalizations loc) {
    switch (_service.errorKind) {
      case AiLiveErrorKind.none:
        return '';
      case AiLiveErrorKind.noInternet:
        return loc.aiLiveNoInternet;
      case AiLiveErrorKind.micPermissionDenied:
        return loc.aiLiveMicPermission;
      case AiLiveErrorKind.micUnavailable:
        return loc.aiLiveMicUnavailable;
      case AiLiveErrorKind.backendUnavailable:
      case AiLiveErrorKind.sessionCreationFailed:
        return loc.aiLiveSessionError;
      case AiLiveErrorKind.languageUnsupported:
        return loc.aiLiveUnsupportedLanguage;
      case AiLiveErrorKind.authFailed:
      case AiLiveErrorKind.rateLimited:
      case AiLiveErrorKind.timedOut:
      case AiLiveErrorKind.malformedEvents:
      case AiLiveErrorKind.connectionFailed:
      case AiLiveErrorKind.unknown:
        return loc.aiLiveServiceError;
    }
  }

  bool get _showSuggestions {
    return _nameCtrl.text.isNotEmpty ||
        _genderCtrl.text.isNotEmpty ||
        _ageCtrl.text.isNotEmpty ||
        _addressCtrl.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = VidhAIColorsX(context);
    final state = _service.state;
    final running = _service.isRunning;
    final error = state == AiLiveState.error;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(directionalIcon(context, Icons.arrow_back_ios),
              color: colors.onBackground, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.aiLiveTitle,
          style: TextStyle(
              color: colors.onBackground, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Status card
            _buildStatusCard(loc, colors, state),
            const SizedBox(height: 20),

            // Live transcript
            _buildTranscriptCard(loc, colors),
            const SizedBox(height: 20),

            // Suggested fields (review/edit before apply)
            if (_showSuggestions) _buildSuggestions(loc, colors),
            if (_showSuggestions) const SizedBox(height: 20),

            // Control
            _buildControl(loc, colors, running, error),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      AppLocalizations loc, VidhAIColorsX colors, AiLiveState state) {
    final isError = state == AiLiveState.error;
    final color = isError
        ? colors.danger
        : (state == AiLiveState.idle
            ? colors.onSurfaceMuted
            : colors.brandDeep);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? colors.danger.withValues(alpha: 0.4)
              : colors.borderColor,
        ),
      ),
      child: Row(
        children: [
          _StatusDot(state: state, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusLabel(loc, state),
              style: TextStyle(color: colors.onBackground, fontSize: 14),
            ),
          ),
          if (isError)
            TextButton(
              onPressed: _retry,
              child: Text(loc.retry,
                  style: TextStyle(
                      color: colors.brandDeep, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard(AppLocalizations loc, VidhAIColorsX colors) {
    final text = _service.liveTranscript.trim();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
      ),
      child: text.isEmpty
          ? Center(
              child: Text(
                loc.aiLiveEmptyTranscript,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
              ),
            )
          : Text(
              text,
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w500),
            ),
    );
  }

  Widget _buildSuggestions(AppLocalizations loc, VidhAIColorsX colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: colors.brandDeep, size: 18),
            const SizedBox(width: 8),
            Text(
              loc.aiLiveSuggestionsTitle,
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _editableField(loc.fullName, _nameCtrl, Icons.person_outline_rounded,
            colors, 'name'),
        const SizedBox(height: 10),
        _editableField(
            loc.gender, _genderCtrl, Icons.wc_outlined, colors, 'gender'),
        const SizedBox(height: 10),
        _editableField(
            loc.ageCalculated, _ageCtrl, Icons.numbers_rounded, colors, 'age'),
        const SizedBox(height: 10),
        _editableField(loc.address, _addressCtrl, Icons.location_on_outlined,
            colors, 'address'),
      ],
    );
  }

  Widget _editableField(String label, TextEditingController ctrl, IconData icon,
      VidhAIColorsX colors, String field) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: colors.onBackground, fontSize: 14),
      onChanged: (_) => _touchedFields.add(field),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: colors.onSurfaceMuted, size: 20),
        filled: true,
        fillColor: colors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.brandDeep, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildControl(
      AppLocalizations loc, VidhAIColorsX colors, bool running, bool error) {
    return Column(
      children: [
        GestureDetector(
          key: const Key('ai_live_toggle'),
          onTap: _toggleListen,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: running || _service.state == AiLiveState.connecting
                  ? colors.brandDeep
                  : colors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: running ? colors.brandDeep : colors.borderColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.brandDeep.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              running ? Icons.stop_rounded : Icons.mic_rounded,
              color: running ? Colors.white : colors.brandDeep,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          running ? loc.stop : loc.aiLiveTapToListen,
          style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
        ),
        if (_showSuggestions) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.check_rounded),
              label: Text(loc.aiLiveApply,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brandDeep,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.state, required this.color});

  final AiLiveState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pulsing =
        state == AiLiveState.listening || state == AiLiveState.processing;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: pulsing
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
    );
  }
}
