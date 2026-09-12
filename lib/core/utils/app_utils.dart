import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:vidhai/core/error/app_error.dart';
import 'package:vidhai/locale/locale.dart';

String formatDate(DateTime date, {String pattern = 'dd MMM yyyy'}) {
  return DateFormat(pattern).format(date);
}

String formatCurrency(double amount, {String symbol = '₹'}) {
  return '$symbol${amount.toStringAsFixed(2)}';
}

double parseCurrency(String? value, {double defaultValue = 0.0}) {
  if (value == null || value.isEmpty) return defaultValue;
  final cleanValue = value.replaceAll(RegExp(r'[^\d.]'), '');
  return double.tryParse(cleanValue) ?? defaultValue;
}

void showSnackbar(BuildContext context, String message,
    {Color? backgroundColor, Color? actionColor}) {
  final loc = AppLocalizations.of(context);
  final snackBar = SnackBar(
    content: Text(message),
    backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.error,
    action: SnackBarAction(
      label: loc.t('ok'),
      textColor: actionColor,
      onPressed: () {},
    ),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

void showErrorDialog(
  BuildContext context,
  AppError error, {
  VoidCallback? onRetry,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final loc = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(loc.t('error')),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc.t('ok')),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(loc.t('retry')),
            ),
        ],
      );
    },
  );
}

String? validateRequired(String? value, {String fieldName = 'Field'}) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName is required';
  }
  return null;
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
  if (!emailRegex.hasMatch(value)) {
    return 'Invalid email format';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Password is required';
  }
  if (value.length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}
