import 'package:flutter/material.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/weather_service.dart';
import 'package:vidhai/features/farm/screens/farm_details_screen.dart';
import 'package:vidhai/features/farm/screens/add_farm_screen.dart';

class FarmScreen extends StatefulWidget {
  const FarmScreen({super.key});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = true;
  final WeatherService _weatherService = WeatherService();
  final Map<int, WeatherData?> _weatherCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFarms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFarms();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    try {
      final farms = await DataService().loadFarms();
      if (mounted) {
        setState(() {
          _farms = farms.map((f) => f.toMap()).toList();
          _isLoading = false;
        });
        _loadWeatherForFarms();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _farms = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWeatherForFarms() async {
    for (int i = 0; i < _farms.length; i++) {
      final farm = _farms[i];
      final location = farm['farmLocation'];
      if (location != null &&
          location['latitude'] != null &&
          location['longitude'] != null) {
        final lat = (location['latitude'] as num).toDouble();
        final lng = (location['longitude'] as num).toDouble();
        final weather =
            await _weatherService.getWeather(lat, lng, farmId: 'farm_$i');
        if (mounted) {
          setState(() {
            _weatherCache[i] = weather;
          });
        }
      }
    }
  }

  int get _totalFarms => _farms.length;

  int get _activeFarms {
    return _farms.where((f) {
      final stage = f['stage'] ?? '';
      return stage.isNotEmpty &&
          stage.toLowerCase() != 'inactive' &&
          stage.toLowerCase() != 'archived';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        leadingWidth: 80,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'VidhAI',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: const Text(
          'My Farms',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddFarmScreen(),
                  ),
                );
                _loadFarms();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Add Farm',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : _farms.isEmpty
              ? _buildEmptyState()
              : _buildFarmList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.landscape_rounded,
                color: Color(0xFF4CAF50),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No farms yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap + Add Farm to create your first farm.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmList() {
    return RefreshIndicator(
      onRefresh: _loadFarms,
      color: const Color(0xFF4CAF50),
      backgroundColor: const Color(0xFF111827),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _buildStatsRow(),
          const SizedBox(height: 16),
          ...List.generate(_farms.length, (index) => _buildFarmCard(index)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total Farms',
            value: '$_totalFarms',
            icon: Icons.agriculture_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Active Farms',
            value: '$_activeFarms',
            icon: Icons.check_circle_outline_rounded,
            accentColor: _activeFarms > 0 ? const Color(0xFF4CAF50) : Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    Color accentColor = const Color(0xFF4CAF50),
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFarmCard(int index) {
    final farm = _farms[index];
    final farmProfile = FarmProfile.fromMap(farm);
    final weather = _weatherCache[index];
    final cropName = farm['cropName'] ?? '';
    final stage = farm['stage'] ?? 'Not configured';
    final waterAvail = farmProfile.waterAvailability.isNotEmpty
        ? farmProfile.waterAvailability
        : 'Not set';
    final locationText = farmProfile.farmLocation != null
        ? farmProfile.farmLocation!.fullAddress
        : 'No location';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FarmDetailsScreen(farmId: farmProfile.farmId),
          ),
        );
        _loadFarms();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.landscape_rounded,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farmProfile.farmName.isNotEmpty
                            ? farmProfile.farmName
                            : 'Farm ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locationText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.straighten_rounded,
                  '${farmProfile.farmSize.isNotEmpty ? farmProfile.farmSize : '-'} ${farmProfile.farmSizeUnit}',
                ),
                _buildInfoChip(
                  Icons.agriculture_rounded,
                  cropName.isNotEmpty ? cropName : 'No crop',
                ),
                _buildInfoChip(
                  Icons.eco_rounded,
                  stage,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.water_drop_outlined,
                  waterAvail,
                ),
                if (weather != null)
                  _buildInfoChip(
                    Icons.wb_sunny_outlined,
                    '${weather.temperature.toStringAsFixed(0)}°C ${weather.condition}',
                  ),
                if (weather == null && farmProfile.farmLocation != null)
                  _buildInfoChip(
                    Icons.cloud_outlined,
                    'Loading weather...',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
