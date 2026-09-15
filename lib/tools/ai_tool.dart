import 'package:flutter/material.dart';

/// A single, real, pre-validated app action the AI may request.
/// Only tools registered here are executable; the AI can never run arbitrary code.
abstract class VidhAITool {
  String get name;
  String get description;

  /// JSON-Schema parameters advertised to the AI brain.
  Map<String, dynamic> get parameters;

  /// Executes the tool against real existing app services.
  /// Must never fabricate data; returns a plain-text/map result for the AI to summarize.
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  });

  /// OpenAI-compatible function-calling wire format used by NVIDIA NIM.
  Map<String, dynamic> toFunctionSpec() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters,
      },
    };
  }
}

class VidhAIToolRegistry {
  VidhAIToolRegistry._();
  static final VidhAIToolRegistry instance = VidhAIToolRegistry._();

  final Map<String, VidhAITool> _tools = {};

  void register(VidhAITool tool) => _tools[tool.name] = tool;

  void registerAll(Iterable<VidhAITool> tools) {
    for (final t in tools) {
      _tools[t.name] = t;
    }
  }

  VidhAITool? get(String name) => _tools[name];

  bool contains(String name) => _tools.containsKey(name);

  List<VidhAITool> get all => _tools.values.toList();

  List<Map<String, dynamic>> aiSpecs() =>
      _tools.values.map((t) => t.toFunctionSpec()).toList();
}

/// Convenience JSON-schema builders.
Map<String, dynamic> stringParam({bool required = false}) => {'type': 'string'};

Map<String, dynamic> withRequired(
        List<String> required, Map<String, dynamic> properties) =>
    {
      'type': 'object',
      'properties': properties,
      'required': required,
    };
