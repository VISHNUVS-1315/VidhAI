import 'package:flutter/material.dart';

import '../../features/forms/form_field_mapper.dart';
import '../../tools/ai_tool.dart';
import 'assistant_field_registry.dart';
import 'assistant_session.dart';

/// Writes a value into a real, currently-mounted form field on the active
/// screen. Only fields the app has explicitly registered can be filled —
/// the assistant can never touch unapproved controls.
class AssistantFormTool extends VidhAITool {
  @override
  String get name => 'FILL_FORM_FIELD';

  @override
  String get description => 'Fill a real form field on the current screen. '
      'Use GET_FORM_FIELDS first to see the available fields and their '
      'accepted options (e.g. gender: Male/Female/Other). Field names must '
      'match exactly, and the value must be one of the listed options when '
      'options are provided.';

  @override
  Map<String, dynamic> get parameters => withRequired(
        ['field', 'value'],
        {
          'field': stringParam(),
          'value': stringParam(),
        },
      );

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final field = (arguments['field'] ?? '').toString().trim();
    final value = (arguments['value'] ?? '').toString().trim();
    if (field.isEmpty || value.isEmpty) {
      return {'error': 'Both field and value are required.'};
    }
    final screen = AssistantSessionScreen.of(arguments);
    final fields = AssistantFieldRegistry.instance.fieldsFor(screen);
    String? label;
    List<String>? options;
    for (final f in fields) {
      if ((f['field'] ?? '').toString() == field) {
        label = (f['label'] ?? '').toString();
        final rawOptions = f['options'];
        if (rawOptions is String && rawOptions.trim().isNotEmpty) {
          options = [
            for (final o in rawOptions.split(','))
              if (o.trim().isNotEmpty) o.trim(),
          ];
        }
      }
    }
    // Normalize the spoken value onto the field format ("ஏழு"/"seven" -> "7")
    // so the form never stores the raw transcription.
    final normalized = const FormFieldMapper()
        .normalizeForField(field, value, options: options ?? const []);
    final result =
        AssistantFieldRegistry.instance.fill(screen, field, normalized);
    if (normalized != value) {
      result['normalizedFrom'] = value;
      if (label != null && result['applied'] != true) {
        result['options'] = options ?? const [];
      }
    }
    return result;
  }
}

/// Performs a real, registered app action (save form, delete farm, etc.).
/// Destructive actions require the farmer's explicit confirmation, which the
/// assistant surfaces; nothing destructive ever runs without it.
class AssistantActionTool extends VidhAITool {
  @override
  String get name => 'EXECUTE_ACTION';

  @override
  String get description =>
      'Perform a real registered action on the current screen, such as saving '
      'a filled form or deleting a farm. Use GET_FORM_FIELDS to see the '
      'available actions. When the result says needsConfirmation, wait for '
      'the farmer to confirm before continuing.';

  @override
  Map<String, dynamic> get parameters => withRequired(
        ['action'],
        {
          'action': stringParam(),
          'screen': stringParam(),
          'confirmed': {'type': 'boolean'},
          'args': {'type': 'object'},
        },
      );

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final action = (arguments['action'] ?? '').toString().trim();
    if (action.isEmpty) {
      return {'error': 'An action name is required.'};
    }
    final screen = AssistantSessionScreen.of(arguments);
    final args = (arguments['args'] is Map)
        ? Map<String, dynamic>.from(arguments['args'] as Map)
        : <String, dynamic>{};
    final confirmed = arguments['confirmed'] == true;
    return AssistantFieldRegistry.instance
        .runAction(screen, action: action, args: args, confirmed: confirmed);
  }
}

/// Lists the real fields and actions available on the current screen so the
/// brain never guesses field names.
class AssistantContextTool extends VidhAITool {
  @override
  String get name => 'GET_FORM_FIELDS';

  @override
  String get description =>
      'List the real form fields and actions currently available on the '
      'active screen, with accepted options and current values. Call this '
      'before FILL_FORM_FIELD or EXECUTE_ACTION.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'screen': stringParam(),
        },
        'required': <String>[],
      };

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final screen = AssistantSessionScreen.of(arguments);
    return {
      'screen': screen,
      'fields': AssistantFieldRegistry.instance.fieldsFor(screen),
      'actions': AssistantFieldRegistry.instance.actionsFor(screen),
    };
  }
}

/// Resolves the screen the assistant should act on. Passed explicitly by the
/// tool call, otherwise reuses the assistant's current screen.
class AssistantSessionScreen {
  static String of(Map<String, dynamic> args) {
    final explicit = (args['screen'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    final current = AssistantSession.instance.screenName;
    return current.isNotEmpty ? current : 'current';
  }
}
