import 'package:flutter_test/flutter_test.dart';

import 'package:vidhai/services/ai/deepgram_events.dart';

void main() {
  group('parseDeepgramEvent', () {
    test('parses an interim Results packet', () {
      final e = parseDeepgramEvent({
        'type': 'Results',
        'channel': {
          'alternatives': [
            {'transcript': 'என் தக்காளி', 'confidence': 0.96},
          ],
        },
        'is_final': false,
        'speech_final': false,
      });
      expect(e.type, DeepgramEventType.results);
      expect(e.transcript, 'என் தக்காளி');
      expect(e.isFinal, isFalse);
      expect(e.speechFinal, isFalse);
    });

    test('parses a final Results packet and trims whitespace', () {
      final e = parseDeepgramEvent({
        'type': 'Results',
        'channel': {
          'alternatives': [
            {'transcript': '  hello world  '},
          ],
        },
        'is_final': true,
        'speech_final': true,
      });
      expect(e.type, DeepgramEventType.results);
      expect(e.transcript, 'hello world');
      expect(e.isFinal, isTrue);
      expect(e.speechFinal, isTrue);
    });

    test('parses SpeechStarted, UtteranceEnd, Metadata, Error', () {
      expect(
        parseDeepgramEvent({'type': 'SpeechStarted'}).type,
        DeepgramEventType.speechStarted,
      );
      expect(
        parseDeepgramEvent({'type': 'UtteranceEnd'}).type,
        DeepgramEventType.utteranceEnd,
      );
      expect(
        parseDeepgramEvent({'type': 'Metadata'}).type,
        DeepgramEventType.metadata,
      );
      final err = parseDeepgramEvent({
        'type': 'Error',
        'err_code': 'INVALID_AUTH',
        'err_msg': 'invalid api key provided',
      });
      expect(err.type, DeepgramEventType.error);
      expect(err.errorCode, 'INVALID_AUTH');
      expect(err.errorMessage, 'invalid api key provided');
    });

    test('malformed payloads degrade gracefully instead of throwing', () {
      expect(parseDeepgramEvent({}).type, DeepgramEventType.unknown);
      expect(parseDeepgramEvent({'type': 42}).type, DeepgramEventType.unknown);
      expect(parseDeepgramEvent({'type': 'SomethingElse'}).type,
          DeepgramEventType.unknown);
      // A Results packet with no transcript is a valid-but-empty results event.
      final e = parseDeepgramEvent({
        'type': 'Results',
        'channel': {'alternatives': 'nope'},
        'is_final': true,
      });
      expect(e.type, DeepgramEventType.results);
      expect(e.transcript, isEmpty);
      expect(e.isFinal, isTrue);
    });
  });

  group('DeepgramTranscriptAssembler', () {
    test('interim packets replace, never duplicate', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(
          transcript: 'என் தக்காளி', isFinal: false, speechFinal: false);
      a.addResults(
          transcript: 'என் தக்காளி செடியில்',
          isFinal: false,
          speechFinal: false);
      a.addResults(
          transcript: 'என் தக்காளி செடியில் இலை மஞ்சளாக மாறுது',
          isFinal: false,
          speechFinal: false);
      expect(a.combined, 'என் தக்காளி செடியில் இலை மஞ்சளாக மாறுது');
      expect(a.utteranceCount, 0);
    });

    test('cumulative final packets commit exactly once', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(
          transcript: 'என் தக்காளி செடியில்',
          isFinal: true,
          speechFinal: false);
      a.addResults(
          transcript: 'என் தக்காளி செடியில் இலை மஞ்சளாக',
          isFinal: true,
          speechFinal: false);
      a.addResults(
          transcript: 'என் தக்காளி செடியில் இலை மஞ்சளாக மாறுது',
          isFinal: true,
          speechFinal: true);
      expect(a.utteranceCount, 1);
      expect(a.completedText, 'என் தக்காளி செடியில் இலை மஞ்சளாக மாறுது');
      expect(a.combined, 'என் தக்காளி செடியில் இலை மஞ்சளாக மாறுது');
      expect(a.hasPendingTranscript, isFalse);
    });

    test('segmented final packets append into one utterance', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(
          transcript: 'I think that', isFinal: true, speechFinal: false);
      a.addResults(
          transcript: 'a great idea', isFinal: true, speechFinal: true);
      expect(a.utteranceCount, 1);
      expect(a.completedText, 'I think that a great idea');
    });

    test('duplicate final packets are ignored', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(transcript: 'hello world', isFinal: true, speechFinal: true);
      a.addResults(transcript: 'hello world', isFinal: true, speechFinal: true);
      expect(a.utteranceCount, 1);
      expect(a.completedText, 'hello world');
    });

    test('speech_final then SpeechStarted commit once (no double commit)', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(transcript: 'hello', isFinal: true, speechFinal: true);
      a.commitPending();
      a.commitPending();
      expect(a.utteranceCount, 1);
      expect(a.completedText, 'hello');
    });

    test('interim covers pending final words without duplication', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(transcript: 'hello', isFinal: true, speechFinal: false);
      a.addResults(
          transcript: 'hello world', isFinal: false, speechFinal: false);
      expect(a.combined, 'hello world');
    });

    test('utteranceEnd commits the pending utterance', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(transcript: 'second', isFinal: true, speechFinal: false);
      a.commitPending();
      expect(a.utteranceCount, 1);
      expect(a.completedText, 'second');
    });

    test('empty transcripts never pollute state', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(transcript: '   ', isFinal: true, speechFinal: true);
      a.addResults(transcript: '', isFinal: false, speechFinal: false);
      expect(a.utteranceCount, 0);
      expect(a.combined, '');
    });

    test('clear resets everything', () {
      final a = DeepgramTranscriptAssembler();
      a.addResults(transcript: 'first', isFinal: true, speechFinal: true);
      a.addResults(
          transcript: 'second partial', isFinal: false, speechFinal: false);
      a.clear();
      expect(a.utteranceCount, 0);
      expect(a.combined, '');
      expect(a.hasPendingTranscript, isFalse);
    });
  });

  group('language mapping', () {
    test('realtimeIsoCode maps all 13 VidhAI codes and falls back to en', () {
      expect(realtimeIsoCode('en'), 'en');
      expect(realtimeIsoCode('ta'), 'ta');
      expect(realtimeIsoCode('ml'), 'ml');
      expect(realtimeIsoCode('or'), 'or');
      expect(realtimeIsoCode(null), 'en');
      expect(realtimeIsoCode('xx'), 'en');
    });

    test('Deepgram supports the Nova-3 languages only', () {
      expect(isDeepgramLanguageSupported('ta'), isTrue);
      expect(isDeepgramLanguageSupported('hi'), isTrue);
      expect(isDeepgramLanguageSupported('kn'), isTrue);
      expect(isDeepgramLanguageSupported('ml'), isFalse);
      expect(isDeepgramLanguageSupported('or'), isFalse);
      expect(isDeepgramLanguageSupported('xx'),
          isTrue); // unknown codes fall back to en
    });

    test('deepgramLanguageFor returns null for unsupported languages', () {
      expect(deepgramLanguageFor('ta'), 'ta');
      expect(deepgramLanguageFor('as'), 'as');
      expect(deepgramLanguageFor('ml'), isNull);
      expect(deepgramLanguageFor('or'), isNull);
    });
  });
}
