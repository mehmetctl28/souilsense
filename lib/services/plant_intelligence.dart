import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../models/sensor_data.dart';
import '../constants/colors.dart';

class HealthScoreResult {
  final int score;
  final bool isFresh;
  final String label; // "Güncel Sağlık" veya "Son Bilinen Ölçüme Göre"

  const HealthScoreResult({
    required this.score,
    required this.isFresh,
    required this.label,
  });
}

class DryingRateAnalysis {
  final bool canPredict;
  final double? dropPerHour;
  final double? hoursUntilCritical;
  final String trendLabel; // "Düşüş Trendi", "Yükseliş Trendi", "Dengeli", "Yetersiz Veri"
  final String summary;

  const DryingRateAnalysis({
    required this.canPredict,
    this.dropPerHour,
    this.hoursUntilCritical,
    required this.trendLabel,
    required this.summary,
  });
}

class IntelligenceCardData {
  final String category; // Moisture Trend, Drying Rate, Watering Response vb.
  final String title;
  final String detail;
  final String badgeText;
  final Color color;
  final IconData icon;

  const IntelligenceCardData({
    required this.category,
    required this.title,
    required this.detail,
    required this.badgeText,
    required this.color,
    required this.icon,
  });
}

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
  final bool isSimulated;
  final Color badgeColor;

  const SensorDiagnosticReport({
    required this.statusText,
    required this.detailText,
    required this.latencyText,
    required this.isHealthy,
    this.isSimulated = false,
    required this.badgeColor,
  });
}

class PlantIntelligence {
  // 4.1: Veri tazeliğini kontrol eden Sağlık Skoru
  static HealthScoreResult evaluateHealthScore(
    Plant plant,
    SensorData? sensor, {
    int offlineTimeoutMinutes = 30,
  }) {
    final int score = calculateHealthScore(
      plant,
      sensor,
      offlineTimeoutMinutes: offlineTimeoutMinutes,
    );
    final bool isFresh =
        sensor != null && sensor.isOnlineWithThreshold(offlineTimeoutMinutes);

    return HealthScoreResult(
      score: score,
      isFresh: isFresh,
      label: isFresh
          ? "Güncel Sağlık: $score/100"
          : "Son Bilinen Ölçüme Göre: $score/100",
    );
  }

  static int calculateHealthScore(
    Plant plant,
    SensorData? sensor, {
    int offlineTimeoutMinutes = 30,
  }) {
    final double moisture = sensor?.moisture ?? plant.moistureLevel;
    final double temp = sensor?.temperature ?? plant.temperature;
    final double light = sensor?.light ?? plant.lightLevel;

    double moistureScore = 50.0;
    if (moisture < plant.minMoisture) {
      final diff = plant.minMoisture - moisture;
      moistureScore = (50.0 - (diff * 2.0)).clamp(0.0, 50.0);
    } else if (moisture > plant.maxMoisture) {
      final diff = moisture - plant.maxMoisture;
      moistureScore = (50.0 - (diff * 1.5)).clamp(10.0, 50.0);
    }

    double tempScore = 30.0;
    if (temp < plant.minTemp) {
      tempScore = (30.0 - ((plant.minTemp - temp) * 3.0)).clamp(0.0, 30.0);
    } else if (temp > plant.maxTemp) {
      tempScore = (30.0 - ((temp - plant.maxTemp) * 3.0)).clamp(0.0, 30.0);
    }

    double lightScore = 20.0;
    if (light < plant.minLight) {
      lightScore = (20.0 - (plant.minLight - light)).clamp(0.0, 20.0);
    } else if (light > plant.maxLight) {
      lightScore = (20.0 - ((light - plant.maxLight) * 0.8)).clamp(5.0, 20.0);
    }

    return (moistureScore + tempScore + lightScore).round().clamp(0, 100);
  }

  // 3.2: Gerçek Timestamp ve Gürültü (Noise) Kontrolüne Dayalı Kuruma Hızı Algoritması
  static DryingRateAnalysis analyzeDryingRate(
    List<TelemetryPoint> history,
    double currentMoisture,
    int minMoisture,
  ) {
    if (history.length < 2) {
      return const DryingRateAnalysis(
        canPredict: false,
        trendLabel: "Yetersiz Veri",
        summary: "Gerçek kuruma hızı hesabı için en az 2 zaman damgalı ölçüm gereklidir.",
      );
    }

    final sorted = List<TelemetryPoint>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final first = sorted.first;
    final last = sorted.last;
    final double elapsedHours = (last.timestamp - first.timestamp) / (1000.0 * 3600.0);

    // Gerçek zaman farkı çok kısaysa (örn: 1 dakikadan az) saatlik hız uydurma
    if (elapsedHours <= 0.016) {
      return const DryingRateAnalysis(
        canPredict: false,
        trendLabel: "Ölçüm Aralığı Kısa",
        summary: "Ölçümler arasındaki zaman farkı henüz saatlik kuruma tahmini için çok kısa.",
      );
    }

    // Ardışık ölçümler arasındaki yön değişimlerini (gürültü) kontrol et
    int upSteps = 0;
    int downSteps = 0;
    for (int i = 1; i < sorted.length; i++) {
      final stepDiff = sorted[i].moisture - sorted[i - 1].moisture;
      if (stepDiff > 1.5) upSteps++;
      if (stepDiff < -1.5) downSteps++;
    }

    final double netChange = last.moisture - first.moisture;

    // Nem yükseliyorsa (yeni sulanmışsa)
    if (netChange > 1.5) {
      return DryingRateAnalysis(
        canPredict: false,
        trendLabel: "Yükseliş Trendi (+%${netChange.toStringAsFixed(1)})",
        summary: "Toprak nemi yükseliyor (yakın zamanda sulama yapıldı). Kuruma tahmini bekleniyor.",
      );
    }

    // Gürültülü veri kontrolü: Hem sert yükseliş hem sert düşüş varsa
    if (upSteps > 0 && downSteps > 0 && (upSteps >= downSteps)) {
      return const DryingRateAnalysis(
        canPredict: false,
        trendLabel: "Dalgalı / Gürültülü Ölçüm",
        summary: "Sensör ölçümlerinde dalgalanma tespit edildi; kararlı kuruma eğrisi bekleniyor.",
      );
    }

    final double totalDrop = first.moisture - last.moisture;
    if (totalDrop <= 0.5) {
      return const DryingRateAnalysis(
        canPredict: false,
        trendLabel: "Sabit / Dengeli",
        summary: "İncelenen zaman aralığında anlamlı bir nem kaybı görülmedi.",
      );
    }

    final double dropPerHour = totalDrop / elapsedHours;

    if (currentMoisture <= minMoisture) {
      return DryingRateAnalysis(
        canPredict: true,
        dropPerHour: dropPerHour,
        hoursUntilCritical: 0,
        trendLabel: "Kritik Sınırın Altında",
        summary:
            "Saatlik kayıp: %${dropPerHour.toStringAsFixed(2)}/saat • Nem zaten alt sınırın (%$minMoisture) altında.",
      );
    }

    final double hoursRemaining = (currentMoisture - minMoisture) / dropPerHour;
    final String timeText = hoursRemaining >= 24
        ? "${(hoursRemaining / 24).toStringAsFixed(1)} gün (~${hoursRemaining.round()} sa)"
        : "~${hoursRemaining.round()} saat";

    return DryingRateAnalysis(
      canPredict: true,
      dropPerHour: dropPerHour,
      hoursUntilCritical: hoursRemaining,
      trendLabel: "Düşüş Hızı: -%${dropPerHour.toStringAsFixed(2)}/saat",
      summary:
          "Saatlik nem kaybı %${dropPerHour.toStringAsFixed(2)}. Bu hızla alt eşiğe (%$minMoisture) ulaşmasına $timeText kaldı.",
    );
  }

  // 4.2: Plant Intelligence 2.0 (6 Çekirdek Analiz Modülü)
  static List<IntelligenceCardData> buildIntelligenceV2({
    required Plant plant,
    required SensorData? sensor,
    required List<TelemetryPoint> history,
    WateringEffectivenessReport? wateringReport,
    int offlineTimeoutMinutes = 30,
  }) {
    final double moisture = sensor?.moisture ?? plant.moistureLevel;
    final double temp = sensor?.temperature ?? plant.temperature;
    final double light = sensor?.light ?? plant.lightLevel;

    final drying = analyzeDryingRate(history, moisture, plant.minMoisture);
    final reliability = diagnoseSensor(
      plant.sensorId,
      sensor,
      history: history,
      offlineTimeoutMinutes: offlineTimeoutMinutes,
    );

    final List<IntelligenceCardData> cards = [];

    // 1. Moisture Trend (Nem Trendi)
    cards.add(
      IntelligenceCardData(
        category: "Moisture Trend",
        title: "Nem Eğilimi ve Eşik Durumu",
        detail:
            "Anlık nem %${moisture.toInt()} (Hedef: %${plant.minMoisture}–%${plant.maxMoisture}). ${drying.trendLabel}.",
        badgeText: moisture < plant.minMoisture
            ? "DÜŞÜK"
            : (moisture > plant.maxMoisture ? "YÜKSEK" : "DENGELİ"),
        color: moisture < plant.minMoisture
            ? AppColors.statusCritical
            : (moisture > plant.maxMoisture ? Colors.orange : AppColors.statusGood),
        icon: Icons.trending_down,
      ),
    );

    // 2. Drying Rate (Toprak Kuruma Hızı)
    cards.add(
      IntelligenceCardData(
        category: "Drying Rate",
        title: "Toprak Kuruma Hızı Analizi",
        detail: drying.summary,
        badgeText: drying.canPredict && drying.dropPerHour != null
            ? "%${drying.dropPerHour!.toStringAsFixed(1)}/sa"
            : "BEKLENİYOR",
        color: drying.canPredict ? AppColors.primary : Colors.blueGrey,
        icon: Icons.hourglass_bottom,
      ),
    );

    // 3. Watering Response (Sulama Sonrası Nem Tepkisi)
    if (wateringReport != null) {
      cards.add(
        IntelligenceCardData(
          category: "Watering Response",
          title: "Sulama Sonrası Toprak Tepkisi",
          detail: wateringReport.summaryText,
          badgeText: wateringReport.isEffective
              ? "+%${wateringReport.delta.toInt()} ARTIŞ"
              : "DÜŞÜK ETKİ",
          color: wateringReport.isEffective ? AppColors.statusGood : AppColors.statusCritical,
          icon: Icons.water_drop,
        ),
      );
    } else {
      cards.add(
        const IntelligenceCardData(
          category: "Watering Response",
          title: "Sulama Sonrası Toprak Tepkisi",
          detail:
              "Henüz sulama öncesi ve sonrası karşılaştırma verisi oluşmadı. İlk sulamada toprak emilim oranı hesaplanacak.",
          badgeText: "VERİ YOK",
          color: Colors.grey,
          icon: Icons.water_drop_outlined,
        ),
      );
    }

    // 4. Sensor Reliability (Sensör Güvenilirliği)
    cards.add(
      IntelligenceCardData(
        category: "Sensor Reliability",
        title: "Sensör ve Veri Güvenilirliği",
        detail: "${reliability.detailText} (Son paket: ${reliability.latencyText}).",
        badgeText: reliability.statusText,
        color: reliability.badgeColor,
        icon: Icons.sensors,
      ),
    );

    // 5. Environmental Stress (Çevresel Stres: Sıcaklık & Işık)
    final bool tempStress = temp < plant.minTemp || temp > plant.maxTemp;
    final bool lightStress = light < plant.minLight || light > plant.maxLight;
    String envDetail;
    String envBadge;
    Color envColor;

    if (tempStress && lightStress) {
      envBadge = "ÇİFT STRES";
      envColor = AppColors.statusCritical;
      envDetail =
          "Hem sıcaklık (${temp.toStringAsFixed(1)}°C) hem de ışık (%${light.toInt()}) ${plant.type} referans sınırlarının dışında.";
    } else if (tempStress) {
      envBadge = "TERMAL STRES";
      envColor = Colors.orange;
      envDetail =
          "Ortam sıcaklığı (${temp.toStringAsFixed(1)}°C), ideal ${plant.minTemp.toInt()}–${plant.maxTemp.toInt()}°C aralığının dışında.";
    } else if (lightStress) {
      envBadge = "IŞIK STRESİ";
      envColor = Colors.amber.shade700;
      envDetail =
          "Işık seviyesi (%${light.toInt()}), ideal %${plant.minLight.toInt()}–%${plant.maxLight.toInt()} aralığının dışında.";
    } else {
      envBadge = "STRES YOK";
      envColor = AppColors.statusGood;
      envDetail =
          "Sıcaklık (${temp.toStringAsFixed(1)}°C) ve ışık (%${light.toInt()}) değerleri bitki üzerinde çevresel stres oluşturmuyor.";
    }

    cards.add(
      IntelligenceCardData(
        category: "Environmental Stress",
        title: "Çevresel Stres Değerlendirmesi",
        detail: envDetail,
        badgeText: envBadge,
        color: envColor,
        icon: Icons.wb_twilight,
      ),
    );

    // 6. Care Recommendation (Açıklanabilir Bakım Önerisi)
    String recDetail;
    String recBadge;
    Color recColor;

    if (!reliability.isHealthy && !reliability.isSimulated) {
      recBadge = "DONANIM KONTROLÜ";
      recColor = Colors.orange;
      recDetail =
          "Sensör verisi güncel veya kararlı değil. Sulama kararı vermeden önce ESP32 bağlantısını ve prob temasını doğrulayın.";
    } else if (moisture < plant.minMoisture) {
      recBadge = "SULAMA YAPIN";
      recColor = AppColors.statusCritical;
      recDetail =
          "Toprak nemi (%${moisture.toInt()}) alt sınırın (%${plant.minMoisture}) altında. Pompayı çalıştırın ve 30 dk sonra nem artışını kontrol edin.";
    } else if (moisture > plant.maxMoisture) {
      recBadge = "SULAMAYI DURDURUN";
      recColor = Colors.orange;
      recDetail =
          "Toprak doygunluğu (%${moisture.toInt()}) üst sınırın üzerinde. Kök havalanması için toprak kuruyana kadar bekleyin.";
    } else if (tempStress) {
      recBadge = "ORTAMI DENGELİYİN";
      recColor = Colors.orange;
      recDetail =
          "Nem dengeli ancak sıcaklık sınır dışında. Bitkiyi doğrudan klima/ısıtıcı akımından uzaklaştırın.";
    } else {
      recBadge = "RÜTİNİZİ KORUYUN";
      recColor = AppColors.statusGood;
      recDetail =
          "Tüm telemetri parametreleri ${plant.type} profiliyle uyumlu. Ek müdahaleye gerek yok.";
    }

    cards.add(
      IntelligenceCardData(
        category: "Care Recommendation",
        title: "Önerilen Bakım Aksiyonu",
        detail: recDetail,
        badgeText: recBadge,
        color: recColor,
        icon: Icons.task_alt,
      ),
    );

    return cards;
  }

  static List<TelemetryMetricCheck> evaluateParameters(
    Plant plant,
    SensorData? sensor, {
    int offlineTimeoutMinutes = 30,
  }) {
    final double moisture = sensor?.moisture ?? plant.moistureLevel;
    final double temp = sensor?.temperature ?? plant.temperature;
    final double light = sensor?.light ?? plant.lightLevel;

    final int? minsAgo = sensor != null
        ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(sensor.lastUpdate)).inMinutes
        : null;
    final bool isStale = sensor == null || !sensor.isOnlineWithThreshold(offlineTimeoutMinutes);

    final String syncNote = sensor == null
        ? "Sensör paketi yok (Varsayılan profil)."
        : (sensor.isSimulated
            ? "Simülasyon verisi aktif."
            : (isStale
                ? "Dikkat: Son veri $minsAgo dk önce alındı (Son bilinen ölçüm)."
                : "Sensör ${minsAgo! < 1 ? 'az önce' : '$minsAgo dk önce'} güncellendi."));

    final List<TelemetryMetricCheck> checks = [];

    final String moistureRange = "%${plant.minMoisture} – %${plant.maxMoisture}";
    if (moisture < plant.minMoisture) {
      checks.add(
        TelemetryMetricCheck(
          parameter: "Toprak Nemi (${plant.type})",
          measuredValue: "%${moisture.toInt()}",
          referenceRange: moistureRange,
          statusLabel: isStale ? "ESKİ VERİ / DÜŞÜK" : "KRİTİK DÜŞÜK",
          technicalNote:
              "Toprak nemi %${moisture.toInt()}. Bitkinin minimum gereksinimi %${plant.minMoisture}. $syncNote",
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
              "Toprak nemi üst sınırın (%${plant.maxMoisture}) üzerinde. $syncNote",
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
          statusLabel: isStale ? "SON BİLİNEN: İYİ" : "OPTİMAL",
          technicalNote: "Toprak nemi ${plant.type} profilinin ideal aralığında. $syncNote",
          statusColor: isStale ? Colors.orange : AppColors.statusGood,
          icon: Icons.water_drop_outlined,
        ),
      );
    }

    final String tempRange = "${plant.minTemp.toStringAsFixed(0)}°C – ${plant.maxTemp.toStringAsFixed(0)}°C";
    checks.add(
      TelemetryMetricCheck(
        parameter: "Ortam Sıcaklığı",
        measuredValue: "${temp.toStringAsFixed(1)}°C",
        referenceRange: tempRange,
        statusLabel: temp > plant.maxTemp
            ? "YÜKSEK"
            : (temp < plant.minTemp ? "DÜŞÜK" : "OPTİMAL"),
        technicalNote: (temp > plant.maxTemp || temp < plant.minTemp)
            ? "Ölçülen sıcaklık ${plant.type} referans sınırlarının ($tempRange) dışında."
            : "Termal koşullar bitki profiliyle uyumlu.",
        statusColor: (temp > plant.maxTemp || temp < plant.minTemp)
            ? Colors.orange
            : AppColors.statusGood,
        icon: Icons.thermostat_outlined,
      ),
    );

    final String lightRange = "%${plant.minLight.toInt()} – %${plant.maxLight.toInt()}";
    checks.add(
      TelemetryMetricCheck(
        parameter: "Işık Şiddeti",
        measuredValue: "%${light.toInt()}",
        referenceRange: lightRange,
        statusLabel: light < plant.minLight
            ? "DÜŞÜK"
            : (light > plant.maxLight ? "YÜKSEK" : "OPTİMAL"),
        technicalNote: (light < plant.minLight || light > plant.maxLight)
            ? "Işık maruziyeti referans aralığının ($lightRange) dışında."
            : "Günlük ışık seviyesi yeterli.",
        statusColor: (light < plant.minLight || light > plant.maxLight)
            ? Colors.amber.shade700
            : AppColors.statusGood,
        icon: Icons.wb_sunny_outlined,
      ),
    );

    return checks;
  }

  // 4.2: Ham ADC + Ardışık Uç Değerler + Donmuş Sensör (Flatline) Tanılaması
  static SensorDiagnosticReport diagnoseSensor(
    String sensorId,
    SensorData? sensor, {
    List<TelemetryPoint> history = const [],
    int offlineTimeoutMinutes = 30,
  }) {
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

    if (!sensor.isOnlineWithThreshold(offlineTimeoutMinutes)) {
      return SensorDiagnosticReport(
        statusText: "ÇEVRİMDIŞI",
        detailText:
            "ESP32 düğümü $offlineTimeoutMinutes dk eşiğinden uzun süredir veri göndermedi. Gösterilen sağlık puanı son bilinen ölçüme göredir.",
        latencyText: "$diffMinutes dk gecikme",
        isHealthy: false,
        isSimulated: sensor.isSimulated,
        badgeColor: AppColors.statusCritical,
      );
    }

    if (sensor.hasMissingFields) {
      return SensorDiagnosticReport(
        statusText: "EKSİK PAKET",
        detailText: "Sensör paketinde nem veya ADC alanı eksik gönderildi.",
        latencyText: "$diffMinutes dk önce",
        isHealthy: false,
        isSimulated: sensor.isSimulated,
        badgeColor: Colors.orange,
      );
    }

    // 1. Ham ADC kısa devre / açık devre kontrolü + ardışık uç değer kontrolü
    final bool extremeAdc =
        sensor.rawAdc != null && (sensor.rawAdc! < 100 || sensor.rawAdc! > 4000);
    final int recentExtremeCount = history.length >= 3
        ? history
            .sublist(history.length - 3)
            .where((p) => p.moisture <= 1.0 || p.moisture >= 99.0)
            .length
        : 0;

    if (extremeAdc || recentExtremeCount >= 3) {
      return SensorDiagnosticReport(
        statusText: "KALİBRASYON / PROB UYARISI",
        detailText: extremeAdc
            ? "Ham ADC (${sensor.rawAdc}) fiziksel sınır dışında. Prob teması veya kablo kontrol edilmeli."
            : "Ardışık 3 ölçüm uç değerde (%0 veya %100) kilitlendi. Kalibrasyon aralığını doğrulayın.",
        latencyText: diffMinutes < 1 ? "Anlık" : "$diffMinutes dk önce",
        isHealthy: false,
        isSimulated: sensor.isSimulated,
        badgeColor: Colors.orange,
      );
    }

    // 2. Uzun süre hiç değişmeyen (Donmuş / Flatline) sensör kontrolü
    if (history.length >= 5) {
      final tail = history.sublist(history.length - 5);
      final spanMinutes = (tail.last.timestamp - tail.first.timestamp) / (1000.0 * 60.0);
      final allIdentical = tail.every(
        (p) =>
            (p.moisture - tail.first.moisture).abs() < 0.01 &&
            (p.temperature - tail.first.temperature).abs() < 0.01,
      );
      if (spanMinutes >= 30 && allIdentical) {
        return SensorDiagnosticReport(
          statusText: "SABİT / DONMUŞ VERİ",
          detailText:
              "Son 5 ölçümde (${spanMinutes.round()} dk boyunca) nem ve sıcaklık hiç değişmedi. Sensör okuma döngüsünü kontrol edin.",
          latencyText: "$diffMinutes dk önce",
          isHealthy: false,
          isSimulated: sensor.isSimulated,
          badgeColor: Colors.orange,
        );
      }
    }

    return SensorDiagnosticReport(
      statusText: sensor.isSimulated ? "SİMÜLASYON AKTİF" : "DONANIM AKTİF",
      detailText: sensor.isSimulated
          ? "Uygulama içi sanal test verisi aktif."
          : "ESP32 telemetri veri akışı, ADC aralığı ve ölçüm varyansı normal.",
      latencyText: diffMinutes < 1 ? "Anlık (<1 dk)" : "$diffMinutes dk önce",
      isHealthy: true,
      isSimulated: sensor.isSimulated,
      badgeColor: sensor.isSimulated ? Colors.blue : AppColors.statusGood,
    );
  }

  static int calculateGardenAverageScore(
    List<Plant> plants,
    Map<String, SensorData> sensors, {
    int offlineTimeoutMinutes = 30,
  }) {
    if (plants.isEmpty) return 100;
    int total = 0;
    for (final p in plants) {
      total += calculateHealthScore(
        p,
        sensors[p.sensorId],
        offlineTimeoutMinutes: offlineTimeoutMinutes,
      );
    }
    return (total / plants.length).round();
  }
}