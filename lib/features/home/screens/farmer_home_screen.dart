import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/services/weather_service.dart';
import 'package:vidhai/services/task_service.dart';
import 'package:vidhai/features/home/screens/weather_details_screen.dart';
import 'package:vidhai/features/home/screens/tasks_screen.dart';
import 'package:vidhai/features/notifications/screens/notification_center_screen.dart';
import 'package:vidhai/services/notification_service.dart';
import 'package:vidhai/services/data_service.dart';

class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  String _userName = 'Farmer';
  List<Map<String, dynamic>> _farms = [];
  final WeatherService _weatherService = WeatherService();
  final TaskService _taskService = TaskService();
  final Map<int, WeatherData?> _weatherCache = {};
  List<FarmTask> _tasks = [];
  bool _isLoadingWeather = false;
  int _selectedWeatherIndex = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dataService = DataService();

    List<Map<String, dynamic>> farms = [];
    try {
      final loadedFarms = await dataService.loadFarms();
      farms = loadedFarms.map((f) => f.toMap()).toList();
    } catch (_) {
      // Fallback to cached SP data
      final prefs = await SharedPreferences.getInstance();
      final farmsStr = prefs.getString('cached_farms');
      if (farmsStr != null) {
        try {
          final decoded = json.decode(farmsStr);
          farms = (decoded as List)
              .map((f) => Map<String, dynamic>.from(f))
              .toList();
        } catch (_) {}
      }
    }

    String userName = 'Farmer';
    try {
      final profile = await dataService.loadProfile();
      if (profile != null && profile.displayName.isNotEmpty) {
        userName = profile.displayName;
      }
    } catch (_) {}
    if (userName == 'Farmer') {
      final prefs = await SharedPreferences.getInstance();
      userName = prefs.getString('user_display_name') ?? 'Farmer';
    }

    try {
      final loadedTasks = await _taskService.loadTasks();
      final unreadCount = await NotificationService().getUnreadCount();
      if (mounted) {
        setState(() {
          _userName = userName;
          _farms = farms;
          _tasks = loadedTasks;
          _unreadCount = unreadCount;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userName = userName;
          _farms = farms;
        });
      }
    }

    if (farms.isNotEmpty) {
      _loadWeatherForFarms(farms);
    }
  }

  Future<void> _loadWeatherForFarms(List<Map<String, dynamic>> farms) async {
    setState(() => _isLoadingWeather = true);
    for (var i = 0; i < farms.length; i++) {
      final loc = farms[i]['farmLocation'];
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        final lat = (loc['latitude'] as num).toDouble();
        final lng = (loc['longitude'] as num).toDouble();
        final weather = await _weatherService.getWeather(lat, lng,
            farmId: 'farm_$i');
        if (mounted) {
          setState(() => _weatherCache[i] = weather);
        }
      }
    }
    if (mounted) setState(() => _isLoadingWeather = false);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF4CAF50),
          backgroundColor: const Color(0xFF111827),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildWeatherSection(),
              const SizedBox(height: 24),
              _buildTasksSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: const DecorationImage(
              image: AssetImage('assets/images/logo.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'VidhAI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        _buildNotificationBell(),
      ],
    );
  }

  Widget _buildNotificationBell() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        );
        final count = await NotificationService().getUnreadCount();
        if (mounted) setState(() => _unreadCount = count);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_farms.length > 1)
              Text(
                '${_selectedWeatherIndex + 1}/${_farms.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _getQuote(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        if (_farms.isEmpty)
          _buildEmptyWeather()
        else
          _buildWeatherCarousel(),
      ],
    );
  }

  String _getQuote() {
    final quotes = [
      'The farmer is the only man in our economy who buys everything at retail, sells everything at wholesale, and pays the freight both ways.',
      'Farming looks mighty easy when your plow is a pencil and you\'re a thousand miles from the corn field.',
      'The ultimate goal of farming is not the growing of crops, but the cultivation and perfection of human beings.',
      'A good farmer is nothing more nor less than a handy man with a sense of humus.',
      'To forget how to dig the earth and tend the soil is to forget ourselves.',
    ];
    final idx = DateTime.now().day % quotes.length;
    return quotes[idx];
  }

  Widget _buildEmptyWeather() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Add farm location to see weather data.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCarousel() {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: _farms.length,
        controller: PageController(viewportFraction: 0.92),
        onPageChanged: (i) => setState(() => _selectedWeatherIndex = i),
        itemBuilder: (context, index) {
          final farm = _farms[index];
          final weather = _weatherCache[index];
          return _buildWeatherCard(farm, weather, index);
        },
      ),
    );
  }

  Widget _buildWeatherCard(
      Map<String, dynamic> farm, WeatherData? weather, int index) {
    final farmName = farm['farmName'] ?? 'Farm ${index + 1}';
    return GestureDetector(
      onTap: () {
        final loc = farm['farmLocation'];
        if (loc != null && loc['latitude'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WeatherDetailsScreen(
                farmName: farmName,
                latitude: (loc['latitude'] as num).toDouble(),
                longitude: (loc['longitude'] as num).toDouble(),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1B5E20).withValues(alpha: 0.8),
              const Color(0xFF2E7D32).withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
          ),
        ),
        child: weather == null
            ? Center(
                child: _isLoadingWeather
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : Text(
                        'No weather data for $farmName',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                      ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          farmName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        WeatherData.weatherIcon(weather.weatherCode),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${weather.temperature.round()}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            weather.condition,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _weatherStat(Icons.water_drop_outlined,
                          '${weather.humidity}%'),
                      _weatherStat(Icons.air, '${weather.windSpeed.round()} km/h'),
                      _weatherStat(
                          Icons.navigation_rounded,
                          WeatherData.windDirectionLabel(
                              weather.windDirection)),
                      if (weather.precipitation != null &&
                          weather.precipitation! > 0)
                        _weatherStat(Icons.umbrella,
                            '${weather.precipitation!.round()}mm'),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _weatherStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 14),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Today's Tasks",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TasksScreen()),
                );
              },
              child: Text(
                'See All',
                style: TextStyle(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tasks.isEmpty)
          _buildEmptyTasks()
        else
          ..._tasks.take(5).map((task) => _buildTaskItem(task)),
        if (_tasks.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TasksScreen()),
                  );
                },
                child: Text(
                  '+${_tasks.length - 5} more tasks',
                  style: TextStyle(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyTasks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.task_alt, color: Colors.white.withValues(alpha: 0.25), size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No tasks yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your farms to generate smart tasks.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              setState(() {
                final idx = _tasks.indexWhere((t) => t.id == task.id);
                if (idx >= 0) {
                  _tasks[idx] = task.copyWith(
                    completed: !task.completed,
                    completedAt: !task.completed ? DateTime.now() : null,
                  );
                }
              });
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
                if (task.scheduledTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.scheduledTime!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
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
}
