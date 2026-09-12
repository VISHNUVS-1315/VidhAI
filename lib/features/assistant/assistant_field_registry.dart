import 'package:flutter/foundation.dart';
import 'package:vidhai/locale/locale.dart';

/// A single live, approved form field on a screen. Screens register these
/// so the assistant can fill **only** real fields that are mounted right now.
class AssistantFieldEntry {
  final String field;
  final String label;
  final String? suggestions;
  final String Function() read;
  final bool Function(String value) set;

  const AssistantFieldEntry({
    required this.field,
    required this.label,
    this.suggestions,
    required this.read,
    required this.set,
  });

  Map<String, dynamic> toMap() => {
        'field': field,
        'label': label,
        if (suggestions != null) 'options': suggestions,
        'value': read(),
      };
}

/// A real app action the assistant may trigger (e.g. save the form, delete a
/// farm). Destructive actions always require an explicit user confirmation,
/// which the assistant overlay surfaces before the underlying code runs.
class AssistantActionEntry {
  final String action;
  final String label;
  final bool destructive;

  /// When true the action never runs until the farmer taps Confirm/Save in the
  /// overlay, even though the action itself is not destructive. Used so form
  /// submissions (profile/farm) are reviewed before anything is persisted.
  final bool requiresConfirmation;
  final String? confirmLabelKey;
  final String? cancelLabelKey;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> args) run;

  const AssistantActionEntry({
    required this.action,
    required this.label,
    this.destructive = false,
    this.requiresConfirmation = false,
    this.confirmLabelKey,
    this.cancelLabelKey,
    required this.run,
  });
}

/// Bridges the VidhAI Assistant overlay to the real, mounted form widgets and
/// screen actions. Nothing here can invent data: a field can only be written
/// if its owning screen is currently on screen and has registered a setter.
class AssistantFieldRegistry {
  AssistantFieldRegistry._();
  static final AssistantFieldRegistry instance = AssistantFieldRegistry._();

  final Map<String, Map<String, AssistantFieldEntry>> _fields = {};
  final Map<String, Map<String, AssistantActionEntry>> _actions = {};

  @visibleForTesting
  bool fieldRegistered(String screen, String field) =>
      _fields[screen]?.containsKey(field) ?? false;

  void registerField(String screen, AssistantFieldEntry entry) {
    _fields.putIfAbsent(screen, () => {}).addAll({entry.field: entry});
  }

  void unregisterField(String screen, String field) {
    if (field == '' || !fieldRegistered(screen, field)) return;
    _fields[screen]?.remove(field);
    if (_fields[screen]?.isEmpty ?? false) _fields.remove(screen);
  }

  void unregisterAction(String screen, String action) {
    if (action == '' ||
        (_actions[screen]?.containsKey(action) ?? false) == false) {
      return;
    }
    _actions[screen]?.remove(action);
    if (_actions[screen]?.isEmpty ?? false) _actions.remove(screen);
  }

  void registerAction(String screen, AssistantActionEntry entry) {
    _actions.putIfAbsent(screen, () => {}).addAll({entry.action: entry});
  }

  /// Current registered fields for a screen, for context and for the brain.
  List<Map<String, dynamic>> fieldsFor(String screen) =>
      (_fields[screen]?.values.toList() ?? const [])
          .map((e) => e.toMap())
          .toList();

  List<Map<String, dynamic>> actionsFor(String screen) =>
      (_actions[screen]?.values.toList() ?? const [])
          .map((a) => {
                'action': a.action,
                'label': a.label,
                'destructive': a.destructive,
              })
          .toList();

  /// Writes a user-friendly value into a real mounted field.
  Map<String, dynamic> fill(String screen, String field, String value,
      {String? language}) {
    final loc = language != null ? AppLocalizations(language) : null;
    final entry = _fields[screen]?[field];
    if (entry == null) {
      String errorMsg;
      if (loc != null) {
        errorMsg = loc
            .t('assistant_field_not_available')
            .replaceAll('{field}', field)
            .replaceAll('{screen}', screen);
      } else {
        errorMsg = 'Field "$field" is not available on screen "$screen".';
      }
      return {'applied': false, 'error': errorMsg};
    }
    try {
      final accepted = entry.set(value);
      if (!accepted) {
        String errorMsg;
        if (loc != null) {
          errorMsg = loc
              .t('assistant_invalid_value')
              .replaceAll('{value}', value)
              .replaceAll('{field}', field);
        } else {
          errorMsg = 'The value "$value" is not valid for "$field".';
        }
        return {
          'applied': false,
          'error': errorMsg,
          'options': entry.suggestions
        };
      }
      return {'applied': true, 'field': field, 'value': entry.read()};
    } catch (e) {
      return {
        'applied': false,
        'error': loc?.assistantCouldNotSetField
                .replaceAll('{field}', field)
                .replaceAll('{error}', e.toString()) ??
            'Could not set "$field": $e',
      };
    }
  }

  /// Triggers a real action on the mounted screen. Destructive actions ask for
  /// an explicit confirmation first; once [confirmed] is true they run for
  /// real against the live app code.
  Future<Map<String, dynamic>> runAction(
    String screen, {
    required String action,
    required Map<String, dynamic> args,
    bool confirmed = false,
    String? language,
  }) async {
    final loc = language != null ? AppLocalizations(language) : null;
    final entry = _actions[screen]?[action];
    if (entry == null) {
      String errorMsg;
      if (loc != null) {
        errorMsg = loc
            .t('assistant_action_not_registered')
            .replaceAll('{action}', action)
            .replaceAll('{screen}', screen);
      } else {
        errorMsg = 'Action "$action" is not registered on screen "$screen".';
      }
      return {'error': errorMsg};
    }
    if (entry.destructive || entry.requiresConfirmation) {
      if (!confirmed) {
        return {
          'needsConfirmation': true,
          'action': action,
          'screen': screen,
          'summary': entry.label,
          'args': args,
          'confirmLabelKey': entry.confirmLabelKey,
          'cancelLabelKey': entry.cancelLabelKey,
        };
      }
    }
    try {
      final result = await entry.run(args);
      return result;
    } catch (e) {
      String errorMsg;
      if (loc != null) {
        errorMsg = loc
            .t('assistant_action_failed')
            .replaceAll('{action}', action)
            .replaceAll('{error}', e.toString());
      } else {
        errorMsg = 'Action "$action" failed: $e';
      }
      return {'error': errorMsg};
    }
  }
}
