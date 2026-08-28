import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vidhai/services/voice_service.dart';
import 'package:vidhai/services/ai/domain_services.dart';
import 'package:vidhai/services/data_service.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  bool isNewlyAdded;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isNewlyAdded = false,
  });
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceService _voiceService = VoiceService();

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isListening = false;

  static const Color _bgColor = Color(0xFF0A0F1A);
  static const Color _bubbleDark = Color(0xFF111827);
  static const Color _accent = Color(0xFF4CAF50);
  static const Color _inputBg = Color(0xFF1A2332);

  bool _hasNonLatin(String text) {
    return RegExp(r'[^\x00-\x7F]').hasMatch(text);
  }

  final _chatService = VidhAIChatService.instance;
  final _dataService = DataService();

  Future<String> _getResponse(String input) async {
    final profile = await _dataService.loadCachedProfile();
    final farms = await _dataService.loadFarms();
    final farmMaps = farms.map((f) => f.toMap()).toList();
    final profileMap = profile?.toMap() ?? {};
    final lang = await _dataService.getSelectedLanguage();
    return _chatService.chat(
      input,
      language: lang,
      userProfile: profileMap,
      farms: farmMaps.isNotEmpty ? farmMaps : null,
    );
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = _ChatMessage(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final responseText = await _getResponse(text);
      if (!mounted) return;
      final aiMsg = _ChatMessage(
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
        isNewlyAdded: true,
      );
      setState(() {
        _isTyping = false;
        _messages.add(aiMsg);
      });
    } catch (e) {
      if (!mounted) return;
      final aiMsg = _ChatMessage(
        text: _hasNonLatin(text)
            ? 'மன்னிக்கவும், ஏதோ தவறு நடந்தது. மீண்டும் முயற்சிக்கவும்.'
            : 'Sorry, something went wrong. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
        isNewlyAdded: true,
      );
      setState(() {
        _isTyping = false;
        _messages.add(aiMsg);
      });
    }
    _scrollToBottom();
  }

  void _startVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);

    await _voiceService.startListening(
      onResult: (text, confidence) {
        setState(() => _isListening = false);
        _controller.text = text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      },
      onListeningComplete: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _voiceService.stopListening();
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text(
              'VidhAI AI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: _accent, size: 8),
                const SizedBox(width: 4),
                Text(
                  'Online',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'VidhAI AI Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me anything about your farming...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('What should I do now?'),
                _buildSuggestionChip('Best crop to grow?'),
                _buildSuggestionChip('Tomato price'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _bubbleDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
          ),
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
        final msg = _messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? _accent : _bubbleDark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser || !msg.isNewlyAdded)
              Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
              )
            else
              _AnimatedMessageText(
                text: msg.text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
                onFinished: () {
                  msg.isNewlyAdded = false;
                },
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(
                color: (isUser ? Colors.white : Colors.white).withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: _bubbleDark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
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
              color: _accent.withValues(alpha: value),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: _bgColor,
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _startVoiceInput,
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : _accent,
              size: 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _isListening
                  ? Colors.red.withValues(alpha: 0.15)
                  : _accent.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) => _sendMessage(value),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _sendMessage(_controller.text),
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
    // Type faster for longer text to avoid waiting too long
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
