import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';
import '../constants/colors.dart';
import '../constants/plant_data.dart';
import '../widgets/moisture_chart.dart';

class PlantDetailScreen extends StatelessWidget {
  final String plantId;

  const PlantDetailScreen({super.key, required this.plantId});

  @override
  Widget build(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context);

    final plantIndex = plantProvider.plants.indexWhere((p) => p.id == plantId);
    if (plantIndex == -1) {
      return const Scaffold(body: Center(child: Text("Bitki bulunamadı.")));
    }
    final plant = plantProvider.plants[plantIndex];

    // Bitki türü veya adına göre katalogdan bilgiyi bul
    final catalogInfo = PlantData.catalog.firstWhere(
      (p) =>
          p.name.toLowerCase() == plant.type.toLowerCase() ||
          p.name.toLowerCase() == plant.name.toLowerCase(),
      orElse: () => PlantData.catalog.first,
    );

    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            // --- 1. ÜST KAPAK GÖRSELİ VE YUVARLAK BUTONLAR ---
            SizedBox(
              height: 230,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (plant.imageUrl != null && plant.imageUrl!.isNotEmpty)
                      ? Image.network(
                          plant.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.network(
                            catalogInfo.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: AppColors.secondary),
                          ),
                        )
                      : Image.network(
                          catalogInfo.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: AppColors.secondary),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.black.withOpacity(0.35),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.black.withOpacity(0.35),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                              onPressed: () {
                                plantProvider.deletePlant(plant.id);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Text(
                      plant.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. SEKME ÇUBUĞU (ANALİZ | BAKIM REHBERİ) ---
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                labelColor: textColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(icon: Icon(Icons.bar_chart_outlined), text: "Analiz"),
                  Tab(icon: Icon(Icons.menu_book_outlined), text: "Bakım Rehberi"),
                ],
              ),
            ),

            // --- 3. SEKME İÇERİKLERİ (KAYDIRILABİLİR) ---
            Expanded(
              child: TabBarView(
                children: [
                  // SEKME 1: ANALİZ
                  ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
                    children: [
                      Container(
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
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatItem(
                                  Icons.water_drop,
                                  "%${plant.moistureLevel.toInt()}",
                                  "Nem (Sınır %${plant.minMoisture})",
                                  textColor,
                                ),
                                _buildVerticalDivider(),
                                _buildStatItem(
                                  Icons.thermostat,
                                  "${plant.temperature.toStringAsFixed(1)}°C",
                                  "Sıcaklık",
                                  textColor,
                                  iconColor: Colors.orange,
                                ),
                                _buildVerticalDivider(),
                                _buildStatItem(
                                  Icons.wb_sunny,
                                  "%${plant.lightLevel.toInt()}",
                                  "Işık",
                                  textColor,
                                  iconColor: Colors.amber,
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Sulama Sistemi",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      plant.isPumpOn ? "Pompa çalışıyor" : "Pompa kapalı",
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: plant.isPumpOn,
                                  activeColor: Colors.white,
                                  activeTrackColor: AppColors.primary,
                                  onChanged: (val) => plantProvider.togglePump(plant.id, val),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          "Son 7 Günlük Nem",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const MoistureChart(),
                    ],
                  ),

                  // SEKME 2: BAKIM REHBERİ
                  ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
                    children: [
                      Text(
                        "Bakım Kartı: ${plant.name}",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        catalogInfo.description,
                        style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.8), height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      _buildCareCard(Icons.water_drop_outlined, "Sulama", catalogInfo.watering, cardColor, textColor),
                      _buildCareCard(Icons.wb_sunny_outlined, "Işık İhtiyacı", catalogInfo.light, cardColor, textColor),
                      _buildCareCard(Icons.thermostat_outlined, "Sıcaklık", catalogInfo.temperature, cardColor, textColor),
                      _buildCareCard(Icons.content_cut, "Budama", "Kuruyan yaprakları temizleyin.", cardColor, textColor),
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

  Widget _buildStatItem(IconData icon, String value, String label, Color textColor, {Color iconColor = AppColors.primary}) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.2));
  }

  Widget _buildCareCard(IconData icon, String title, String desc, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: textColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}