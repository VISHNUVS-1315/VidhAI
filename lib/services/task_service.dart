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

  List<FarmTask> generateTasksFromFarms(List<Map<String, dynamic>> farms) {
    final tasks = <FarmTask>[];

    for (final farm in farms) {
      final farmName = farm['farmName'] ?? 'Farm';
      final farmIndex = farm['index'] ?? 0;
      final soil = farm['soilType'] ?? '';
      final water = farm['waterAvailability'] ?? '';

      tasks.add(FarmTask(
        id: 'irr_${farmIndex}_${DateTime.now().millisecondsSinceEpoch}',
        farmName: farmName,
        farmIndex: farmIndex,
        title: 'Check irrigation system - $farmName',
        category: 'irrigation',
        scheduledTime: '8:00 AM',
        createdAt: DateTime.now(),
      ));

      if (water.toLowerCase().contains('low') ||
          water.toLowerCase().contains('very low')) {
        tasks.add(FarmTask(
          id: 'water_${farmIndex}_${DateTime.now().millisecondsSinceEpoch + 1}',
          farmName: farmName,
          farmIndex: farmIndex,
          title: 'Water supply check needed - $farmName',
          category: 'irrigation',
          scheduledTime: '9:00 AM',
          createdAt: DateTime.now(),
        ));
      }

      tasks.add(FarmTask(
        id: 'crop_${farmIndex}_${DateTime.now().millisecondsSinceEpoch + 2}',
        farmName: farmName,
        farmIndex: farmIndex,
        title: 'Monitor crop health - $farmName',
        category: 'monitoring',
        scheduledTime: '10:00 AM',
        createdAt: DateTime.now(),
      ));

      tasks.add(FarmTask(
        id: 'pest_${farmIndex}_${DateTime.now().millisecondsSinceEpoch + 3}',
        farmName: farmName,
        farmIndex: farmIndex,
        title: 'Pest inspection - $farmName',
        category: 'pest',
        scheduledTime: '11:00 AM',
        createdAt: DateTime.now(),
      ));

      if (soil.isNotEmpty) {
        tasks.add(FarmTask(
          id: 'soil_${farmIndex}_${DateTime.now().millisecondsSinceEpoch + 4}',
          farmName: farmName,
          farmIndex: farmIndex,
          title: 'Soil condition review - $farmName',
          category: 'soil',
          scheduledTime: '2:00 PM',
          createdAt: DateTime.now(),
        ));
      }

      tasks.add(FarmTask(
        id: 'log_${farmIndex}_${DateTime.now().millisecondsSinceEpoch + 5}',
        farmName: farmName,
        farmIndex: farmIndex,
        title: 'Update farm log - $farmName',
        category: 'general',
        scheduledTime: '4:00 PM',
        createdAt: DateTime.now(),
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
