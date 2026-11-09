import 'package:flutter/material.dart';
import '../constants/colors.dart';

class MoistureChart extends StatefulWidget {
  final double currentMoisture;
  final double currentTemp;
  final double currentLight;
  final List<double>? historyValues;

  const MoistureChart({
    super.key,
    this.currentMoisture = 50.0,
    this.currentTemp = 24.0,
    this.currentLight = 60.0,
    this.historyValues,
  });

  @override
  State<MoistureChart> createState() => _MoistureChartState();
}

class _MoistureChartState extends State<MoistureChart> {
  int _selectedMetric = 0; // 0: Nem, 1: Sıcaklık, 2: Işık, 3: Sulama Geçmişi

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

    final double normalized = (baseValue / maxScale).clamp(0.08, 0.95);
    final List<double> chartValues = [
      (normalized * 0.92).clamp(0.05, 1.0),
      (normalized * 1.08).clamp(0.05, 1.0),
      (normalized * 0.85).clamp(0.05, 1.0),
      (normalized * 0.78).clamp(0.05, 1.0),
      (normalized * 1.12).clamp(0.05, 1.0),
      (normalized * 0.96).clamp(0.05, 1.0),
      normalized,
    ];

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
          // METRİK SEÇİCİ SEKMELER
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricTab(0, "Nem Geçmişi", Icons.water_drop_outlined, textColor),
                const SizedBox(width: 8),
                _buildMetricTab(1, "Sıcaklık", Icons.thermostat_outlined, textColor),
                const SizedBox(width: 8),
                _buildMetricTab(2, "Işık Analizi", Icons.wb_sunny_outlined, textColor),
                const SizedBox(width: 8),
                _buildMetricTab(3, "Sulama Kaydı", Icons.history, textColor),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_selectedMetric == 3)
            _buildWateringHistoryList(textColor)
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedMetric == 0
                      ? "Haftalık Nem Değişimi"
                      : (_selectedMetric == 1 ? "Ortam Sıcaklığı" : "Günlük Işık Maruziyeti"),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Anlık: ${baseValue.toStringAsFixed(0)}$unit",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: activeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text("${maxScale.toInt()}$unit",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.5))),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(lineColor: activeColor, values: chartValues),
              ),
            ),
            const SizedBox(height: 10),
            Text("0$unit",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.5))),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text("Pzt", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Sal", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Çar", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Prş", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Cum", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Cmt", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Bugün", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
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

  Widget _buildWateringHistoryList(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Son Bakım ve Sulama Zaman Çizelgesi",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),
        _buildHistoryRow("Bugün", "Anlık toprak nemi: %${widget.currentMoisture.toInt()}", Icons.sensors, AppColors.primary, textColor),
        _buildHistoryRow("Dün • 18:30", "Sulama sonrası nem %24 → %68 yükseldi", Icons.water_drop, Colors.blue, textColor),
        _buildHistoryRow("3 Gün Önce", "Kritik nem uyarısı tetiklendi (%22)", Icons.warning_amber_rounded, Colors.orange, textColor),
      ],
    );
  }

  Widget _buildHistoryRow(String time, String desc, IconData icon, Color color, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Color lineColor;
  final List<double> values;

  _ChartPainter({required this.lineColor, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
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
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final dotFill = Paint()..color = Colors.white;
    final dotBorder = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final p in points) {
      canvas.drawCircle(p, 5.0, dotFill);
      canvas.drawCircle(p, 5.0, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}