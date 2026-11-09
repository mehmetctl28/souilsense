import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/plant.dart';
import '../models/sensor_data.dart';
import '../providers/plant_provider.dart';
import '../providers/sensor_provider.dart';
import '../services/plant_intelligence.dart';
import 'add_plant_screen.dart';
import 'plant_detail_screen.dart';

enum PlantFilter { all, healthy, thirsty, offline }

class MyPlantsScreen extends StatefulWidget {
  const MyPlantsScreen({super.key});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  String _searchQuery = "";
  PlantFilter _selectedFilter = PlantFilter.all;
  bool _sortByName = true;

  // 4.2.7 Sensör ID'sini kart üzerinden değiştirebilme
  Future<void> _showEditSensorDialog(
    BuildContext context,
    Plant plant,
    PlantProvider plantProvider,
    SensorProvider sensorProvider,
  ) async {
    final controller = TextEditingController(text: plant.sensorId);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "${plant.name} • Sensör Eşleştir",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: textColor),
          decoration: const InputDecoration(
            labelText: "Yeni Sensör Kimliği (ID)",
            hintText: "Örn: sensor2",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newId = controller.text.trim();
              final ok = await plantProvider.updateSensorId(plant.id, newId);
              if (ok) {
                await sensorProvider.ensureSensorExists(newId);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? "Sensör kimliği '$newId' olarak güncellendi."
                          : "Bu sensör başka bir bitkide kullanımda veya geçersiz!",
                    ),
                  ),
                );
              }
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context);
    final sensorProvider = Provider.of<SensorProvider>(context);
    final allPlants = plantProvider.plants;

    double getLiveMoisture(Plant p) {
      final SensorData? s = sensorProvider.getSensor(p.sensorId);
      return s != null ? s.moisture : p.moistureLevel;
    }

    double getLiveTemp(Plant p) {
      final SensorData? s = sensorProvider.getSensor(p.sensorId);
      return s != null ? s.temperature : p.temperature;
    }

    bool isPlantOnline(Plant p) {
      final SensorData? s = sensorProvider.getSensor(p.sensorId);
      return s != null && s.isOnline;
    }

    final int totalCount = allPlants.length;
    final int thirstyCount = allPlants.where((p) => getLiveMoisture(p) < p.minMoisture).length;
    final int healthyCount = allPlants.where((p) => getLiveMoisture(p) >= p.minMoisture).length;
    final int offlineCount = allPlants.where((p) => !isPlantOnline(p)).length;

    List<Plant> filteredPlants = allPlants.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final moisture = getLiveMoisture(p);
      final online = isPlantOnline(p);

      switch (_selectedFilter) {
        case PlantFilter.all:
          return true;
        case PlantFilter.healthy:
          return moisture >= p.minMoisture;
        case PlantFilter.thirsty:
          return moisture < p.minMoisture;
        case PlantFilter.offline:
          return !online;
      }
    }).toList();

    filteredPlants.sort((a, b) {
      if (_sortByName) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        return getLiveMoisture(a).compareTo(getLiveMoisture(b));
      }
    });

    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ÜST BAŞLIK + SIRALAMA + EKLE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Bahçem",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: _sortByName ? "Neme Göre Sırala" : "İsme Göre Sırala",
                        icon: Icon(
                          _sortByName ? Icons.sort_by_alpha : Icons.water_drop_outlined,
                          color: textColor,
                        ),
                        onPressed: () => setState(() => _sortByName = !_sortByName),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddPlantScreen()),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add, color: textColor, size: 24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. ARAMA ÇUBUĞU
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search, color: Colors.grey),
                    hintText: "Bitki ara...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 3. FİLTRE ÇİPLERİ
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip("Tümü · $totalCount", PlantFilter.all, cardColor, textColor),
                    const SizedBox(width: 8),
                    _buildFilterChip("Sağlıklı · $healthyCount", PlantFilter.healthy, cardColor, textColor),
                    const SizedBox(width: 8),
                    _buildFilterChip("Sulama gerekli · $thirstyCount", PlantFilter.thirsty, cardColor, textColor),
                    const SizedBox(width: 8),
                    _buildFilterChip("Çevrimdışı · $offlineCount", PlantFilter.offline, cardColor, textColor),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. BİTKİ KARTLARI GRİDİ
              Expanded(
                child: allPlants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_florist_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "Bahçende henüz bitki yok.",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddPlantScreen()),
                                );
                              },
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text("Bitki Ekle", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredPlants.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.68,
                        ),
                        itemBuilder: (context, index) {
                          final plant = filteredPlants[index];
                          final sensor = sensorProvider.getSensor(plant.sensorId);
                          final score = PlantIntelligence.calculateHealthScore(plant, sensor);

                          return _buildGardenCard(
                            context,
                            plant,
                            getLiveMoisture(plant),
                            getLiveTemp(plant),
                            isPlantOnline(plant),
                            score,
                            plantProvider,
                            sensorProvider,
                            cardColor,
                            textColor,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, PlantFilter filter, Color cardColor, Color textColor) {
    final bool isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : textColor.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildGardenCard(
    BuildContext context,
    Plant plant,
    double liveMoisture,
    double liveTemp,
    bool isOnline,
    int healthScore,
    PlantProvider plantProvider,
    SensorProvider sensorProvider,
    Color cardColor,
    Color textColor,
  ) {
    final bool isThirsty = liveMoisture < plant.minMoisture;
    final Color statusColor = isThirsty ? AppColors.statusCritical : AppColors.statusGood;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: (plant.imageUrl != null && plant.imageUrl!.isNotEmpty)
                        ? Image.network(
                            plant.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: cardColor,
                              child: Icon(Icons.local_florist_outlined,
                                  color: Colors.grey.shade400, size: 32),
                            ),
                          )
                        : Container(
                            color: cardColor,
                            child: Icon(Icons.local_florist_outlined,
                                color: Colors.grey.shade400, size: 32),
                          ),
                  ),
                  // Sol Üst: Tıklanabilir Sensör ID Rozeti (4.2.7 Sensör Değiştirme)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () => _showEditSensorDialog(context, plant, plantProvider, sensorProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: isOnline ? AppColors.statusGood : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              plant.sensorId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.edit, size: 10, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Sağ Üst: Kart Üzerinden Hızlı Sulama / Durum Rozeti (4.2.6)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: isThirsty
                          ? () async {
                              await plantProvider.togglePump(plant.id, true);
                              await sensorProvider.requestPumpState(
                                sensorId: plant.sensorId,
                                requestedState: true,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("${plant.name} hızlı sulandı! 💧"),
                                  ),
                                );
                              }
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isThirsty ? Icons.water_drop : Icons.check,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isThirsty ? "Sula" : "İyi",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          plant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ),
                      Text(
                        "${liveTemp.toStringAsFixed(0)}°C",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (liveMoisture / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey.withOpacity(0.18),
                      color: isThirsty ? AppColors.statusCritical : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "%${liveMoisture.toInt()} (Sınır %${plant.minMoisture})",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor.withOpacity(0.85),
                        ),
                      ),
                      Text(
                        "♥ $healthScore",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: healthScore >= 75 ? AppColors.statusGood : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}