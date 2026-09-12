import 'package:flutter/material.dart';
import 'package:vidhai/services/weather_service.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

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
          widget.farmName,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.brandDeep))
          : _weather == null
              ? Center(
                  child: Text(
                    loc.weatherDataUnavailable,
                    style: TextStyle(color: colors.onSurfaceMuted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWeather,
                  color: colors.brandDeep,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildCurrentWeather(),
                      const SizedBox(height: 20),
                      _buildDetailGrid(),
                      const SizedBox(height: 20),
                      if (_weather!.hourly.isNotEmpty) ...[
                        Text(
                          loc.hourlyForecastHeading,
                          style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildHourlyForecast(),
                      ],
                      const SizedBox(height: 20),
                      if (_weather!.daily.isNotEmpty) ...[
                        Text(
                          loc.dailyForecastHeading,
                          style: TextStyle(
                            color: colors.onBackground,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._weather!.daily.map((d) => _buildDailyItem(d)),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        '${loc.weatherLastUpdated} ${_formatTime(_weather!.timestamp)}',
                        style: TextStyle(
                          color: colors.onSurfaceMuted,
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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final w = _weather!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.brandDeep.withValues(alpha: 0.8),
            colors.brandDeep.withValues(alpha: 0.6),
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
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 52,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            w.condition,
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${loc.weatherFeelsLike} ${w.feelsLike.round()}°C',
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailGrid() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final w = _weather!;
    final items = [
      _DetailItem(
          Icons.water_drop_outlined, loc.weatherHumidity, '${w.humidity}%'),
      _DetailItem(Icons.air, loc.weatherWind, '${w.windSpeed.round()} km/h'),
      _DetailItem(Icons.navigation_rounded, loc.weatherDirection,
          WeatherData.windDirectionLabel(w.windDirection)),
      _DetailItem(
          Icons.compress, loc.weatherPressure, '${w.pressure.round()} hPa'),
      _DetailItem(Icons.speed, loc.weatherGusts, '${w.windGusts.round()} km/h'),
      if (w.precipitation != null)
        _DetailItem(
            Icons.umbrella, loc.weatherRain, '${w.precipitation!.round()} mm'),
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
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: colors.brandDeep, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      item.value,
                      style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _weather!.hourly.length.clamp(0, 24),
        itemBuilder: (context, i) {
          final h = _weather!.hourly[i];
          final hour = h.time.hour;
          final label = hour == DateTime.now().hour
              ? loc.weatherHourNow
              : '${hour.toString().padLeft(2, '0')}:00';
          return Container(
            width: 64,
            margin: const EdgeInsetsDirectional.only(end: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: hour == DateTime.now().hour
                  ? colors.brandDeep.withValues(alpha: 0.2)
                  : colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hour == DateTime.now().hour
                    ? colors.brandDeep.withValues(alpha: 0.3)
                    : colors.borderColor,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Text(WeatherData.weatherIcon(h.weatherCode),
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text('${h.temperature.round()}°',
                    style: TextStyle(
                        color: colors.onBackground,
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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final dayName = _dayName(d.date, loc);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(dayName,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
          ),
          Text(WeatherData.weatherIcon(d.weatherCode),
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text('${d.maxTemp.round()}°',
              style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          Text(' / ${d.minTemp.round()}°',
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13)),
          const Spacer(),
          if (d.precipitationSum > 0)
            Row(
              children: [
                Icon(Icons.umbrella, color: colors.onSurfaceMuted, size: 14),
                const SizedBox(width: 3),
                Text('${d.precipitationSum.round()}mm',
                    style:
                        TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }

  String _dayName(DateTime date, AppLocalizations loc) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month) {
      return loc.weatherDayToday;
    }
    if (date.day == now.day + 1) return loc.weatherDayTomorrow;
    return [
      loc.weekdayMon,
      loc.weekdayTue,
      loc.weekdayWed,
      loc.weekdayThu,
      loc.weekdayFri,
      loc.weekdaySat,
      loc.weekdaySun
    ][date.weekday - 1];
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
