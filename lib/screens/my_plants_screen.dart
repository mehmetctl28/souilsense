import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';
import '../widgets/plant_card.dart';
import '../constants/text_styles.dart';

class MyPlantsScreen extends StatelessWidget {
  const MyPlantsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlantProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bitkilerim')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: provider.plants.isEmpty
            ? const Center(child: Text('Henüz bitkiniz yok'))
            : ListView.builder(
                itemCount: provider.plants.length,
                itemBuilder: (context, index) {
                  final p = provider.plants[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical:6.0),
                    child: PlantCard(
                      plantName: p.name,
                      humidity: '${p.moistureLevel.toStringAsFixed(1)}%',
                      status: p.moistureLevel>=50 ? 'İyi':'Orta',
                      statusColor: p.moistureLevel>=50 ? Colors.green:Colors.orange,
                      moistureLevel: p.moistureLevel,
                      sensorId: p.sensorId,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
