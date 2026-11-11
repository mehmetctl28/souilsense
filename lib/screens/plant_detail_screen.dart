import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';
import '../providers/sensor_provider.dart';
import '../models/sensor_data.dart';
import '../constants/colors.dart';
import '../constants/plant_data.dart';
import '../services/plant_intelligence.dart';
import '../widgets/moisture_chart.dart';

class PlantDetailScreen extends StatelessWidget {
  final String plantId;

  const PlantDetailScreen({super.key, required this.plantId});

  String _formatTime(int timestamp) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inMinutes < 1) return "Az önce";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} sa önce";
    return "${diff.inDays} gün önce";
  }

  Future<void> _showCalibrationDialog(
    BuildContext context,
    String sensorId,
    SensorProvider sensorProvider,
  ) async {
    final config = sensorProvider.getSensorConfig(sensorId);
    final liveSensor = sensorProvider.getSensor(sensorId);
    final dryCtrl = TextEditingController(text: config.dryAdcValue.toString());
    final wetCtrl = TextEditingController(text: config.wetAdcValue.toString());
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Sensör Kalibrasyon Sihirbazı ($sensorId)",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                liveSensor?.rawAdc != null
                    ? "Anlık Ham ADC: ${liveSensor!.rawAdc}"
                    : "ESP32'den 'rawAdc' alanı geldiğinde otomatik yüzde dönüşümü uygulanır.",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dryCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  labelText: "1. Kuru Toprak / Hava ADC Değeri (%0)",
                  hintText: "Örn: 3200",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: wetCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  labelText: "2. Tam Islak Toprak ADC Değeri (%100)",
                  hintText: "Örn: 1400",
                ),
              ),
            ],
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
              final dry = int.tryParse(dryCtrl.text.trim()) ?? 3200;
              final wet = int.tryParse(wetCtrl.text.trim()) ?? 1400;
              if ((dry - wet).abs() < 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Kuru ve ıslak ADC değerleri arasında en az 200 fark olmalıdır."),
                  ),
                );
                return;
              }
              await sensorProvider.saveSensorConfig(
                SensorConfig(
                  sensorId: sensorId,
                  dryAdcValue: dry,
                  wetAdcValue: wet,
                  readIntervalSeconds: config.readIntervalSeconds,
                  maxPumpSeconds: sensorProvider.maxPumpSeconds,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Kalibrasyonu Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context);
    final sensorProvider = Provider.of<SensorProvider>(context);

    final plantIndex = plantProvider.plants.indexWhere((p) => p.id == plantId);
    if (plantIndex == -1) {
      return const Scaffold(body: Center(child: Text("Bitki bulunamadı.")));
    }
    final plant = plantProvider.plants[plantIndex];

    final SensorData? liveSensor = sensorProvider.getSensor(plant.sensorId);
    final double liveMoisture = liveSensor != null ? liveSensor.moisture : plant.moistureLevel;
    final double liveTemp = liveSensor != null ? liveSensor.temperature : plant.temperature;
    final double liveLight = liveSensor != null ? liveSensor.light : plant.lightLevel;
    final bool isOnline = sensorProvider.isSensorOnline(plant.sensorId);

    final pumpState = sensorProvider.getPumpState(
      plant.sensorId,
      fallbackPumpOn: plant.isPumpOn,
    );
    final telemetryPoints = sensorProvider.getTelemetryHistory(plant.sensorId);
    final historyValues = sensorProvider.getMoistureHistory(plant.sensorId, liveMoisture);
    final timelineEvents = sensorProvider.getTimeline(plant.sensorId, liveMoisture);
    final wateringReport = sensorProvider.getWateringReport(plant.sensorId);

    // 4. Bölüm: Veri tazeliği kontrollü Sağlık Skoru ve Plant Intelligence 2.0
    final healthResult = PlantIntelligence.evaluateHealthScore(
      plant,
      liveSensor,
      offlineTimeoutMinutes: sensorProvider.offlineTimeoutMinutes,
    );
    final dryingAnalysis = PlantIntelligence.analyzeDryingRate(
      telemetryPoints,
      liveMoisture,
      plant.minMoisture,
    );
    final intelligenceCards = PlantIntelligence.buildIntelligenceV2(
      plant: plant,
      sensor: liveSensor,
      history: telemetryPoints,
      wateringReport: wateringReport,
      offlineTimeoutMinutes: sensorProvider.offlineTimeoutMinutes,
    );
    final sensorReport = PlantIntelligence.diagnoseSensor(
      plant.sensorId,
      liveSensor,
      history: telemetryPoints,
      offlineTimeoutMinutes: sensorProvider.offlineTimeoutMinutes,
    );

    PlantInfo? matchedCatalog;
    for (final item in PlantData.catalog) {
      if (item.name.toLowerCase() == plant.type.toLowerCase() ||
          item.name.toLowerCase() == plant.name.toLowerCase()) {
        matchedCatalog = item;
        break;
      }
    }

    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            // 1. ÜST KAPAK GÖRSELİ + VERİ TAZELİĞİ ROZETİ
            SizedBox(
              height: 235,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (plant.imageUrl != null && plant.imageUrl!.isNotEmpty)
                      ? Image.network(
                          plant.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: AppColors.secondary),
                        )
                      : Container(color: AppColors.secondary),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.25),
                          Colors.black.withOpacity(0.72),
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
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.50),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                healthResult.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: healthResult.isFresh ? Colors.white : Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
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
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Text(
                          plant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
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
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "Düğüm: ${plant.sensorId} • ${sensorReport.statusText}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. SEKMELER
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                labelColor: textColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.bar_chart_outlined), text: "Analiz"),
                  Tab(icon: Icon(Icons.psychology_outlined), text: "Zekâ 2.0"),
                  Tab(icon: Icon(Icons.menu_book_outlined), text: "Rehber"),
                ],
              ),
            ),

            // 3. SEKME İÇERİKLERİ
            Expanded(
              child: TabBarView(
                children: [
                  // SEKME 1: ANALİZ + KURUMA HIZI + GERÇEK ZAMAN SERİSİ GRAFİĞİ
                  ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatItem(
                                  Icons.water_drop,
                                  "%${liveMoisture.toInt()}",
                                  "Nem (%${plant.minMoisture}-${plant.maxMoisture})",
                                  textColor,
                                ),
                                _buildVerticalDivider(),
                                _buildStatItem(
                                  Icons.thermostat,
                                  "${liveTemp.toStringAsFixed(1)}°C",
                                  "Sıcaklık",
                                  textColor,
                                  iconColor: Colors.orange,
                                ),
                                _buildVerticalDivider(),
                                _buildStatItem(
                                  Icons.wb_sunny,
                                  "%${liveLight.toInt()}",
                                  "Işık",
                                  textColor,
                                  iconColor: Colors.amber,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // 3.2: Saatlik Kuruma Hızı Bilgi Bandı
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.hourglass_bottom,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dryingAnalysis.summary,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(height: 1),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Sulama Pompası",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "Cihaz: ${pumpState.actualState ? 'Çalışıyor' : 'Kapalı'} • Komut: ${pumpState.requestedState ? 'Açık (${pumpState.maxDurationSeconds}sn)' : 'Beklemede'}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: pumpState.requestedState,
                                  activeColor: Colors.white,
                                  activeTrackColor: AppColors.primary,
                                  onChanged: (val) {
                                    plantProvider.togglePump(plant.id, val);
                                    sensorProvider.requestPumpState(
                                      sensorId: plant.sensorId,
                                      requestedState: val,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Otomatik Sulama Modu",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "Nem %${plant.minMoisture} altına düştüğünde pompayı otomatik tetikle",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: pumpState.autoWatering,
                                  activeColor: Colors.white,
                                  activeTrackColor: AppColors.secondary,
                                  onChanged: (val) {
                                    sensorProvider.requestPumpState(
                                      sensorId: plant.sensorId,
                                      requestedState: pumpState.requestedState,
                                      autoWatering: val,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 3.1: Gerçek Zaman Serisi ve Sulama Etki Raporu Bağlandı
                      MoistureChart(
                        currentMoisture: liveMoisture,
                        currentTemp: liveTemp,
                        currentLight: liveLight,
                        historyValues: historyValues,
                        telemetryPoints: telemetryPoints,
                        wateringEvents: timelineEvents,
                        wateringReport: wateringReport,
                      ),
                    ],
                  ),

                  // SEKME 2: PLANT INTELLIGENCE 2.0 (6 Çekirdek Analiz Modülü + Kalibrasyon)
                  ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "Plant Intelligence 2.0 Analizi",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _showCalibrationDialog(context, plant.sensorId, sensorProvider),
                            icon: const Icon(Icons.tune, size: 16, color: AppColors.primary),
                            label: const Text(
                              "ADC Kalibre Et",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...intelligenceCards.map((card) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(card.icon, color: card.color, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${card.title} (${card.category})",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: card.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      card.badgeText,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: card.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                card.detail,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 14),
                      Text(
                        "Kayıt Geçmişi (System Log)",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 10),
                      ...timelineEvents.map((ev) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                ev.type == 'watering' ? Icons.water_drop_outlined : Icons.sensors,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ev.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      ev.subtitle,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(ev.timestamp),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),

                  // SEKME 3: BAKIM REHBERİ
                  ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
                    children: [
                      if (matchedCatalog == null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "'${plant.type}' türü katalogda bulunamadığı için standart bakım parametreleri gösteriliyor.",
                                  style: TextStyle(fontSize: 13, color: textColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        matchedCatalog != null
                            ? "Bakım Kartı: ${matchedCatalog.name}"
                            : "Standart Bakım Rehberi",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        matchedCatalog?.description ??
                            "Toprak nemini düzenli takip edin ve bitkinizi doğrudan yakıcı güneş ışığından koruyun.",
                        style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.8), height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      _buildCareCard(
                        Icons.water_drop_outlined,
                        "Sulama Aralığı",
                        "İdeal Nem: %${plant.minMoisture} – %${plant.maxMoisture}. ${matchedCatalog?.watering ?? ''}",
                        cardColor,
                        textColor,
                      ),
                      _buildCareCard(
                        Icons.wb_sunny_outlined,
                        "Işık İhtiyacı",
                        "İdeal Işık: %${plant.minLight.toInt()} – %${plant.maxLight.toInt()}. ${matchedCatalog?.light ?? ''}",
                        cardColor,
                        textColor,
                      ),
                      _buildCareCard(
                        Icons.thermostat_outlined,
                        "Sıcaklık Aralığı",
                        "İdeal Sıcaklık: ${plant.minTemp.toInt()}°C – ${plant.maxTemp.toInt()}°C. ${matchedCatalog?.temperature ?? ''}",
                        cardColor,
                        textColor,
                      ),
                      _buildCareCard(
                        Icons.content_cut,
                        "Budama",
                        "Kuruyan veya sararan yaprakları steril bir makasla temizleyin.",
                        cardColor,
                        textColor,
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

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color textColor, {
    Color iconColor = AppColors.primary,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor)),
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