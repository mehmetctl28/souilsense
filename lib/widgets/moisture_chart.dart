import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/sensor_data.dart';
import '../providers/sensor_provider.dart';

class MoistureChart extends StatefulWidget {
  final double currentMoisture;
  final double currentTemp;
  final double currentLight;
  final List<double>? historyValues;
  final List<TelemetryPoint>? telemetryPoints;
  final List<TimelineEvent>? wateringEvents;
  final WateringEffectivenessReport? wateringReport;

  const MoistureChart({
    super.key,
    this.currentMoisture = 50.0,
    this.currentTemp = 24.0,
    this.currentLight = 60.0,
    this.historyValues,
    this.telemetryPoints,
    this.wateringEvents,
    this.wateringReport,
  });

  @override
  State<MoistureChart> createState() => _MoistureChartState();
}

class _MoistureChartState extends State<MoistureChart> {
  int _selectedMetric = 0; // 0: Nem, 1: Sıcaklık, 2: Işık, 3: Sulama Kaydı
  int _selectedRangeHours = 24; // 24: Son 24 Saat, 168: Son 7 Gün

  String _formatClockOrDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (_selectedRangeHours > 24) {
      return "${dt.day}/${dt.month} $h:$m";
    }
    return "$h:$m";
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    final double baseValue = _selectedMetric == 0
        ? widget.currentMoisture
        : (_selectedMetric == 1 ? widget.currentTemp : widget.currentLight);

    final double maxScale = _selectedMetric == 1 ? 45.0 : 100.0;
    final String unit = _selectedMetric == 1 ? "°C" : "%";
    final Color activeColor = _selectedMetric == 0
        ? AppColors.secondary
        : (_selectedMetric == 1 ? Colors.orange : Colors.amber.shade700);

    // Zaman aralığına göre gerçek TelemetryPoint filtrelemesi
    final int cutoffTs = DateTime.now()
        .subtract(Duration(hours: _selectedRangeHours))
        .millisecondsSinceEpoch;

    final List<TelemetryPoint> allPoints = widget.telemetryPoints ?? const [];
    final List<TelemetryPoint> filteredPoints =
        allPoints.where((p) => p.timestamp >= cutoffTs).toList();

    final List<TelemetryPoint> activePoints =
        filteredPoints.isNotEmpty ? filteredPoints : allPoints;

    List<double> rawSeries = [];
    if (activePoints.length >= 2) {
      rawSeries = activePoints.map((p) {
        if (_selectedMetric == 0) return p.moisture;
        if (_selectedMetric == 1) return p.temperature;
        return p.light;
      }).toList();
    } else if (_selectedMetric == 0 &&
        widget.historyValues != null &&
        widget.historyValues!.length >= 2) {
      rawSeries = widget.historyValues!;
    }

    final bool hasRealSeries = rawSeries.length >= 2;
    final List<double> normalizedValues = hasRealSeries
        ? rawSeries.map((v) => (v / maxScale).clamp(0.05, 0.98)).toList()
        : const [];

    double minVal = baseValue;
    double maxVal = baseValue;
    double avgVal = baseValue;
    if (hasRealSeries) {
      minVal = rawSeries.reduce(math.min);
      maxVal = rawSeries.reduce(math.max);
      avgVal = rawSeries.reduce((a, b) => a + b) / rawSeries.length;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. METRİK SEKMELERİ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricTab(0, "Nem Serisi", Icons.water_drop_outlined, textColor),
                const SizedBox(width: 8),
                _buildMetricTab(1, "Sıcaklık", Icons.thermostat_outlined, textColor),
                const SizedBox(width: 8),
                _buildMetricTab(2, "Işık", Icons.wb_sunny_outlined, textColor),
                const SizedBox(width: 8),
                _buildMetricTab(3, "Sulama & Etki", Icons.history, textColor),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_selectedMetric == 3)
            _buildRealWateringHistory(textColor)
          else ...[
            // 2. ZAMAN ARALIĞI SEÇİCİ (24 Saat / 7 Gün)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedMetric == 0
                        ? "Gerçek Nem Geçmişi"
                        : (_selectedMetric == 1 ? "Sıcaklık Geçmişi" : "Işık Geçmişi"),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
                Row(
                  children: [
                    _buildRangeChip("24 Saat", 24, textColor),
                    const SizedBox(width: 6),
                    _buildRangeChip("7 Gün", 168, textColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!hasRealSeries)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.timeline, color: activeColor, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      "Tekil Ölçüm: ${baseValue.toStringAsFixed(1)}$unit",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Gerçek zaman serisi grafiği için en az 2 zaman damgalı ölçüm paketi bekleniyor (Örnek/yapay veri gösterilmez).",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else ...[
              // 3. MİN / MAKS / ORTALAMA ÖZET BAR
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn("Min", "${minVal.toStringAsFixed(1)}$unit", textColor),
                    _buildStatColumn("Ortalama", "${avgVal.toStringAsFixed(1)}$unit", textColor),
                    _buildStatColumn("Maks", "${maxVal.toStringAsFixed(1)}$unit", textColor),
                    _buildStatColumn("Son", "${baseValue.toStringAsFixed(1)}$unit", activeColor),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "${maxScale.toInt()}$unit",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 145,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ChartPainter(lineColor: activeColor, values: normalizedValues),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "0$unit",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.5),
                ),
              ),
              if (activePoints.length >= 2) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatClockOrDate(activePoints.first.timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      "${activePoints.length} gerçek ölçüm",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      _formatClockOrDate(activePoints.last.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildRangeChip(String label, int hours, Color textColor) {
    final bool selected = _selectedRangeHours == hours;
    return GestureDetector(
      onTap: () => setState(() => _selectedRangeHours = hours),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.primary : textColor.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTab(int index, String label, IconData icon, Color textColor) {
    final bool isSelected = _selectedMetric == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMetric = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : textColor.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : textColor.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealWateringHistory(Color textColor) {
    final events = (widget.wateringEvents ?? const [])
        .where((e) => e.type == 'watering' || e.type == 'alert')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.wateringReport != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (widget.wateringReport!.isEffective
                      ? AppColors.statusGood
                      : AppColors.statusCritical)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  widget.wateringReport!.isEffective ? Icons.check_circle : Icons.warning_amber,
                  color: widget.wateringReport!.isEffective
                      ? AppColors.statusGood
                      : AppColors.statusCritical,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.wateringReport!.summaryText,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "Bu bitki için henüz kayıtlı bir sulama veya pompa olayı bulunmuyor.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          )
        else
          ...events.take(6).map((ev) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: const Icon(Icons.water_drop_outlined, size: 15, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(ev.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(
                    _formatClockOrDate(ev.timestamp),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Color lineColor;
  final List<double> values;

  _ChartPainter({required this.lineColor, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final points = <Offset>[];
    final stepX = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height * (1 - values[i]);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.28), lineColor.withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final dotFill = Paint()..color = Colors.white;
    final dotBorder = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final p in points) {
      canvas.drawCircle(p, 4.5, dotFill);
      canvas.drawCircle(p, 4.5, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}