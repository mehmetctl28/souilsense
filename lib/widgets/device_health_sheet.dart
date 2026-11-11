import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/plant_provider.dart';
import '../providers/sensor_provider.dart';
import '../services/plant_intelligence.dart';

class DeviceHealthSheet extends StatelessWidget {
  const DeviceHealthSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const DeviceHealthSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context);
    final sensorProvider = Provider.of<SensorProvider>(context);
    final plants = plantProvider.plants;

    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.78,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.developer_board, color: AppColors.primary, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Cihaz Sağlık Merkezi (Device Health)",
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (sensorProvider.isHardwareMode ? AppColors.statusGood : Colors.blue)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      sensorProvider.isHardwareMode ? "DONANIM MODU" : "SİMÜLASYON",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sensorProvider.isHardwareMode ? AppColors.statusGood : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Eşleşmiş ESP32 düğümlerinin telemetri kararlılığı, ADC kalibrasyonu ve pompa geri bildirim durumu:",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: plants.isEmpty
                    ? const Center(
                        child: Text(
                          "Henüz eşleştirilmiş bir bitki veya sensör düğümü bulunmuyor.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: plants.length,
                        itemBuilder: (context, index) {
                          final plant = plants[index];
                          final sId = plant.sensorId;
                          final sensor = sensorProvider.getSensor(sId);
                          final config = sensorProvider.getSensorConfig(sId);
                          final pump = sensorProvider.getPumpState(sId);
                          final history = sensorProvider.getTelemetryHistory(sId);

                          final report = PlantIntelligence.diagnoseSensor(
                            sId,
                            sensor,
                            history: history,
                            offlineTimeoutMinutes: sensorProvider.offlineTimeoutMinutes,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: report.badgeColor.withOpacity(0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Düğüm: $sId (${plant.name})",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: report.badgeColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        report.statusText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: report.badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  report.detailText,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const Divider(height: 18),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 8,
                                  children: [
                                    _buildMetricChip(
                                      "Son Paket",
                                      report.latencyText,
                                      textColor,
                                    ),
                                    _buildMetricChip(
                                      "Ham ADC",
                                      sensor?.rawAdc != null ? "${sensor!.rawAdc}" : "Yüzde Modu",
                                      textColor,
                                    ),
                                    _buildMetricChip(
                                      "ADC Kalibrasyon",
                                      "${config.dryAdcValue} (Kuru) / ${config.wetAdcValue} (Islak)",
                                      textColor,
                                    ),
                                    _buildMetricChip(
                                      "Pompa Yanıtı",
                                      pump.timedOut
                                          ? "ZAMAN AŞIMI (Hata)"
                                          : (pump.isPendingConfirmation
                                              ? "ESP32 Onayı Bekleniyor"
                                              : (pump.actualState ? "Çalışıyor" : "Hazır (Kapalı)")),
                                      pump.timedOut ? AppColors.statusCritical : textColor,
                                    ),
                                  ],
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
  }

  Widget _buildMetricChip(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}