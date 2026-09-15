/// Classifies AI-layer failures into a small, actionable set and decides
/// whether a request is worth retrying with backoff.
///
/// The app's chat/voice/orchestrator surfaces feed exceptions (especially
/// [SecureApiException]) through [fromError]; the retry policy in [shouldRetry]
/// bounds extra attempts so a flaky provider never stalls the farmer.
library;

enum AiErrorKind {
  offline,
  auth,
  timeout,
  rateLimited,
  busy,
  generic,
}

class AiFailure {
  final AiErrorKind kind;
  final String message;
  final bool retryable;
  final int? statusCode;

  const AiFailure({
    required this.kind,
    required this.message,
    this.retryable = false,
    this.statusCode,
  });
}

class AiFailureHandler {
  AiFailureHandler._();

  /// Extra attempts (after the first try) allowed for retryable failures.
  static const int maxExtraAttempts = 2;

  /// Primary (recommended): classify from an HTTP status + message.
  static AiFailure fromStatus(int? statusCode, String message) {
    switch (statusCode) {
      case 401:
      case 403:
        return AiFailure(
          kind: AiErrorKind.auth,
          message: _authMessage,
          statusCode: statusCode,
        );
      case 408:
      case 504:
        return AiFailure(
          kind: AiErrorKind.timeout,
          message: _timeoutMessage,
          retryable: true,
          statusCode: statusCode,
        );
      case 429:
        return AiFailure(
          kind: AiErrorKind.rateLimited,
          message: _rateLimitMessage,
          retryable: true,
          statusCode: statusCode,
        );
      case 500:
      case 502:
      case 503:
        return AiFailure(
          kind: AiErrorKind.busy,
          message: _busyMessage,
          retryable: true,
          statusCode: statusCode,
        );
      default:
        return AiFailure(
          kind: AiErrorKind.generic,
          message: message.isEmpty ? _genericMessage : message,
          statusCode: statusCode,
        );
    }
  }

  /// Secondary: classify an arbitrary thrown object via message heuristics.
  static AiFailure fromError(Object error) {
    final text = error.toString().toLowerCase();
    final message = error.toString();

    if (text.contains('not signed in') ||
        text.contains('invalid or expired token')) {
      return const AiFailure(kind: AiErrorKind.auth, message: _authMessage);
    }
    if (text.contains('internet') ||
        text.contains('offline') ||
        text.contains('no network') ||
        text.contains('host')) {
      return const AiFailure(kind: AiErrorKind.offline, message: _offlineMessage);
    }
    if (text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('took too long') ||
        text.contains('socketexception') ||
        text.contains('connection')) {
      return const AiFailure(
        kind: AiErrorKind.timeout,
        message: _timeoutMessage,
        retryable: true,
      );
    }
    if (text.contains('ratelimit') || text.contains('rate limit')) {
      return const AiFailure(
        kind: AiErrorKind.rateLimited,
        message: _rateLimitMessage,
        retryable: true,
      );
    }
    if (text.contains('internet') ||
        text.contains('offline') ||
        text.contains('host')) {
      return const AiFailure(kind: AiErrorKind.offline, message: _offlineMessage);
    }
    if (text.contains('500') || text.contains('503') || text.contains('502') ||
        text.contains('504') || text.contains('service unavailable')) {
      return const AiFailure(
        kind: AiErrorKind.busy,
        message: _busyMessage,
        retryable: true,
      );
    }
    return AiFailure(
        kind: AiErrorKind.generic, message: message.isEmpty ? _genericMessage : message);
  }

  static bool shouldRetry(AiFailure failure, int attemptedSoFar) {
    return failure.retryable && attemptedSoFar <= maxExtraAttempts;
  }

  /// Increasing backoff between attempts: ~400ms, ~1s, ~1.8s.
  static Duration backoffForAttempt(int attemptedBefore) {
    if (attemptedBefore <= 0) return const Duration(milliseconds: 400);
    if (attemptedBefore == 1) return const Duration(milliseconds: 1000);
    return const Duration(milliseconds: 1800);
  }

  static const String _offlineMessage =
      'AI requires an internet connection. Please check your connection and try again.';
  static const String _authMessage =
      'You are not signed in. Please sign in and try again.';
  static const String _timeoutMessage =
      'The AI service took too long to respond. Please try again.';
  static const String _rateLimitMessage =
      'The AI service is busy right now. Please try again in a moment.';
  static const String _busyMessage =
      'The AI service is temporarily unavailable. Please try again.';
  static const String _genericMessage =
      'Something went wrong with the AI service. Please try again.';
}