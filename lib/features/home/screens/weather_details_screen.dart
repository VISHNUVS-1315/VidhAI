import 'package:flutter/material.dart';
import 'package:vidhai/services/weather_service.dart';

class WeatherDetailsScreen extends StatefulWidget {
  final String farmName;
  final double latitude;
  final double longitude;

  const WeatherDetailsScreen({
    super.key,
    required this.farmName,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<WeatherDetailsScreen> createState() => _WeatherDetailsScreenState();
}

class _WeatherDetailsScreenState extends State<WeatherDetailsScreen> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weather;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoading = true);
    final weather = await _weatherService.getWeather(
      widget.latitude,
      widget.longitude,
      farmId: widget.farmName,
    );
    if (mounted) {
      setState(() {
        _weather = weather;
        _isLoading = false;
      });
    }
  }

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
        title: Text(
          widget.farmName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : _weather == null
              ? Center(
                  child: Text(
                    'Weather data unavailable',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWeather,
                  color: const Color(0xFF4CAF50),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildCurrentWeather(),
                      const SizedBox(height: 20),
                      _buildDetailGrid(),
                      const SizedBox(height: 20),
                      if (_weather!.hourly.isNotEmpty) ...[
                        const Text(
                          'Hourly Forecast',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildHourlyForecast(),
                      ],
                      const SizedBox(height: 20),
                      if (_weather!.daily.isNotEmpty) ...[
                        const Text(
                          '7-Day Forecast',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._weather!.daily.map((d) => _buildDailyItem(d)),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Last updated: ${_formatTime(_weather!.timestamp)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCurrentWeather() {
    final w = _weather!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withValues(alpha: 0.8),
            const Color(0xFF2E7D32).withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            WeatherData.weatherIcon(w.weatherCode),
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            '${w.temperature.round()}°C',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            w.condition,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Feels like ${w.feelsLike.round()}°C',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailGrid() {
    final w = _weather!;
    final items = [
      _DetailItem(Icons.water_drop_outlined, 'Humidity', '${w.humidity}%'),
      _DetailItem(Icons.air, 'Wind', '${w.windSpeed.round()} km/h'),
      _DetailItem(Icons.navigation_rounded, 'Direction',
          WeatherData.windDirectionLabel(w.windDirection)),
      _DetailItem(Icons.compress, 'Pressure', '${w.pressure.round()} hPa'),
      _DetailItem(Icons.speed, 'Gusts', '${w.windGusts.round()} km/h'),
      if (w.precipitation != null)
        _DetailItem(Icons.umbrella, 'Rain', '${w.precipitation!.round()} mm'),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.2,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon,
                        color: const Color(0xFF4CAF50), size: 18),
                    const SizedBox(height: 6),
                    Text(
                      item.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildHourlyForecast() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _weather!.hourly.length.clamp(0, 24),
        itemBuilder: (context, i) {
          final h = _weather!.hourly[i];
          final hour = h.time.hour;
          final label = hour == DateTime.now().hour ? 'Now' : '${hour.toString().padLeft(2, '0')}:00';
          return Container(
            width: 64,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: hour == DateTime.now().hour
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                  : const Color(0xFF111827),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hour == DateTime.now().hour
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                const SizedBox(height: 4),
                Text(WeatherData.weatherIcon(h.weatherCode),
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text('${h.temperature.round()}°',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyItem(DailyForecast d) {
    final dayName = _dayName(d.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(dayName,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          ),
          Text(WeatherData.weatherIcon(d.weatherCode),
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text('${d.maxTemp.round()}°',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(' / ${d.minTemp.round()}°',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
          const Spacer(),
          if (d.precipitationSum > 0)
            Row(
              children: [
                Icon(Icons.umbrella, color: Colors.white.withValues(alpha: 0.4), size: 14),
                const SizedBox(width: 3),
                Text('${d.precipitationSum.round()}mm',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }

  String _dayName(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month) return 'Today';
    if (date.day == now.day + 1) return 'Tomorrow';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  const _DetailItem(this.icon, this.label, this.value);
}
