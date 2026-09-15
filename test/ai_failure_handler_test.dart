import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/core/ai/ai_failure_handler.dart';

void main() {
  group('AiFailureHandler.fromStatus', () {
    test('auth statuses map to auth', () {
      final f = AiFailureHandler.fromStatus(401, 'denied');
      expect(f.kind, AiErrorKind.auth);
      expect(f.retryable, isFalse);
    });

    test('timeout statuses are retryable', () {
      expect(AiFailureHandler.fromStatus(504, 'x').kind, AiErrorKind.timeout);
      expect(AiFailureHandler.fromStatus(504, 'x').retryable, isTrue);
    });

    test('429 maps to rateLimited and is retryable', () {
      final f = AiFailureHandler.fromStatus(429, 'busy');
      expect(f.kind, AiErrorKind.rateLimited);
      expect(f.retryable, isTrue);
    });

    test('5xx maps to busy and is retryable', () {
      for (final code in [500, 502, 503]) {
        final f = AiFailureHandler.fromStatus(code, 'x');
        expect(f.kind, AiErrorKind.busy);
        expect(f.retryable, isTrue);
      }
    });

    test('unknown status falls back to generic', () {
      final f = AiFailureHandler.fromStatus(418, 'teapot');
      expect(f.kind, AiErrorKind.generic);
      expect(f.retryable, isFalse);
    });
  });

  group('AiFailureHandler.fromError', () {
    test('connects network/socket errors to timeout (retryable)', () {
      final f = AiFailureHandler.fromError(
        TimeoutException('The request timed out.'),
      );
      expect(f.kind, AiErrorKind.timeout);
      expect(f.retryable, isTrue);
    });

    test('connects socket/connection phrases to timeout (retryable)', () {
      final f = AiFailureHandler.fromError(
        Exception('Connection reset by peer'),
      );
      expect(f.kind, AiErrorKind.timeout);
      expect(f.retryable, isTrue);
    });

    test('internet/offline phrases map to offline', () {
      final f = AiFailureHandler.fromError(Exception('No internet connection'));
      expect(f.kind, AiErrorKind.offline);
    });

    test('rate limit phrases map to rateLimited', () {
      final f = AiFailureHandler.fromError(Exception('Rate limit exceeded'));
      expect(f.kind, AiErrorKind.rateLimited);
      expect(f.retryable, isTrue);
    });

    test('5xx phrases map to busy (retryable)', () {
      final f = AiFailureHandler.fromError(
        Exception('HTTP 503 Service Unavailable'),
      );
      expect(f.kind, AiErrorKind.busy);
      expect(f.retryable, isTrue);
    });
  });

  group('Retry policy', () {
    test('shouldRetry stops after extra attempts are exhausted', () {
      const f = AiFailure(kind: AiErrorKind.timeout, message: 'x', retryable: true);
      expect(AiFailureHandler.shouldRetry(f, 0), isTrue);
      expect(AiFailureHandler.shouldRetry(f, 1), isTrue);
      expect(AiFailureHandler.shouldRetry(f, 2), isTrue);
      expect(AiFailureHandler.shouldRetry(f, 3), isFalse);
    });

    test('non-retryable failures never retry', () {
      const f = AiFailure(kind: AiErrorKind.auth, message: 'x');
      expect(AiFailureHandler.shouldRetry(f, 0), isFalse);
    });

    test('backoff grows between attempts', () {
      expect(AiFailureHandler.backoffForAttempt(0), const Duration(milliseconds: 400));
      expect(AiFailureHandler.backoffForAttempt(1), const Duration(milliseconds: 1000));
      expect(AiFailureHandler.backoffForAttempt(2), const Duration(milliseconds: 1800));
    });
  });
}