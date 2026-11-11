import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/auth_provider.dart';
import '../models/plant.dart';
import '../models/sensor_data.dart';
import '../constants/colors.dart';
import '../services/plant_intelligence.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/todo_list.dart';
import 'add_plant_screen.dart';
import 'plant_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _formatLastUpdate(int? timestamp) {
    if (timestamp == null || timestamp == 0) return "Veri yok";
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inMinutes < 1) return "Az önce";
    if (diff.inMinutes < 60) return "${diff.inMinutes} dk önce";
    if (diff.inHours < 24) return "${diff.inHours} sa önce";
    return "${diff.inDays} gün önce";
  }

  void _showCriticalAndWateringSheet(
    BuildContext context,
    List<Plant> plants,
    SensorProvider sensorProvider,
    PlantProvider plantProvider,
  ) {
    FocusManager.instance.primaryFocus?.unfocus();
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset > 0 ? bottomInset + 12 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop_outlined, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Sulama ve Nem Kontrolü",
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Saksıların anlık nem değerleri ve manuel pompa tetikleme listesi:",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: plants.length,
                    itemBuilder: (context, index) {
                      final plant = plants[index];
                      final SensorData? sensor = sensorProvider.getSensor(plant.sensorId);
                      final double liveMoisture = sensor != null ? sensor.moisture : plant.moistureLevel;
                      final bool isThirsty = liveMoisture < plant.minMoisture;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)),
                            );
                          },
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: isThirsty
                                ? AppColors.statusCritical.withOpacity(0.15)
                                : AppColors.statusGood.withOpacity(0.15),
                            child: Icon(
                              Icons.water_drop_outlined,
                              size: 20,
                              color: isThirsty ? AppColors.statusCritical : AppColors.statusGood,
                            ),
                          ),
                          title: Text(
                            plant.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                          ),
                          subtitle: Text(
                            "Nem: %${liveMoisture.toInt()} (Eşik: %${plant.minMoisture}) • ${_formatLastUpdate(sensor?.lastUpdate)}",
                            style: TextStyle(
                              color: isThirsty ? AppColors.statusCritical : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isThirsty ? AppColors.statusCritical : AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await plantProvider.togglePump(plant.id, true);
                              await sensorProvider.requestPumpState(
                                sensorId: plant.sensorId,
                                requestedState: true,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("${plant.name}: Pompa komutu gönderildi.")),
                                );
                              }
                            },
                            child: const Text(
                              "Sula",
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGardenHistorySheet(BuildContext context, SensorProvider sensorProvider) {
    FocusManager.instance.primaryFocus?.unfocus();
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final events = sensorProvider.getAllGardenTimeline();

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.65,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Sistem Kayıt Geçmişi",
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Sensör veri paketleri ve sulama komutlarının zaman damgalı kayıtları:",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: events.isEmpty
                        ? const Center(
                            child: Text(
                              "Henüz kayıtlı işlem bulunmuyor.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              final ev = events[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      ev.type == 'watering' ? Icons.water_drop_outlined : Icons.sensors,
                                      color: AppColors.primary,
                                      size: 20,
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
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            ev.subtitle,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatLastUpdate(ev.timestamp),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTelemetrySimulatorSheet(
    BuildContext context,
    List<Plant> plants,
    SensorProvider sensorProvider,
  ) {
    FocusManager.instance.primaryFocus?.unfocus();
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    if (plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test için önce bir bitki ekleyin.")),
      );
      return;
    }

    Plant selectedPlant = plants.first;
    final initialSensor = sensorProvider.getSensor(selectedPlant.sensorId);
    double simMoisture = initialSensor?.moisture ?? selectedPlant.moistureLevel;
    double simTemp = initialSensor?.temperature ?? selectedPlant.temperature;
    double simLight = initialSensor?.light ?? selectedPlant.lightLevel;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final checks = PlantIntelligence.evaluateParameters(
              selectedPlant,
              SensorData(
                sensorId: selectedPlant.sensorId,
                moisture: simMoisture,
                temperature: simTemp,
                light: simLight,
                lastUpdate: DateTime.now().millisecondsSinceEpoch,
              ),
            );

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, color: AppColors.primary, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Telemetri Test & Eşik Simülatörü",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Sensör değerlerini manuel değiştirerek eşik uyarılarını ve otomatik görev tetiklemesini test edin:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        children: plants.map((p) {
                          final isSelected = p.id == selectedPlant.id;
                          return ChoiceChip(
                            label: Text(p.name),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              final s = sensorProvider.getSensor(p.sensorId);
                              setModalState(() {
                                selectedPlant = p;
                                simMoisture = s?.moisture ?? p.moistureLevel;
                                simTemp = s?.temperature ?? p.temperature;
                                simLight = s?.light ?? p.lightLevel;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Toprak Nemi: %${simMoisture.toInt()} (Alt Eşik: %${selectedPlant.minMoisture})",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                      ),
                      Slider(
                        value: simMoisture.clamp(0.0, 100.0),
                        min: 0,
                        max: 100,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setModalState(() => simMoisture = v),
                      ),
                      Text(
                        "Ortam Sıcaklığı: ${simTemp.toStringAsFixed(1)}°C (Referans: 18–28°C)",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                      ),
                      Slider(
                        value: simTemp.clamp(5.0, 42.0),
                        min: 5,
                        max: 42,
                        activeColor: Colors.orange,
                        onChanged: (v) => setModalState(() => simTemp = v),
                      ),
                      Text(
                        "Işık Şiddeti: %${simLight.toInt()} (Referans: %25–85)",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                      ),
                      Slider(
                        value: simLight.clamp(0.0, 100.0),
                        min: 0,
                        max: 100,
                        activeColor: Colors.amber.shade700,
                        onChanged: (v) => setModalState(() => simLight = v),
                      ),
                      const SizedBox(height: 8),
                      ...checks.map(
                        (c) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "${c.parameter}: ${c.measuredValue}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  c.statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: c.statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () async {
                            await sensorProvider.simulateSensorReading(
                              sensorId: selectedPlant.sensorId,
                              moisture: simMoisture,
                              temperature: simTemp,
                              light: simLight,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text(
                            "Değerleri Sensöre Uygula",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context);
    final sensorProvider = Provider.of<SensorProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final plants = plantProvider.plants;

    final attentionPlants = plants.where((p) {
      final s = sensorProvider.getSensor(p.sensorId);
      final liveMoisture = s != null ? s.moisture : p.moistureLevel;
      return liveMoisture < p.minMoisture;
    }).toList();

    final int healthyPlantCount = plants.length - attentionPlants.length;

    final int onlineSensorCount = plants
        .where((p) => sensorProvider.isSensorOnline(p.sensorId))
        .length;

    final int gardenHealthScore = PlantIntelligence.calculateGardenAverageScore(
      plants,
      sensorProvider.sensors,
      offlineTimeoutMinutes: sensorProvider.offlineTimeoutMinutes,
    );

    double avgMoisture = 0;
    double avgTemp = 0;
    if (plants.isNotEmpty) {
      for (final p in plants) {
        final s = sensorProvider.getSensor(p.sensorId);
        avgMoisture += s?.moisture ?? p.moistureLevel;
        avgTemp += s?.temperature ?? p.temperature;
      }
      avgMoisture /= plants.length;
      avgTemp /= plants.length;
    }

    final userName = authProvider.currentUser?.displayName ?? "";
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ÜST BAR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SoilSense",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          userName.isNotEmpty ? "Merhaba, $userName 👋" : "Merhaba, 👋",
                          style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_outlined, color: textColor, size: 28),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 2. ANA DURUM KARTI
                if (plants.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Akıllı Bahçene Hoş Geldin",
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Henüz kayıtlı bitkin yok. İlk bitkini ve ESP32 sensörünü eşleştirerek canlı takibe başla.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddPlantScreen()),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text("İlk Bitkini Ekle", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (attentionPlants.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB5483A), Color(0xFFD9824B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Bakım Bekleyenler Var!",
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "${attentionPlants.length} bitkinin toprak nemi alt sınırın altında.",
                          style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 15),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () => _showCriticalAndWateringSheet(
                            context,
                            attentionPlants,
                            sensorProvider,
                            plantProvider,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Şimdi Kontrol Et", style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Her Şey Yolunda!",
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Tüm bitkilerinin nem, sıcaklık ve ışık değerleri referans aralığında.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                // 3. BAHÇE DURUM ÖZETİ (Overflow Korumalı ve Şeffaf Metrikli)
                if (plants.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Bahçe Durum Özeti",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (gardenHealthScore >= 75
                                        ? AppColors.statusGood
                                        : AppColors.statusCritical)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "Uyum: %$gardenHealthScore",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: gardenHealthScore >= 75
                                      ? AppColors.statusGood
                                      : AppColors.statusCritical,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildOverviewMetric(
                              Icons.check_circle_outline,
                              "$healthyPlantCount/${plants.length}",
                              "İdeal Bitki",
                              AppColors.statusGood,
                              textColor,
                            ),
                            _buildOverviewMetric(
                              Icons.water_drop_outlined,
                              "%${avgMoisture.toInt()}",
                              "Ort. Nem",
                              AppColors.primary,
                              textColor,
                            ),
                            _buildOverviewMetric(
                              Icons.thermostat_outlined,
                              "${avgTemp.toStringAsFixed(1)}°C",
                              "Ort. Sıcaklık",
                              Colors.orange,
                              textColor,
                            ),
                            _buildOverviewMetric(
                              Icons.sensors,
                              "$onlineSensorCount/${plants.length}",
                              "Aktif Sensör",
                              AppColors.secondary,
                              textColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 26),

                // 4. HIZLI İŞLEMLER
                Text(
                  "Hızlı İşlemler",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    QuickActionButton(
                      icon: Icons.add,
                      label: "Bitki Ekle",
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddPlantScreen()),
                        );
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.water_drop_outlined,
                      label: "Sulama",
                      onTap: () {
                        if (plants.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Önce bahçenize bir bitki ekleyin.")),
                          );
                        } else {
                          _showCriticalAndWateringSheet(context, plants, sensorProvider, plantProvider);
                        }
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.history,
                      label: "Geçmiş",
                      onTap: () => _showGardenHistorySheet(context, sensorProvider),
                    ),
                    QuickActionButton(
                      icon: Icons.tune,
                      label: "Simülatör",
                      onTap: () => _showTelemetrySimulatorSheet(context, plants, sensorProvider),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 5. BUGÜNÜN PLANI
                const TodoList(),
                const SizedBox(height: 14),
                // Kritik 4: Donanım / Simülasyon Modu ve Son Gerçek Veri Durum Bandı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sensorProvider.isHardwareMode
                        ? AppColors.statusGood.withOpacity(0.12)
                        : Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sensorProvider.isHardwareMode
                          ? AppColors.statusGood.withOpacity(0.4)
                          : Colors.blue.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sensorProvider.isHardwareMode ? Icons.memory : Icons.science_outlined,
                        size: 18,
                        color: sensorProvider.isHardwareMode ? AppColors.statusGood : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sensorProvider.isHardwareMode
                              ? "Gerçek Donanım Modu Aktif • Bağlı ESP32: ${sensorProvider.connectedHardwareSensorCount}/${plants.length} • Son Veri: ${_formatLastUpdate(sensorProvider.lastHardwareUpdateTimestamp)}"
                              : "Simülasyon Modu Aktif (Ölçümler sanal test verisidir, gerçek sensör verisi değildir)",
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewMetric(
    IconData icon,
    String value,
    String label,
    Color iconColor,
    Color textColor,
  ) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}