import 'package:flutter/material.dart';
import 'package:vidhai/services/task_service.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/weather_service.dart';
import 'package:vidhai/features/farm/crop_stage.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TaskService _taskService = TaskService();
  List<FarmTask> _allTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    var tasks = await _taskService.loadTasks();
    if (tasks.isEmpty) {
      tasks = await _generateContextTasks();
      if (tasks.isNotEmpty) await _taskService.saveTasks(tasks);
    }
    if (mounted) {
      setState(() {
        _allTasks = tasks;
        _isLoading = false;
      });
    }
  }

  Future<List<FarmTask>> _generateContextTasks() async {
    try {
      final dataService = DataService();
      final farms = await dataService.loadFarms();
      if (farms.isEmpty) return [];

      final weatherByFarmIndex = <int, Map<String, dynamic>>{};
      final cropNameByFarmIndex = <int, String>{};
      final stageByFarmIndex = <int, String>{};

      final weatherService = WeatherService();
      for (var i = 0; i < farms.length; i++) {
        final farm = farms[i];
        final loc = farm.farmLocation;
        final lat = loc?.latitude;
        final lng = loc?.longitude;
        if (lat != null && lng != null) {
          try {
            final w = await weatherService.getWeather(lat, lng);
            if (w != null) {
              weatherByFarmIndex[farm.index] = WeatherData.alertContext(w);
            }
          } catch (_) {}
        }
        try {
          final crops = await dataService.loadCrops(farm.farmId);
          CropRecord? active;
          for (final c in crops) {
            if (c.status == 'active') {
              active = c;
              break;
            }
          }
          if (active != null) {
            final stageInfo = computeCropStage(active);
            cropNameByFarmIndex[farm.index] = active.cropName;
            if (stageInfo.stage != null) {
              stageByFarmIndex[farm.index] = stageInfo.stage!;
            }
          }
        } catch (_) {}
      }

      return TaskService.generateTasksFromFarms(
        farms.map((f) => f.toMap()).toList(),
        weatherByFarmIndex: weatherByFarmIndex,
        cropNameByFarmIndex: cropNameByFarmIndex,
        stageByFarmIndex: stageByFarmIndex,
      );
    } catch (_) {
      return [];
    }
  }

  int get _completedCount => _allTasks.where((t) => t.completed).length;
  double get _progress =>
      _allTasks.isEmpty ? 0 : _completedCount / _allTasks.length;

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(directionalIcon(context, Icons.arrow_back_ios),
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.todaysTasks,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.brandDeep))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              color: colors.brandDeep,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildAIAssistantCard(),
                  const SizedBox(height: 16),
                  if (_allTasks.isEmpty) ...[
                    _buildEmptyState(),
                  ] else ...[
                    _buildProgressHeader(),
                    const SizedBox(height: 16),
                    ..._allTasks.map((task) => _buildTaskItem(task)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildProgressHeader() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                loc.tasksCompletedCount
                    .replaceAll('{done}', '$_completedCount')
                    .replaceAll('{total}', '${_allTasks.length}'),
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${(_progress * 100).round()}%',
                style: TextStyle(
                  color: colors.brandDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: colors.borderColor,
              valueColor: AlwaysStoppedAnimation(colors.brandDeep),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantCard() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => _showAIAssistantSheet(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.brandDeep.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.auto_awesome, color: colors.brandDeep, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.farmAssistantTitle,
                    style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.aiAssistantWhatNow,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.brandDeep.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic,
                      color: colors.brandDeep.withValues(alpha: 0.8), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    loc.ask,
                    style: TextStyle(
                      color: colors.brandDeep.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAIAssistantSheet() {
    final TextEditingController controller = TextEditingController();
    String responseText = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colors = VidhAIColorsX(context);
            final loc = AppLocalizations.of(context);
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: colors.onSurfaceMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.brandDeep.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.auto_awesome,
                            color: colors.brandDeep, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        loc.vidhaiAssistant,
                        style: TextStyle(
                          color: colors.onBackground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: colors.onSurfaceMuted, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: responseText.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.psychology_rounded,
                                      color: colors.onSurfaceMuted, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    loc.askAboutFarm,
                                    style: TextStyle(
                                      color: colors.onSurfaceMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: Text(
                                responseText,
                                style: TextStyle(
                                  color: colors.onBackground,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        top: BorderSide(color: colors.borderColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.brandDeep.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.mic,
                                color: colors.brandDeep.withValues(alpha: 0.8),
                                size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: colors.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.borderColor),
                            ),
                            child: TextField(
                              controller: controller,
                              style: TextStyle(
                                  color: colors.onBackground, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: loc.askVoiceOrTyping,
                                hintStyle: TextStyle(
                                  color: colors.onSurfaceMuted,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  setModalState(() {
                                    responseText = loc.aiResponsePlaceholder;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            if (controller.text.trim().isNotEmpty) {
                              setModalState(() {
                                responseText = loc.aiResponsePlaceholder;
                              });
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.brandDeep,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskItem(FarmTask task) {
    final colors = VidhAIColorsX(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await _taskService.toggleTaskCompletion(task);
              _loadTasks();
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: task.completed ? colors.brandDeep : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.completed ? colors.brandDeep : colors.borderColor,
                  width: 1.5,
                ),
              ),
              child: task.completed
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.completed
                        ? colors.onSurfaceMuted
                        : colors.onBackground,
                    fontSize: 14,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.farmName} ${task.scheduledTime != null ? "· ${task.scheduledTime}" : ""}',
                  style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _categoryColor(task.category).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.category,
              style: TextStyle(
                color: _categoryColor(task.category),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'irrigation':
        return const Color(0xFF2196F3);
      case 'pest':
        return const Color(0xFFFF9800);
      case 'soil':
        return const Color(0xFF795548);
      case 'monitoring':
        return const Color(0xFF9C27B0);
      case 'weather':
        return const Color(0xFF00ACC1);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  Widget _buildEmptyState() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, color: colors.onSurfaceMuted, size: 64),
            const SizedBox(height: 16),
            Text(
              loc.noTasksYet,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.configureFarmsSmartTasks,
              style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
