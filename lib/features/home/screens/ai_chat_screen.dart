import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/features/assistant/voice_turn_recorder.dart';
import 'package:vidhai/features/home/screens/live_voice_screen.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/services/ai/ai_chat_service.dart';
import 'package:vidhai/services/ai/domain_services.dart';
import 'package:vidhai/services/ai/nvidia_service.dart';
import 'package:vidhai/services/ai/nvidia_vision_service.dart';
import 'package:vidhai/services/ai/tts_service.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class _ChatMessage {
  String text;
  final bool isUser;
  final DateTime timestamp;
  bool isNewlyAdded;
  final List<XFile>? imageFiles;
  final String? fileName;
  final bool voiceInitiated;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isNewlyAdded = false,
    this.imageFiles,
    this.fileName,
    this.voiceInitiated = false,
  });
}

class AiChatScreen extends StatefulWidget {
  final String source;
  final String? targetFarmId;

  const AiChatScreen({
    required this.source,
    this.targetFarmId,
    super.key,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _chatService = VidhAIChatService.instance;
  final _history = ChatHistoryService.instance;
  final _dataService = DataService();
  final _tts = TtsService.instance;
  final _recorder = VoiceTurnRecorder();

  final List<_ChatMessage> _messages = [];
  final List<XFile> _pendingImages = [];
  final List<String> _pendingFiles = [];

  List<FarmProfile> _farms = [];
  String? _selectedFarmId;

  bool _isTyping = false;
  bool _recording = false;
  String _liveTranscript = '';
  double _waveAmp = 0;
  int _speakingIndex = -1;
  StreamSubscription<double>? _ampSub;

  /// True while an assistant reply is being streamed token-by-token.
  bool _streamActive = false;

  @override
  void initState() {
    super.initState();
    _tts.addListener(_onTtsChanged);
    _loadFarms();
    final active = _history.activeSession;
    if (active != null) {
      _messages.addAll(active.messages.map((m) => _ChatMessage(
            text: m.content,
            isUser: m.role == 'user',
            timestamp: m.timestamp,
          )));
    }
  }

  Future<void> _loadFarms() async {
    try {
      final farms = await _dataService.loadFarms();
      if (!mounted) return;
      setState(() {
        _farms = farms;
        final target = widget.targetFarmId;
        _selectedFarmId = target != null && farms.any((f) => f.farmId == target)
            ? target
            : farms.length == 1
                ? farms.first.farmId
                : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tts.removeListener(_onTtsChanged);
    _ampSub?.cancel();
    unawaited(_recorder.cancel());
    unawaited(_tts.stop());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTtsChanged() {
    if (!_tts.isSpeaking && _speakingIndex != -1 && mounted) {
      setState(() => _speakingIndex = -1);
    }
  }

  // ── AI helpers ─────────────────────────────────────────────────────────

  Future<String> _getLanguage() => _dataService.getSelectedLanguage();

  Future<String> _getResponse(
    String input, {
    void Function(String delta)? onDelta,
  }) async {
    // Never block an AI request on a Firestore round-trip. The screen already
    // refreshes farms in the background; until that completes, use the local
    // offline-first cache so the NVIDIA request can start immediately.
    final profile = await _dataService.loadCachedProfile();
    final farms =
        _farms.isNotEmpty ? _farms : await _dataService.loadCachedFarms();
    final selId = _selectedFarmId;
    final farmMaps = selId != null
        ? farms
            .where((f) => f.farmId == selId)
            .take(1)
            .map((f) => f.toMap())
            .toList()
        : farms.map((f) => f.toMap()).toList();
    final profileMap = profile?.toMap() ?? {};
    final lang = await _getLanguage();
    return _chatService.chat(
      input,
      language: lang,
      userProfile: profileMap,
      farms: farmMaps.isNotEmpty ? farmMaps : null,
      onDelta: onDelta,
    );
  }

  String _polishResponse(String raw) {
    var text = raw.trim();
    // String.replaceAll does not expand regex capture groups in the
    // replacement string, which previously rendered literal "$1" in chat.
    text = text.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'^•\s?$', multiLine: true), '');
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  ChatSession _session({String? title}) {
    return _history.activeSession ??
        _history.createSession(
          title: title == null ? null : _titleFor(title),
        );
  }

  String _titleFor(String text) {
    final clean = text.trim();
    if (clean.length <= 40) return clean;
    return '${clean.substring(0, 37)}...';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Keeps the view pinned to the newest token while streaming, but only when
  /// the user is already near the bottom (avoids fighting manual scrolling).
  void _autoScrollOnDelta() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent - position.pixels < 260) {
        position.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Sending ────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text, {bool voiceInitiated = false}) async {
    final clean = text.trim();
    if (clean.isEmpty && _pendingImages.isEmpty && _pendingFiles.isEmpty) {
      return;
    }
    if (_pendingImages.isNotEmpty) {
      await _sendWithImages(clean, voiceInitiated: voiceInitiated);
      return;
    }
    if (_pendingFiles.isNotEmpty) {
      final fileName = _pendingFiles.removeAt(0);
      if (mounted) setState(() {});
      await _standardSend(clean,
          fileName: fileName, voiceInitiated: voiceInitiated);
      return;
    }
    if (clean.isEmpty) return;
    await _standardSend(clean, voiceInitiated: voiceInitiated);
  }

  Future<void> _standardSend(
    String text, {
    String? fileName,
    bool voiceInitiated = false,
  }) async {
    if (_isTyping || _streamActive) return;
    final loc = AppLocalizations.of(context);
    final userMsg = _ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      fileName: fileName,
      voiceInitiated: voiceInitiated,
    );
    final session = _session(title: text);
    session.messages.add(ChatMessage.user(text));

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
      _streamActive = false;
    });
    _controller.clear();
    _scrollToBottom();

    var streamed = '';
    _ChatMessage? assistantMsg;

    void onDelta(String delta) {
      if (!mounted) return;
      streamed += delta;
      if (assistantMsg == null) {
        assistantMsg = _ChatMessage(
          text: streamed,
          isUser: false,
          timestamp: DateTime.now(),
        );
        setState(() {
          _isTyping = false;
          _streamActive = true;
          _messages.add(assistantMsg!);
        });
      } else {
        setState(() {
          assistantMsg!.text = streamed;
        });
      }
      _autoScrollOnDelta();
    }

    try {
      final response = await _getResponse(text, onDelta: onDelta);
      if (!mounted) return;
      final finalText = streamed.isNotEmpty ? streamed : response;
      final reply = _polishResponse(finalText);
      assistantMsg?.text = reply;
      session.messages.add(ChatMessage.assistant(reply));
      session.updatedAt = DateTime.now();
      setState(() {
        _isTyping = false;
        _streamActive = false;
        if (assistantMsg == null) {
          _messages.add(_ChatMessage(
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
      });
      _scrollToBottom();
      if (voiceInitiated) _speak(reply);
    } catch (_) {
      if (!mounted) return;
      final reply = loc.aiGenericError;
      assistantMsg?.text = reply;
      setState(() {
        _isTyping = false;
        _streamActive = false;
        if (assistantMsg == null) {
          _messages.add(_ChatMessage(
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
            isNewlyAdded: true,
          ));
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendWithImages(
    String text, {
    bool voiceInitiated = false,
  }) async {
    if (_isTyping || _streamActive) return;
    final loc = AppLocalizations.of(context);
    final images = List<XFile>.from(_pendingImages);
    setState(() => _pendingImages.clear());
    final userMsg = _ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      imageFiles: images,
      voiceInitiated: voiceInitiated,
    );
    final session = _session(title: text.isEmpty ? 'photo query' : text);
    session.messages.add(ChatMessage.user(text.isEmpty ? 'Photo query' : text));

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final lang = await _getLanguage();
      final carriers = <Uint8ListLike>[];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        carriers.add(Uint8ListLike(bytes: bytes, mimeType: _mimeFor(image)));
      }
      final prompt = text.trim().isEmpty ? loc.attachPhotoHint : text.trim();
      final analysis = await NvidiaVisionService.instance.analyze(
        images: carriers,
        prompt: prompt,
        language: lang,
      );
      if (!mounted) return;
      final reply = analysis.success && analysis.text.trim().isNotEmpty
          ? _polishResponse(analysis.text)
          : loc.aiGenericError;
      final aiMsg = _ChatMessage(
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
        isNewlyAdded: true,
      );
      session.messages.add(ChatMessage.assistant(reply));
      session.updatedAt = DateTime.now();
      setState(() {
        _isTyping = false;
        _messages.add(aiMsg);
      });
      _scrollToBottom();
      if (voiceInitiated) _speak(reply);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isTyping = false);
      _messages.add(_ChatMessage(
        text: loc.aiGenericError,
        isUser: false,
        timestamp: DateTime.now(),
        isNewlyAdded: true,
      ));
      _scrollToBottom();
    }
  }

  String _mimeFor(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  // ── Voice recording ────────────────────────────────────────────────────

  Future<void> _beginRecording() async {
    final lang = await _getLanguage();
    _recorder.onText = (t) {
      if (mounted) setState(() => _liveTranscript = t);
    };
    final started = await _recorder.start(lang);
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).aiVoiceError)),
      );
      return;
    }
    setState(() {
      _recording = true;
      _liveTranscript = '';
      _waveAmp = 0;
    });
    _ampSub?.cancel();
    _ampSub = _recorder.amplitude.listen(_onAmplitude);
  }

  void _onAmplitude(double db) {
    if (!mounted) return;
    final v = ((db + 55) / 55).clamp(0.0, 1.0);
    setState(() => _waveAmp = v);
  }

  Future<void> _confirmRecording() async {
    setState(() => _recording = false);
    await _ampSub?.cancel();
    _ampSub = null;
    final transcript = await _recorder.finish();
    if (!mounted) return;
    if (transcript.trim().isEmpty) return;
    await _sendMessage(transcript, voiceInitiated: true);
  }

  Future<void> _cancelRecording() async {
    setState(() => _recording = false);
    await _ampSub?.cancel();
    _ampSub = null;
    await _recorder.cancel();
  }

  // ── Voice output ───────────────────────────────────────────────────────

  Future<void> _speak(String text) async {
    final lang = await _getLanguage();
    unawaited(_tts.speak(text, language: lang));
  }

  Future<void> _toggleSpeak(int index, String text) async {
    if (_speakingIndex == index && _tts.isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _speakingIndex = -1);
      return;
    }
    await _tts.stop();
    if (!mounted) return;
    setState(() => _speakingIndex = index);
    final lang = await _getLanguage();
    await _tts.speak(text, language: lang);
  }

  // ── History ────────────────────────────────────────────────────────────

  void _startNewChat() {
    _history.createSession();
    setState(() {
      _messages.clear();
      _controller.clear();
      _pendingImages.clear();
      _pendingFiles.clear();
      _speakingIndex = -1;
    });
    _scrollToBottom();
  }

  void _loadSession(String sessionId) {
    _history.setActiveSession(sessionId);
    final stored = _history.getHistoryForSession(sessionId);
    setState(() {
      _messages
        ..clear()
        ..addAll(stored.map((m) => _ChatMessage(
              text: m.content,
              isUser: m.role == 'user',
              timestamp: m.timestamp,
            )));
      _controller.clear();
      _pendingImages.clear();
      _pendingFiles.clear();
      _speakingIndex = -1;
    });
    _scrollToBottom();
  }

  void _deleteSession(String sessionId) {
    final wasActive = _history.activeSession?.id == sessionId;
    _history.deleteSession(sessionId);
    if (wasActive) {
      setState(() => _messages.clear());
    } else {
      setState(() {});
    }
  }

  void _openLiveVoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveVoiceScreen()),
    );
  }

  void _openHistory() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final x = FreshLeafColorsX(sheetContext);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            final sessions = _history.sessions;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                  child: Row(
                    children: [
                      Text(
                        loc.chatHistory,
                        style: TextStyle(
                          color: x.onBackground,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _startNewChat();
                        },
                        icon: Icon(Icons.edit_square, color: x.brand, size: 18),
                        label: Text(loc.newChat),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: sessions.isEmpty
                      ? _buildNoChats(x, loc)
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            return Dismissible(
                              key: ValueKey(session.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: AlignmentDirectional.centerEnd,
                                padding:
                                    const EdgeInsetsDirectional.only(end: 24),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: x.error,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _deleteSession(session.id),
                              child: ListTile(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _loadSession(session.id);
                                },
                                leading: CircleAvatar(
                                  backgroundColor:
                                      x.brand.withValues(alpha: 0.12),
                                  child: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: x.brand,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  session.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: x.onBackground,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  session.messages.isEmpty
                                      ? _formatListTime(session.updatedAt)
                                      : '${session.preview}\n${_formatListTime(session.updatedAt)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: x.onSurfaceMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNoChats(FreshLeafColorsX x, AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            color: x.onSurfaceMuted.withValues(alpha: 0.6),
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            loc.noChatsYet,
            style: TextStyle(color: x.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Attachments ────────────────────────────────────────────────────────

  void _showAttachmentSheet() {
    final loc = AppLocalizations.of(context);
    final x = FreshLeafColorsX(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: x.brand),
                title: Text(
                  loc.camera,
                  style: TextStyle(color: x.onBackground, fontSize: 15),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: x.brand),
                title: Text(
                  loc.gallery,
                  style: TextStyle(color: x.onBackground, fontSize: 15),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file_outlined, color: x.brand),
                title: Text(
                  loc.file,
                  style: TextStyle(color: x.onBackground, fontSize: 15),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickFile();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _pendingImages.add(picked));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || !mounted) return;
    final name = result.files.single.name;
    if (name.isEmpty) return;
    setState(() => _pendingFiles.add(name));
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final x = FreshLeafColorsX(context);
    return Scaffold(
      backgroundColor: x.bg,
      appBar: AppBar(
        backgroundColor: x.bg,
        leading: widget.source == 'shell'
            ? const SizedBox(width: 48)
            : IconButton(
                icon: Icon(
                  directionalIcon(context, Icons.arrow_back_ios_new_rounded),
                  color: x.onBackground,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        title: Text(
          AppLocalizations.of(context).aiChatAssistantHeading,
          style: TextStyle(
            color: x.onBackground,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).voice,
            icon: Icon(Icons.record_voice_over_rounded, color: x.onBackground),
            onPressed: _openLiveVoice,
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).chatHistory,
            icon: Icon(Icons.history_rounded, color: x.onBackground),
            onPressed: _openHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_isTyping
                ? _buildEmptyState()
                : _buildMessageList(),
          ),
          _buildFarmSelector(),
          _buildAttachmentChips(),
          if (_recording) _buildRecordingBar() else _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildFarmSelector() {
    if (_farms.isEmpty) return const SizedBox.shrink();
    final x = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      decoration: BoxDecoration(
        color: x.bg,
        border: Border(top: BorderSide(color: x.borderColor, width: 0.5)),
      ),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                selected: _selectedFarmId == null,
                onSelected: (_) => setState(() => _selectedFarmId = null),
                label: Text(loc.t('chat_all_farms')),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color:
                      _selectedFarmId == null ? Colors.white : x.onBackground,
                ),
                selectedColor: x.brand,
                backgroundColor: x.surface,
                side: BorderSide(color: x.borderColor),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                avatar: Icon(Icons.agriculture_rounded,
                    size: 15,
                    color: _selectedFarmId == null
                        ? Colors.white
                        : x.onSurfaceMuted),
              ),
            ),
            for (final farm in _farms)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ChoiceChip(
                  selected: _selectedFarmId == farm.farmId,
                  onSelected: (_) =>
                      setState(() => _selectedFarmId = farm.farmId),
                  label: Text(
                    farm.farmName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _selectedFarmId == farm.farmId
                        ? Colors.white
                        : x.onBackground,
                  ),
                  selectedColor: x.brand,
                  backgroundColor: x.surface,
                  side: BorderSide(color: x.borderColor),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final x = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [x.brand, x.brandStrong],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: x.brand.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.aiChatAssistantHeading,
              style: TextStyle(
                color: x.onBackground,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              loc.chatHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: x.onSurfaceMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index], index);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final x = FreshLeafColorsX(context);
    if (msg.isUser) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [x.brand, x.brandStrong],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(18),
              topEnd: Radius.circular(18),
              bottomEnd: Radius.circular(18),
              bottomStart: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (msg.imageFiles != null && msg.imageFiles!.isNotEmpty)
                ..._buildImagePreview(msg.imageFiles!),
              if (msg.fileName != null) _buildFileNameChip(msg.fileName!, x),
              if (msg.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: (msg.imageFiles != null || msg.fileName != null)
                        ? 6
                        : 0,
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatTime(msg.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isSpeaking = _speakingIndex == index;
    return Container(
      width: double.maxFinite,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: x.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: x.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [x.brand, x.brandStrong],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).aiChatAssistantHeading,
                  style: TextStyle(
                    color: x.brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _toggleSpeak(index, msg.text),
                icon: Icon(
                  isSpeaking
                      ? Icons.volume_up_rounded
                      : Icons.volume_up_outlined,
                  color: isSpeaking ? x.brand : x.onSurfaceMuted,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: isSpeaking
                    ? AppLocalizations.of(context).stop
                    : AppLocalizations.of(context).voice,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (msg.isNewlyAdded)
            _AnimatedMessageText(
              text: msg.text,
              style: TextStyle(
                color: x.onBackground,
                fontSize: 15,
                height: 1.45,
              ),
              onFinished: () => msg.isNewlyAdded = false,
            )
          else
            Text(
              msg.text,
              style: TextStyle(
                color: x.onBackground,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            _formatTime(msg.timestamp),
            style: TextStyle(
              color: x.onSurfaceMuted.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildImagePreview(List<XFile> images) {
    return images.map((image) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(image.path),
            height: 160,
            width: 240,
            fit: BoxFit.cover,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFileNameChip(String name, FreshLeafColorsX x) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final x = FreshLeafColorsX(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: x.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(x, 0),
            const SizedBox(width: 5),
            _buildDot(x, 1),
            const SizedBox(width: 5),
            _buildDot(x, 2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(FreshLeafColorsX x, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return AnimatedOpacity(
          opacity: value,
          duration: const Duration(milliseconds: 600),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: x.brand.withValues(alpha: value),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  // ── Composer ───────────────────────────────────────────────────────────

  Widget _buildAttachmentChips() {
    if (_pendingImages.isEmpty && _pendingFiles.isEmpty) {
      return const SizedBox.shrink();
    }
    final x = FreshLeafColorsX(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: x.bg,
        border: Border(top: BorderSide(color: x.borderColor, width: 0.5)),
      ),
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < _pendingImages.length; i++)
              _buildImageChip(_pendingImages[i], i),
            for (var i = 0; i < _pendingFiles.length; i++)
              _buildFileChip(_pendingFiles[i], i),
          ],
        ),
      ),
    );
  }

  Widget _buildImageChip(XFile image, int index) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Image.file(
              File(image.path),
              height: 44,
              width: 44,
              fit: BoxFit.cover,
            ),
            PositionedDirectional(
              end: 0,
              top: 0,
              child: InkWell(
                onTap: () => setState(() => _pendingImages.removeAt(index)),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileChip(String name, int index) {
    final x = FreshLeafColorsX(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: x.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: x.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, color: x.brand, size: 16),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: x.onBackground, fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => setState(() => _pendingFiles.removeAt(index)),
              child:
                  Icon(Icons.close_rounded, color: x.onSurfaceMuted, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final x = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    final hasText = _controller.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: x.bg,
        border: Border(top: BorderSide(color: x.borderColor, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _showAttachmentSheet,
            icon: const Icon(Icons.add_rounded),
            color: x.onSurfaceMuted,
            tooltip: loc.addAttachment,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46, maxHeight: 120),
              decoration: BoxDecoration(
                color: x.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: x.borderColor),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                style: TextStyle(color: x.onBackground, fontSize: 15),
                decoration: InputDecoration(
                  hintText: loc.askAnything,
                  hintStyle: TextStyle(color: x.onSurfaceMuted, fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty &&
                      !_isTyping &&
                      !_streamActive) {
                    _sendMessage(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 2),
          if (_isTyping || _streamActive)
            _buildStopButton(x)
          else if (hasText)
            _buildSendButton(x)
          else
            IconButton(
              onPressed: _beginRecording,
              icon: const Icon(Icons.mic_none_rounded),
              color: x.brand,
              tooltip: loc.voice,
            ),
        ],
      ),
    );
  }

  Widget _buildSendButton(FreshLeafColorsX x) {
    return InkWell(
      onTap: () => _sendMessage(_controller.text),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [x.brand, x.brandStrong],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// Stops the in-flight stream while keeping whatever text already arrived.
  void _stopStream() {
    NvidiaService.instance.cancelCurrentStream();
  }

  Widget _buildStopButton(FreshLeafColorsX x) {
    return InkWell(
      onTap: _stopStream,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: x.error.withValues(alpha: 0.12),
        ),
        child: Icon(Icons.stop_rounded, color: x.error, size: 26),
      ),
    );
  }

  Widget _buildRecordingBar() {
    final x = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: x.bg,
        border: Border(top: BorderSide(color: x.borderColor, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWaveform(x),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _liveTranscript.isEmpty
                ? Text(
                    loc.aiVoiceListening,
                    key: const ValueKey('listening'),
                    style: TextStyle(color: x.onSurfaceMuted, fontSize: 13),
                  )
                : Text(
                    _liveTranscript,
                    key: const ValueKey('transcript'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: x.onBackground, fontSize: 14),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRecordAction(
                x: x,
                icon: Icons.close_rounded,
                color: x.error,
                onTap: _cancelRecording,
                tooltip: loc.cancel,
              ),
              const SizedBox(width: 56),
              _buildRecordAction(
                x: x,
                icon: Icons.check_rounded,
                color: x.brand,
                onTap: _confirmRecording,
                tooltip: loc.yes,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordAction({
    required FreshLeafColorsX x,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
        ),
        const SizedBox(height: 4),
        Text(tooltip, style: TextStyle(color: x.onSurfaceMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildWaveform(FreshLeafColorsX x) {
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(36, (index) {
          final wave = (1 + math.sin(index * 0.7)) / 2;
          final height = 6 + (_waveAmp * 22 * (0.4 + wave * 0.6));
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            width: 3,
            height: height.clamp(4, 30).toDouble(),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _waveAmp > 0.12
                  ? x.brand
                  : x.onSurfaceMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // ── Formatting ─────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatListTime(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    if (sameDay) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final d = t.day.toString().padLeft(2, '0');
    final mo = t.month.toString().padLeft(2, '0');
    return '$d/$mo';
  }
}

class _AnimatedMessageText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback onFinished;

  const _AnimatedMessageText({
    required this.text,
    required this.style,
    required this.onFinished,
  });

  @override
  State<_AnimatedMessageText> createState() => _AnimatedMessageTextState();
}

class _AnimatedMessageTextState extends State<_AnimatedMessageText> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    final int delay = widget.text.length > 200 ? 5 : 15;
    _timer = Timer.periodic(Duration(milliseconds: delay), (timer) {
      if (_currentIndex < widget.text.length) {
        if (mounted) {
          setState(() {
            _currentIndex++;
            _displayedText = widget.text.substring(0, _currentIndex);
          });
        }
      } else {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}
