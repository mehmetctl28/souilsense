import 'package:flutter/material.dart';
import '../constants/colors.dart';

class MoistureChart extends StatelessWidget {
  const MoistureChart({super.key});

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Nem Analizi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Son 7 Gün",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("100%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.6))),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _ChartPainter(lineColor: AppColors.secondary),
            ),
          ),
          const SizedBox(height: 12),
          Text("0%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.6))),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text("Pzt", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              Text("Sal", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              Text("Çar", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              Text("Prş", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              Text("Cum", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              Text("Cmt", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              Text("Paz", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Color lineColor;
  _ChartPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final values = [0.75, 0.68, 0.62, 0.35, 0.20, 0.82, 0.72];
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
      canvas.drawCircle(p, 5.5, dotFill);
      canvas.drawCircle(p, 5.5, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}