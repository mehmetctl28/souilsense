class SensorConfig {
  final String sensorId;
  final int dryAdcValue; // Kuru toprak ham ADC (Örn: 3200)
  final int wetAdcValue; // Islak toprak ham ADC (Örn: 1400)
  final int readIntervalSeconds;
  final int maxPumpSeconds;

  const SensorConfig({
    required this.sensorId,
    this.dryAdcValue = 3200,
    this.wetAdcValue = 1400,
    this.readIntervalSeconds = 60,
    this.maxPumpSeconds = 15,
  });

  // Ham ADC değerini kalibrasyon sınırlarına göre %0-%100 nem değerine dönüştürür
  double convertAdcToMoisture(int rawAdc) {
    final span = (dryAdcValue - wetAdcValue).abs();
    if (span == 0) return 50.0;
    final normalized = ((dryAdcValue - rawAdc) / span) * 100.0;
    return normalized.clamp(0.0, 100.0);
  }

  factory SensorConfig.fromMap(String sensorId, Map<dynamic, dynamic> map) {
    return SensorConfig(
      sensorId: sensorId,
      dryAdcValue: SensorData.parseSafeInt(map['dryAdcValue'], fallback: 3200),
      wetAdcValue: SensorData.parseSafeInt(map['wetAdcValue'], fallback: 1400),
      readIntervalSeconds: SensorData.parseSafeInt(map['readIntervalSeconds'], fallback: 60),
      maxPumpSeconds: SensorData.parseSafeInt(map['maxPumpSeconds'], fallback: 15),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dryAdcValue': dryAdcValue,
      'wetAdcValue': wetAdcValue,
      'readIntervalSeconds': readIntervalSeconds,
      'maxPumpSeconds': maxPumpSeconds,
    };
  }
}

class TelemetryPoint {
  final int timestamp;
  final double moisture;
  final double temperature;
  final double light;

  const TelemetryPoint({
    required this.timestamp,
    required this.moisture,
    required this.temperature,
    required this.light,
  });

  factory TelemetryPoint.fromMap(int timestamp, Map<dynamic, dynamic> map) {
    return TelemetryPoint(
      timestamp: timestamp,
      moisture: SensorData.parseSafeDouble(map['moisture'], fallback: 0.0).clamp(0.0, 100.0),
      temperature: SensorData.parseSafeDouble(map['temperature'], fallback: 24.0),
      light: SensorData.parseSafeDouble(map['light'], fallback: 60.0).clamp(0.0, 100.0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moisture': moisture,
      'temperature': temperature,
      'light': light,
    };
  }
}

class WateringEffectivenessReport {
  final String sensorId;
  final double preMoisture;
  final double postMoisture;
  final int timestamp;

  const WateringEffectivenessReport({
    required this.sensorId,
    required this.preMoisture,
    required this.postMoisture,
    required this.timestamp,
  });

  double get delta => postMoisture - preMoisture;
  bool get isEffective => delta >= 5.0;

  String get summaryText {
    if (isEffective) {
      return "Sulama öncesi %${preMoisture.toInt()} → Sonrası %${postMoisture.toInt()} (+\%${delta.toInt()} artış, kök emilimi doğrulandı).";
    }
    return "Pompa çalıştı (%${preMoisture.toInt()} → \%${postMoisture.toInt()}) ancak beklenen nem artışı görülmedi. Su deposunu ve hortumu kontrol edin.";
  }
}

class SensorData {
  final String sensorId;
  final double moisture;
  final double temperature;
  final double light;
  final int? rawAdc;
  final int lastUpdate;
  final bool isSimulated;
  final bool hasMissingFields;

  SensorData({
    required this.sensorId,
    required this.moisture,
    required this.temperature,
    required this.light,
    this.rawAdc,
    required this.lastUpdate,
    this.isSimulated = false,
    this.hasMissingFields = false,
  });

  static double parseSafeDouble(dynamic value, {required double fallback}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.').trim()) ?? fallback;
    }
    return fallback;
  }

  static int parseSafeInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  static int normalizeTimestamp(dynamic rawTimestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final parsed = parseSafeInt(rawTimestamp, fallback: 0);
    if (parsed <= 0) return 0; // Eksik zaman damgasını gizlemez, 0 olarak işaretler
    if (parsed < 1577836800000) {
      if (parsed > 1577836800) return parsed * 1000;
      return now;
    }
    return parsed;
  }

  factory SensorData.fromMap(
    String sensorId,
    Map<dynamic, dynamic> map, {
    SensorConfig? config,
    bool isSimulated = false,
  }) {
    final int? adc = map['rawAdc'] != null ? parseSafeInt(map['rawAdc'], fallback: 0) : null;
    final bool missing = map['moisture'] == null && adc == null;

    double resolvedMoisture;
    if (adc != null && config != null) {
      resolvedMoisture = config.convertAdcToMoisture(adc);
    } else {
      resolvedMoisture = parseSafeDouble(map['moisture'], fallback: 0.0).clamp(0.0, 100.0);
    }

    final normalizedTs = normalizeTimestamp(map['lastUpdate']);

    return SensorData(
      sensorId: sensorId,
      moisture: resolvedMoisture,
      temperature: parseSafeDouble(map['temperature'], fallback: 24.0),
      light: parseSafeDouble(map['light'], fallback: 60.0).clamp(0.0, 100.0),
      rawAdc: adc,
      lastUpdate: normalizedTs > 0 ? normalizedTs : DateTime.now().millisecondsSinceEpoch,
      isSimulated: isSimulated || map['isSimulated'] == true,
      hasMissingFields: missing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moisture': moisture,
      'temperature': temperature,
      'light': light,
      if (rawAdc != null) 'rawAdc': rawAdc,
      'lastUpdate': lastUpdate,
      'isSimulated': isSimulated,
    };
  }

  bool isOnlineWithThreshold(int timeoutMinutes) {
    if (lastUpdate <= 0) return false;
    final difference = DateTime.now().millisecondsSinceEpoch - lastUpdate;
    return difference < timeoutMinutes * 60 * 1000;
  }

  bool get isOnline => isOnlineWithThreshold(30);
}