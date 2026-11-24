class SensorConfig {
  final String sensorId;
  final int dryAdcValue;
  final int wetAdcValue;
  final int readIntervalSeconds;
  final int maxPumpSeconds;

  const SensorConfig({
    required this.sensorId,
    this.dryAdcValue = 3200,
    this.wetAdcValue = 1400,
    this.readIntervalSeconds = 60,
    this.maxPumpSeconds = 15,
  });

  bool get isValid =>
      dryAdcValue >= 0 &&
      dryAdcValue <= 4095 &&
      wetAdcValue >= 0 &&
      wetAdcValue <= 4095 &&
      (dryAdcValue - wetAdcValue).abs() >= 200 &&
      maxPumpSeconds >= 1 &&
      maxPumpSeconds <= 30 &&
      readIntervalSeconds >= 1 &&
      readIntervalSeconds <= 3600;

  double convertAdcToMoisture(int rawAdc) {
    final span = dryAdcValue - wetAdcValue;
    if (!isValid) return double.nan;
    final normalized = ((dryAdcValue - rawAdc) / span) * 100.0;
    return normalized.clamp(0.0, 100.0);
  }

  factory SensorConfig.fromMap(String sensorId, Map<dynamic, dynamic> map) {
    return SensorConfig(
      sensorId: sensorId,
      dryAdcValue: SensorData.parseSafeInt(map['dryAdcValue'], fallback: 3200),
      wetAdcValue: SensorData.parseSafeInt(map['wetAdcValue'], fallback: 1400),
      readIntervalSeconds:
          SensorData.parseSafeInt(map['readIntervalSeconds'], fallback: 60),
      maxPumpSeconds:
          SensorData.parseSafeInt(map['maxPumpSeconds'], fallback: 15),
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
      moisture: SensorData.parseSafeDouble(map['moisture'], fallback: 0.0)
          .clamp(0.0, 100.0),
      temperature:
          SensorData.parseSafeDouble(map['temperature'], fallback: 24.0),
      light: SensorData.parseSafeDouble(map['light'], fallback: 60.0)
          .clamp(0.0, 100.0),
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
      return "Sulama öncesi %${preMoisture.toInt()} -> Sonrası %${postMoisture.toInt()} (+%${delta.toInt()} artış, kök emilimi doğrulandı).";
    }
    return "Pompa çalıştı (%${preMoisture.toInt()} -> %${postMoisture.toInt()}) ancak beklenen nem artışı görülmedi. Su deposunu ve hortumu kontrol edin.";
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
  final int protocolVersion;

  SensorData({
    required this.sensorId,
    required this.moisture,
    required this.temperature,
    required this.light,
    this.rawAdc,
    required this.lastUpdate,
    this.isSimulated = false,
    this.hasMissingFields = false,
    this.protocolVersion = 0,
  });

  static double? finiteNumber(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value.replaceAll(',', '.').trim())
            : null;
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static double parseSafeDouble(dynamic value, {required double fallback}) =>
      finiteNumber(value) ?? fallback;

  static int parseSafeInt(dynamic value, {required int fallback}) {
    final n = finiteNumber(value);
    return n != null && n == n.truncateToDouble() ? n.toInt() : fallback;
  }

  /// Accept plausible Unix seconds or milliseconds; never invent a receipt time.
  static int normalizeTimestamp(dynamic rawTimestamp) {
    final parsed = parseSafeInt(rawTimestamp, fallback: 0);
    if (parsed >= 1577836800 && parsed <= 4102444800) return parsed * 1000;
    if (parsed >= 1577836800000 && parsed <= 4102444800000) return parsed;
    return 0;
  }

  factory SensorData.fromMap(
    String sensorId,
    Map<dynamic, dynamic> map, {
    SensorConfig? config,
    bool isSimulated = false,
  }) {
    final raw = finiteNumber(map['rawAdc']);
    final adcValid =
        raw != null && raw == raw.truncateToDouble() && raw >= 0 && raw <= 4095;
    final adc = adcValid ? raw.toInt() : null;
    final moisture = finiteNumber(map['moisture']);
    final temp = finiteNumber(map['temperature']);
    final light = finiteNumber(map['light']);
    final useAdc = map.containsKey('rawAdc') && config != null;
    final moistureValid = useAdc
        ? adcValid && config.isValid
        : moisture != null && moisture >= 0 && moisture <= 100;
    final valid = moistureValid &&
        temp != null &&
        temp >= -50 &&
        temp <= 100 &&
        light != null &&
        light >= 0 &&
        light <= 100 &&
        (!map.containsKey('rawAdc') || adcValid);
    return SensorData(
      sensorId: sensorId,
      moisture: useAdc && moistureValid
          ? config.convertAdcToMoisture(adc!)
          : moistureValid
              ? moisture!
              : 0,
      temperature: temp ?? 0,
      light: light ?? 0,
      rawAdc: adc,
      lastUpdate: normalizeTimestamp(map['lastUpdate']),
      isSimulated: isSimulated || map['isSimulated'] == true,
      hasMissingFields: !valid,
      protocolVersion: parseSafeInt(map['protocolVersion'], fallback: 0),
    );
  }

  bool get isValidMeasurement =>
      !hasMissingFields &&
      moisture.isFinite &&
      moisture >= 0 &&
      moisture <= 100 &&
      temperature.isFinite &&
      temperature >= -50 &&
      temperature <= 100 &&
      light.isFinite &&
      light >= 0 &&
      light <= 100;

  Map<String, dynamic> toMap() {
    return {
      'moisture': moisture,
      'temperature': temperature,
      'light': light,
      if (rawAdc != null) 'rawAdc': rawAdc,
      'lastUpdate': lastUpdate,
      'isSimulated': isSimulated,
      'protocolVersion': protocolVersion,
    };
  }

  bool isOnlineWithThreshold(int timeoutMinutes) {
    if (lastUpdate <= 0 || !isValidMeasurement) return false;
    final difference = DateTime.now().millisecondsSinceEpoch - lastUpdate;
    if (difference < 0) return false;
    return difference < timeoutMinutes * 60 * 1000;
  }

  bool get isOnline => isOnlineWithThreshold(30);
}
