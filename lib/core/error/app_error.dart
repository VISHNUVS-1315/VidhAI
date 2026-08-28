import 'package:flutter/material.dart';

class AppError implements Exception {
  final String message;
  final String? prefix;
  final Object? cause;

  AppError({required this.message, this.prefix, this.cause});

  @override
  String toString() {
    if (prefix != null) {
      return '$prefix: $message';
    }
    return 'AppError: $message';
  }
}

extension AppErrorExtension on Object {
  AppError asAppError([String? prefix]) {
    return AppError(message: toString(), prefix: prefix);
  }
}

Widget buildErrorView(
  BuildContext context,
  AppError error, {
  VoidCallback? onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            error.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          if (onRetry != null) ...[
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}