import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/services/ai/secure_api_client.dart';

void main() {
  group('SecureApiClient.decodeSse', () {
    test('yields each data JSON event across chunk boundaries', () async {
      final bytes = Stream<List<int>>.fromIterable([
        utf8.encode('data: {"delta":'),
        utf8.encode('"he"}\n\n'),
        utf8.encode('data: {"delta":"llo"}\n\n'),
        utf8.encode('data: [DONE]\n\n'),
      ]);
      final events = await SecureApiClient.decodeSse(bytes).toList();
      expect(events, [
        {'delta': 'he'},
        {'delta': 'llo'},
      ]);
    });

    test('skips malformed frames and non-data keepalive lines', () async {
      final bytes = Stream<List<int>>.value(
        utf8.encode(
          ': keepalive\n\n'
          'data: {"delta":"a"}\n\n'
          'data: not json\n\n'
          'data: {"delta":"b"}\n\n'
          'data: [DONE]\n\n',
        ),
      );
      final events = await SecureApiClient.decodeSse(bytes).toList();
      expect(events, [
        {'delta': 'a'},
        {'delta': 'b'},
      ]);
    });

    test('handles CRLF line endings', () async {
      final bytes = Stream<List<int>>.value(
        utf8.encode(
          'data: {"delta":"x"}\r\n\r\n'
          'data: {"done":true}\r\n\r\n',
        ),
      );
      final events = await SecureApiClient.decodeSse(bytes).toList();
      expect(events, [
        {'delta': 'x'},
        {'done': true},
      ]);
    });

    test('multibyte UTF-8 split across chunks decodes correctly', () async {
      final encoded = utf8.encode('data: {"delta":"\u{1F331}"}\n\n');
      final splitAt = encoded.length - 2;
      final bytes = Stream<List<int>>.fromIterable([
        encoded.sublist(0, splitAt),
        encoded.sublist(splitAt),
      ]);
      final events = await SecureApiClient.decodeSse(bytes).toList();
      expect(events, [
        {'delta': '\u{1F331}'},
      ]);
    });

    test('empty stream yields no events', () async {
      final events = await SecureApiClient.decodeSse(
        const Stream<List<int>>.empty(),
      ).toList();
      expect(events, isEmpty);
    });
  });
}