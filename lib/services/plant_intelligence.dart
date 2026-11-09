import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../models/sensor_data.dart';
import '../constants/colors.dart';

class TelemetryMetricCheck {
  final String parameter; // Toprak Nemi, Ortam Sıcaklığı, Işık Şiddeti
  final String measuredValue; // %20, 24.0°C vb.
  final String referenceRange; // %30 - %80, 18°C - 28°C vb.
  final String statusLabel; // OPTİMAL, KRİTİK DÜŞÜK, YÜKSEK
  final String technicalNote; // Kısa teknik açıklama
  final Color statusColor;
  final IconData icon;

  const TelemetryMetricCheck({
    required this.parameter,
    required this.measuredValue,
    required this.referenceRange,
    required this.statusLabel,
    required this.technicalNote,
    required this.statusColor,
    required this.icon,
  });
}

class SensorDiagnosticReport {
  final String statusText;
  final String detailText;
  final String latencyText;
  final bool isHealthy;
  final Color badgeColor;

  const SensorDiagnosticReport({
    required this.statusText,
    required this.detailText,
    required this.latencyText,
    required this.isHealthy,
    required this.badgeColor,
  });
}

class PlantIntelligence {
  // 1. TEKNİK UYUM PUANI (Nem: 50p, Sıcaklık: 30p, Işık: 20p = Toplam 100p)
  static int calculateHealthScore(Plant plant, SensorData? sensor) {
    final double moisture = sensor?.moisture ?? plant.moistureLevel;
    final double temp = sensor?.temperature ?? plant.temperature;
    final double light = sensor?.light ?? plant.lightLevel;

    // Nem Puanı (Max 50)
    double moistureScore = 50.0;
    if (moisture < plant.minMoisture) {
      final diff = plant.minMoisture - moisture;
      moistureScore = (50.0 - (diff * 2.0)).clamp(0.0, 50.0);
    } else if (moisture > 80.0) {
      final diff = moisture - 80.0;
      moistureScore = (50.0 - (diff * 1.5)).clamp(10.0, 50.0);
    }

    // Sıcaklık Puanı (Max 30, Referans: 18°C - 28°C)
    double tempScore = 30.0;
    if (temp < 18.0) {
      tempScore = (30.0 - ((18.0 - temp) * 3.0)).clamp(0.0, 30.0);
    } else if (temp > 28.0) {
      tempScore = (30.0 - ((temp - 28.0) * 3.0)).clamp(0.0, 30.0);
    }

    // Işık Puanı (Max 20, Referans: %25 - %85)
    double lightScore = 20.0;
    if (light < 25.0) {
      lightScore = (20.0 - (25.0 - light)).clamp(0.0, 20.0);
    } else if (light > 85.0) {
      lightScore = (20.0 - ((light - 85.0) * 0.8)).clamp(5.0, 20.0);
    }

    return (moistureScore + tempScore + lightScore).round().clamp(0, 100);
  }

  // 2. PARAMETRE BAZLI TEKNİK TANILAMA TABLOSU
  static List<TelemetryMetricCheck> evaluateParameters(Plant plant, SensorData? sensor) {
    final double moisture = sensor?.moisture ?? plant.moistureLevel;
    final double temp = sensor?.temperature ?? plant.temperature;
    final double light = sensor?.light ?? plant.lightLevel;

    final List<TelemetryMetricCheck> checks = [];

    // A. Toprak Nemi Analizi
    if (moisture < plant.minMoisture) {
      final deficit = (plant.minMoisture - moisture).toInt();
      checks.add(
        TelemetryMetricCheck(
          parameter: "Toprak Nemi",
          measuredValue: "%${moisture.toInt()}",
          referenceRange: "%${plant.minMoisture} – %80",
          statusLabel: "KRİTİK DÜŞÜK",
          technicalNote: "Alt eşik değerinin %$deficit altında. Sulama döngüsü başlatılmalı.",
          statusColor: AppColors.statusCritical,
          icon: Icons.water_drop_outlined,
        ),
      );
    } else if (moisture > 80.0) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Toprak Nemi",
          measuredValue: "%${moisture.toInt()}",
          referenceRange: "%${plant.minMoisture} – %80",
          statusLabel: "DOYGUN / YÜKSEK",
          technicalNote: "Toprak su doygunluğu yüksek. Drenaj kontrol edilmeli, sulama kapalı tutulmalı.",
          statusColor: Colors.orange,
          icon: Icons.water_drop_outlined,
        ),
      );
    } else {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Toprak Nemi",
          measuredValue: "%${moisture.toInt()}",
          referenceRange: "%${plant.minMoisture} – %80",
          statusLabel: "OPTİMAL",
          technicalNote: "Nem seviyesi belirlenen referans sınırları içerisinde.",
          statusColor: AppColors.statusGood,
          icon: Icons.water_drop_outlined,
        ),
      );
    }

    // B. Ortam Sıcaklığı Analizi
    if (temp > 28.0) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Ortam Sıcaklığı",
          measuredValue: "${temp.toStringAsFixed(1)}°C",
          referenceRange: "18.0°C – 28.0°C",
          statusLabel: "YÜKSEK",
          technicalNote: "Yüksek sıcaklık nedeniyle topraktaki buharlaşma hızı artabilir.",
          statusColor: Colors.orange,
          icon: Icons.thermostat_outlined,
        ),
      );
    } else if (temp < 18.0) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Ortam Sıcaklığı",
          measuredValue: "${temp.toStringAsFixed(1)}°C",
          referenceRange: "18.0°C – 28.0°C",
          statusLabel: "DÜŞÜK",
          technicalNote: "Sıcaklık referans değerin altında. Kök su tüketimi yavaşlayabilir.",
          statusColor: Colors.blue,
          icon: Icons.thermostat_outlined,
        ),
      );
    } else {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Ortam Sıcaklığı",
          measuredValue: "${temp.toStringAsFixed(1)}°C",
          referenceRange: "18.0°C – 28.0°C",
          statusLabel: "OPTİMAL",
          technicalNote: "Termal koşullar bitki gelişimi için standart aralıkta.",
          statusColor: AppColors.statusGood,
          icon: Icons.thermostat_outlined,
        ),
      );
    }

    // C. Işık Şiddeti Analizi
    if (light < 25.0) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Işık Şiddeti",
          measuredValue: "%${light.toInt()}",
          referenceRange: "%25 – %85",
          statusLabel: "YETERSİZ",
          technicalNote: "Günlük ışık maruziyeti düşük.",
          statusColor: Colors.amber.shade700,
          icon: Icons.wb_sunny_outlined,
        ),
      );
    } else {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Işık Şiddeti",
          measuredValue: "%${light.toInt()}",
          referenceRange: "%25 – %85",
          statusLabel: "OPTİMAL",
          technicalNote: "Işık seviyesi yeterli düzeyde.",
          statusColor: AppColors.statusGood,
          icon: Icons.wb_sunny_outlined,
        ),
      );
    }

    return checks;
  }

  // 3. DONANIM VE SENSÖR TANILAMA (Sensor Diagnostics)
  static SensorDiagnosticReport diagnoseSensor(String sensorId, SensorData? sensor) {
    if (sensorId.isEmpty) {
      return const SensorDiagnosticReport(
        statusText: "ATANMAMIŞ",
        detailText: "Kayıtlı sensör kimliği bulunmuyor.",
        latencyText: "-",
        isHealthy: false,
        badgeColor: Colors.grey,
      );
    }

    if (sensor == null) {
      return SensorDiagnosticReport(
        statusText: "VERİ YOK",
        detailText: "'$sensorId' düğümünden paket alınamadı.",
        latencyText: "Bekleniyor",
        isHealthy: false,
        badgeColor: Colors.orange,
      );
    }

    final diffMinutes = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(sensor.lastUpdate))
        .inMinutes;

    if (diffMinutes > 30) {
      return SensorDiagnosticReport(
        statusText: "ÇEVRİMDIŞI",
        detailText: "ESP32 düğümü 30 dakikadan uzun süredir paket göndermedi.",
        latencyText: "$diffMinutes dk gecikme",
        isHealthy: false,
        badgeColor: AppColors.statusCritical,
      );
    }

    if (sensor.moisture <= 1.0 || sensor.moisture >= 99.0) {
      return SensorDiagnosticReport(
        statusText: "KALİBRASYON UYARISI",
        detailText: "Sensör uç değer (%${sensor.moisture.toInt()}) okuyor. Prob temasını kontrol edin.",
        latencyText: diffMinutes < 1 ? "< 1 dk" : "$diffMinutes dk önce",
        isHealthy: false,
        badgeColor: Colors.orange,
      );
    }

    return SensorDiagnosticReport(
      statusText: "AKTİF",
      detailText: "Telemetri veri akışı ve kalibrasyon değerleri normal.",
      latencyText: diffMinutes < 1 ? "Anlık (<1 dk)" : "$diffMinutes dk önce",
      isHealthy: true,
      badgeColor: AppColors.statusGood,
    );
  }

  // 4. BAHÇE GENEL UYUM ORTALAMASI
  static int calculateGardenAverageScore(
    List<Plant> plants,
    Map<String, SensorData> sensors,
  ) {
    if (plants.isEmpty) return 100;
    int total = 0;
    for (final p in plants) {
      total += calculateHealthScore(p, sensors[p.sensorId]);
    }
    return (total / plants.length).round();
  }
}