import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../models/sensor_data.dart';
import '../constants/colors.dart';

class TelemetryMetricCheck {
  final String parameter;
  final String measuredValue;
  final String referenceRange;
  final String statusLabel;
  final String technicalNote;
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
  // 2.E: Bitkinin kendi profiline göre 100 üzerinden bilimsel sağlık skoru
  static int calculateHealthScore(Plant plant, SensorData? sensor) {
    final double moisture = sensor?.moisture ?? plant.moistureLevel;
    final double temp = sensor?.temperature ?? plant.temperature;
    final double light = sensor?.light ?? plant.lightLevel;

    // 1. Nem Uyumu (Max 50p -> plant.minMoisture ile plant.maxMoisture arası)
    double moistureScore = 50.0;
    if (moisture < plant.minMoisture) {
      final diff = plant.minMoisture - moisture;
      moistureScore = (50.0 - (diff * 2.0)).clamp(0.0, 50.0);
    } else if (moisture > plant.maxMoisture) {
      final diff = moisture - plant.maxMoisture;
      moistureScore = (50.0 - (diff * 1.5)).clamp(10.0, 50.0);
    }

    // 2. Sıcaklık Uyumu (Max 30p -> plant.minTemp ile plant.maxTemp arası)
    double tempScore = 30.0;
    if (temp < plant.minTemp) {
      tempScore = (30.0 - ((plant.minTemp - temp) * 3.0)).clamp(0.0, 30.0);
    } else if (temp > plant.maxTemp) {
      tempScore = (30.0 - ((temp - plant.maxTemp) * 3.0)).clamp(0.0, 30.0);
    }

    // 3. Işık Uyumu (Max 20p -> plant.minLight ile plant.maxLight arası)
    double lightScore = 20.0;
    if (light < plant.minLight) {
      lightScore = (20.0 - (plant.minLight - light)).clamp(0.0, 20.0);
    } else if (light > plant.maxLight) {
      lightScore = (20.0 - ((light - plant.maxLight) * 0.8)).clamp(5.0, 20.0);
    }

    return (moistureScore + tempScore + lightScore).round().clamp(0, 100);
  }

  // 2.E & 3.2: Bitkiye özel referans aralıklarıyla açıklayıcı parametre değerlendirmesi
  static List<TelemetryMetricCheck> evaluateParameters(Plant plant, SensorData? sensor) {
    final double moisture = sensor?.moisture ?? plant.moistureLevel;
    final double temp = sensor?.temperature ?? plant.temperature;
    final double light = sensor?.light ?? plant.lightLevel;

    final int? minsAgo = sensor != null
        ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(sensor.lastUpdate)).inMinutes
        : null;
    final String syncNote = minsAgo == null
        ? "Varsayılan kayıt değeri."
        : (minsAgo < 1 ? "Sensör az önce güncellendi." : "Sensör $minsAgo dk önce güncellendi.");

    final List<TelemetryMetricCheck> checks = [];

    // A. Toprak Nemi
    final String moistureRange = "%${plant.minMoisture} – %${plant.maxMoisture}";
    if (moisture < plant.minMoisture) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Toprak Nemi (${plant.type})",
          measuredValue: "%${moisture.toInt()}",
          referenceRange: moistureRange,
          statusLabel: "KRİTİK DÜŞÜK",
          technicalNote:
              "Toprak nemi %${moisture.toInt()}. Bitkinin minimum gereksinimi %${plant.minMoisture}. $syncNote Sulama önerilir.",
          statusColor: AppColors.statusCritical,
          icon: Icons.water_drop_outlined,
        ),
      );
    } else if (moisture > plant.maxMoisture) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Toprak Nemi (${plant.type})",
          measuredValue: "%${moisture.toInt()}",
          referenceRange: moistureRange,
          statusLabel: "YÜKSEK",
          technicalNote:
              "Toprak nemi üst sınırın (%${plant.maxMoisture}) üzerinde. $syncNote Toprak kuruyana kadar sulama yapılmamalı.",
          statusColor: Colors.orange,
          icon: Icons.water_drop_outlined,
        ),
      );
    } else {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Toprak Nemi (${plant.type})",
          measuredValue: "%${moisture.toInt()}",
          referenceRange: moistureRange,
          statusLabel: "OPTİMAL",
          technicalNote: "Toprak nemi ${plant.type} profilinin ideal aralığında. $syncNote",
          statusColor: AppColors.statusGood,
          icon: Icons.water_drop_outlined,
        ),
      );
    }

    // B. Ortam Sıcaklığı
    final String tempRange = "${plant.minTemp.toStringAsFixed(0)}°C – ${plant.maxTemp.toStringAsFixed(0)}°C";
    if (temp > plant.maxTemp) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Ortam Sıcaklığı",
          measuredValue: "${temp.toStringAsFixed(1)}°C",
          referenceRange: tempRange,
          statusLabel: "YÜKSEK",
          technicalNote:
              "Sıcaklık ${plant.type} için önerilen ${plant.maxTemp.toStringAsFixed(0)}°C sınırının üzerinde. Buharlaşma hızı artabilir.",
          statusColor: Colors.orange,
          icon: Icons.thermostat_outlined,
        ),
      );
    } else if (temp < plant.minTemp) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Ortam Sıcaklığı",
          measuredValue: "${temp.toStringAsFixed(1)}°C",
          referenceRange: tempRange,
          statusLabel: "DÜŞÜK",
          technicalNote:
              "Sıcaklık ${plant.type} için minimum ${plant.minTemp.toStringAsFixed(0)}°C sınırının altında.",
          statusColor: Colors.blue,
          icon: Icons.thermostat_outlined,
        ),
      );
    } else {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Ortam Sıcaklığı",
          measuredValue: "${temp.toStringAsFixed(1)}°C",
          referenceRange: tempRange,
          statusLabel: "OPTİMAL",
          technicalNote: "Sıcaklık değeri bitki profiliyle tam uyumlu.",
          statusColor: AppColors.statusGood,
          icon: Icons.thermostat_outlined,
        ),
      );
    }

    // C. Işık Şiddeti
    final String lightRange = "%${plant.minLight.toInt()} – %${plant.maxLight.toInt()}";
    if (light < plant.minLight) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Işık Şiddeti",
          measuredValue: "%${light.toInt()}",
          referenceRange: lightRange,
          statusLabel: "DÜŞÜK",
          technicalNote:
              "Işık seviyesi ${plant.type} için gereken minimum %${plant.minLight.toInt()} değerinin altında.",
          statusColor: Colors.amber.shade700,
          icon: Icons.wb_sunny_outlined,
        ),
      );
    } else if (light > plant.maxLight) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Işık Şiddeti",
          measuredValue: "%${light.toInt()}",
          referenceRange: lightRange,
          statusLabel: "YÜKSEK",
          technicalNote:
              "Işık seviyesi maksimum %${plant.maxLight.toInt()} sınırının üzerinde. Doğrudan güneş yaprak yanığı yapabilir.",
          statusColor: Colors.orange,
          icon: Icons.wb_sunny_outlined,
        ),
      );
    } else {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Işık Şiddeti",
          measuredValue: "%${light.toInt()}",
          referenceRange: lightRange,
          statusLabel: "OPTİMAL",
          technicalNote: "Günlük ışık seviyesi bitki profiliyle uyumlu.",
          statusColor: AppColors.statusGood,
          icon: Icons.wb_sunny_outlined,
        ),
      );
    }

    return checks;
  }

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
        statusText: "BEKLENİYOR",
        detailText: "'$sensorId' düğümünden henüz telemetri paketi alınmadı.",
        latencyText: "Veri yok",
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