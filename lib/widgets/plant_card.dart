import 'package:flutter/material.dart';
import '../constants/colors.dart';

class PlantCard extends StatelessWidget {
  final String plantName;
  final String humidity;
  final String status;
  final Color statusColor;
  final double moistureLevel;
  final String? imageUrl;
  final String? sensorId;
  final VoidCallback? onSensorTap;

  const PlantCard({
    super.key,
    required this.plantName,
    required this.humidity,
    required this.status,
    required this.statusColor,
    required this.moistureLevel,
    this.imageUrl,
    this.sensorId,
    this.onSensorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? Image.network(imageUrl!, height: 110, width: double.infinity, fit: BoxFit.cover)
                  : Container(height:110, width: double.infinity, color: Colors.grey[200], child: const Icon(Icons.local_florist, size: 44, color: Colors.green)),
            ),
            const SizedBox(height: 10),
            Text(plantName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (moistureLevel.clamp(0,100))/100, minHeight: 6, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(statusColor)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(humidity, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
              if (sensorId != null)
                GestureDetector(
                  onTap: onSensorTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal:8, vertical:6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [const Icon(Icons.sensors, size:14, color:Colors.white), const SizedBox(width:6), Text(sensorId!, style: const TextStyle(color:Colors.white, fontSize:12))]),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal:8, vertical:6),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
