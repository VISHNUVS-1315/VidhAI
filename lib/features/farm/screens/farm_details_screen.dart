import 'package:flutter/material.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/weather_service.dart';
import 'package:vidhai/features/home/screens/weather_details_screen.dart';
import 'package:vidhai/services/data_service.dart';

class FarmDetailsScreen extends StatefulWidget {
  final String farmId;

  const FarmDetailsScreen({super.key, required this.farmId});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  FarmProfile? _farmProfile;
  bool _isLoading = true;
  WeatherData? _weather;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _loadFarm();
  }

  Future<void> _loadFarm() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final farms = await DataService().loadFarms();
      final match = farms.where((f) => f.farmId == widget.farmId);
      if (match.isNotEmpty && mounted) {
        setState(() {
          _farmProfile = match.first;
          _isLoading = false;
        });
        _loadWeather();
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWeather() async {
    if (_farmProfile?.farmLocation == null) return;
    final lat = _farmProfile!.farmLocation!.latitude;
    final lng = _farmProfile!.farmLocation!.longitude;
    if (lat == null || lng == null) return;
    try {
      final weather =
          await _weatherService.getWeather(lat, lng, farmId: widget.farmId);
      if (mounted) {
        setState(() {
          _weather = weather;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _farmProfile != null
              ? (_farmProfile!.farmName.isNotEmpty
                  ? _farmProfile!.farmName
                  : 'Farm')
              : 'Farm Details',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : _farmProfile == null
              ? const Center(
                  child: Text('Farm not found',
                      style: TextStyle(color: Colors.white38)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final profile = _farmProfile!;
    final stage = 'Active';

    return RefreshIndicator(
      onRefresh: _loadFarm,
      color: const Color(0xFF4CAF50),
      backgroundColor: const Color(0xFF111827),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _buildTopSection(profile, stage),
          const SizedBox(height: 20),
          _buildSectionGrid(profile),
        ],
      ),
    );
  }

  Widget _buildTopSection(FarmProfile profile, String stage) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.landscape_rounded,
                  color: Color(0xFF4CAF50),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.farmName.isNotEmpty
                          ? profile.farmName
                          : 'Farm',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.farmLocation != null
                          ? profile.farmLocation!.fullAddress
                          : 'No location set',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTopInfoItem(
                Icons.straighten_rounded,
                'Size',
                '${profile.farmSize.isNotEmpty ? profile.farmSize : '-'} ${profile.farmSizeUnit}',
              ),
              const SizedBox(width: 16),
              _buildTopInfoItem(
                Icons.eco_rounded,
                'Method',
                profile.farmingMethod.isNotEmpty
                    ? profile.farmingMethod
                    : 'Not set',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50), size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionGrid(FarmProfile profile) {
    final farmId = profile.farmId;
    final sections = <_SectionItem>[
      _SectionItem(
        icon: Icons.agriculture_rounded,
        label: 'Crop Info',
        color: const Color(0xFF66BB6A),
        detail: 'Configure crop',
        onTap: () => Navigator.pushNamed(context, '/crop_setup',
            arguments: farmId),
      ),
      _SectionItem(
        icon: Icons.wb_sunny_outlined,
        label: 'Weather',
        color: const Color(0xFFFFB300),
        detail: _weather != null
            ? '${_weather!.temperature.toStringAsFixed(0)}°C - ${_weather!.condition}'
            : 'Tap to view',
        onTap: () {
          if (profile.farmLocation != null &&
              profile.farmLocation!.latitude != null &&
              profile.farmLocation!.longitude != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WeatherDetailsScreen(
                  farmName: profile.farmName,
                  latitude: profile.farmLocation!.latitude!,
                  longitude: profile.farmLocation!.longitude!,
                ),
              ),
            );
          }
        },
      ),
      _SectionItem(
        icon: Icons.water_drop_outlined,
        label: 'Water',
        color: const Color(0xFF2196F3),
        detail: profile.waterAvailability.isNotEmpty
            ? profile.waterAvailability
            : 'No data yet',
        onTap: () => _showDetailDialog('Water', _getWaterDetail(profile)),
      ),
      _SectionItem(
        icon: Icons.terrain_rounded,
        label: 'Soil',
        color: const Color(0xFF8D6E63),
        detail: profile.soilType.isNotEmpty ? profile.soilType : 'No data yet',
        onTap: () => _showDetailDialog('Soil', _getSoilDetail(profile)),
      ),
      _SectionItem(
        icon: Icons.water_outlined,
        label: 'Irrigation',
        color: const Color(0xFF00BCD4),
        detail: profile.irrigationType.isNotEmpty
            ? profile.irrigationType
            : 'No data yet',
        onTap: () =>
            _showDetailDialog('Irrigation', _getIrrigationDetail(profile)),
      ),
      _SectionItem(
        icon: Icons.receipt_long_rounded,
        label: 'Expenses',
        color: const Color(0xFFFF7043),
        detail: 'View records',
        onTap: () => Navigator.pushNamed(context, '/expenses',
            arguments: farmId),
      ),
      _SectionItem(
        icon: Icons.science_rounded,
        label: 'Pesticides',
        color: const Color(0xFFAB47BC),
        detail: 'View records',
        onTap: () => Navigator.pushNamed(context, '/pesticides',
            arguments: farmId),
      ),
      _SectionItem(
        icon: Icons.spa_rounded,
        label: 'Fertilizers',
        color: const Color(0xFF26A69A),
        detail: 'View records',
        onTap: () => Navigator.pushNamed(context, '/fertilizers',
            arguments: farmId),
      ),
      _SectionItem(
        icon: Icons.bug_report_rounded,
        label: 'Disease',
        color: const Color(0xFFEF5350),
        detail: 'View alerts',
        onTap: () => Navigator.pushNamed(context, '/diseases',
            arguments: farmId),
      ),
      _SectionItem(
        icon: Icons.history_rounded,
        label: 'History',
        color: const Color(0xFF78909C),
        detail: 'Farm history',
        onTap: () => Navigator.pushNamed(context, '/farm_history',
            arguments: farmId),
      ),
      _SectionItem(
        icon: Icons.auto_awesome_rounded,
        label: 'Recommend',
        color: const Color(0xFF7C4DFF),
        detail: 'AI crop advice',
        onTap: () =>
            Navigator.pushNamed(context, '/crop_recommendation'),
      ),
      _SectionItem(
        icon: Icons.set_meal_rounded,
        label: 'Farming',
        color: const Color(0xFF4CAF50),
        detail: profile.farmingMethod.isNotEmpty
            ? profile.farmingMethod
            : 'Not set',
        onTap: () => _showDetailDialog(
            'Farming Method',
            profile.farmingMethod.isNotEmpty
                ? profile.farmingMethod
                : 'No farming method configured'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        return _buildSectionCard(sections[index]);
      },
    );
  }

  Widget _buildSectionCard(_SectionItem section) {
    return GestureDetector(
      onTap: section.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(section.icon, color: section.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              section.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              section.detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getWaterDetail(FarmProfile profile) {
    final parts = <String>[];
    if (profile.waterAvailability.isNotEmpty) {
      parts.add('Availability: ${profile.waterAvailability}');
    }
    if (profile.waterSource.isNotEmpty) {
      parts.add('Source: ${profile.waterSource}');
    }
    return parts.isNotEmpty ? parts.join('\n') : 'No water data configured';
  }

  String _getSoilDetail(FarmProfile profile) {
    final parts = <String>[];
    if (profile.soilType.isNotEmpty) parts.add('Type: ${profile.soilType}');
    if (profile.soilAiResult != null) {
      parts.add('AI Analysis: ${profile.soilAiResult!.soilType}');
    }
    return parts.isNotEmpty ? parts.join('\n') : 'No soil data configured';
  }

  String _getIrrigationDetail(FarmProfile profile) {
    final parts = <String>[];
    if (profile.irrigationType.isNotEmpty) {
      parts.add('Type: ${profile.irrigationType}');
    }
    if (profile.waterSource.isNotEmpty) {
      parts.add('Source: ${profile.waterSource}');
    }
    return parts.isNotEmpty
        ? parts.join('\n')
        : 'No irrigation data configured';
  }

  void _showDetailDialog(String title, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          detail,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionItem {
  final IconData icon;
  final String label;
  final Color color;
  final String detail;
  final VoidCallback onTap;

  const _SectionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.detail,
    required this.onTap,
  });
}
