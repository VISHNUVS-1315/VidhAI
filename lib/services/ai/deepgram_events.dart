/// Pure parsing and assembly helpers for Deepgram realtime transcription
/// (`/v1/listen` WebSocket) events.
///
/// Kept free of plugins so the streaming behaviour can be unit tested without
/// a device. [DeepgramTranscriptAssembler] keeps the finalised transcript
/// separate from the live interim segment so words are never duplicated and
/// the visible text stays stable, per the Deepgram interim/final contract:
///
///  - `is_final: false` packets are cumulative interim transcripts for the
///    current utterance and are replaced (never appended);
///  - `is_final: true` packets finalise a segment. Deepgram may either deliver
///    a cumulative superset of the previous final text or a fresh segment that
///    must be appended (the classic multi-`is_final` utterance), so both
///    shapes are reconciled before committing;
///  - `speech_final: true` / `SpeechStarted` / `UtteranceEnd` signal the end of
///    the current utterance, which commits the pending final text exactly once.
library;

/// The event shapes this app consumes from the Deepgram `/v1/listen` socket.
enum DeepgramEventType {
  results,
  metadata,
  speechStarted,
  utteranceEnd,
  error,
  unknown,
}

/// A decoded, typed Deepgram server event.
class DeepgramSpeechEvent {
  const DeepgramSpeechEvent({
    this.type = DeepgramEventType.unknown,
    this.transcript = '',
    this.isFinal = false,
    this.speechFinal = false,
    this.errorCode,
    this.errorMessage,
  });

  final DeepgramEventType type;

  /// Truncated, trimmed best alternative transcript (only for `results`).
  final String transcript;

  /// `is_final` — whether the segment transcript is finalised.
  final bool isFinal;

  /// `speech_final` — whether this packet ends the current utterance.
  final bool speechFinal;

  final String? errorCode;
  final String? errorMessage;
}

/// Parses a raw decoded JSON map from the Deepgram WebSocket.
///
/// Unknown or malformed payloads degrade to `DeepgramEventType.unknown`
/// instead of throwing, so a single bad event can never crash the session.
DeepgramSpeechEvent parseDeepgramEvent(Map<String, dynamic> json) {
  final type = json['type'];
  if (type is! String) return const DeepgramSpeechEvent();

  switch (type) {
    case 'Results':
      final alternatives = _firstAlternatives(json['channel']);
      final transcript = alternatives == null
          ? ''
          : ((alternatives['transcript'] as String?) ?? '').trim();
      return DeepgramSpeechEvent(
        type: DeepgramEventType.results,
        transcript: transcript,
        isFinal: json['is_final'] == true,
        speechFinal: json['speech_final'] == true,
      );
    case 'SpeechStarted':
      return const DeepgramSpeechEvent(type: DeepgramEventType.speechStarted);
    case 'UtteranceEnd':
      return const DeepgramSpeechEvent(type: DeepgramEventType.utteranceEnd);
    case 'Metadata':
      return const DeepgramSpeechEvent(type: DeepgramEventType.metadata);
    case 'Error':
      return DeepgramSpeechEvent(
        type: DeepgramEventType.error,
        errorCode: json['err_code'] as String?,
        errorMessage: json['err_msg'] as String?,
      );
    default:
      return const DeepgramSpeechEvent();
  }
}

Map<String, dynamic>? _firstAlternatives(dynamic channel) {
  if (channel is! Map<String, dynamic>) return null;
  final alternatives = channel['alternatives'];
  if (alternatives is! List || alternatives.isEmpty) return null;
  final first = alternatives.first;
  return first is Map<String, dynamic> ? first : null;
}

/// Assembles Deepgram interim segments and finalised utterances into one
/// stable display transcript (no duplicated or scrambled words).
class DeepgramTranscriptAssembler {
  static const int _maxUtterances = 120;

  final List<String> _committed = [];
  String _pending = '';
  String _interim = '';

  /// Only the finalised (committed) utterances.
  String get completedText => _committed.join('\n');

  /// Thing to show right now: committed utterances plus the live current
  /// segment. The interim (when present) is the authoritative live text of the
  /// current utterance and already contains the pending final words, so it is
  /// shown instead of the pending buffer to avoid duplication.
  String get combined {
    final current = _interim.isNotEmpty ? _interim : _pending;
    if (current.isEmpty) return completedText;
    if (_committed.isEmpty) return current;
    return '$completedText\n$current';
  }

  bool get hasPendingTranscript => _pending.isNotEmpty || _interim.isNotEmpty;

  /// Number of finalised utterances (useful for tests).
  int get utteranceCount => _committed.length;

  /// Applies a parsed Results packet.
  void addResults({
    required String transcript,
    required bool isFinal,
    required bool speechFinal,
  }) {
    final t = transcript.trim();
    if (t.isEmpty) return;

    if (!isFinal) {
      _interim = t;
      return;
    }

    _interim = '';
    if (t == _pending) {
      // Duplicate delivery of the same final text.
    } else if (_pending.isNotEmpty && _pending.endsWith(t)) {
      // Already contained at the tail of the pending utterance.
    } else if (_pending.isNotEmpty && t.startsWith(_pending)) {
      // Cumulative update of the pending utterance.
      _pending = t;
    } else if (_pending.contains(t)) {
      // Rescored subset that is already covered.
    } else {
      // Fresh segment of the same utterance: append.
      _pending = _pending.isEmpty ? t : '$_pending $t';
    }

    if (speechFinal) {
      _commitPending();
    }
  }

  /// Commits any pending final text for the current utterance. Safe to call
  /// repeatedly (e.g. on SpeechStarted AND UtteranceEnd AND user stop).
  void commitPending() => _commitPending();

  void _commitPending() {
    final text = _pending.trim();
    _pending = '';
    _interim = '';
    if (text.isEmpty) return;
    if (_committed.isNotEmpty && _committed.last == text) return;
    _committed.add(text);
    if (_committed.length > _maxUtterances) {
      _committed.removeAt(0);
    }
  }

  void clear() {
    _committed.clear();
    _pending = '';
    _interim = '';
  }
}

/// VidhAI language codes -> ISO-639-1 codes (identity for all 13 codes).
const Map<String, String> vidhaiToIso6391 = {
  'en': 'en',
  'ta': 'ta',
  'te': 'te',
  'kn': 'kn',
  'ml': 'ml',
  'hi': 'hi',
  'bn': 'bn',
  'mr': 'mr',
  'gu': 'gu',
  'pa': 'pa',
  'or': 'or',
  'as': 'as',
  'ur': 'ur',
};

/// BCP-47 tags recognised by the Deepgram Nova-3 realtime `/v1/listen`
/// endpoint. Malayalam (`ml`) and Odia/Oriya (`or`) are NOT offered by any
/// Deepgram streaming model, so those codes map to no language.
const Map<String, String> deepgramIsoToBcp47 = {
  'en': 'en',
  'ta': 'ta',
  'te': 'te',
  'kn': 'kn',
  'hi': 'hi',
  'bn': 'bn',
  'mr': 'mr',
  'gu': 'gu',
  'pa': 'pa',
  'ur': 'ur',
  'as': 'as',
};

/// Maps a VidhAI language code to an ISO-639-1 code, 'en' when unknown.
String realtimeIsoCode(String? languageCode) =>
    vidhaiToIso6391[languageCode] ?? 'en';

/// Whether the given VidhAI language can be transcribed by Deepgram now.
bool isDeepgramLanguageSupported(String? languageCode) =>
    deepgramIsoToBcp47.containsKey(realtimeIsoCode(languageCode));

/// Deepgram BCP-47 language tag for the VidhAI language, or null when Deepgram
/// has no streaming model for it (Malayalam, Odia).
String? deepgramLanguageFor(String? languageCode) =>
    deepgramIsoToBcp47[realtimeIsoCode(languageCode)];
