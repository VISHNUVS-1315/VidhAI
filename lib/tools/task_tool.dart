import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../services/task_service.dart';
import '../services/weather_service.dart';
import '../features/farm/crop_stage.dart';
import '../data/models/crop_models.dart';
import '../tools/ai_tool.dart';

/// Reads and updates the farmer's real daily task list.
class TaskTool extends VidhAITool {
  TaskTool();
  final DataService _data = DataService();
  final TaskService _tasks = TaskService();

  @override
  String get name => 'FARM_TASKS';

  @override
  String get description =>
      'Read the farmer\'s daily farm tasks, or mark a task as done. '
      'Action values: "list" (returns today\'s real tasks), '
      '"toggle" (marks a task completed). Data comes from the farmer\'s own saved tasks only.';

  @override
  Map<String, dynamic> get parameters => withRequired(
        <String>['action'],
        {
          'action': stringParam(),
          'taskId': stringParam(),
        },
      );

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final action = (arguments['action'] ?? '').toString();
    var tasks = await _tasks.loadTasks();

    if (tasks.isEmpty) {
      try {
        final farms = await _data.loadFarms();
        if (farms.isNotEmpty) {
          final context = await _buildTaskContext();
          tasks = TaskService.generateTasksFromFarms(
            context.farmMaps,
            weatherByFarmIndex: context.weatherByFarmIndex,
            cropNameByFarmIndex: context.cropNameByFarmIndex,
            stageByFarmIndex: context.stageByFarmIndex,
          );
          await _tasks.saveTasks(tasks);
        }
      } catch (_) {}
    }

    if (action == 'toggle') {
      final taskId = (arguments['taskId'] ?? '').toString();
      FarmTask? found;
      for (final t in tasks) {
        if (t.id == taskId) {
          found = t;
          break;
        }
      }
      if (found == null) {
        return {'error': 'Task not found.'};
      }
      await _tasks.toggleTaskCompletion(found);
      return {
        'updated': true,
        'taskId': taskId,
        'title': found.title,
        'completed': !found.completed,
      };
    }

    if (tasks.isEmpty) {
      return {
        'tasks': <Object>[],
        'note': 'No tasks yet. The tasks appear once the farmer adds farms.',
      };
    }

    // Cap payload; keep it truthful and compact.
    final now = DateTime.now();
    return {
      'tasks': tasks.take(8).map((t) {
        final isToday = t.scheduledTime != null;
        return {
          'id': t.id,
          'title': t.title,
          'category': t.category,
          'scheduledTime': isToday ? t.scheduledTime : null,
          'completed': t.completed,
          'dueDate':
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        };
      }).toList(),
      'count': tasks.length,
    };
  }

  Future<_TaskContext> _buildTaskContext() async {
    List<Map<String, dynamic>> farmMaps = [];
    try {
      final farms = await _data.loadFarms();
      farmMaps = farms.map((f) => f.toMap()).toList();
    } catch (_) {}

    final weatherByFarmIndex = <int, Map<String, dynamic>>{};
    final cropNameByFarmIndex = <int, String>{};
    final stageByFarmIndex = <int, String>{};

    final weatherService = WeatherService();
    for (final farmMap in farmMaps) {
      final index = farmMap['index'] ?? 0;
      final loc = farmMap['farmLocation'];
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        try {
          final w = await weatherService.getWeather(
            (loc['latitude'] as num).toDouble(),
            (loc['longitude'] as num).toDouble(),
          );
          if (w != null) {
            weatherByFarmIndex[index] = WeatherData.alertContext(w);
          }
        } catch (_) {}
      }
      try {
        final crops = await _data.loadCrops(farmMap['farmId']);
        CropRecord? active;
        for (final c in crops) {
          if (c.status == 'active') {
            active = c;
            break;
          }
        }
        if (active != null) {
          final stageInfo = computeCropStage(active);
          cropNameByFarmIndex[index] = active.cropName;
          if (stageInfo.stage != null) {
            stageByFarmIndex[index] = stageInfo.stage!;
          }
        }
      } catch (_) {}
    }

    return _TaskContext(
      farmMaps: farmMaps,
      weatherByFarmIndex: weatherByFarmIndex,
      cropNameByFarmIndex: cropNameByFarmIndex,
      stageByFarmIndex: stageByFarmIndex,
    );
  }
}

class _TaskContext {
  final List<Map<String, dynamic>> farmMaps;
  final Map<int, Map<String, dynamic>> weatherByFarmIndex;
  final Map<int, String> cropNameByFarmIndex;
  final Map<int, String> stageByFarmIndex;

  const _TaskContext({
    required this.farmMaps,
    required this.weatherByFarmIndex,
    required this.cropNameByFarmIndex,
    required this.stageByFarmIndex,
  });
}
