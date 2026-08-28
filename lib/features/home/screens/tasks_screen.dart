import 'package:flutter/material.dart';
import 'package:vidhai/services/task_service.dart';

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
    final tasks = await _taskService.loadTasks();
    if (mounted) {
      setState(() {
        _allTasks = tasks;
        _isLoading = false;
      });
    }
  }

  int get _completedCount => _allTasks.where((t) => t.completed).length;
  double get _progress =>
      _allTasks.isEmpty ? 0 : _completedCount / _allTasks.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Today's Tasks",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              color: const Color(0xFF4CAF50),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$_completedCount of ${_allTasks.length} completed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${(_progress * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
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
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantCard() {
    return GestureDetector(
      onTap: () => _showAIAssistantSheet(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF4CAF50), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VidhAI Farm Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'What should I do now?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, color: const Color(0xFF4CAF50).withValues(alpha: 0.8), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Ask',
                    style: TextStyle(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
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
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: Color(0xFF0A0F1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
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
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF4CAF50), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'VidhAI Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5), size: 20),
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
                                      color: Colors.white.withValues(alpha: 0.15), size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Ask me anything about your farm',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.3),
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
                                  color: Colors.white.withValues(alpha: 0.7),
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
                      color: const Color(0xFF111827),
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
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
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.mic,
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.8), size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0F1A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: TextField(
                              controller: controller,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Ask by voice or typing...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  setModalState(() {
                                    responseText = 'AI response will appear here once the backend is configured.';
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
                                responseText = 'AI response will appear here once the backend is configured.';
                              });
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
                color: task.completed
                    ? const Color(0xFF4CAF50)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.completed
                      ? const Color(0xFF4CAF50)
                      : Colors.white.withValues(alpha: 0.2),
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
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white,
                    fontSize: 14,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.farmName} ${task.scheduledTime != null ? "· ${task.scheduledTime}" : ""}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
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
      default:
        return const Color(0xFF4CAF50);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt,
                color: Colors.white.withValues(alpha: 0.2), size: 64),
            const SizedBox(height: 16),
            const Text(
              'No tasks yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure your farms to generate smart tasks.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
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
