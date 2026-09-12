import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/vidhai_theme.dart';
import '../../../core/widgets/vidhai_widgets.dart';
import '../../../data/models/market_price_models.dart';
import '../../../locale/locale.dart';
import '../../../services/market_price_service.dart';
import '../../assistant/assistant_button.dart';

/// Full detail for a single reported market price. Shows the original unit
/// and conversion factor alongside the per-kg price plus a real 7/30-day
/// trend chart drawn from the reported daily series (never fabricated: when
/// the provider has no history an honest note is shown).
class MarketPriceDetailScreen extends StatefulWidget {
  final MarketPriceRecord record;
  const MarketPriceDetailScreen({super.key, required this.record});

  @override
  State<MarketPriceDetailScreen> createState() =>
      _MarketPriceDetailScreenState();
}

class _MarketPriceDetailScreenState extends State<MarketPriceDetailScreen> {
  int _days = 7;
  List<PriceHistoryPoint> _history = const [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final record = widget.record;
    if (record.state.isEmpty) return;
    setState(() => _loadingHistory = true);
    final points = await MarketPriceService.instance.fetchHistory(
      state: record.state,
      commodity: record.commodity,
      days: _days,
    );
    if (!mounted) return;
    setState(() {
      _history = points;
      _loadingHistory = false;
    });
  }

  void _changeDays(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    final record = widget.record;
    final trend = record.trend;
    final trendColor = trend == 'up'
        ? colors.success
        : trend == 'down'
            ? colors.danger
            : colors.onSurfaceMuted;
    final trendIcon = trend == 'up'
        ? Icons.arrow_upward_rounded
        : trend == 'down'
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    final kgLabel = record.hasReliablePerKg
        ? MarketFormat.inr(record.normalizedPricePerKg)
        : loc.marketPriceUnitUnavailable;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(directionalIcon(context, Icons.arrow_back_ios_rounded),
              color: colors.onBackground, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.marketViewDetails,
          style: TextStyle(
              color: colors.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          const VidhAIAssistantButton(
              screen: 'market_price_detail', size: 36, iconSize: 18),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(trendIcon, color: trendColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record.commodity,
                              style: TextStyle(
                                  color: colors.onBackground,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          if (record.variety != null &&
                              record.variety!.isNotEmpty)
                            Text(record.variety!,
                                style: TextStyle(
                                    color: colors.onSurfaceMuted,
                                    fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${loc.marketPricePerKg} '
                              '(${loc.marketOriginalUnit.toLowerCase()}: ${record.unitLabel})',
                              style: TextStyle(
                                  color: colors.onSurfaceMuted, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(kgLabel,
                              style: TextStyle(
                                  color: record.hasReliablePerKg
                                      ? colors.brandDeep
                                      : colors.onSurfaceMuted,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    if (record.conversionFactor != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(loc.marketUnitConversion,
                              style: TextStyle(
                                  color: colors.onSurfaceMuted, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                              '1 ${record.unitLabel} = '
                              '${record.conversionFactor!.toStringAsFixed(2)} kg',
                              style: TextStyle(
                                  color: colors.onBackground,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _priceBox(
                  colors,
                  loc.marketMinPrice,
                  record.minPrice != null
                      ? MarketFormat.inr(record.minPrice)
                      : '—'),
              const SizedBox(width: 10),
              _priceBox(
                  colors,
                  loc.marketModalPrice,
                  record.modalPrice != null
                      ? MarketFormat.inr(record.modalPrice)
                      : '—'),
              const SizedBox(width: 10),
              _priceBox(
                  colors,
                  loc.marketMaxPrice,
                  record.maxPrice != null
                      ? MarketFormat.inr(record.maxPrice)
                      : '—'),
            ],
          ),
          if (record.state.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PriceTrendCard(
              loading: _loadingHistory,
              points: _history,
              days: _days,
              onDaysChanged: _changeDays,
              onRefresh: _loadHistory,
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderColor),
            ),
            child: Column(
              children: [
                _infoRow(colors, Icons.location_on_outlined, loc.marketMarket,
                    record.market),
                _infoRow(colors, Icons.map_outlined, loc.marketDistrictPrices,
                    record.district),
                _infoRow(
                    colors, Icons.flag_outlined, loc.marketState, record.state),
                if (record.arrival != null && record.arrival!.isNotEmpty)
                  _infoRow(colors, Icons.local_shipping_outlined,
                      loc.marketArrivals, record.arrival!),
                _infoRow(
                    colors,
                    Icons.calendar_today_rounded,
                    loc.marketLastUpdated,
                    record.date.isEmpty ? '—' : record.date),
                if (record.source.isNotEmpty)
                  _infoRow(colors, Icons.storage_rounded, loc.marketSource,
                      record.source),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderColor),
            ),
            child: Text(
              loc.marketDisclaimer,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${loc.marketOriginalUnit}: ${record.originalUnit}',
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBox(VidhAIColorsX colors, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderColor),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      VidhAIColorsX colors, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: colors.brandDeep, size: 16),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Trend card: 7/30-day segmented control + the custom bar chart of the real
/// reported daily average (₹/kg). Empty when the provider has no series.
class _PriceTrendCard extends StatelessWidget {
  final bool loading;
  final List<PriceHistoryPoint> points;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onRefresh;

  const _PriceTrendCard({
    required this.loading,
    required this.points,
    required this.days,
    required this.onDaysChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: colors.brandDeep, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(loc.marketPriceHistory,
                    style: TextStyle(
                        color: colors.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.refresh_rounded,
                    color: colors.onSurfaceMuted, size: 18),
                onPressed: loading ? null : onRefresh,
                tooltip: loc.refresh,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                  value: 7,
                  label: Text(loc.marketHistory7d,
                      style: const TextStyle(fontSize: 12))),
              ButtonSegment(
                  value: 30,
                  label: Text(loc.marketHistory30d,
                      style: const TextStyle(fontSize: 12))),
            ],
            selected: {days},
            onSelectionChanged: (s) => onDaysChanged(s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: WidgetStatePropertyAll(
                  TextStyle(fontSize: 12, color: colors.onBackground)),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? colors.brandDeep
                      : colors.onSurfaceMuted),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? colors.brand.withValues(alpha: 0.16)
                      : colors.surfaceMuted),
              side:
                  WidgetStatePropertyAll(BorderSide(color: colors.borderColor)),
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ))
          else if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(loc.marketHistoryNone,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colors.onSurfaceMuted, fontSize: 12.5)),
              ),
            )
          else ...[
            SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _HistoryChartPainter(
                  points: points,
                  lineColor: colors.brandDeep.withValues(alpha: 0.85),
                  barColor: colors.brand.withValues(alpha: 0.16),
                  gridColor: colors.borderColor,
                  mutedColor: colors.onSurfaceMuted,
                  labelColor: colors.onBackground,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(loc.marketHistoryNote,
                style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// Light-weight bar chart (no third-party dependency) for the daily series.
class _HistoryChartPainter extends CustomPainter {
  final List<PriceHistoryPoint> points;
  final Color lineColor;
  final Color barColor;
  final Color gridColor;
  final Color mutedColor;
  final Color labelColor;

  const _HistoryChartPainter({
    required this.points,
    required this.lineColor,
    required this.barColor,
    required this.gridColor,
    required this.mutedColor,
    required this.labelColor,
  });

  static String _shortDate(String date) {
    final p = date.split('-');
    if (p.length != 3) return date;
    return '${p[2]}/${p[1]}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.normalizedPricePerKg).toList();
    if (values.isEmpty) return;
    final dataMax = values.reduce(math.max);
    final dataMin = values.reduce(math.min);
    final range = math.max(1.0, dataMax - dataMin);
    final topPad = 26.0;
    final bottomPad = 24.0;
    final drawH = size.height - topPad - bottomPad;
    final drawW = size.width;
    final baseY = topPad + drawH;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = topPad + drawH * (1 - f);
      canvas.drawLine(Offset(0, y), Offset(drawW, y), gridPaint);
    }

    final slot = drawW / values.length;
    final barW = math.max(2.0, math.min(14.0, slot * 0.58));

    final barPaint = Paint()..color = barColor;
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final pointsXY = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final t = (values[i] - dataMin) / range;
      final y = baseY - t * (drawH - 6) - 3;
      final x = slot * i + slot / 2;
      pointsXY.add(Offset(x, y));
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(
              center: Offset(x, (baseY + y) / 2),
              width: barW,
              height: (baseY - y)),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        barPaint,
      );
    }
    if (pointsXY.length > 1) {
      path.moveTo(pointsXY.first.dx, pointsXY.first.dy);
      for (final p in pointsXY.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final metric = TextStyle(
        color: labelColor, fontSize: 9.5, fontWeight: FontWeight.w600);
    final short = TextStyle(color: mutedColor, fontSize: 9);

    final maxTp = TextPainter()
      ..text =
          TextSpan(text: MarketFormat.inr(dataMax, decimals: 1), style: metric);
    maxTp.layout();
    maxTp.paint(canvas, Offset(4, 2));

    if (points.length > 1) {
      final ft = TextPainter()
        ..text = TextSpan(text: _shortDate(points.first.date), style: short);
      ft.layout();
      ft.paint(canvas, Offset(4, size.height - bottomPad + 6));
      final lt = TextPainter()
        ..text = TextSpan(text: _shortDate(points.last.date), style: short);
      lt.layout();
      lt.paint(canvas,
          Offset(size.width - lt.width - 4, size.height - bottomPad + 6));
    } else if (points.isNotEmpty) {
      final ot = TextPainter()
        ..text = TextSpan(text: _shortDate(points.first.date), style: short);
      ot.layout();
      ot.paint(canvas,
          Offset(size.width / 2 - ot.width / 2, size.height - bottomPad + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter old) =>
      old.points != points || old.lineColor != lineColor;
}
