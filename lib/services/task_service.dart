import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FarmTask {
  final String id;
  final String farmName;
  final int farmIndex;
  final String title;
  final String category;
  final String? scheduledTime;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;

  const FarmTask({
    required this.id,
    required this.farmName,
    required this.farmIndex,
    required this.title,
    required this.category,
    this.scheduledTime,
    this.completed = false,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmName': farmName,
        'farmIndex': farmIndex,
        'title': title,
        'category': category,
        'scheduledTime': scheduledTime,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory FarmTask.fromMap(Map<String, dynamic> m) => FarmTask(
        id: m['id'] ?? '',
        farmName: m['farmName'] ?? '',
        farmIndex: m['farmIndex'] ?? 0,
        title: m['title'] ?? '',
        category: m['category'] ?? '',
        scheduledTime: m['scheduledTime'],
        completed: m['completed'] ?? false,
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
        completedAt: m['completedAt'] != null
            ? DateTime.tryParse(m['completedAt'])
            : null,
      );

  FarmTask copyWith({bool? completed, DateTime? completedAt}) => FarmTask(
        id: id,
        farmName: farmName,
        farmIndex: farmIndex,
        title: title,
        category: category,
        scheduledTime: scheduledTime,
        completed: completed ?? this.completed,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates the farmer's daily tasks from real farm records. Optional
  /// device-side context (today's weather and the active crop's stage) makes
  /// the plan relevant without inventing data:
  ///   [weatherByFarmIndex] — map of `farm.index` to a weather map with
  ///     keys `rainAlert`, `heatAlert`, `humidity`.
  ///   [cropNameByFarmIndex] / [stageByFarmIndex] — active crop name and its
  ///     computed stage (from `kCropStages`) per farm index.
  static List<FarmTask> generateTasksFromFarms(
    List<Map<String, dynamic>> farms, {
    Map<int, Map<String, dynamic>>? weatherByFarmIndex,
    Map<int, String>? cropNameByFarmIndex,
    Map<int, String>? stageByFarmIndex,
  }) {
    final tasks = <FarmTask>[];
    final now = DateTime.now();
    final base = now.millisecondsSinceEpoch;

    for (final farm in farms) {
      final farmName = farm['farmName'] ?? 'Farm';
      final farmIndex = farm['index'] ?? 0;
      final soil = farm['soilType'] ?? '';
      final water = farm['waterAvailability'] ?? '';

      FarmTask make(String prefix, String title, String category, String time,
              [int shift = 0]) =>
          FarmTask(
            id: '${prefix}_${farmIndex}_${base + shift}',
            farmName: farmName,
            farmIndex: farmIndex,
            title: title,
            category: category,
            scheduledTime: time,
            createdAt: now,
          );

      var shift = 0;

      final cropName = cropNameByFarmIndex?[farmIndex];
      final stage = stageByFarmIndex?[farmIndex];
      final hasCrop = cropName != null && cropName.isNotEmpty;

      tasks.add(make(
        'irr',
        'Check irrigation system - $farmName',
        'irrigation',
        '8:00 AM',
        shift++,
      ));

      if (water.toLowerCase().contains('low') ||
          water.toLowerCase().contains('very low')) {
        tasks.add(make(
          'water',
          'Water supply check needed - $farmName',
          'irrigation',
          '9:00 AM',
          shift++,
        ));
      }

      tasks.add(make(
        'crop',
        hasCrop
            ? 'Monitor $cropName health'
                '${stage != null && stage.isNotEmpty ? ' ($stage)' : ''} - $farmName'
            : 'Monitor crop health - $farmName',
        'monitoring',
        '10:00 AM',
        shift++,
      ));

      if (hasCrop) {
        final s = (stage ?? '').toLowerCase();
        if (s == 'flowering') {
          tasks.add(make(
            'stage',
            'Check flowering progress of $cropName - $farmName',
            'monitoring',
            '10:30 AM',
            shift++,
          ));
        } else if (s == 'maturity' ||
            s == 'harvest ready' ||
            s == 'harvested') {
          tasks.add(make(
            'stage',
            'Prepare for harvest of $cropName - $farmName',
            'monitoring',
            '8:30 AM',
            shift++,
          ));
        } else if (s == 'seedling' || s == 'vegetative') {
          tasks.add(make(
            'stage',
            'Check soil moisture for $cropName - $farmName',
            'irrigation',
            '9:30 AM',
            shift++,
          ));
        }
      }

      tasks.add(make(
        'pest',
        'Pest inspection - $farmName',
        'pest',
        '11:00 AM',
        shift++,
      ));

      final weather = weatherByFarmIndex?[farmIndex];
      if (weather != null) {
        final rain = (weather['rainAlert'] ?? false) as bool;
        final heat = (weather['heatAlert'] ?? false) as bool;
        final humidity = (weather['humidity'] as num?)?.toInt() ?? 0;
        if (rain) {
          tasks.add(make(
            'wxr',
            'Delay spraying — rain expected - $farmName',
            'weather',
            '6:30 AM',
            shift++,
          ));
        }
        if (heat) {
          tasks.add(make(
            'wxh',
            'High heat alert — irrigate in the evening - $farmName',
            'weather',
            '6:00 PM',
            shift++,
          ));
        }
        if (humidity >= 85) {
          tasks.add(make(
            'wxhum',
            'High humidity — watch for fungal disease - $farmName',
            'pest',
            '5:30 PM',
            shift++,
          ));
        }
      }

      if (soil.isNotEmpty) {
        tasks.add(make(
          'soil',
          'Soil condition review - $farmName',
          'soil',
          '2:00 PM',
          shift++,
        ));
      }

      tasks.add(make(
        'log',
        'Update farm log - $farmName',
        'general',
        '4:00 PM',
        shift++,
      ));
    }

    return tasks;
  }

  Future<void> saveTasks(List<FarmTask> tasks) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final taskMaps = tasks.map((t) => t.toMap()).toList();
      await _firestore.collection('users').doc(uid).set({
        'tasks': taskMaps,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Save locally as fallback
      final prefs = await SharedPreferences.getInstance();
      final json = tasks.map((t) => t.toMap()).toList();
      await prefs.setString('cached_tasks', json.toString());
    }
  }

  Future<List<FarmTask>> loadTasks() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null || data['tasks'] == null) return [];

      final tasksList = (data['tasks'] as List)
          .map((t) => FarmTask.fromMap(Map<String, dynamic>.from(t)))
          .toList();
      return tasksList;
    } catch (_) {
      return [];
    }
  }

  Future<void> toggleTaskCompletion(FarmTask task) async {
    final updated = task.copyWith(
      completed: !task.completed,
      completedAt: !task.completed ? DateTime.now() : null,
    );

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null || data['tasks'] == null) return;

      final tasks = (data['tasks'] as List)
          .map((t) => FarmTask.fromMap(Map<String, dynamic>.from(t)))
          .toList();

      final idx = tasks.indexWhere((t) => t.id == task.id);
      if (idx >= 0) {
        tasks[idx] = updated;
        await _firestore.collection('users').doc(uid).set({
          'tasks': tasks.map((t) => t.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Offline - will sync later
    }
  }
}
